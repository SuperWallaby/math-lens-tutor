import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../io_compat/read_path_bytes.dart';
import '../layout/tablet_layout.dart';
import '../services/api_client.dart';
import 'analysis_screen.dart';

/// 모바일(iOS/Android)만 `ImageSource.camera` 를 지원합니다.
/// macOS/Windows/Linux 는 cameraDelegate 없이 예외가 납니다.
bool get _supportsImagePickerCamera =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// 데스크톱에서 Finder 등으로 드롭 받기 (`desktop_drop`).
bool get _supportsDesktopDrop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// macOS·Windows·Linux 에서 `ImageSource.gallery` 는 사진 앱이 아니라 파일 선택 패널입니다.
String get _galleryButtonLabel =>
    _supportsImagePickerCamera ? '앨범' : '이미지 파일';

Iterable<DropItem> _flattenDropItems(List<DropItem> items) sync* {
  for (final item in items) {
    if (item is DropItemDirectory) {
      yield* _flattenDropItems(item.children);
    } else {
      yield item;
    }
  }
}

String _inferImageExtension(DropItem item) {
  String tail(String s) {
    final i = s.lastIndexOf('.');
    return i >= 0 && i < s.length - 1 ? s.substring(i).toLowerCase() : '';
  }

  final fromPath = tail(item.path);
  if (fromPath.isNotEmpty) return fromPath;
  final fromName = tail(item.name);
  if (fromName.isNotEmpty) return fromName;
  return '.jpg';
}

bool _isImageDropItem(DropItem item) {
  if (item is DropItemDirectory) return false;
  final mime = item.mimeType?.toLowerCase();
  if (mime != null && mime.startsWith('image/')) return true;
  const ok = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.heic',
    '.heif',
    '.bmp',
    '.tif',
    '.tiff',
  };
  final ext = _inferImageExtension(item);
  return ok.contains(ext);
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String _uploadFilename = 'upload.jpg';
  String? _error;
  bool _dragHover = false;

  void _openStreamingAnalysis(Uint8List bytes, String filename) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          apiClient: widget.apiClient,
          imageBytes: bytes,
          uploadFilename: filename,
        ),
      ),
    );
  }

  Future<void> _onDropDone(DropDoneDetails detail) async {
    if (!mounted) return;
    setState(() => _dragHover = false);

    DropItem? chosen;
    for (final item in _flattenDropItems(detail.files)) {
      if (_isImageDropItem(item)) {
        chosen = item;
        break;
      }
    }

    if (chosen == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미지 파일(jpg, png, heic 등)을 드롭해 주세요.'),
        ),
      );
      return;
    }

    final bookmark = chosen.extraAppleBookmark;
    var scoped = false;
    if (bookmark != null && bookmark.isNotEmpty) {
      scoped = await DesktopDrop.instance.startAccessingSecurityScopedResource(
        bookmark: bookmark,
      );
    }

    try {
      final bytes = await readLocalPathBytes(chosen.path);
      if (!mounted) return;
      final name = chosen.name.trim().isNotEmpty
          ? chosen.name
          : 'drop_${DateTime.now().millisecondsSinceEpoch}${_inferImageExtension(chosen)}';
      setState(() {
        _imageBytes = bytes;
        _uploadFilename = name;
        _error = null;
      });
      _openStreamingAnalysis(bytes, name);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '파일을 불러오지 못했습니다: $e');
    } finally {
      if (scoped && bookmark != null && bookmark.isNotEmpty) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark,
        );
      }
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (source == ImageSource.camera && !_supportsImagePickerCamera) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'macOS·데스크톱에서는 카메라를 쓸 수 없습니다. 이미지 파일을 선택해 주세요.',
          ),
        ),
      );
      return;
    }
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1200,
    );

    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    final name = picked.name.trim().isNotEmpty
        ? picked.name
        : 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';

    setState(() {
      _imageBytes = bytes;
      _uploadFilename = name;
      _error = null;
    });
    _openStreamingAnalysis(bytes, name);
  }

  void _onPrimaryButton() {
    final bytes = _imageBytes;
    if (bytes == null) return;
    _openStreamingAnalysis(bytes, _uploadFilename);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('풀이 사진 분석')),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
            Text(
              kIsWeb
                  ? '풀이 과정과 선택 답안이 보이도록 이미지 파일을 선택하세요. (웹 브라우저)'
                  : _supportsImagePickerCamera
                      ? '풀이 과정과 선택 답안이 보이도록 사진을 찍거나 앨범에서 선택하세요.'
                      : '풀이 과정과 선택 답안이 보이도록 이미지 파일을 고르거나, 아래 상자로 끌어다 놓으세요. '
                          '(macOS·Windows 등: 파일 창 또는 드래그 앤 드롭. 카메라는 모바일만)',
              style: TextStyle(
                color: const Color(0xFFCBD5E1),
                height: 1.5,
                fontSize: TabletLayout.body(context),
              ),
            ),
            const SizedBox(height: 18),
            _buildPreviewDropZone(context),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: Icon(
                      _supportsImagePickerCamera
                          ? Icons.photo_library_rounded
                          : Icons.folder_open_rounded,
                    ),
                    label: Text(_galleryButtonLabel),
                  ),
                ),
                if (_supportsImagePickerCamera) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('카메라'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _imageBytes == null ? null : _onPrimaryButton,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('분석하고 유사 문제 생성'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFCA5A5), height: 1.45),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewDropZone(BuildContext context) {
    final preview = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _dragHover
              ? const Color(0xFF38BDF8)
              : Colors.white.withValues(alpha: 0.08),
          width: _dragHover ? 2 : 1,
        ),
      ),
      child: _imageBytes == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _dragHover ? Icons.file_download_rounded : Icons.add_photo_alternate_rounded,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text('이미지 미리보기'),
                  if (_supportsDesktopDrop) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Finder·탐색기에서 이미지를 이 상자로 드래그해 놓을 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(_imageBytes!, fit: BoxFit.contain),
            ),
    );

    final previewAr =
        TabletLayout.isTablet(context) ? 1.02 : 0.78;

    if (!_supportsDesktopDrop) {
      return AspectRatio(aspectRatio: previewAr, child: preview);
    }

    return AspectRatio(
      aspectRatio: previewAr,
      child: DropTarget(
        enable: true,
        onDragEntered: (_) {
          setState(() => _dragHover = true);
        },
        onDragExited: (_) {
          setState(() => _dragHover = false);
        },
        onDragDone: _onDropDone,
        child: preview,
      ),
    );
  }
}
