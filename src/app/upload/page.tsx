import { redirect } from "next/navigation";

/** 웹 핵심 기능은 앱 가입 후 이용 — API도 JWT 필수 */
export default function UploadPage() {
  redirect("/signup");
}
