import '../models/app_models.dart';

class OnboardingFeatureSlide {
  const OnboardingFeatureSlide({
    required this.imageAsset,
    required this.title,
    required this.body,
  });

  final String imageAsset;
  final String title;
  final String body;
}

List<OnboardingFeatureSlide> onboardingSlidesForRole(AppUserRole? role) {
  switch (role) {
    case AppUserRole.parent:
      return _slides('parent', _parentCopy);
    case AppUserRole.teacher:
      return _slides('teacher', _teacherCopy);
    case AppUserRole.student:
    case null:
      return _slides('student', _studentCopy);
  }
}

List<OnboardingFeatureSlide> _slides(
  String role,
  List<({String title, String body})> copy,
) {
  const files = [
    '01.png',
    '02.png',
    '03.png',
    '04.png',
  ];
  return List.generate(files.length, (i) {
    return OnboardingFeatureSlide(
      imageAsset: 'assets/onboarding/$role/${files[i]}',
      title: copy[i].title,
      body: copy[i].body,
    );
  });
}

const _studentCopy = [
  (
    title: '틀린 문제 AI 분석',
    body: '오답 원인·약점 개념을 찾고 맞춤 유사 문제로 이어져요.',
  ),
  (
    title: '사진 한 장으로 시작',
    body: '풀이 사진을 올리면 유사 문제와 해설을 생성해요.',
  ),
  (
    title: '단원별 학습 진행',
    body: '교과 단원별로 어디까지 했는지 한눈에 확인해요.',
  ),
  (
    title: '학습 분석 리포트',
    body: '풀이 과정·오답 진단·추천 학습 포인트를 한눈에 확인해요.',
  ),
];

const _parentCopy = [
  (
    title: '아이 오답 분석',
    body: '자녀 풀이에서 틀린 이유와 약점 개념을 확인해요.',
  ),
  (
    title: '풀이 사진 분석',
    body: '아이가 찍은 풀이를 AI가 분석하고 유사 문제를 만들어요.',
  ),
  (
    title: '단원별 진도 확인',
    body: '연결된 자녀의 단원별 학습 진행을 실시간으로 봐요.',
  ),
  (
    title: '학습 분석 리포트',
    body: '풀이 분석·오답 진단·학습 포인트를 리포트로 확인해요.',
  ),
];

const _teacherCopy = [
  (
    title: '학생별 오답 분석',
    body: '풀이 분석으로 학생마다 필요한 보충 포인트를 파악해요.',
  ),
  (
    title: '풀이 사진 AI 분석',
    body: '학생 풀이 사진에서 유사 문제와 해설을 빠르게 제공해요.',
  ),
  (
    title: '반 단원별 진도',
    body: '학급·학생 단원별 학습 진행을 한 화면에서 관리해요.',
  ),
  (
    title: '학습 분석 리포트',
    body: '풀이 분석·오답 진단·보충 포인트를 리포트로 확인해요.',
  ),
];
