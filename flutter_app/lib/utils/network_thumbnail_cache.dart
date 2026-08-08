import 'package:flutter/widgets.dart';

/// 리스트 썸네일 등 작은 [Image.network]에 넘길 cacheWidth/cacheHeight.
/// 표시 크기(logical px) × DPR만 디코딩해 메모리·스크롤 부담을 줄인다.
int networkImageCacheExtent(double logicalSize, BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalSize * dpr).round().clamp(1, 4096);
}
