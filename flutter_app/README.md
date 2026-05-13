# Math Lens Tutor Flutter App

Flutter native client for the Math Lens Tutor backend.

## Backend URL

기본값은 프로덕션 **`https://study-alpha-rosy.vercel.app`** (`ApiClient` 컴파일 상수).

로컬 Next 서버를 쓸 때만 덮어쓴다:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

다른 환경 예시:

- iOS Simulator (로컬): `http://localhost:3000`
- Android Emulator (로컬): `http://10.0.2.2:3000`

## Anonymous Device ID

The app does not require login in the first release. It creates one anonymous
device ID with `shared_preferences` and sends it as `X-Device-Id` on API calls,
so the backend can keep learning records separated per device.

## Run

프로젝트 **루트**에서 (Chrome 웹 + 로컬 API `localhost:3000`):

```bash
npm run flutter:web
```

별도 터미널에서 Next 서버: `npm run dev`

네이티브 등:

```bash
cd flutter_app
flutter pub get
flutter run
# 로컬 백엔드:
# flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

### iOS 시뮬레이터 (기기 이름 고정)

`iPhone 17` 예전 UUID 때문에 Xcode destination 오류가 나면, **프로젝트 루트**에서 기본 **`iPhone 17 Pro`** 로 실행:

```bash
npm run flutter:run:ios
```

다른 시뮬레이터 이름을 쓰려면:

```bash
FLUTTER_IOS_DEVICE="iPhone 17 Pro Max" npm run flutter:run:ios
```

API 주소만 바꿀 때:

```bash
FLUTTER_API_BASE_URL=http://127.0.0.1:3000 npm run flutter:run:ios
```

(`yarn` 으로 돌리면 `flutter` 가 PATH 에 안 잡히는 경우가 있어, 터미널에서 **`npm run`** 또는 **`bash scripts/flutter-run-ios-simulator.sh`** 권장.)

## iOS app icon & launch screen

Regenerate from a master PNG (auto square-crop to 1024×1024 center):

```bash
python3 scripts/generate_ios_icons_from_master.py branding/app-icon-master-source.png
```

Writes into `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and `LaunchImage.imageset/`.

## Build

```bash
flutter build apk --dart-define=API_BASE_URL=https://your-app.vercel.app
flutter build appbundle --dart-define=API_BASE_URL=https://your-app.vercel.app
flutter build ipa --dart-define=API_BASE_URL=https://your-app.vercel.app
```

Store identifiers are **`com.neoproject.study`** (`android/app/build.gradle.kts`, Xcode Runner bundle ID).

Before store submission, verify:

- Android application id / iOS bundle id match App Store Connect / Play Console
- Camera/photo permission copy: Android Manifest and iOS Info.plist
# math_lens_tutor

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
