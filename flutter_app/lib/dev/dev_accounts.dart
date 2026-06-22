/// 로컬 개발용 빈 계정 — 서버 `src/lib/dev-accounts.ts` 와 id 동기화
class DevAccountOption {
  const DevAccountOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

const devAccountOptions = [
  DevAccountOption(id: 'empty-1', label: '빈 계정 · 민준'),
  DevAccountOption(id: 'empty-2', label: '빈 계정 · 서연'),
  DevAccountOption(id: 'empty-3', label: '빈 계정 · 준호'),
  DevAccountOption(id: 'empty-4', label: '빈 계정 · 지우'),
  DevAccountOption(id: 'empty-5', label: '빈 계정 · 하은'),
];

List<DevAccountOption> get devAccountOptionsList => devAccountOptions;
