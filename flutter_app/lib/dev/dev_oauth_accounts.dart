/// 로컬 개발용 OAuth 계정 — 서버 `src/lib/dev-oauth-accounts.ts` 와 id 동기화
class DevOAuthLoginOption {
  const DevOAuthLoginOption({
    required this.id,
    required this.label,
    required this.provider,
    required this.email,
  });

  final String id;
  final String label;
  final String provider;
  final String email;
}

const devOAuthLoginOptions = [
  DevOAuthLoginOption(
    id: 'kakao-crawl123',
    label: '카카오 · crawl123@naver.com',
    provider: 'kakao',
    email: 'crawl123@naver.com',
  ),
  DevOAuthLoginOption(
    id: 'apple-crawl123',
    label: 'Apple · crawl123@naver.com',
    provider: 'apple',
    email: 'crawl123@naver.com',
  ),
];

List<DevOAuthLoginOption> get devOAuthLoginOptionsList => devOAuthLoginOptions;
