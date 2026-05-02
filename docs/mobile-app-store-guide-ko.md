# Flutter 스토어 출시 (짧은 메모)

## 번들 ID / 패키지 이름 (한 가지)

**`com.mathlens.tutor`**

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
flutter build ipa --dart-define=API_BASE_URL=https://study-alpha-rosy.vercel.app
flutter build appbundle --dart-define=API_BASE_URL=https://study-alpha-rosy.vercel.app
```

## `.env`

서버(Azure·Mongo)는 레포 루트 `.env.example` → `.env.local` / Vercel 환경 변수. Flutter 앱 바이너리에는 넣지 않는다.

## 스토어에 넣을 URL

- 개인정보: `https://study-alpha-rosy.vercel.app/privacy`

## 계정 있을 때만 할 일

**Apple:** App Store Connect에 **Bundle ID `com.mathlens.tutor`**로 앱 생성 → Xcode 서명·프로비저닝 → TestFlight → 심사.  
**Google:** Play Console에 **패키지 `com.mathlens.tutor`**로 앱 생성 → 데이터 보안 설문 → 내부 테스트 `.aab` → 프로덕션.

웹 배포 상세는 `docs/vercel-deploy-guide-ko.md`.
