import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/widgets/home_stage.dart';

const jimin = HomeStageUser(
  name: '지민',
  grade: '중1',
  organization: '한빛중학교',
  streakWeeks: 3,
);

Widget _stage(
  HomeStageUser user, {
  HomeStageMode mode = HomeStageMode.returning,
  Widget? footer,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HomeStage(
          mode: mode,
          user: user,
          today: DateTime(2026, 10, 17),
          card: const SizedBox(key: Key('card'), height: 40),
          footer: footer,
        ),
      ),
    ),
  );
}

void main() {
  test('title, subline, and streak rules', () {
    expect(homeStageTitle(jimin), '지민님');
    expect(homeStageSubline(jimin), '중1 · 한빛중학교');
    expect(
      homeStageSubline(const HomeStageUser(name: '지민', organization: '한빛중학교')),
      '한빛중학교',
    );
    expect(homeStageSubline(const HomeStageUser(name: '지민')), isNull);
    expect(homeStageTitle(const HomeStageUser()), '반가워요');
    expect(
      homeStageTitle(const HomeStageUser(name: '지민', isGuest: true)),
      '반가워요',
    );
    expect(homeStageSubline(const HomeStageUser(isGuest: true)), '둘러보는 중');
    expect(homeStageShowsStreak(HomeStageMode.returning, jimin), isTrue);
    expect(homeStageShowsStreak(HomeStageMode.firstVisit, jimin), isFalse);
    expect(
      homeStageShowsStreak(
        HomeStageMode.returning,
        const HomeStageUser(name: '지민'),
      ),
      isFalse,
    );
    expect(
      homeStageShowsStreak(
        HomeStageMode.returning,
        const HomeStageUser(name: '지민', streakWeeks: 3, isGuest: true),
      ),
      isFalse,
    );
  });

  test('headline copy per mode', () {
    expect(homeStageHeadline(HomeStageMode.firstVisit), '오늘은 한 장만\n올려도 돼요');
    expect(homeStageHeadline(HomeStageMode.returning), '어제 막힌 곳부터\n이어가요');
  });

  group('HomeStageUser.from', () {
    final profile = LearningProfile.fromJson({
      'grade': '중2',
      'stats': {'streakWeeks': 4},
    });

    test('takes grade from the user, school from organizationName', () {
      final u = HomeStageUser.from(
        const AppUser(
          id: 'u1',
          displayName: '지민',
          profileComplete: true,
          grade: '중1',
          organizationName: '한빛중학교',
          profileImageUrl: 'https://example.com/me.png',
        ),
        profile,
        isGuest: false,
      );
      expect(u.name, '지민');
      expect(u.grade, '중1');
      expect(u.organization, '한빛중학교');
      expect(u.imageUrl, 'https://example.com/me.png');
      expect(u.streakWeeks, 4);
      expect(u.isGuest, isFalse);
    });

    test('falls back to the profile grade when the user grade is empty', () {
      for (final grade in <String?>[null, '']) {
        final u = HomeStageUser.from(
          AppUser(
            id: 'u1',
            displayName: '지민',
            profileComplete: true,
            grade: grade,
          ),
          profile,
          isGuest: false,
        );
        expect(u.grade, '중2');
        expect(u.organization, '');
        expect(u.imageUrl, isNull);
      }
    });

    test('handles a missing user (guest)', () {
      final u = HomeStageUser.from(null, profile, isGuest: true);
      expect(u.name, '');
      expect(u.grade, '중2');
      expect(u.isGuest, isTrue);
    });
  });

  testWidgets('returning stage shows date, name, subline, streak, headline', (
    tester,
  ) async {
    await tester.pumpWidget(_stage(jimin));
    for (final t in [
      '10월 17일 토요일',
      '지민님',
      '중1 · 한빛중학교',
      '3주 연속',
      '어제 막힌 곳부터\n이어가요',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('우열'), findsNothing);
  });

  testWidgets('first visit stage hides the streak chip', (tester) async {
    await tester.pumpWidget(_stage(jimin, mode: HomeStageMode.firstVisit));
    expect(find.text('3주 연속'), findsNothing);
    expect(find.text('오늘은 한 장만\n올려도 돼요'), findsOneWidget);
  });

  testWidgets('guest stage shows the person glyph and guest copy', (
    tester,
  ) async {
    await tester.pumpWidget(_stage(const HomeStageUser(isGuest: true)));
    expect(find.text('반가워요'), findsOneWidget);
    expect(find.text('둘러보는 중'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.text('3주 연속'), findsNothing);
  });

  testWidgets('card spans the stage width and footer sits below the headline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _stage(jimin, footer: const SizedBox(key: Key('footer'), height: 20)),
    );
    expect(tester.getSize(find.byType(HomeStage)).width, 800);
    expect(tester.getSize(find.byKey(const Key('card'))).width, 800 - 40);
    final headlineBottom = tester
        .getBottomLeft(find.text('어제 막힌 곳부터\n이어가요'))
        .dy;
    expect(
      tester.getTopLeft(find.byKey(const Key('footer'))).dy,
      greaterThan(headlineBottom),
    );
  });

  testWidgets('date, name, subline, and headline carry a soft text shadow', (
    tester,
  ) async {
    await tester.pumpWidget(_stage(jimin));
    const expected = [
      Shadow(color: Color(0x591E46AA), offset: Offset(0, 1), blurRadius: 3),
    ];
    for (final t in ['10월 17일 토요일', '지민님', '중1 · 한빛중학교', '어제 막힌 곳부터\n이어가요']) {
      expect(
        tester.widget<Text>(find.text(t)).style?.shadows,
        expected,
        reason: t,
      );
    }
  });

  testWidgets('long name and school ellipsize without overflow at 320 wide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _stage(
        const HomeStageUser(
          name: '김가나다라마바사',
          grade: '중1',
          organization: '서울특별시립한빛국제중학교',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final name = tester.widget<Text>(find.text('김가나다라마바사님'));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    final sub = tester.widget<Text>(find.text('중1 · 서울특별시립한빛국제중학교'));
    expect(sub.maxLines, 1);
    expect(sub.overflow, TextOverflow.ellipsis);
    final iconLeft = tester
        .getTopLeft(find.byKey(const Key('home-stage-icon')))
        .dx;
    expect(
      tester.getTopRight(find.text('김가나다라마바사님')).dx,
      lessThanOrEqualTo(iconLeft),
    );
    expect(
      tester.getTopRight(find.text('중1 · 서울특별시립한빛국제중학교')).dx,
      lessThanOrEqualTo(iconLeft),
    );
  });

  testWidgets('broken profile photo falls back to the initial', (tester) async {
    await tester.pumpWidget(
      _stage(
        const HomeStageUser(
          name: '지민',
          imageUrl: 'https://invalid.invalid/x.png',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('지'), findsOneWidget);
  });

  testWidgets('without a photo the initial shows right away', (tester) async {
    await tester.pumpWidget(_stage(const HomeStageUser(name: '지민')));
    expect(find.text('지'), findsOneWidget);
  });

  testWidgets('the stage is not a button; avatar and icon are not announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_stage(jimin));
      expect(find.semantics.byLabel('지민님'), findsOneWidget);
      expect(find.semantics.byLabel('10월 17일 토요일'), findsOneWidget);
      // 이니셜 아바타는 이름 줄과 겹치므로 따로 읽히지 않는다.
      expect(find.semantics.byLabel('지'), findsNothing);
      expect(find.semantics.byLabel('우열'), findsNothing);
      expect(find.semantics.byAction(SemanticsAction.tap), findsNothing);
    } finally {
      handle.dispose();
    }
  });

  test('the stage icon ships at 3x of its 108pt size, not 1024px', () {
    final bytes = File('assets/brand/app_icon_cutout.png').readAsBytesSync();
    // PNG 머리(IHDR)의 가로·세로: 16번째 바이트부터 4바이트씩.
    final header = ByteData.sublistView(bytes, 16, 24);
    expect(header.getUint32(0), 324);
    expect(header.getUint32(4), 324);
    expect(bytes.length, lessThan(200 * 1024));
  });

  testWidgets('the stage icon decodes at the file size it ships at', (
    tester,
  ) async {
    await tester.pumpWidget(_stage(jimin));
    final icon = tester.widget<Image>(find.byKey(const Key('home-stage-icon')));
    expect(icon.width, 108);
    expect((icon.image as ResizeImage).width, 324);
  });
}
