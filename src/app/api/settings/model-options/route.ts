import { NextResponse } from "next/server";
import {
  buildTextDeploymentCandidateList,
  buildVisionDeploymentCandidateList,
} from "@/lib/model-deployment-options";
import { hasAzureOpenAiConfig } from "@/lib/azure";

export const runtime = "nodejs";

/** 설정 화면·클라이언트가 `/api/analyze`에 넘길 수 있는 배포 이름 후보만 노출 */
export async function GET() {
  if (!hasAzureOpenAiConfig()) {
    return NextResponse.json({
      vision: [] as string[],
      text: [] as string[],
      configured: false,
    });
  }

  return NextResponse.json({
    vision: buildVisionDeploymentCandidateList(),
    text: buildTextDeploymentCandidateList(),
    configured: true,
  });
}
