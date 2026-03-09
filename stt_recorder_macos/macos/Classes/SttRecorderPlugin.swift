import AVFoundation
import Cocoa
import FlutterMacOS
import Speech

private let methodChannelName = "stt_recorder"
private let eventChannelName = "stt_recorder/events"
private let speechUnavailableMarker = "__speech_unavailable__"

public class SttRecorderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  private var audioEngine: AVAudioEngine?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var speechRecognizer: SFSpeechRecognizer?
  private var audioFile: AVAudioFile?
  private var outputUrl: URL?

  private var isCapturing = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger
    )
    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger
    )

    let instance = SttRecorderPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startCapture":
      guard let args = call.arguments as? [String: Any],
            let localeId = args["localeId"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "startCapture requires localeId",
            details: nil
          )
        )
        return
      }
      startCapture(localeId: localeId, result: result)
    case "stopCapture":
      stopCapture(result: result)
    case "cancelCapture":
      cancelCapture(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startCapture(localeId: String, result: @escaping FlutterResult) {
    if isCapturing {
      result(
        FlutterError(
          code: "already_capturing",
          message: "Capture already started",
          details: nil
        )
      )
      return
    }

    requestPermissions { [weak self] micGranted, speechGranted, error in
      guard let self else { return }

      if let error {
        result(
          FlutterError(
            code: "permission_request_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }

      guard micGranted else {
        result(
          FlutterError(
            code: "permission_denied",
            message: "Microphone permission is required",
            details: nil
          )
        )
        return
      }

      do {
        try self.configureAndStart(
          localeId: localeId,
          enableSpeechRecognition: speechGranted
        )
        result(nil)
      } catch {
        self.cleanup(deleteFile: true)
        result(
          FlutterError(
            code: "capture_start_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private func stopCapture(result: @escaping FlutterResult) {
    guard isCapturing else {
      result(
        FlutterError(
          code: "not_capturing",
          message: "No active capture session",
          details: nil
        )
      )
      return
    }

    guard let outputUrl else {
      cleanup(deleteFile: false)
      result(
        FlutterError(
          code: "missing_path",
          message: "No output file path",
          details: nil
        )
      )
      return
    }

    do {
      cleanup(deleteFile: false)
      let data = try Data(contentsOf: outputUrl)
      result([
        "bytes": FlutterStandardTypedData(bytes: data),
        "fileName": outputUrl.lastPathComponent,
        "mimeType": "audio/wav",
        "path": outputUrl.path,
      ])
    } catch {
      cleanup(deleteFile: false)
      result(
        FlutterError(
          code: "capture_stop_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func cancelCapture(result: @escaping FlutterResult) {
    cleanup(deleteFile: true)
    result(nil)
  }

  private func configureAndStart(
    localeId: String,
    enableSpeechRecognition: Bool
  ) throws {
    let recognizer: SFSpeechRecognizer?
    if enableSpeechRecognition {
      recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        ?? SFSpeechRecognizer()
    } else {
      recognizer = nil
    }
    let canStreamSpeech = recognizer?.isAvailable == true

    let engine = AVAudioEngine()
    let request: SFSpeechAudioBufferRecognitionRequest?
    if canStreamSpeech {
      let speechRequest = SFSpeechAudioBufferRecognitionRequest()
      speechRequest.shouldReportPartialResults = true
      request = speechRequest
    } else {
      request = nil
    }

    let inputNode = engine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    let fileUrl = FileManager.default.temporaryDirectory
      .appendingPathComponent("voice-capture-\(Int(Date().timeIntervalSince1970)).wav")
    let file = try AVAudioFile(forWriting: fileUrl, settings: recordingFormat.settings)

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
      [weak self] buffer, _ in
      guard let self else { return }
      self.recognitionRequest?.append(buffer)
      do {
        try self.audioFile?.write(from: buffer)
      } catch {
        self.eventSink?(FlutterError(
          code: "audio_write_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }

    if let recognizer, let request {
      recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
        guard let self else { return }
        if let text = result?.bestTranscription.formattedString, !text.isEmpty {
          self.eventSink?(text)
        }
        if error != nil {
          self.restartSpeechTaskIfNeeded()
          return
        }
        if result?.isFinal == true {
          self.restartSpeechTaskIfNeeded()
        }
      }
    } else {
      eventSink?(speechUnavailableMarker)
      recognitionTask = nil
    }

    engine.prepare()
    try engine.start()

    speechRecognizer = recognizer
    recognitionRequest = request
    audioEngine = engine
    audioFile = file
    outputUrl = fileUrl
    isCapturing = true
  }

  private func cleanup(deleteFile: Bool) {
    isCapturing = false

    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    recognitionTask?.cancel()
    recognitionTask = nil

    speechRecognizer = nil
    audioFile = nil

    if deleteFile, let outputUrl {
      try? FileManager.default.removeItem(at: outputUrl)
      self.outputUrl = nil
    }
  }

  private func restartSpeechTaskIfNeeded() {
    guard isCapturing else { return }
    guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

    recognitionTask?.cancel()
    recognitionTask = nil

    let newRequest = SFSpeechAudioBufferRecognitionRequest()
    newRequest.shouldReportPartialResults = true
    recognitionRequest = newRequest

    recognitionTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
      guard let self else { return }
      if let text = result?.bestTranscription.formattedString, !text.isEmpty {
        self.eventSink?(text)
      }
      if error != nil {
        self.restartSpeechTaskIfNeeded()
        return
      }
      if result?.isFinal == true {
        self.restartSpeechTaskIfNeeded()
      }
    }
  }

  private func requestPermissions(
    completion: @escaping (_ micGranted: Bool, _ speechGranted: Bool, _ error: Error?) -> Void
  ) {
    var micGranted = false
    var speechGranted = false

    let group = DispatchGroup()

    group.enter()
    AVCaptureDevice.requestAccess(for: .audio) { granted in
      micGranted = granted
      group.leave()
    }

    group.enter()
    SFSpeechRecognizer.requestAuthorization { status in
      speechGranted = status == .authorized
      group.leave()
    }

    group.notify(queue: .main) {
      completion(micGranted, speechGranted, nil)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
