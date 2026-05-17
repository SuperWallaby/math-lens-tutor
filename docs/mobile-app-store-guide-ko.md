# Flutter 스토어 출시 (짧은 메모)

## 번들 ID / 패키지 이름 (한 가지)

**`com.neoproject.study`**

- **Apple:** App Store Connect·Xcode의 **Bundle ID**  
- **Google:** Play Console **애플리케이션 ID**(패키지 이름) — 생성 후 변경 불가  

코드(Android `applicationId`, iOS `PRODUCT_BUNDLE_IDENTIFIER` 등)는 이미 위 값으로 맞춰 두었다.

## API 주소 (프로덕션)

기본값이 코드에 박혀 있다: **`https://study-alpha-rosy.vercel.app`** (`flutter_app/lib/services/api_client.dart`)

로컬 Next만 쓸 때만 덮어쓴다:

```bash
cd flutter_app
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

스토어 빌드는 기본값 그대로 두거나, 명시하려면:

```bash
cd flutter_app
flutter build ipa --dart-define=API_BASE_URL=https://study-alpha-rosy.vercel.app
flutter build appbundle --dart-define=API_BASE_URL=https://study-alpha-rosy.vercel.app
```

**일괄 빌드 (IPA + AAB + APK, `releases/` 에 복사):**

```bash
# 레포 루트
yarn flutter:release              # 현재 pubspec 버전으로 전부
yarn flutter:release:bump         # 빌드번호 +1 후 전부 (스토어 제출용)

# 또는
./flutter_app/scripts/release.sh
./flutter_app/scripts/release.sh --bump build
./flutter_app/scripts/release.sh ios      # iOS만
./flutter_app/scripts/release.sh android  # Android만
```

빌드가 끝나면 `flutter_app/releases/<버전>/` **절대 경로**를 출력하고, macOS에서는 **Finder로 그 폴더를 자동으로 엽니다**. 끄려면 `OPEN_FINDER=0 yarn flutter:release`.

플랫폼만:

```bash
./flutter_app/scripts/build-ios-ipa-release.sh
./flutter_app/scripts/build-android-release.sh
```

**코드 서명:** Xcode에서 `Runner` 타깃 → Signing & Capabilities → **Team** 을 선택해야 `flutter build ipa` 가 된다. (본인 Mac; 에이전트/서버에는 보통 인증서 없음)

**Xcode로 프로젝트 열기:** `open flutter_app/ios/Runner.xcworkspace`

## Archives 탭이 비어 있을 때

Organizer의 **Archives**는 **`Product → Archive`를 성공한 뒤**에만 쌓입니다. 터미널의 `flutter build ipa`가 **코드 서명 실패**로 끝났다면 아카이브도 생성되지 않습니다.

**본인 Mac에서 Xcode로 아카이브 (권장 순서):**

1. `open flutter_app/ios/Runner.xcworkspace`
2. 왼쪽 **Runner** 프로젝트 → **Runner** 타깃 → **Signing & Capabilities** → **Team** 선택 (유료 Apple Developer), **Automatically manage signing** 켜기
3. 상단 실행 대상을 실제 기기가 아니라 **Any iOS Device (arm64)** 로 선택 (시뮬레이터면 Archive 메뉴가 안 됨)
4. 메뉴 **Product → Archive** → 완료 후 Organizer 창에 아카이브 등장
5. 아카이브 선택 → **Distribute App** → **App Store Connect** → **Upload**

업로드 직후 Connect **TestFlight**에서 빌드가 보이면 성공입니다.

## `.env`

서버(Azure·Mongo)는 레포 루트 `.env.example` → `.env.local` / Vercel 환경 변수. Flutter 앱 바이너리에는 넣지 않는다.

## 스토어에 넣을 URL

- 개인정보: `https://study-alpha-rosy.vercel.app/privacy`

## iPad 12.9"/13" 스크린샷 (2048×2732)

Playwright로 프로덕션 웹을 열어 캡처한다. 루트의 `문제풀이.png`로 업로드·분석까지 진행한다.

```bash
cd study   # 레포 루트
npm install
npx playwright install chromium   # 최초 1회
npm run capture:ipad-screens
```

결과: `screen-shots/ios-ipad-12.9-2048x2732/*.png`  
로컬 서버를 쓰려면: `BASE_URL=http://localhost:3000 npm run capture:ipad-screens`  
다른 이미지: `IMAGE_PATH=/절대/경로/사진.png npm run capture:ipad-screens`

## 계정 있을 때만 할 일

**Apple:** App Store Connect에 **Bundle ID `com.neoproject.study`**로 앱 생성 → Xcode 서명·프로비저닝 → TestFlight → 심사.  
**Google:** Play Console에 **패키지 `com.neoproject.study`**로 앱 생성 → 데이터 보안 설문 → 내부 테스트 `.aab` → 프로덕션.

웹 배포 상세는 `docs/vercel-deploy-guide-ko.md`.
