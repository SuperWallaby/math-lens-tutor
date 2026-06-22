# Math Lens Tutor Flutter App

Flutter native client for the Math Lens Tutor backend.

## Backend URL

기본값은 프로덕션 **`https://study-alpha-rosy.vercel.app`** (`ApiClient` 컴파일 상수).

로컬 Next 서버를 쓸 때만 덮어쓴다:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## 간편 가입 (카카오 · Google · Apple)

앱 실행 시 **간편 가입** 후 이용합니다. 비밀번호 로그인은 없습니다.

1. 카카오 / Google / Apple 중 선택
2. 역할 선택: **학생** · **학부모** · **교사**
3. 학생: **학생 고유번호(WY-XXXXXX)** 자동 발급 → 학부모·교사에게 공유
4. 학부모·교사: 학생 고유번호로 연결 → 학생 목록에서 선택해 활동·수준 조회

### 서버 env (Vercel / `.env.local`)

```
JWT_SECRET=
MONGODB_URI=
GOOGLE_CLIENT_ID_IOS=
GOOGLE_CLIENT_ID_ANDROID=
GOOGLE_CLIENT_ID_WEB=
APPLE_CLIENT_ID=
KAKAO_REST_API_KEY=
KAKAO_NATIVE_APP_KEY=
```

### Flutter dart-define

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000 \
  --dart-define=KAKAO_NATIVE_APP_KEY=your_kakao_native_key
```

`npm run dev` / `npm run flutter:run:local` 는 `.env.local` 에서 키를 읽어 dart-define 과 네이티브 URL scheme 을 자동 동기화합니다.

### Kakao Developers 콘솔 설정

1. [Kakao Developers](https://developers.kakao.com/console/app) → 앱 추가
2. **앱 키** → Native App Key, REST API Key 를 `.env.local` 에 저장
3. **플랫폼**
   - **Android**: 패키지 `com.neoproject.study`, 키 해시 등록 → `npm run kakao:key-hash`
   - **iOS**: Bundle ID `com.neoproject.study`
4. **카카오 로그인** → ON, Redirect URI `kakao{NATIVE_APP_KEY}://oauth` (SDK 기본값)
5. 동기화: `npm run kakao:sync` (Android `local.properties` + iOS `Kakao.xcconfig`)
6. Vercel 에 `KAKAO_NATIVE_APP_KEY`, `KAKAO_REST_API_KEY` 등록 (서버 OAuth 검증용)

### Apple Sign In

1. [Apple Developer](https://developer.apple.com/account/resources/identifiers/list) → **Identifiers** → `com.neoproject.study`
2. **Sign in with Apple** capability 활성화 → Save
3. Xcode **Runner** → Signing & Capabilities (entitlements 파일 `Runner.entitlements` 반영됨)
4. `.env.local` / Vercel: `APPLE_CLIENT_ID=com.neoproject.study` (identityToken `aud` 검증)
5. **iOS 실기기**에서 테스트 (시뮬레이터는 Apple ID 로그인 제한 있음)

- **Google**: iOS `GoogleService-Info.plist`, Android OAuth client ID

## Device ID + 세션

가입 시 기존 `X-Device-Id` 학습 데이터는 계정으로 병합됩니다. 이후 API는 `Authorization: Bearer` JWT와 (학부모·교사) `X-View-As-Student` 헤더를 사용합니다.

## Run

프로젝트 **루트**에서:

```bash
npm run flutter:pub-get
npm run flutter:run:ios
```

로컬 백엔드:

```bash
npm run dev
# 다른 터미널
npm run flutter:run:local
```

Store identifiers: **`com.neoproject.study`**
