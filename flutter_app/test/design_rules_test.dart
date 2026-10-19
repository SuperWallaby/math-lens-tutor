import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 유리가 정의된 곳. 여기서만 `BackdropFilter(` 를 직접 쓴다.
const _glassFile = 'lib/widgets/glass.dart';

/// `GlassSurface(` 를 둘 수 있는 파일 (경로가 정확히 같아야 한다).
///
/// 유리는 떠 있는 층에만 쓴다. 콘텐츠는 흰 카드(AppCard)다.
const _glassSurfaceAllowlist = {
  _glassFile: '유리 정의 (탭바, 카메라, 흐림 가장자리, 시트, 팝업이 여기서 만든다)',
  'lib/widgets/home_stage.dart': '홈의 파란 무대 위 예외: 무대 카드가 파란 바탕을 비춘다',
  'lib/widgets/page_stage.dart': '탭 화면 위 파란 무대: 무대 카드·칸·알약·원이 파란 바탕을 비춘다',
  'lib/screens/student_hub_screen.dart': '홈의 파란 무대 위 카드들 (무대 예외)',
  'lib/screens/open_practice_flow.dart': '문제를 만드는 동안 화면 위에 뜨는 로딩 팝업',
};

/// 콘텐츠 화면이 되살리면 안 되는 옛 유리 위젯과, 유리를 우회하는 기본 위젯.
const _bannedNames = [
  'GlassPanel(',
  'GlassButton(',
  'GlassField(',
  'GlassSunken(',
  'GlassChoice(',
  'GlassGlyph(',
  'GlassInfoRow(',
  'showModalBottomSheet',
  'AlertDialog(',
];

/// `lib/screens`, `lib/widgets` 아래 모든 .dart 파일의 {경로: 내용}.
Map<String, String> _libSources() {
  final files = [
    ...Directory('lib/screens').listSync(recursive: true),
    ...Directory('lib/widgets').listSync(recursive: true),
  ].whereType<File>().where((f) => f.path.endsWith('.dart'));
  return {
    for (final f in files)
      f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
  };
}

/// 규칙을 어긴 곳을 "파일: 이유" 로 모아 돌려준다. 경로는 `endsWith` 가 아니라
/// 정확히 같은지로 비교한다.
List<String> designRuleViolations(Map<String, String> sources) {
  final violations = <String>[];
  sources.forEach((path, src) {
    if (path != _glassFile) {
      for (final b in _bannedNames) {
        if (src.contains(b)) violations.add('$path uses $b');
      }
      if (src.contains('BackdropFilter(')) {
        violations.add('$path uses BackdropFilter( outside $_glassFile');
      }
    }
    if (src.contains('GlassSurface(') &&
        !_glassSurfaceAllowlist.containsKey(path)) {
      violations.add(
        '$path uses GlassSurface( but is not in the floating-layer allowlist',
      );
    }
  });
  return violations;
}

void main() {
  test('content never uses glass (spec 3장): glass lives on the floating layer', () {
    expect(designRuleViolations(_libSources()), isEmpty);
  });

  test('the allowlist only names files that exist and really use glass', () {
    final sources = _libSources();
    for (final path in _glassSurfaceAllowlist.keys) {
      expect(sources.containsKey(path), isTrue, reason: '$path does not exist');
      expect(
        sources[path]!.contains('GlassSurface('),
        isTrue,
        reason: '$path no longer uses GlassSurface( — drop it from the allowlist',
      );
    }
  });

  group('the rule itself', () {
    final clean = {
      _glassFile: 'BackdropFilter(filter: f) GlassSurface( showModalBottomSheet',
      'lib/screens/settings_screen.dart': 'AppCard(child: Text(x))',
    };

    test('passes a tree that follows the rule', () {
      expect(designRuleViolations(clean), isEmpty);
    });

    test('fails when a settings screen places GlassSurface(', () {
      final bad = {
        ...clean,
        'lib/screens/settings_screen.dart': 'GlassSurface(child: Text(x))',
      };
      expect(designRuleViolations(bad), hasLength(1));
      expect(designRuleViolations(bad).single, contains('settings_screen.dart'));
    });

    test('fails on BackdropFilter( anywhere but glass.dart', () {
      final bad = {
        ...clean,
        'lib/widgets/app_card.dart': 'BackdropFilter(filter: f)',
      };
      expect(designRuleViolations(bad).single, contains('app_card.dart'));
    });

    test('a look-alike path does not get the glass.dart exemption', () {
      final bad = {
        ...clean,
        'lib/widgets/my_glass.dart': 'BackdropFilter(filter: f)',
        'lib/screens/old/home_stage.dart': 'GlassSurface(child: x)',
      };
      expect(
        designRuleViolations(bad),
        [
          'lib/widgets/my_glass.dart uses BackdropFilter( outside $_glassFile',
          'lib/screens/old/home_stage.dart uses GlassSurface( but is not in '
              'the floating-layer allowlist',
        ],
      );
    });

    test('still bans the retired glass widgets and raw sheets and dialogs', () {
      for (final name in _bannedNames) {
        final bad = {...clean, 'lib/screens/x.dart': 'a $name b'};
        expect(
          designRuleViolations(bad),
          ['lib/screens/x.dart uses $name'],
          reason: name,
        );
      }
    });
  });

  test('no blob atmosphere or wallpaper assets', () {
    final glass = File(_glassFile).readAsStringSync();
    expect(glass.contains('RadialGradient'), isFalse);
    expect(Directory('assets/glass').existsSync(), isFalse);
  });
}
