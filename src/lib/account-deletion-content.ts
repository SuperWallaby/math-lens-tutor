/** Google Play / App Store 계정·데이터 삭제 안내 — privacy·account-deletion 페이지 공용 */

export const APP_NAME = "우열";
export const APP_NAME_EN = "Wooyeol";
export const PUBLIC_SITE_URL =
  process.env.APP_PUBLIC_URL?.replace(/\/$/, "") ||
  "https://study-hazel-six.vercel.app";

export function supportEmail(): string {
  return (
    process.env.SUPPORT_EMAIL?.trim() ||
    process.env.NEXT_PUBLIC_SUPPORT_EMAIL?.trim() ||
    "support@wooyeol.com"
  );
}

export const ACCOUNT_DELETION_PATH = "/account-deletion";

export function accountDeletionUrl(): string {
  return `${PUBLIC_SITE_URL}${ACCOUNT_DELETION_PATH}`;
}

export const deletedDataItems = [
  "계정 프로필(표시 이름, 역할, 학년, 학생 고유번호 등)",
  "OAuth·이메일 로그인과 연결된 사용자 레코드",
  "학부모·학생·교사 간 연결(student_links)",
  "업로드한 풀이 사진 및 분석 결과",
  "유사 문제 세트, 연습·채점 기록",
  "학습 프로필·피드 관련 서버 저장 데이터",
  "해당 계정과 연결된 객체 스토리지(R2) 파일",
];

export const retainedDataItems = [
  "법령에 따라 보관이 필요한 경우 해당 법정 기간 동안 최소한의 기록",
  "익명·집계된 통계(개인을 식별할 수 없는 형태)",
];
