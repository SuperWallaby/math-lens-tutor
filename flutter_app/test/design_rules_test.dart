import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content never uses glass widgets (spec 3장)', () {
    const banned = [
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
    final files = [
      ...Directory('lib/screens').listSync(recursive: true),
      ...Directory('lib/widgets').listSync(recursive: true),
    ].whereType<File>().where(
      (f) => f.path.endsWith('.dart') && !f.path.endsWith('glass.dart'),
    );
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final b in banned) {
        expect(src.contains(b), isFalse, reason: '${f.path} uses $b');
      }
    }
  });

  test('no blob atmosphere or wallpaper assets', () {
    final glass = File('lib/widgets/glass.dart').readAsStringSync();
    expect(glass.contains('RadialGradient'), isFalse);
    expect(Directory('assets/glass').existsSync(), isFalse);
  });
}
