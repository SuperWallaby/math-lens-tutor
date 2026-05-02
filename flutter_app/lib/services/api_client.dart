import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl = (baseUrl ?? _defaultBaseUrl).replaceAll(RegExp(r'/$'), ''),
      _deviceId = _loadOrCreateDeviceId();

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://study-alpha-rosy.vercel.app',
  );
  static const _deviceIdKey = 'anonymous_device_id';

  final String baseUrl;
  final Future<String> _deviceId;

  Future<AnalyzeResult> analyzeImage(File imageFile) async {
    final uri = Uri.parse('$baseUrl/api/analyze');
    final request = http.MultipartRequest('POST', uri);
    request.headers['X-Device-Id'] = await _deviceId;
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '분석 요청에 실패했습니다.');
    }

    return AnalyzeResult.fromJson(body);
  }

  Future<GeneratedProblemSet> getProblemSet(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/problem-sets/$id'),
      headers: await _deviceHeaders(),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '문제 세트를 불러오지 못했습니다.');
    }

    return GeneratedProblemSet.fromJson(
      (body['problemSet'] as Map).cast<String, dynamic>(),
    );
  }

  Future<ProblemAttempt> submitAnswer({
    required String setId,
    required String problemId,
    required String answer,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/attempts'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'setId': setId,
        'problemId': problemId,
        'answer': answer,
      }),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '답안을 제출하지 못했습니다.');
    }

    return ProblemAttempt.fromJson(body);
  }

  Future<LearningInsight> getInsight() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/insights'),
      headers: await _deviceHeaders(),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '학습 데이터를 불러오지 못했습니다.');
    }

    return LearningInsight.fromJson(
      (body['insight'] as Map).cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {
      throw ApiException('서버 응답을 읽을 수 없습니다.');
    }
  }

  Future<Map<String, String>> _deviceHeaders() async {
    return {'X-Device-Id': await _deviceId};
  }

  Future<Map<String, String>> _jsonHeaders() async {
    return {'Content-Type': 'application/json', 'X-Device-Id': await _deviceId};
  }

  static Future<String> _loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _generateAnonymousDeviceId();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  static String _generateAnonymousDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final suffix = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'device_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
