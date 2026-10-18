import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Liquid Glass 리뉴얼 뒤 아무도 쓰지 않아 지운 코드. 다시 생기면 알려 준다.
const _retiredNames = {
  'GlassCircleButton': '사진 위 동그라미 유리 버튼 — 쓰는 화면이 없다',
  'buildCssGlassLayer': '웹 CSS 유리 — 스펙 3장: 웹에서 HtmlElementView로 유리를 만들지 않는다',
  'embeddedInShell': '업로드는 가운데 카메라로 여는 전체 화면이다',
  'AppShadows': '옛 볼록·오목 그림자',
  'glassFill': '옛 유리 색 — GlassSpec이 대신한다',
  'glassStroke': '옛 유리 색 — GlassSpec이 대신한다',
  'glassShadow': '옛 유리 색 — GlassSpec이 대신한다',
  'class MissionCard': '홈 미션은 student_hub_screen의 무대 카드가 그린다',
  'showConnectButton': '학생 코드는 다 입력되면 저절로 연결된다',
};

void main() {
  test('retired widgets, tokens and flags stay deleted', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final found = <String>[];
    for (final file in sources) {
      final src = file.readAsStringSync();
      for (final name in _retiredNames.keys) {
        if (src.contains(name)) found.add('${file.path}: $name');
      }
    }
    expect(found, isEmpty);
  });

  test('the web CSS glass layer files are gone', () {
    expect(File('lib/widgets/glass_css_layer_web.dart').existsSync(), isFalse);
    expect(File('lib/widgets/glass_css_layer_stub.dart').existsSync(), isFalse);
  });
}
