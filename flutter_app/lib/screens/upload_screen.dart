import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../io_compat/read_path_bytes.dart';
import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
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
  /// 사진 선택 등으로 시작한 분석 진행 여부(UI만 바꿈, 메인 버튼 스피너 아님).
  bool _analysisBusy = false;
  /// 사용자가「다시 분석」만 눌렀을 때 해당 버튼에만 로딩 표시.
  bool _buttonSubmitLoading = false;
  AnalyzeResult? _readyResult;
  String? _error;
  bool _dragHover = false;
  AnalyzeQualityMode _qualityMode = AnalyzeQualityMode.balanced;
  /// 증가시키면 이전 분석 요청 완료 콜백 무시(새 이미지 등).
  int _analyzeSeq = 0;

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
        _readyResult = null;
        _error = null;
      });
      _scheduleAnalyzeAfterImageSet();
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
      maxWidth: 1800,
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
      _readyResult = null;
      _error = null;
    });
    _scheduleAnalyzeAfterImageSet();
  }

  void _scheduleAnalyzeAfterImageSet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runAnalyzeSequence(fromUserTap: false);
    });
  }

  /// [fromUserTap] 이 true면「다시 분석」버튼에만 스피너를 표시합니다.
  /// 완료 후 자동으로 분석 화면으로 넘기지 않고 `_readyResult`에 두며, 사용자가「결과 보기」에서 이동합니다.
  Future<void> _runAnalyzeSequence({required bool fromUserTap}) async {
    final bytes = _imageBytes;
    if (bytes == null) return;

    final seq = ++_analyzeSeq;
    if (!mounted) return;
    setState(() {
      _analysisBusy = true;
      _error = null;
      if (fromUserTap) _buttonSubmitLoading = true;
    });

    try {
      final AnalyzeResult result = await widget.apiClient.analyzeImageBytes(
        bytes,
        filename: _uploadFilename,
        qualityMode: _qualityMode,
      );
      if (!mounted || seq != _analyzeSeq) return;
      setState(() {
        _analysisBusy = false;
        _buttonSubmitLoading = false;
        _readyResult = result;
      });
    } catch (error) {
      if (!mounted || seq != _analyzeSeq) return;
      setState(() {
        _analysisBusy = false;
        _buttonSubmitLoading = false;
        _error = error.toString();
      });
    }
  }

  void _openResultScreen() {
    final r = _readyResult;
    if (r == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          apiClient: widget.apiClient,
          result: r,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _analyzeSeq++;
    super.dispose();
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
            Text(
              '응답 모드',
              style: TextStyle(
                color: const Color(0xFFE2E8F0),
                fontWeight: FontWeight.w600,
                fontSize: TabletLayout.isWideTablet(context) ? 16 : 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '모드를 고른 뒤 사진을 넣으면 자동으로 분석이 시작됩니다. 진행 상태는 아래 안내와 막대로 표시되며, 완료 후 「결과 보기」를 눌러 이동하세요.',
              style: TextStyle(
                color: const Color(0xFF94A3B8),
                fontSize: TabletLayout.bodySmall(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<AnalyzeQualityMode>(
              segments: const [
                ButtonSegment<AnalyzeQualityMode>(
                  value: AnalyzeQualityMode.fast,
                  label: Text('빠른'),
                  tooltip: '빠른 응답',
                ),
                ButtonSegment<AnalyzeQualityMode>(
                  value: AnalyzeQualityMode.balanced,
                  label: Text('밸런스'),
                ),
                ButtonSegment<AnalyzeQualityMode>(
                  value: AnalyzeQualityMode.accurate,
                  label: Text('정확'),
                  tooltip: '정확한 응답',
                ),
              ],
              selected: {_qualityMode},
              onSelectionChanged: (Set<AnalyzeQualityMode> next) {
                if (next.isEmpty || _analysisBusy) return;
                setState(() => _qualityMode = next.first);
              },
            ),
            const SizedBox(height: 14),
            if (_analysisBusy && !_buttonSubmitLoading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '분석 및 유사 문제 생성 중입니다. 잠시만 기다려 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: TabletLayout.bodySmall(context),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ],
            FilledButton.icon(
              onPressed: (_readyResult == null || _analysisBusy)
                  ? null
                  : _openResultScreen,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('결과 보기'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: (_imageBytes == null || _analysisBusy || _buttonSubmitLoading)
                  ? null
                  : () => _runAnalyzeSequence(fromUserTap: true),
              icon: _buttonSubmitLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label:
                  Text(_buttonSubmitLoading ? '분석 중...' : '다시 분석'),
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
