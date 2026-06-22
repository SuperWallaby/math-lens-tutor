import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 모바일(iOS/Android)과 모바일 웹은 `ImageSource.camera` 를 지원합니다.
/// macOS/Windows/Linux 데스크톱은 cameraDelegate 없이 예외가 납니다.
bool get supportsProblemImageCamera {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return true;
  }
  return kIsWeb;
}

ImageSource get primaryProblemImageSource =>
    supportsProblemImageCamera ? ImageSource.camera : ImageSource.gallery;

String get problemImageGalleryLabel =>
    supportsProblemImageCamera ? '앨범' : '이미지 파일';

IconData get problemImageGalleryIcon =>
    supportsProblemImageCamera
        ? Icons.photo_library_rounded
        : Icons.folder_open_rounded;

class PickedProblemImage {
  const PickedProblemImage({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;
}

Future<PickedProblemImage?> pickProblemImage({
  required ImageSource source,
  required BuildContext context,
}) async {
  if (source == ImageSource.camera && !supportsProblemImageCamera) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'macOS·데스크톱에서는 카메라를 쓸 수 없습니다. 이미지 파일을 선택해 주세요.',
          ),
        ),
      );
    }
    return null;
  }

  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 88,
    maxWidth: 1200,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  final name = picked.name.trim().isNotEmpty
      ? picked.name
      : 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';

  return PickedProblemImage(bytes: bytes, filename: name);
}

Future<PickedProblemImage?> pickProfileImage({
  required BuildContext context,
}) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 82,
    maxWidth: 512,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  final name = picked.name.trim().isNotEmpty
      ? picked.name
      : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

  return PickedProblemImage(bytes: bytes, filename: name);
}
