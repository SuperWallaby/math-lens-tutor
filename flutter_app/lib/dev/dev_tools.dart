import '../models/app_models.dart';
import '../screens/onboarding_screen.dart';
import '../services/api_client.dart';
import '../services/app_prefs.dart';
import '../services/auth_session.dart';

const devMockLinkedStudent = LinkedStudent(
  id: 'dev-linked-student',
  displayName: '김우열',
  studentCode: 'WY-7K3M9P',
);

const _devStudentCode = 'WY-DEV001';

Future<void> clearAllLocalData(AuthSession authSession) async {
  resetAppPrefsCache();
  final prefs = await getAppPrefs();
  await prefs.clear();
  await authSession.clear();
}

Future<void> resetIntroOnboarding() async {
  final prefs = await getAppPrefs();
  await prefs.remove(kOnboardingCompleteKey);
}

Future<void> loginAsDevEmptyAccount({
  required AuthSession authSession,
  required ApiClient apiClient,
  required String accountId,
}) async {
  await authSession.clear();
  resetAppPrefsCache();
  await apiClient.devLogin(accountId);
}

Future<void> applyDevGuestPersona({
  required AuthSession authSession,
  required ApiClient apiClient,
  required AppUserRole role,
}) async {
  final deviceId = await apiClient.deviceScopedUserId;
  await authSession.clear();
  resetAppPrefsCache();
  await authSession.enterGuestMode(deviceId);
  await authSession.completeGuestProfile(
    role: role,
    age: role == AppUserRole.student ? 15 : null,
    grade: role == AppUserRole.student ? '중2' : null,
    organizationName:
        role == AppUserRole.teacher ? '개발 테스트 학원' : null,
  );

  if (role.isGuardian) {
    await authSession.setLinkedStudents([devMockLinkedStudent]);
  }

  final user = authSession.user;
  if (user == null) return;

  await authSession.updateUser(
    AppUser(
      id: user.id,
      displayName: user.displayName,
      profileComplete: true,
      role: role,
      age: role == AppUserRole.student ? 15 : user.age,
      grade: role == AppUserRole.student ? '중2' : user.grade,
      organizationName: role == AppUserRole.teacher
          ? '개발 테스트 학원'
          : user.organizationName,
      studentCode: role == AppUserRole.student ? _devStudentCode : null,
    ),
  );
}

String describeDevSession(AuthSession authSession) {
  final user = authSession.user;
  if (user == null) return '세션 없음';

  final auth = authSession.isGuest
      ? '게스트'
      : authSession.isSignedIn
          ? '로그인'
          : '미인증';
  final role = user.role?.label ?? '역할 없음';
  final linked = authSession.linkedStudents.length;

  if (user.isGuardian) {
    return '$auth · $role · 연결 $linked명';
  }
  if (user.isStudent && user.studentCode != null) {
    return '$auth · $role · ${user.studentCode}';
  }
  return '$auth · $role';
}
