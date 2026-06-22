# 우열 스토어 출시 체크리스트

## 1. 빌드 산출물 (완료 시 `flutter_app/releases/<버전>/`)

| 파일 | 용도 |
|------|------|
| `wooyeol-*-build*.ipa` | App Store / TestFlight |
| `wooyeol-*-build*.aab` | Google Play (필수) |
| `wooyeol-*-build*.apk` | 내부 테스트·직접 설치 |

```bash
# 레포 루트
yarn flutter:release:bump    # 빌드번호 +1 후 IPA+AAB+APK
yarn flutter:release:ios     # iOS만
yarn flutter:release:android # Android만
```

현재 빌드: **1.0.2+4**  
폴더: `flutter_app/releases/1.0.2+4/`

- API: `https://study-hazel-six.vercel.app`
- 번들 ID: `com.neoproject.study`

## 2. 스토어 업로드

### Apple

1. [Transporter](https://apps.apple.com/us/app/transporter/id1450874784)로 `.ipa` 업로드  
   또는 Xcode → Organizer → Distribute App
2. App Store Connect → TestFlight 확인
3. 스크린샷·메타데이터 입력 후 심사 제출

### Google Play

상세 절차: **[`docs/google-play-registration-guide-ko.md`](./google-play-registration-guide-ko.md)**

1. Play Console → **내부 테스트** 또는 **프로덕션**
2. `.aab` 업로드
3. 데이터 보안 설문·스토어 등록정보·스크린샷

## 3. 스크린샷 규격

### iOS (App Store Connect)

| 슬롯 | 픽셀 (세로) | 폴더 |
|------|-------------|------|
| iPhone 6.7" | 1290 × 2796 | `screen-shots/ios-app-store-6.7in-1290x2796/` |
| iPhone 6.5" | 1284 × 2778 | `screen-shots/ios-app-store-6.5in-1284x2778/` |
| iPhone (구형) | 1242 × 2688 | `screen-shots/ios-app-store-1242x2688/` |
| iPad 12.9"/13" | 2048 × 2732 | `screen-shots/ios-ipad-12.9-2048x2732/` |

6.7" 세트만 올려도 되는 경우가 많지만, Connect에서 요구하는 슬롯을 확인하세요.

### Android (Play Console)

- **휴대전화**: 최소 2장, 권장 1080×1920 ~ 1440×2560 (세로)
- **7인치 태블릿 / 10인치**: iPad 캡처 리사이즈 재사용 가능
- 6.7" iPhone 캡처를 1080×1920으로 리사이즈해도 무방

### 캡처 방법 (Flutter 시뮬레이터)

```bash
# 레포 루트 — iPhone + iPad 6화면 자동 (학생 4 + 학부모 2)
./scripts/capture-flutter-store-screenshots.sh

# 기기 이름이 다르면
IPHONE_DEVICE="iPhone 15 Pro Max" IPAD_DEVICE="iPad Pro 13-inch (M4)" \
  ./scripts/capture-flutter-store-screenshots.sh
```

캡처 화면 (`STORE_SCREENSHOT`):

| 파일 | 화면 |
|------|------|
| 01-student-home | 학생 홈 |
| 02-upload | 업로드 |
| 03-analysis | 분석 결과 |
| 04-practice | 연습 |
| 05-parent-home | 학부모 홈 (코칭 카드) |
| 06-parent-explain | 학부모 틀린 문제 설명 |

수동 1장:

```bash
cd flutter_app
flutter run -d "iPhone 16 Pro Max" \
  --dart-define=STORE_SCREENSHOT=parent-home \
  --release
# 다른 터미널
flutter screenshot -o ../screen-shots/flutter-iphone-raw/test.png
```

기존 iPad만: `./scripts/capture-flutter-ipad-screenshots.sh`

## 4. 스토어 메타데이터 (초안)

- **앱 이름**: 우열
- **부제**: AI 수학 튜터 — 풀이 분석·유사문제
- **개인정보 처리방침**: https://study-hazel-six.vercel.app/privacy
- **계정·데이터 삭제**: https://study-hazel-six.vercel.app/account-deletion
- **카테고리**: 교육
- **연령**: 4+ (또는 9+ — 콘텐츠에 맞게)

## 5. 제출 전 확인

- [ ] 프로덕션 API 응답 정상 (`/api/auth/me` 등)
- [ ] OAuth (Google / Apple / Kakao) 프로덕션 키·리다이렉트 URI
- [ ] TestFlight / 내부 테스트에서 회원가입 → 학생·학부모 플로우
- [ ] 스크린샷 6장 이상 (학부모 UI 포함)
- [ ] 빌드번호 증가 (`yarn flutter:release:bump`)

## 6. 다음 버전 제출 시

```bash
yarn flutter:release:bump   # 1.0.2+4 → 1.0.2+5
./scripts/capture-flutter-store-screenshots.sh
# IPA/AAB 업로드 + 스크린샷 갱신
```
