import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stt_recorder_web/src/wav_encoder.dart';

void main() {
  group('encodePcm16Wav', () {
    test('throws when channels are empty', () {
      expect(
        () => encodePcm16Wav(
          channels: const <Float32List>[],
          sampleRate: 16000,
        ),
        throwsArgumentError,
      );
    });

    test('throws when sample rate is not positive', () {
      expect(
        () => encodePcm16Wav(
          channels: <Float32List>[
            Float32List.fromList(const <double>[0]),
          ],
          sampleRate: 0,
        ),
        throwsArgumentError,
      );
    });

    test('encodes mono PCM samples into a WAV container', () {
      final wavBytes = encodePcm16Wav(
        channels: <Float32List>[
          Float32List.fromList(const <double>[-1, 0, 1]),
        ],
        sampleRate: 16000,
      );
      final byteData = ByteData.sublistView(wavBytes);

      expect(String.fromCharCodes(wavBytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wavBytes.sublist(8, 12)), 'WAVE');
      expect(byteData.getUint16(22, Endian.little), 1);
      expect(byteData.getUint32(24, Endian.little), 16000);
      expect(byteData.getUint16(34, Endian.little), 16);
      expect(byteData.getInt16(44, Endian.little), -32768);
      expect(byteData.getInt16(46, Endian.little), 0);
      expect(byteData.getInt16(48, Endian.little), 32767);
    });

    test('throws when channel lengths differ', () {
      expect(
        () => encodePcm16Wav(
          channels: <Float32List>[
            Float32List.fromList(const <double>[0, 0]),
            Float32List.fromList(const <double>[0]),
          ],
          sampleRate: 16000,
        ),
        throwsArgumentError,
      );
    });
  });
}
