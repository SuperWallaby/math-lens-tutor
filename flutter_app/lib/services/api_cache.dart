/// 탭 전환 시 불필요한 API 재조회를 줄이는 TTL.
const tabDataCacheTtl = Duration(seconds: 90);

class TimedCache<T> {
  T? value;
  DateTime? fetchedAt;
  Future<T>? inflight;

  bool get isFresh {
    final v = value;
    final at = fetchedAt;
    if (v == null || at == null) return false;
    return DateTime.now().difference(at) < tabDataCacheTtl;
  }

  void store(T next) {
    value = next;
    fetchedAt = DateTime.now();
    inflight = null;
  }

  void invalidate() {
    value = null;
    fetchedAt = null;
    inflight = null;
  }
}
