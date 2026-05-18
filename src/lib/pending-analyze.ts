/** 업로드 →스트리밍 결과 페이지로 넘길 때만 사용 (메모리, 새로고침 시 사라짐) */
let pendingFile: File | null = null;

export function setPendingAnalyzeFile(file: File) {
  pendingFile = file;
}

export function takePendingAnalyzeFile(): File | null {
  const file = pendingFile;
  pendingFile = null;
  return file;
}
