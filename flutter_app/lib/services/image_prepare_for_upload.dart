import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

bool get _aggressiveMobileCompress =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// ImagePicker `maxWidth`·`imageQuality` 와 같은 기준으로 맞춥니다.
/// 드래그앤드롭 등 원본이 큰 바이너리도 업로드 전에 줄입니다.
class PreparedAnalyzeImage {
  const PreparedAnalyzeImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

class _PrepareImageArgs {
  const _PrepareImageArgs({
    required this.raw,
    required this.filename,
    required this.maxSide,
    required this.jpegQuality,
  });

  final Uint8List raw;
  final String filename;
  final int maxSide;
  final int jpegQuality;
}

PreparedAnalyzeImage _prepareImageBytesIsolate(_PrepareImageArgs args) {
  return prepareImageBytesForAnalyzeUpload(
    args.raw,
    args.filename,
    maxSide: args.maxSide,
    jpegQuality: args.jpegQuality,
  );
}

PreparedAnalyzeImage prepareImageBytesForAnalyzeUpload(
  Uint8List raw,
  String filename, {
  int? maxSide,
  int? jpegQuality,
}) {
  final side = maxSide ?? (_aggressiveMobileCompress ? 1024 : 1200);
  final quality = jpegQuality ?? (_aggressiveMobileCompress ? 85 : 88);
  img.Image? decoded = img.decodeImage(raw);
  if (decoded == null) {
    return PreparedAnalyzeImage(bytes: raw, filename: filename);
  }

  img.Image resized = decoded;
  if (decoded.width > side || decoded.height > side) {
    if (decoded.width >= decoded.height) {
      resized = img.copyResize(
        decoded,
        width: side,
        interpolation: img.Interpolation.linear,
      );
    } else {
      resized = img.copyResize(
        decoded,
        height: side,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  final forJpeg = resized.hasAlpha ? _compositeOnWhite(resized) : resized;
  List<int>? jpgBytes;
  try {
    jpgBytes = img.encodeJpg(forJpeg, quality: quality);
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

Future<PreparedAnalyzeImage> prepareImageBytesForAnalyzeUploadAsync(
  Uint8List raw,
  String filename, {
  int? maxSide,
  int? jpegQuality,
}) async {
  final side = maxSide ?? (_aggressiveMobileCompress ? 1024 : 1200);
  final quality = jpegQuality ?? (_aggressiveMobileCompress ? 85 : 88);
  if (kIsWeb) {
    return prepareImageBytesForAnalyzeUpload(
      raw,
      filename,
      maxSide: side,
      jpegQuality: quality,
    );
  }
  return compute(
    _prepareImageBytesIsolate,
    _PrepareImageArgs(
      raw: raw,
      filename: filename,
      maxSide: side,
      jpegQuality: quality,
    ),
  );
}

/// 프로필 아바타용 — 작은 정사각형·낮은 품질로 업로드 크기를 줄입니다.
PreparedAnalyzeImage prepareImageBytesForProfileUpload(
  Uint8List raw,
  String filename,
) {
  return prepareImageBytesForAnalyzeUpload(
    raw,
    filename,
    maxSide: 384,
    jpegQuality: 80,
  );
}

Future<PreparedAnalyzeImage> prepareImageBytesForProfileUploadAsync(
  Uint8List raw,
  String filename,
) {
  return prepareImageBytesForAnalyzeUploadAsync(
    raw,
    filename,
    maxSide: 384,
    jpegQuality: 80,
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
