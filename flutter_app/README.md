# Math Lens Tutor Flutter App

Flutter native client for the Math Lens Tutor backend.

## Backend URL

The app talks to the existing Next.js API. Pass the backend URL at run/build time:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Common values:

- iOS Simulator: `http://localhost:3000`
- Android Emulator: `http://10.0.2.2:3000`
- Physical device: `http://<your-lan-ip>:3000`
- Production: your deployed HTTPS URL

## Anonymous Device ID

The app does not require login in the first release. It creates one anonymous
device ID with `shared_preferences` and sends it as `X-Device-Id` on API calls,
so the backend can keep learning records separated per device.

## Run

```bash
cd flutter_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## Build

```bash
flutter build apk --dart-define=API_BASE_URL=https://your-app.vercel.app
flutter build appbundle --dart-define=API_BASE_URL=https://your-app.vercel.app
flutter build ipa --dart-define=API_BASE_URL=https://your-app.vercel.app
```

Before store submission, update:

- Android application id: `android/app/build.gradle.kts`
- iOS bundle id: Xcode Runner target settings
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
