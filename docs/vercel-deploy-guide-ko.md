# Vercel 배포 가이드 (웹 우선)

이 레포의 **Next.js 웹 앱**을 Vercel에 올리는 절차입니다. Flutter 네이티브 앱은 나중에 배포된 HTTPS URL을 `--dart-define=API_BASE_URL`로 넘기면 됩니다.

## 전제

- GitHub/GitLab/Bitbucket 등에 레포가 연결되어 있거나, Vercel CLI로 배포할 수 있음
- Node 패키지 매니저는 **npm** 기준 (`package-lock.json` 사용)

## 이 레포에서 이미 맞춰 둔 것

- **GitHub**: [SuperWallaby/math-lens-tutor](https://github.com/SuperWallaby/math-lens-tutor) (`main` 푸시)
- **Vercel 프로덕션(별칭 예시)**: `https://study-alpha-rosy.vercel.app` — 팀·프로젝트 이름에 따라 URL은 대시보드 기준으로 확인
- **웹만 배포**: 루트에 `.vercelignore`로 `flutter_app/`, `mobile/` 업로드 제외 → 빌드 시간·용량 절감
- **타입 검사**: `tsconfig.json`에서 `flutter_app`, `mobile` 제외 → Expo 코드가 Next 빌드를 깨지 않음

Git 저장소는 처음부터 있었고(`git init` 중복 불필요), 원격만 추가해 푸시한 상태입니다.

### GitHub 자동 배포가 안 될 때

Vercel 대시보드에서 GitHub **Login Connection**이 없으면 레포 Import/Git 연동이 실패할 수 있습니다. [계정 연결 문서](https://vercel.com/docs/accounts/create-an-account#login-methods-and-connections)를 따라 GitHub를 연결한 뒤, 프로젝트에 레포를 연결하면 `git push`마다 자동 배포됩니다. 연결 전에는 **Vercel CLI**로 배포할 수 있습니다.

```bash
export npm_config_cache="$(pwd)/.npm-cache-cli"
mkdir -p "$npm_config_cache"
npx vercel@latest deploy --prod --yes --scope <팀-slug>
```

팀이 여러 개면 CLI가 `--scope`를 요구합니다. 대시보드 URL의 `/team-slug/project` 형태를 참고하세요.

### 빌드 시 `.env` 경고

Vercel 빌드 로그에 로컬 `.env` 감지 경고가 나오면, 프로덕션·프리뷰용 값은 **Vercel 환경 변수**로만 두고 저장소에는 시크릿을 넣지 마세요(`.gitignore`에 `.env*` 포함).

## 1. Vercel에서 새 프로젝트 만들기

1. [Vercel Dashboard](https://vercel.com) → **Add New…** → **Project**
2. 레포지토리 Import
3. **Framework Preset**: Next.js (자동 인식되는 경우 그대로)
4. **Root Directory**: 레포 루트 그대로 (`/`). 이 레포는 Next 앱이 루트에 있습니다.

### 빌드 설정 (대부분 기본값 그대로)

| 항목 | 값 |
| --- | --- |
| Install Command | `npm install` 또는 `npm ci` |
| Build Command | `npm run build` |
| Output Directory | Next.js 기본 (직접 지정 불필요) |
| Node.js Version | Vercel 권장 LTS (프로젝트와 맞으면 OK) |

## 2. 환경 변수 (필수/권장)

Vercel 프로젝트 → **Settings** → **Environment Variables**에 아래를 넣습니다. **Production** (필요하면 Preview/Development도 동일)에 체크합니다.

### Azure OpenAI (이미지 분석·문제 생성)

없으면 API는 **샘플 데이터**로 동작할 수 있으나, 실서비스 분석은 반드시 설정하는 것이 좋습니다.

| Name | 설명 |
| --- | --- |
| `AZURE_OPENAI_ENDPOINT` | 예: `https://<리소스명>.openai.azure.com` (끝 `/` 없어도 됨) |
| `AZURE_OPENAI_API_KEY` | Azure 포털에서 발급한 키 |
| `AZURE_OPENAI_DEPLOYMENT` | 배포 이름 (비전 가능 모델, 예: `gpt-4o`) |
| `AZURE_OPENAI_DEPLOYMENT_*` | 선택. 빠름/밸런스/정확 모드별 배포 — 예시는 `.env.example` 참고 |
| `AZURE_OPENAI_DEPLOYMENT_VISION` | 선택. 비선 시 밸런스 배포로 폴백 |
| `AZURE_OPENAI_API_VERSION` | 선택. 미설정 시 코드 기본값 `2024-08-01-preview` |

**한국 중부 리전:** 주 사용자가 한국이라면 Cognitive Services 계정을 `koreacentral`에 두고 엔드포인트만 바꿀 수 있습니다. 이 구독 예시에서는 `TestAzResourceAi`에 `trx-kr-gpt-4-1-mini`, `trx-kr-gpt-4-1-vision`, 정확 모드용 기존 `gpt-5.4` 배포가 사용 가능합니다(`gpt-5.4-pro`는 해당 리전 카탈로그에 없을 수 있음). 자세한 키·값 예시는 루트 `.env.example` 주석 블록을 따르세요.

### MongoDB (영구 저장)

없으면 서버는 **메모리 저장소**로 동작해 재배포 시 데이터가 사라집니다. 프로덕션에서는 설정을 권장합니다.

| Name | 설명 |
| --- | --- |
| `MONGODB_URI` | Atlas 등 연결 문자열 |
| `MONGODB_DB_NAME` | 선택. 미설정 시 `math_lens_tutor` |

### MongoDB Atlas 방화벽

Vercel 서버리스는 고정 IP가 아닙니다. Atlas 사용 시 **Network Access**에서 접근 허용 범위를 서비스 정책에 맞게 설정하세요. (예: `0.0.0.0/0` 허용은 편하지만 보안 정책과 트레이드오프가 있습니다.)

## 3. 배포 후 확인

배포가 끝나면 발급된 도메인(예: `https://xxx.vercel.app`)으로 아래를 확인합니다.

1. **메인 페이지**: `/`
2. **업로드·분석**: `/upload` — 풀이 사진 업로드 후 분석이 되는지
3. **개인정보 처리방침**: `/privacy` — 스토어 제출용 URL로 사용 가능
4. **대시보드**: `/dashboard` — MongoDB 연결 시 기기/사용자별 데이터 정책에 맞게 동작하는지

서버 오류 시 MongoDB가 연결되어 있으면 **`api_error_logs`** 컬렉션에 에러 로그가 남을 수 있습니다.

## 4. 웹 클라이언트와 익명 기기 ID

브라우저에서 웹 UI만 쓸 때는 Flutter와 달리 **`X-Device-Id` 헤더를 자동으로 붙이지 않습니다.**  
현재 API는 헤더가 없으면 내부적으로 데모 사용자 기준으로 처리할 수 있습니다. 나중에 웹에서도 기기별 분리가 필요하면 **localStorage에 익명 ID를 두고 fetch 헤더에 넣는 방식**으로 확장하면 됩니다.

Flutter 앱은 이미 `X-Device-Id`를 보내도록 되어 있습니다.

## 5. 다음 단계 (Flutter 앱을 같은 백엔드로 붙일 때)

배포된 프로덕션 URL을 확정한 뒤:

```bash
cd flutter_app
flutter run --dart-define=API_BASE_URL=https://your-project.vercel.app
```

스토어 빌드 예:

```bash
flutter build appbundle --dart-define=API_BASE_URL=https://your-project.vercel.app
```

## 6. 자주 나오는 이슈

| 증상 | 점검 |
| --- | --- |
| 분석이 항상 샘플만 된다 | `AZURE_OPENAI_*` 누락/오타, 배포가 비전 미지원 모델인지 |
| 데이터가 재배포마다 사라진다 | `MONGODB_URI` 미설정 → 메모리 스토어 모드 |
| Mongo 연결 실패 | Atlas IP 허용 목록, URI 사용자/비밀번호, DB 이름 |
| 이미지 분석 400 (MIME) | 서버에서 이미지 MIME 보정 로직이 있으나, 극단적 파일명은 확장자 확인 |

---

배포 URL이 정해지면 `docs/mobile-app-store-guide-ko.md`의 백엔드 주소 항목에 같은 URL을 적어 두면 Flutter·웹·스토어 안내가 한결 맞습니다.
