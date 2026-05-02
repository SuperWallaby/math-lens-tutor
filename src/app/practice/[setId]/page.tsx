import { notFound } from "next/navigation";
import { AppShell } from "@/components/AppShell";
import { PracticeRunner } from "@/components/PracticeRunner";
import { getProblemSet } from "@/lib/store";

export default async function PracticePage({
  params,
}: {
  params: Promise<{ setId: string }>;
}) {
  const { setId } = await params;
  const problemSet = await getProblemSet(setId);

  if (!problemSet) {
    notFound();
  }

  return (
    <AppShell>
      <div className="mb-8">
        <p className="text-sm font-medium text-blue-200">Step 2</p>
        <h1 className="mt-3 text-4xl font-black">{problemSet.title}</h1>
        <p className="mt-4 max-w-3xl leading-8 text-slate-300">
          {problemSet.learningGoal}
        </p>
      </div>
      <PracticeRunner problemSet={problemSet} />
    </AppShell>
  );
}
