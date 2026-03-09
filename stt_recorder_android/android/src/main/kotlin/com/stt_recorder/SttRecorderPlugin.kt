package com.stt_recorder

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

private const val METHOD_CHANNEL = "stt_recorder"
private const val EVENT_CHANNEL = "stt_recorder/events"
private const val SPEECH_UNAVAILABLE_MARKER = "__speech_unavailable__"
private const val SPEECH_ERROR_PREFIX = "__speech_error__:"

class SttRecorderPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    RecognitionListener {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var speechRecognizer: SpeechRecognizer? = null
    private var recognitionIntent: Intent? = null
    private var usingExternalAudioForStt = false
    private var sttAudioReadFd: ParcelFileDescriptor? = null
    private var sttAudioWriteFd: ParcelFileDescriptor? = null
    private var sttAudioOutputStream: ParcelFileDescriptor.AutoCloseOutputStream? = null

    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    private var fileOutputStream: FileOutputStream? = null

    private var wavFile: File? = null
    private var writtenBytes: Long = 0
    @Volatile private var isCapturing = false

    private val sampleRate = 16_000
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO
    private val audioEncoding = AudioFormat.ENCODING_PCM_16BIT

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "startCapture" -> {
                val localeId = call.argument<String>("localeId") ?: "en_US"
                startCapture(localeId, result)
            }

