import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web hot restart 시 `SharedPreferences.getInstance()` 동시 호출 deadlock 방지.
Future<SharedPreferences>? _prefsFuture;

Future<SharedPreferences> getAppPrefs() {
  return _prefsFuture ??= _loadPrefs();
}

Future<SharedPreferences> _loadPrefs() async {
  try {
    return await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 5),
    );
  } on TimeoutException catch (e) {
    if (kDebugMode) {
      debugPrint('[app_prefs] SharedPreferences timeout (web hot restart?): $e');
    }
    _prefsFuture = null;
    rethrow;
  }
}

/// prefs 접근 실패 시 bootstrap 이 영원히 로딩에 걸리지 않도록.
void resetAppPrefsCache() {
  _prefsFuture = null;
}
