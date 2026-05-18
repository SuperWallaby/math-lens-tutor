import { AppShell } from "@/components/AppShell";
import { UploadForm } from "@/components/UploadForm";

export default function UploadPage() {
  return (
    <AppShell>
      <div className="mx-auto max-w-3xl">
        <p className="text-sm font-medium text-blue-200">Step 1</p>
        <h1 className="mt-3 text-4xl font-black">수학 풀이 사진 분석</h1>
        <p className="mt-4 leading-8 text-slate-300">
          풀이 과정과 선택한 정답이 보이는 사진을 업로드하세요. 문제·풀이 단계·오답
          가능성·부족 개념을 읽고 유사 문제를 만들어 드립니다.
        </p>
        <div className="mt-8">
          <UploadForm />
        </div>
      </div>
    </AppShell>
  );
}