            "stopCapture" -> stopCapture(result)
            "cancelCapture" -> cancelCapture(result)
            else -> result.notImplemented()
        }
    }

    private fun startCapture(localeId: String, result: MethodChannel.Result) {
        if (isCapturing) {
            result.error("already_capturing", "Capture already started", null)
            return
        }
        if (!hasRecordAudioPermission()) {
            result.error("permission_denied", "RECORD_AUDIO permission is required", null)
            return
        }

        try {
            val supportsExternalAudioForStt = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
            if (supportsExternalAudioForStt) {
                val pipe = ParcelFileDescriptor.createPipe()
                sttAudioReadFd = pipe[0]
                sttAudioWriteFd = pipe[1]
                sttAudioOutputStream = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])
            }

            val file = File(
                appContext.cacheDir,
                "voice-capture-${System.currentTimeMillis()}.wav",
            )
            val stream = FileOutputStream(file)
            stream.write(ByteArray(44)) // Placeholder header.

            val minBufferSize = AudioRecord.getMinBufferSize(
                sampleRate,
                channelConfig,
                audioEncoding,
            )
            val bufferSize = if (minBufferSize > 0) minBufferSize * 2 else 8192

            val recorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                audioEncoding,
                bufferSize,
            )

            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                stream.close()
                result.error("recorder_init_failed", "Unable to initialize AudioRecord", null)
                return
            }

            val recognizer = if (SpeechRecognizer.isRecognitionAvailable(appContext)) {
                SpeechRecognizer.createSpeechRecognizer(appContext).also {
                    it.setRecognitionListener(this)
                }
            } else {
                null
            }

            recognitionIntent = if (recognizer != null) {
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                    )
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
                    if (supportsExternalAudioForStt && sttAudioReadFd != null) {
                        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, sttAudioReadFd)
                        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, audioEncoding)
                        putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
                        usingExternalAudioForStt = true
                    } else {
                        usingExternalAudioForStt = false
                    }
                }
            } else {
                usingExternalAudioForStt = false
                null
            }

            wavFile = file
            fileOutputStream = stream
            audioRecord = recorder
            speechRecognizer = recognizer
            writtenBytes = 0L
            isCapturing = true

            recorder.startRecording()
            startRecordingThread(bufferSize)

            if (recognizer != null && recognitionIntent != null) {
                recognizer.startListening(recognitionIntent)
            } else {
                emitSuccess(SPEECH_UNAVAILABLE_MARKER)
            }
            result.success(null)
        } catch (error: Exception) {
            cleanup(deleteFile = true)
            result.error("capture_start_failed", error.message, null)
        }
    }

    private fun startRecordingThread(bufferSize: Int) {
        val recorder = audioRecord ?: return

        recordingThread = Thread {
            val buffer = ByteArray(bufferSize)
            while (isCapturing) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read <= 0) continue
                try {
                    fileOutputStream?.write(buffer, 0, read)
                    sttAudioOutputStream?.write(buffer, 0, read)
                    writtenBytes += read
                } catch (error: IOException) {
                    emitError("write_failed", error.message ?: "Audio write failed", null)
                    break
                }
            }
        }.apply {
            name = "SttRecorderRecorder"
            start()
        }
    }

    private fun stopCapture(result: MethodChannel.Result) {
        if (!isCapturing) {
            result.error("not_capturing", "No active capture session", null)
            return
        }

        val file = wavFile
        val path = file?.absolutePath
        if (path == null || file == null) {
            result.error("missing_path", "No output file path available", null)
            return
        }

        try {
            stopInternal(finalizeFile = true, deleteFile = false)
            val bytes = file.readBytes()
            result.success(
                hashMapOf(
                    "bytes" to bytes,
                    "fileName" to file.name,
                    "mimeType" to "audio/wav",
                    "path" to path,
                ),
            )
        } catch (error: Exception) {
            result.error("capture_stop_failed", error.message, null)
        }
    }

    private fun cancelCapture(result: MethodChannel.Result) {
        try {
            stopInternal(finalizeFile = false, deleteFile = true)
            result.success(null)
        } catch (error: Exception) {
            result.error("capture_cancel_failed", error.message, null)
        }
    }

    private fun stopInternal(finalizeFile: Boolean, deleteFile: Boolean) {
        isCapturing = false

        speechRecognizer?.stopListening()
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        closeSttAudioPipe()

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        recordingThread?.join(500)
        recordingThread = null

        fileOutputStream?.flush()
        fileOutputStream?.close()
        fileOutputStream = null

        val file = wavFile
        if (finalizeFile && file != null) {
            writeWavHeader(file, writtenBytes)
        }
        if (deleteFile) {
            file?.delete()
            wavFile = null
        }

        writtenBytes = 0L
    }

    private fun cleanup(deleteFile: Boolean) {
        try {
            stopInternal(finalizeFile = !deleteFile, deleteFile = deleteFile)
        } catch (_: Exception) {
            // best effort cleanup
        }
    }

    private fun writeWavHeader(file: File, dataLength: Long) {
        val byteRate = sampleRate * 1 * 16 / 8
        val totalDataLen = dataLength + 36
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)

        header.put("RIFF".toByteArray())
        header.putInt(totalDataLen.toInt())
        header.put("WAVE".toByteArray())
        header.put("fmt ".toByteArray())
        header.putInt(16)
        header.putShort(1) // PCM
        header.putShort(1) // mono
        header.putInt(sampleRate)
        header.putInt(byteRate)
        header.putShort((1 * 16 / 8).toShort())
        header.putShort(16)
        header.put("data".toByteArray())
        header.putInt(dataLength.toInt())

        RandomAccessFile(file, "rw").use { raf ->
            raf.seek(0)
            raf.write(header.array())
        }
    }

    private fun emitBestText(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val best = matches?.firstOrNull()?.trim()
        if (!best.isNullOrEmpty()) {
            emitSuccess(best)
        }
    }

    private fun hasRecordAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onReadyForSpeech(params: Bundle?) = Unit

    override fun onBeginningOfSpeech() = Unit

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() {
        if (usingExternalAudioForStt) return
        restartListening()
    }

    override fun onError(error: Int) {
        if (usingExternalAudioForStt) {
            emitSuccess("$SPEECH_ERROR_PREFIX$error")
            return
        }

        // `ERROR_NO_MATCH` / `ERROR_SPEECH_TIMEOUT` can happen during silence.
        // Keep the stream alive and restart recognition instead of emitting an
        // EventChannel error that can terminate Dart listeners.
        restartListening()
    }

    override fun onResults(results: Bundle?) {
        emitBestText(results)
        if (usingExternalAudioForStt) return
        restartListening()
    }

    override fun onPartialResults(partialResults: Bundle?) {
        emitBestText(partialResults)
    }

    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    private fun restartListening() {
        if (!isCapturing) return
        val recognizer = speechRecognizer ?: return
        val intent = recognitionIntent ?: return
        recognizer.cancel()
        recognizer.startListening(intent)
    }

    private fun closeSttAudioPipe() {
        try {
            sttAudioOutputStream?.close()
        } catch (_: IOException) {
            // ignore
        }
        sttAudioOutputStream = null

        try {
            sttAudioWriteFd?.close()
        } catch (_: IOException) {
            // ignore
        }
        sttAudioWriteFd = null

        try {
            sttAudioReadFd?.close()
        } catch (_: IOException) {
            // ignore
        }
        sttAudioReadFd = null
        usingExternalAudioForStt = false
    }

    private fun emitSuccess(payload: String) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun emitError(code: String, message: String, details: Any?) {
        mainHandler.post {
            eventSink?.error(code, message, details)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        cleanup(deleteFile = true)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
