# Flutter 스토어 출시 (짧은 메모)

## 앱 ID (코드에 이미 맞춤)

- **Bundle / applicationId:** `com.mathlens.tutor`  
- Android·iOS·macOS·Linux·Windows 식별자는 위와 맞췄다. 스토어( App Store Connect / Play Console )에 **같은 ID**로 앱을 만들면 된다.

## API 주소 (배포한 웹 URL)

빌드할 때마다 프로덕션 HTTPS를 넣는다.

```bash
cd flutter_app
flutter build ipa --dart-define=API_BASE_URL=https://<프로덕션-도메인>
flutter build appbundle --dart-define=API_BASE_URL=https://<프로덕션-도메인>
```

## `.env` — 내가 대신 못 넣는 이유

Azure 키·Mongo URI·Vercel 환경 변수는 **당신 계정·대시보드**에서만 설정 가능하다. 레포 루트 `.env.example`을 복사해 로컬은 `.env.local`로 두고, Vercel에는 **같은 변수 이름**으로 Environment Variables에 붙여 넣으면 된다.

## 스토어에 넣을 URL

- 개인정보: `https://<프로덕션-도메인>/privacy`

## 계정 있을 때만 할 일

**Apple:** App Store Connect에 위 Bundle ID로 앱 생성 → Xcode 서명·프로비저닝 → TestFlight → 심사.  
**Google:** Play Console에 패키지 `com.mathlens.tutor`로 앱 생성(변경 불가) → 데이터 보안 설문 → 내부 테스트 `.aab` → 프로덕션.

웹(Vercel) 배포 상세는 `docs/vercel-deploy-guide-ko.md`.
