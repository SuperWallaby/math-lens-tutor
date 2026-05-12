import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// ImagePicker `maxWidth: 1800` / `imageQuality: 88` 와 같은 기준으로 맞춥니다.
/// 드래그앤드롭 등 원본이 큰 바이너리도 업로드 전에 줄입니다.
class PreparedAnalyzeImage {
  const PreparedAnalyzeImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

PreparedAnalyzeImage prepareImageBytesForAnalyzeUpload(
  Uint8List raw,
  String filename, {
  int maxSide = 1800,
  int jpegQuality = 88,
}) {
  img.Image? decoded = img.decodeImage(raw);
  if (decoded == null) {
    return PreparedAnalyzeImage(bytes: raw, filename: filename);
  }

  img.Image resized = decoded;
  if (decoded.width > maxSide || decoded.height > maxSide) {
    if (decoded.width >= decoded.height) {
      resized = img.copyResize(
        decoded,
        width: maxSide,
        interpolation: img.Interpolation.linear,
      );
    } else {
      resized = img.copyResize(
        decoded,
        height: maxSide,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  final forJpeg = resized.hasAlpha ? _compositeOnWhite(resized) : resized;
  List<int>? jpgBytes;
  try {
    jpgBytes = img.encodeJpg(forJpeg, quality: jpegQuality);
  } catch (_) {
    jpgBytes = null;
  }
  if (jpgBytes == null || jpgBytes.isEmpty) {
    return PreparedAnalyzeImage(bytes: raw, filename: filename);
  }

  final outName = _toJpegFilename(filename);
  return PreparedAnalyzeImage(
    bytes: Uint8List.fromList(jpgBytes),
    filename: outName,
  );
}

img.Image _compositeOnWhite(img.Image src) {
  final bg = img.Image(width: src.width, height: src.height, numChannels: 3);
  img.fill(bg, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(bg, src, blend: img.BlendMode.alpha);
  return bg;
}

String _toJpegFilename(String name) {
  final idx = name.lastIndexOf('.');
  if (idx <= 0) {
    return '$name.jpg';
  }
  return '${name.substring(0, idx)}.jpg';
}
