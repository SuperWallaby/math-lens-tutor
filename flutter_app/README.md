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

- **Kakao**: [Kakao Developers](https://developers.kakao.com) 앱 등록, iOS URL scheme / Android key hash 설정
- **Google**: iOS `GoogleService-Info.plist`, Android OAuth client ID
- **Apple**: Xcode → Sign in with Apple capability

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
