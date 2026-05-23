import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import 'api_base_url.dart';
import 'auth_session.dart';
import 'image_prepare_for_upload.dart';
import 'oauth_service.dart';

/// iOS/Android: 긴 NDJSON 스트림 대신 짧은 HTTP 3회(vision→tutor→similar).
bool get _usePhasedAnalyze => !kIsWeb;

class ApiClient {
  ApiClient({
    String? baseUrl,
    required this.authSession,
  }) : baseUrl = (baseUrl ?? resolveApiBaseUrl()).replaceAll(RegExp(r'/$'), ''),
       _deviceId = _loadOrCreateDeviceId() {
    if (kDebugMode) {
      debugPrint('[ApiClient] baseUrl=$baseUrl (debug→local unless API_BASE_URL set)');
    }
  }

  static const _deviceIdKey = 'anonymous_device_id';

  final String baseUrl;
  final AuthSession authSession;
  final Future<String> _deviceId;
  VoidCallback? onUnauthorized;

  MediaType _guessImageMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.bmp')) return MediaType('image', 'bmp');
    return MediaType('image', 'jpeg');
  }

  Future<AnalyzeResult> analyzeImageBytes(
    Uint8List bytes, {
    required String filename,
    AnalyzeQualityMode qualityMode = AnalyzeQualityMode.balanced,
    void Function(String progressMessage)? onProgress,
    void Function(Map<String, dynamic> event)? onStreamEvent,
  }) async {
    if (_usePhasedAnalyze) {
      return _analyzeImageBytesPhased(
        bytes,
        filename: filename,
        qualityMode: qualityMode,
        onProgress: onProgress,
        onStreamEvent: onStreamEvent,
      );
    }
    return _analyzeImageBytesStreaming(
      bytes,
      filename: filename,
      qualityMode: qualityMode,
      onProgress: onProgress,
      onStreamEvent: onStreamEvent,
    );
  }

  Future<AnalyzeResult> _analyzeImageBytesPhased(
    Uint8List bytes, {
    required String filename,
    required AnalyzeQualityMode qualityMode,
    void Function(String progressMessage)? onProgress,
    void Function(Map<String, dynamic> event)? onStreamEvent,
  }) async {
    final prepared = prepareImageBytesForAnalyzeUpload(bytes, filename);

    void emitProgress(String step, String message) {
      onProgress?.call(message);
      onStreamEvent?.call({
        'type': 'progress',
        'step': step,
        'message': message,
      });
    }

    void emitPartial(Map<String, dynamic> event) => onStreamEvent?.call(event);

    try {
      emitProgress('upload', '사진 읽는 중…');

      final visionRequest = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/analyze/vision'),
      );
      visionRequest.headers.addAll(await _authHeaders());
      visionRequest.fields['qualityMode'] = qualityMode.name;
      visionRequest.files.add(
        http.MultipartFile.fromBytes(
          'image',
          prepared.bytes,
          filename: prepared.filename,
          contentType: _guessImageMediaType(prepared.filename),
        ),
      );

      emitProgress('vision', '사진에서 문제 읽는 중…');
      final visionResponse = await visionRequest.send().timeout(
        const Duration(minutes: 3),
      );
      final visionBody = await http.Response.fromStream(visionResponse);
      final visionJson = _decodeMap(visionBody);
      if (visionResponse.statusCode >= 400) {
        throw ApiException(
          visionJson['error'] as String? ?? '사진을 읽지 못했습니다.',
        );
      }

      emitPartial({
        'type': 'meta',
        'submissionId': visionJson['submissionId'],
        'problemSetId': visionJson['problemSetId'],
        'message': '사진에서 문제 읽는 중…',
      });
      emitPartial({
        'type': 'partial',
        'step': 'vision',
        'analysis': visionJson['analysis'],
        'message': '사진에서 문제 읽는 중…',
      });

      emitProgress('tutor', '풀이 중…');

      final quality = visionJson['qualityMode'] ?? qualityMode.name;

      final tutorResponse = await http
          .post(
            Uri.parse('$baseUrl/api/analyze/tutor'),
            headers: await _jsonHeaders(),
            body: jsonEncode({
              'vision': visionJson['vision'],
              'qualityMode': quality,
              'textDeploymentName': visionJson['textDeploymentName'],
            }),
          )
          .timeout(const Duration(minutes: 3));

      final tutorJson = _decodeMap(tutorResponse);
      if (tutorResponse.statusCode >= 400) {
        throw ApiException(
          tutorJson['error'] as String? ?? '정답·오답 진단에 실패했습니다.',
        );
      }

      emitPartial({
        'type': 'partial',
        'step': 'tutor',
        'analysis': tutorJson['analysis'],
        'message': '풀이 중…',
      });

      emitProgress('similar', '유사 문제 만드는 중…');
      final similarResponse = await http
          .post(
            Uri.parse('$baseUrl/api/analyze/similar'),
            headers: await _jsonHeaders(),
            body: jsonEncode({
              'submissionId': visionJson['submissionId'],
              'problemSetId': visionJson['problemSetId'],
              'analysis': tutorJson['analysis'],
              'qualityMode': quality,
              'textDeploymentName': visionJson['textDeploymentName'],
            }),
          )
          .timeout(const Duration(minutes: 3));

      final similarJson = _decodeMap(similarResponse);
      if (similarResponse.statusCode >= 400) {
        throw ApiException(
          similarJson['error'] as String? ?? '유사 문제 생성에 실패했습니다.',
        );
      }

      emitPartial({
        'type': 'partial',
        'step': 'similar',
        'problemSet': similarJson['problemSet'],
        'message': '유사 문제 만드는 중…',
      });
      emitProgress('save', '결과 저장 중…');
      final finalizeResponse = await http
          .post(
            Uri.parse('$baseUrl/api/analyze/finalize'),
            headers: await _jsonHeaders(),
            body: jsonEncode({
              'submissionId': visionJson['submissionId'],
              'problemSetId': visionJson['problemSetId'],
              'imageUrl': visionJson['imageUrl'],
              'imageName': visionJson['imageName'],
              'analysis': tutorJson['analysis'],
              'qualityMode': quality,
              'textDeploymentName': visionJson['textDeploymentName'],
              'visionDeploymentName': visionJson['visionDeploymentName'],
              'usedSample': similarJson['usedSample'] == true,
              'problemSet': similarJson['problemSet'],
            }),
          )
          .timeout(const Duration(minutes: 2));

      final finalizeJson = _decodeMap(finalizeResponse);
      if (finalizeResponse.statusCode >= 400) {
        throw ApiException(
          finalizeJson['error'] as String? ?? '결과 저장에 실패했습니다.',
        );
      }

      return AnalyzeResult.fromJson(finalizeJson);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_friendlyNetworkMessage(e));
    }
  }

  Future<AnalyzeResult> _analyzeImageBytesStreaming(
    Uint8List bytes, {
    required String filename,
    required AnalyzeQualityMode qualityMode,
    void Function(String progressMessage)? onProgress,
    void Function(Map<String, dynamic> event)? onStreamEvent,
  }) async {
    final prepared = prepareImageBytesForAnalyzeUpload(bytes, filename);
    final uri = Uri.parse('$baseUrl/api/analyze');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeaders());
    request.fields['qualityMode'] = qualityMode.name;
    request.fields['streamProgress'] = '1';
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        prepared.bytes,
        filename: prepared.filename,
        contentType: _guessImageMediaType(prepared.filename),
      ),
    );

    try {
      final streamed = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw ApiException(
            '분석 시간이 너무 길어 요청이 중단되었습니다. 잠시 후 다시 시도해 주세요.',
          );
        },
      );

      final body = await _readAnalyzeStreamBody(
        streamed,
        onProgress: onProgress,
        onStreamEvent: onStreamEvent,
      );

      return AnalyzeResult.fromJson(body);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_friendlyNetworkMessage(e));
    }
  }

  Future<Map<String, dynamic>> _readAnalyzeStreamBody(
    http.StreamedResponse streamed, {
    void Function(String progressMessage)? onProgress,
    void Function(Map<String, dynamic> event)? onStreamEvent,
  }) async {
    final buffer = StringBuffer();
    Map<String, dynamic>? resultBody;
    String? serverError;

    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      var text = buffer.toString();
      var newline = text.indexOf('\n');
      while (newline >= 0) {
        final line = text.substring(0, newline).trim();
        text = text.substring(newline + 1);
        if (line.isNotEmpty) {
          _handleAnalyzeNdjsonLine(
            line,
            onProgress: onProgress,
            onStreamEvent: onStreamEvent,
            onResult: (m) => resultBody = m,
            onError: (msg) => serverError = msg,
          );
        }
        newline = text.indexOf('\n');
      }
      buffer
        ..clear()
        ..write(text);
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      _handleAnalyzeNdjsonLine(
        tail,
        onProgress: onProgress,
        onStreamEvent: onStreamEvent,
        onResult: (m) => resultBody = m,
        onError: (msg) => serverError = msg,
      );
    }

    if (serverError != null) {
      throw ApiException(serverError!);
    }

    if (streamed.statusCode >= 400) {
      throw ApiException(
        resultBody?['error'] as String? ?? '분석 요청에 실패했습니다.',
      );
    }

    if (resultBody == null) {
      throw ApiException('서버 응답을 읽을 수 없습니다.');
    }

    return resultBody!;
  }

  void _handleAnalyzeNdjsonLine(
    String line, {
    void Function(String progressMessage)? onProgress,
    void Function(Map<String, dynamic> event)? onStreamEvent,
    required void Function(Map<String, dynamic>) onResult,
    required void Function(String message) onError,
  }) {
    final dynamic decoded = jsonDecode(line);
    if (decoded is! Map) return;
    final map = decoded.cast<String, dynamic>();
    final type = map['type'] as String?;

    if (type == 'progress' || type == 'meta' || type == 'partial') {
      final message = map['message'] as String?;
      if (message != null && message.isNotEmpty) {
        onProgress?.call(message);
      }
      onStreamEvent?.call(map);
      return;
    }

    if (type == 'error') {
      onError(map['error'] as String? ?? '분석 요청에 실패했습니다.');
      return;
    }

    if (type == 'result') {
      onResult(map);
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {
      throw ApiException('서버 응답을 읽을 수 없습니다.');
    }
  }

  String _friendlyNetworkMessage(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('bad file descriptor') ||
        s.contains('connection reset') ||
        s.contains('broken pipe') ||
        s.contains('connection closed') ||
        s.contains('software caused connection abort')) {
      return '서버 연결이 끊어졌습니다. Wi‑Fi 상태를 확인한 뒤 다시 시도해 주세요. (분석이 길면 iOS에서 자주 발생합니다)';
    }
    if (s.contains('socketexception') || s.contains('clientexception')) {
      return '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
    }
    if (s.contains('timeoutexception') || s.contains('timed out')) {
      return '요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.';
    }
    return '분석 요청에 실패했습니다.';
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
      headers: await _authHeaders(),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '학습 데이터를 불러오지 못했습니다.');
    }

    return LearningInsight.fromJson(
      (body['insight'] as Map).cast<String, dynamic>(),
    );
  }

  Future<AppUser> signInWithOAuth(OAuthCredentialBundle credential) async {
    final payload = <String, dynamic>{
      'provider': credential.provider,
    };
    if (credential.idToken != null) {
      payload['idToken'] = credential.idToken;
    }
    if (credential.accessToken != null) {
      payload['accessToken'] = credential.accessToken;
    }
    if (credential.displayName != null) {
      payload['displayName'] = credential.displayName;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/oauth'),
      headers: await _jsonHeaders(),
      body: jsonEncode(payload),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '간편 가입에 실패했습니다.');
    }

    final token = body['token'] as String? ?? '';
    final user = AppUser.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
    await authSession.setSession(token: token, user: user);
    return user;
  }

  Future<LearningProfile> getLearningProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/learning/profile'),
      headers: await _authHeaders(),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '학습 프로필을 불러오지 못했습니다.');
    }

    return LearningProfile.fromJson(
      (body['profile'] as Map).cast<String, dynamic>(),
    );
  }

  Future<TeacherClassOverview> getTeacherOverview() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/teacher/overview'),
      headers: await _authHeaders(),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '반 현황을 불러오지 못했습니다.');
    }

    return TeacherClassOverview.fromJson(
      (body['overview'] as Map).cast<String, dynamic>(),
    );
  }

  Future<AppUser> completeProfile(
    AppUserRole role, {
    String? grade,
    String? organizationName,
  }) async {
    final payload = <String, dynamic>{'role': role.apiValue};
    if (grade != null && grade.trim().isNotEmpty) {
      payload['grade'] = grade.trim();
    }
    if (organizationName != null && organizationName.trim().isNotEmpty) {
      payload['organizationName'] = organizationName.trim();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/complete-profile'),
      headers: await _jsonHeaders(),
      body: jsonEncode(payload),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '역할 설정에 실패했습니다.');
    }

    final user = AppUser.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
    await authSession.updateUser(user);
    return user;
  }

  Future<({AppUser user, List<LinkedStudent> linkedStudents})> fetchMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: await _authHeaders(),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '사용자 정보를 불러오지 못했습니다.');
    }

    final user = AppUser.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
    final linkedStudents = ((body['linkedStudents'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => LinkedStudent.fromJson(item.cast<String, dynamic>()))
        .toList();
    await authSession.setSession(
      token: authSession.token ?? '',
      user: user,
      linkedStudents: linkedStudents,
    );
    return (user: user, linkedStudents: linkedStudents);
  }

  Future<LinkedStudent> linkStudent(String studentCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/students/link'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'studentCode': studentCode.trim()}),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '학생 연결에 실패했습니다.');
    }

    final student = LinkedStudent.fromJson(
      (body['student'] as Map).cast<String, dynamic>(),
    );
    final students = [...authSession.linkedStudents];
    if (!students.any((item) => item.id == student.id)) {
      students.insert(0, student);
    }
    await authSession.setLinkedStudents(students);
    if (authSession.viewAsStudentId == null) {
      await authSession.setViewAsStudentId(student.id);
    }
    return student;
  }

  Future<List<LinkedStudent>> fetchLinkedStudents() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/students/linked'),
      headers: await _authHeaders(),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(
        body['error'] as String? ?? '연결된 학생 목록을 불러오지 못했습니다.',
      );
    }

    final students = ((body['students'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => LinkedStudent.fromJson(item.cast<String, dynamic>()))
        .toList();
    await authSession.setLinkedStudents(students);
    return students;
  }

  Future<List<SubmissionSummary>> getSubmissionSummaries() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/submissions'),
      headers: await _authHeaders(),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '활동 목록을 불러오지 못했습니다.');
    }

    return ((body['submissions'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => SubmissionSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  void _handleAuthStatus(int statusCode) {
    if (statusCode == 401) {
      authSession.clear();
      onUnauthorized?.call();
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {
      throw ApiException('서버 응답을 읽을 수 없습니다.');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'X-Device-Id': await _deviceId,
    };
    final token = authSession.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final viewAs = authSession.viewAsStudentId;
    if (viewAs != null && viewAs.isNotEmpty) {
      headers['X-View-As-Student'] = viewAs;
    }
    return headers;
  }

  Future<Map<String, String>> _deviceHeaders() async => _authHeaders();

  Future<Map<String, String>> _jsonHeaders() async {
    return {
      'Content-Type': 'application/json',
      ...(await _authHeaders()),
    };
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
