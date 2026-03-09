import 'dart:math' as math;
import 'dart:typed_data';

/// Encodes normalized PCM channel data into a 16-bit WAV file.
Uint8List encodePcm16Wav({
  required List<Float32List> channels,
  required int sampleRate,
}) {
  if (channels.isEmpty) {
    throw ArgumentError.value(channels, 'channels', 'Must not be empty');
  }
  if (sampleRate <= 0) {
    throw ArgumentError.value(
      sampleRate,
      'sampleRate',
      'Must be greater than zero',
    );
  }

  final frameCount = channels.first.length;
  for (final channel in channels.skip(1)) {
    if (channel.length != frameCount) {
      throw ArgumentError.value(
        channels,
        'channels',
        'All channels must have the same frame count',
      );
    }
  }

  const bitsPerSample = 16;
  final channelCount = channels.length;
  const bytesPerSample = bitsPerSample ~/ 8;
  final blockAlign = channelCount * bytesPerSample;
  final byteRate = sampleRate * blockAlign;
  final dataSize = frameCount * blockAlign;
  final byteData = ByteData(44 + dataSize);

  _writeAscii(byteData, 0, 'RIFF');
  byteData
    ..setUint32(4, 36 + dataSize, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, channelCount, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, blockAlign, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint32(40, dataSize, Endian.little);
  _writeAscii(byteData, 8, 'WAVE');
  _writeAscii(byteData, 12, 'fmt ');
  _writeAscii(byteData, 36, 'data');

  var offset = 44;
  for (var frame = 0; frame < frameCount; frame++) {
    for (var channel = 0; channel < channelCount; channel++) {
      final sample = channels[channel][frame];
      final normalizedSample = math.max(-1, math.min(1, sample)).toDouble();
      final pcmSample = normalizedSample < 0
          ? (normalizedSample * 0x8000).round()
          : (normalizedSample * 0x7FFF).round();
      byteData.setInt16(offset, pcmSample, Endian.little);
      offset += bytesPerSample;
    }
  }

  return byteData.buffer.asUint8List();
}

void _writeAscii(ByteData byteData, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    byteData.setUint8(offset + index, value.codeUnitAt(index));
  }
}
