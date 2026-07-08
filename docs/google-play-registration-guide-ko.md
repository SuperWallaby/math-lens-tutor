# 우열 — Google Play 등록 가이드

Google Play Console에 **우열** Android 앱을 처음 등록·출시할 때 따라갈 단계입니다.

## 관련 문서


| 문서                                                                 | 내용                                 |
| ------------------------------------------------------------------ | ---------------------------------- |
| **이 파일**                                                           | Play Console 등록·제출 절차 (Android 전용) |
| `[store-release-checklist-ko.md](./store-release-checklist-ko.md)` | iOS+Android 공통 체크리스트, 스크린샷 규격      |
| `[mobile-app-store-guide-ko.md](./mobile-app-store-guide-ko.md)`   | 빌드 명령, 번들 ID, API URL              |
| `[flutter_app/README.md](../flutter_app/README.md)`                | 카카오·Google·Apple OAuth 설정          |


## 앱 식별 정보 (고정값)


| 항목                      | 값                                             |
| ----------------------- | --------------------------------------------- |
| 앱 이름 (스토어)              | **우열**                                        |
| 패키지 이름 (Application ID) | `**com.neoproject.study`** — 생성 후 **변경 불가**   |
| API (프로덕션)              | `https://study-hazel-six.vercel.app`         |
| 개인정보 처리방침 URL           | `https://study-hazel-six.vercel.app/privacy` (⚠️ `study-alpha-rosy` 등 구 URL 사용 금지) |
| 계정·데이터 삭제 URL            | `https://study-hazel-six.vercel.app/account-deletion` |
| 카테고리                    | 교육                                            |


---

## 0. 사전 준비

