# 모바일 앱 쉘 (Expo)

웹으로 배포한 Next.js 앱을 **같은 화면을 앱으로 감싼(WebView) 하이브리드**입니다.

## 실행 전

1. `mobile/.env` 파일을 만들고 배포 URL을 넣습니다. (`.env.example` 참고)

   ```env
   EXPO_PUBLIC_WEB_URL=https://your-app.vercel.app
   ```

2. 의존성 설치는 저장소 루트가 아니라 `mobile` 폴더에서 합니다.

   ```bash
   cd mobile
   npm install
   npx expo start
   ```

## 스토어 제출·계정·동료 협업

[docs/mobile-app-store-guide-ko.md](../docs/mobile-app-store-guide-ko.md) 를 읽으세요.

## 식별자 변경

`app.json` 의 `ios.bundleIdentifier`, `android.package` 를 회사 도메인 역순으로 바꿉니다.

예: `com.yourcompany.mathlenstutor`

## 프로덕션 빌드 (요약)

스토어용 `.ipa` / `.aab` 는 보통 **Expo Application Services (EAS Build)** 로 만듭니다. 상세는 위 가이드 문서를 참고하세요.
