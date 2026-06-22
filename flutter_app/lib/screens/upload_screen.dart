import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../io_compat/read_path_bytes.dart';
import '../layout/tablet_layout.dart';
import '../services/api_client.dart';
import '../utils/problem_image_picker.dart';
import 'analysis_screen.dart';
import '../theme/app_design_system.dart';

/// 데스크톱에서 Finder 등으로 드롭 받기 (`desktop_drop`).
bool get _supportsDesktopDrop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

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
  const UploadScreen({
    super.key,
    required this.apiClient,
    this.embeddedInShell = false,
  });

  final ApiClient apiClient;
  final bool embeddedInShell;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
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
    final picked = await pickProblemImage(source: source, context: context);
    if (picked == null || !mounted) return;

    setState(() {
      _imageBytes = picked.bytes;
      _uploadFilename = picked.filename;
      _error = null;
    });
    _openStreamingAnalysis(picked.bytes, picked.filename);
  }

  void _onPrimaryButton() {
    final bytes = _imageBytes;
    if (bytes == null) return;
    _openStreamingAnalysis(bytes, _uploadFilename);
  }

  @override
  Widget build(BuildContext context) {
    final content = TabletBody(
      child: ListView(
        padding: TabletLayout.pagePadding(context),
        children: [
          if (widget.embeddedInShell) ...[
            Text(
              '문제지 업로드',
              style: TextStyle(
                fontSize: TabletLayout.titleSection(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI가 왜 틀렸는지 분석해드려요',
              style: TextStyle(color: AppColors.textSub),
            ),
            const SizedBox(height: 16),
          ],
          Text(
              supportsProblemImageCamera
                  ? '풀이 과정과 선택 답안이 보이도록 사진을 찍거나 앨범에서 선택하세요.'
                  : kIsWeb
                      ? '풀이 과정과 선택 답안이 보이도록 이미지 파일을 선택하세요.'
                      : '풀이 과정과 선택 답안이 보이도록 이미지 파일을 고르거나, 아래 상자로 끌어다 놓으세요.',
              style: TextStyle(
                color: AppColors.textSub,
                height: 1.5,
                fontSize: TabletLayout.body(context),
              ),
            ),
            const SizedBox(height: 18),
            _buildPreviewDropZone(context),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: Icon(problemImageGalleryIcon),
              label: Text(problemImageGalleryLabel),
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
                style: const TextStyle(color: AppColors.accent, height: 1.45),
              ),
            ],
        ],
      ),
    );

    if (widget.embeddedInShell) {
      return SafeArea(child: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('풀이 사진 분석')),
      body: SafeArea(child: content),
    );
  }

  Widget _buildPreviewDropZone(BuildContext context) {
    final isEmpty = _imageBytes == null;
    final emptyLabel = supportsProblemImageCamera
        ? '문제 사진 촬영하기'
        : '이미지 파일 선택하기';

    final preview = DecoratedBox(
      decoration: BoxDecoration(
        color: isEmpty ? AppColors.primary.withValues(alpha: 0.04) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: _dragHover
              ? AppColors.primary
              : isEmpty
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
          width: _dragHover ? 2 : 1,
        ),
      ),
      child: isEmpty
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pick(primaryProblemImageSource),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _dragHover
                            ? Icons.file_download_rounded
                            : Icons.camera_alt_rounded,
                        size: 36,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        emptyLabel,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (_supportsDesktopDrop) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '또는 Finder·탐색기에서 이미지를 드래그해 놓을 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSub,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: Image.memory(_imageBytes!, fit: BoxFit.contain),
            ),
    );

    if (isEmpty) {
      const emptyPreviewHeight = 168.0;
      if (!_supportsDesktopDrop) {
        return SizedBox(
          height: emptyPreviewHeight,
          width: double.infinity,
          child: preview,
        );
      }

      return SizedBox(
        height: emptyPreviewHeight,
        width: double.infinity,
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

    final previewAr = TabletLayout.isTablet(context) ? 1.02 : 0.78;

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