1. **Google Play 개발자 계정**
  [Google Play Console](https://play.google.com/console) 가입 (1회 등록비 약 $25).  
   개인/조직 중 하나 선택 후 결제·본인 확인 완료.
2. **릴리스 서명 키 (필수)**
  현재 `flutter_app/android/app/build.gradle.kts` 의 release 빌드는 **debug 키**로 서명되어 있을 수 있습니다.  
   **Play에 올리는 AAB는 release keystore로 서명**해야 합니다.
   `flutter_app/android/key.properties` (git에 커밋하지 말 것):
   `build.gradle.kts` 에 release `signingConfigs` 연결 후 다시 빌드:
  > Play **앱 서명**을 켜면 Google이 앱 서명 키를 관리하고, 개발자는 **업로드 키**만으로 AAB를 올립니다. 첫 업로드 시 업로드 키 등록 절차가 나옵니다.
3. **OAuth·카카오 (출시 전)**
  - Google Cloud: Android OAuth 클라이언트 — 패키지 `com.neoproject.study` + **SHA-1**(release/upload keystore)  
  - [Kakao Developers](https://developers.kakao.com/console/app): Android 플랫폼 — 패키지명 + **키 해시**  
    ```bash
    npm run kakao:key-hash   # debug 해시
    # release/upload keystore SHA-1 → 카카오 콘솔에 추가 등록
    ```
  - Vercel env: `GOOGLE_CLIENT_ID_ANDROID`, `KAKAO_NATIVE_APP_KEY`, `KAKAO_REST_API_KEY` 등  
  - 상세: `flutter_app/README.md`

---

## 1. Play Console에서 앱 만들기

1. [Play Console](https://play.google.com/console) → **앱 만들기**
2. **앱 이름**: 우열
3. **기본 언어**: 한국어
4. **앱 / 게임**: 앱
5. **유료 / 무료**: 무료
6. **개발자 프로그램 정책** 동의
7. **앱 설정 → 앱 무결성** (또는 첫 업로드 시 안내)
  - **Google Play 앱 서명** 사용 권장 (기본)  
  - 업로드 키 인증서(SHA-1)를 Google OAuth·카카오에 등록
8. **패키지 이름**
  첫 AAB 업로드 시 `com.neoproject.study` 가 자동으로 고정됩니다.  
   Console에서 미리 다른 패키지로 만들지 마세요 — 코드와 **반드시 동일**해야 합니다.

---

## 2. AAB 빌드

```bash
# 레포 루트
yarn flutter:release:bump      # 스토어 제출마다 빌드번호 +1 권장
# 또는
yarn flutter:release:android   # 버전 그대로 Android만
```

산출물:

```
flutter_app/releases/<버전>/wooyeol-*-build*.aab
```

예: `flutter_app/releases/1.0.2+4/wooyeol-1.0.2-build4.aab`

---

## 3. 스토어 등록정보 (스토어 설정)

**Play Console → 해당 앱 → 스토어 설정 → 기본 스토어 등록정보**


| 항목          | 가이드                                           |
| ----------- | --------------------------------------------- |
| 앱 이름        | 우열                                            |
| 간단한 설명      | 80자 이내 (예: AI가 풀이 사진을 분석하고 유사 문제로 연습하는 수학 튜터) |
| 자세한 설명      | 4000자 이내 — 업로드·분석·연습·학부모 코칭 요약                |
| 앱 아이콘       | 512×512 PNG → `flutter_app/branding/play-store-icon-512.png` |
| 그래픽 이미지     | 1024×500 → `flutter_app/branding/play-store-feature-graphic-1024x500.png` |
| 스크린샷 (휴대전화) | **최소 2장**, 세로 권장 1080×1920 ~ 1440×2560        |
| 태블릿         | 선택 — iPad 캡처 리사이즈 재사용 가능                      |


스크린샷 생성:

```bash
./scripts/capture-flutter-store-screenshots.sh
# 휴대전화용: screen-shots/ios-app-store-6.7in-1290x2796/ 를 1080×1920 등으로 리사이즈
```

캡처 화면: 학생 홈, 업로드, 분석, 연습, 학부모 홈, 학부모 설명 (6장) — `[store-release-checklist-ko.md](./store-release-checklist-ko.md)` 참고.

---

## 4. 앱 콘텐츠 (정책·설문)

대시보드 **앱 콘텐츠**에서 항목별로 완료 표시가 나올 때까지 진행합니다.

### 4.1 개인정보 처리방침 · 계정 삭제

| 항목 | URL |
|------|-----|
| 개인정보 처리방침 | `https://study-hazel-six.vercel.app/privacy` |
| **계정·데이터 삭제 (Play 필수)** | **`https://study-hazel-six.vercel.app/account-deletion`** |

Play Console **데이터 보안** → 계정 삭제 링크 칸에는 **`/account-deletion`** URL을 넣습니다.

### 4.2 앱 액세스 권한 (App access) — **영어로 입력**

Play Console → **앱 콘텐츠** → **앱 액세스 권한** → **앱의 일부 또는 전체 기능에 제한이 있음**

우열은 로그인 후 학습·학부모 기능을 씁니다. Google은 심사 시 **로그인 세부정보를 영어**로 요구합니다.

#### 심사용 계정 (코드 기본값)

**`devstudy*@wooyeol.com`** — **이메일로 시작하기** → 주소 입력 → **비밀번호 없이 즉시 로그인** (서버 배포 후 프로덕션에서도 동작)

| 용도 | 이메일 예시 |
|------|-------------|
| 학생 | `devstudy.student@wooyeol.com` |
| 학부모 | `devstudy.parent@wooyeol.com` |

본인 폰에서 한 번씩 로그인해 역할·학년·학생 연결·샘플 업로드를 세팅해 두면 심사가 수월합니다.

#### Play Console에 붙여넣을 영문 (복사용)

```
Wooyeol requires sign-in to save learning history and use parent features.

Email sign-in (no password):
1. Open the app.
2. Tap "이메일로 시작하기" (Start with email).
3. Enter a review email below and continue — signed in immediately (no inbox needed).

Student: devstudy.student@wooyeol.com
Parent:  devstudy.parent@wooyeol.com

If profile setup appears:
- Student: role "학생" (Student) → grade "중1" → complete onboarding slides.
- Parent: role "학부모" (Parent) → enter student code WY-XXXXXX from student Settings.

Guest trial: tap "로그인 없이 체험하기" for upload/analysis without account. Parent/coaching needs parent email above.

Notes: Teacher role disabled. Camera for worksheet photos. UI in Korean.
```

`WY-XXXXXX`는 실제 세팅 값으로 바꿔 넣으세요.

### 4.3 광고

- 우열에 광고 없으면 **앱에 광고 없음**

### 4.4 콘텐츠 등급

- 설문 작성 → IARC 등급 (교육 앱, 폭력·성적 콘텐츠 없음 등)

### 4.5 타깃층 및 콘텐츠

- 대상 연령·아동 대상 여부 솔직히 선택 (미성년 학습 앱이면 아동 관련 항목 주의)

### 4.6 데이터 보안 (중요)

`AndroidManifest` 기준 실제 수집·전송 데이터에 맞게 작성:


| 권한/데이터 | 용도                           |
| ------ | ---------------------------- |
| 인터넷    | API 통신                       |
| 카메라    | 문제 사진 촬영                     |
| 사진/미디어 | 갤러리에서 문제 이미지 선택              |
| 계정 정보  | OAuth (Google, Apple, Kakao) |
| 학습 데이터 | 풀이·분석·연습 기록 (서버 저장)          |


- 데이터 **암호화 전송**(HTTPS) 여부: 예  
- 사용자가 **삭제 요청** 가능 여부: 정책·고객 문의에 맞게  
- 제3자 공유: OAuth 제공자·호스팅(Vercel) 등 실제와 일치하게

### 4.7 정부 앱 / 금융 기능 등

- 해당 없으면 **아니오**

---

## 5. 테스트 → 프로덕션 업로드

### 5.1 내부 테스트 (권장 첫 단계)

1. **테스트 → 내부 테스트** → 새 릴리스 만들기
2. **App bundle** 업로드: `wooyeol-*-build*.aab`
3. **출시 이름 / 릴리스 노트** (한국어)
4. 테스터 이메일 목록 추가 → 링크로 설치 확인
5. 회원가입, 사진 업로드, 분석, 학부모 연결, 카카오/구글 로그인 검증

### 5.2 프로덕션

내부·비공개 테스트에서 문제 없으면:

1. **프로덕션** → 새 릴리스
2. 동일 AAB (또는 수정 후 빌드번호 올린 새 AAB)
3. **국가/지역**: 대한민국 (필요 시 추가)
4. **검토 제출**

첫 프로덕션 출시는 Google 검토에 **수일** 걸릴 수 있습니다.

---

## 6. 버전·업데이트 규칙


| 파일                         | 역할                               |
| -------------------------- | -------------------------------- |
| `flutter_app/pubspec.yaml` | `version: 1.0.2+4` → `이름+빌드번호`   |
| Play `versionCode`         | `+` 뒤 숫자 (4) — **매 업로드마다 증가 필수** |
| Play `versionName`         | `1.0.2` — 사용자에게 보이는 버전           |


```bash
yarn flutter:release:bump   # 1.0.2+4 → 1.0.2+5
```

---

## 7. 제출 전 체크리스트

- [ ] Release keystore로 서명한 `.aab`
- [ ] `versionCode` 이전 업로드보다 큼
- [ ] 프로덕션 API 동작 (`/api/auth/me`, 업로드·분석)
- [ ] Google Android OAuth SHA-1 = **업로드 keystore** (debug 아님)
- [ ] 카카오 Android 키 해시 = release/upload keystore
- [ ] 개인정보 URL·데이터 보안 설문 일치
- [ ] 스크린샷 2장 이상 (학부모 UI 포함 권장)
- [ ] 심사용 `devstudy*@wooyeol.com` 계정 세팅 + 앱 액세스 권한 영문 안내

---

## 8. 자주 하는 실수


| 증상                     | 원인                     | 조치                                  |
| ---------------------- | ---------------------- | ----------------------------------- |
| 업로드 거부 (서명)            | debug 키로 빌드            | release keystore 설정 후 재빌드           |
| Google 로그인 실패 (출시 빌드만) | OAuth SHA-1이 debug만 등록 | Play 업로드 키 SHA-1을 Cloud Console에 추가 |
| 카카오 로그인 실패             | 키 해시 미등록               | release keystore 해시를 카카오 콘솔에 추가     |
| versionCode 충돌         | 빌드번호 미증가               | `yarn flutter:release:bump`         |
| 정책 보류                  | 데이터 보안·아동 정책 불일치       | 앱 콘텐츠 설문 재확인                        |


Play Console **업로드 키 SHA-1** 확인:  
앱 → **앱 무결성** → **업로드 키 인증서**

---

## 9. 유용한 링크

- [Play Console](https://play.google.com/console)
- [앱 서명](https://developer.android.com/studio/publish/app-signing)
- [스토어 등록정보 요구사항](https://support.google.com/googleplay/android-developer/answer/9866151)
- [데이터 보안 양식](https://support.google.com/googleplay/android-developer/answer/10787469)

