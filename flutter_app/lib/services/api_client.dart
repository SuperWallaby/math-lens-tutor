import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/app_models.dart';
import '../app_variant.dart';
import 'api_base_url.dart';
import 'app_prefs.dart';
import 'auth_session.dart';
import 'api_cache.dart';
import 'image_prepare_for_upload.dart';
import 'oauth_service.dart';

/// iOS/Android: 긴 NDJSON 스트림 대신 짧은 HTTP 3회(vision→tutor→similar).
bool get _usePhasedAnalyze => !kIsWeb;

enum LearningProfileScope { summary, full }

class ApiClient {
  ApiClient({
    String? baseUrl,
    required this.authSession,
  }) : baseUrl = (baseUrl ?? resolveApiBaseUrl()).replaceAll(RegExp(r'/$'), ''),
       _deviceId = _loadOrCreateDeviceId() {
    if (kDebugMode) {
      debugPrint('[ApiClient] baseUrl=${this.baseUrl}');
    }
  }

  static String get _deviceIdKey => deviceIdPrefsKey;

  final String baseUrl;
  final AuthSession authSession;
  final Future<String> _deviceId;
  VoidCallback? onUnauthorized;

  final _profileSummaryCache = TimedCache<LearningProfile>();
  final _profileFullCache = TimedCache<LearningProfile>();
  final _submissionsCache = TimedCache<List<SubmissionSummary>>();
  final _trainingFeedCache = TimedCache<TrainingFeedResponse>();

  TimedCache<LearningProfile> _profileCacheFor(LearningProfileScope scope) =>
      scope == LearningProfileScope.summary
          ? _profileSummaryCache
          : _profileFullCache;

  /// 홈 탭 — 프로필·제출 목록 캐시가 모두 유효할 때 탭 전환 재조회 생략.
  bool get isStudentTabDataFresh =>
      _profileSummaryCache.isFresh && _submissionsCache.isFresh;

  /// 훈련 탭 — 프로필·피드 캐시가 모두 유효할 때 탭 전환 재조회 생략.
  bool get isTrainingTabDataFresh =>
      _profileSummaryCache.isFresh && _trainingFeedCache.isFresh;

  /// 진도 탭 — 전체(full) 프로필 캐시가 유효할 때 탭 전환 재조회 생략.
  bool get isProgressTabDataFresh => _profileFullCache.isFresh;

  void invalidateLearningProfileCache() {
    _profileSummaryCache.invalidate();
    _profileFullCache.invalidate();
    _submissionsCache.invalidate();
    _trainingFeedCache.invalidate();
  }

  /// 학습 프로필 — 동시 요청 dedupe + TTL 캐시로 탭 전환 지연을 줄입니다.
  Future<LearningProfile> getLearningProfile({
    bool forceRefresh = false,
    LearningProfileScope scope = LearningProfileScope.full,
  }) async {
    final cache = _profileCacheFor(scope);
    if (forceRefresh) {
      cache.invalidate();
    } else if (cache.isFresh) {
      return cache.value!;
    } else if (cache.inflight != null) {
      return cache.inflight!;
    }

    final future = _fetchLearningProfile(scope: scope);
    cache.inflight = future;
    try {
      final profile = await future;
      cache.store(profile);
      return profile;
    } finally {
      cache.inflight = null;
    }
  }

  static String? resolveImageUrl(String baseUrl, String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final normalizedBase = baseUrl.replaceAll(RegExp(r'/$'), '');
    return trimmed.startsWith('/') ? '$normalizedBase$trimmed' : '$normalizedBase/$trimmed';
  }

  /// 목록 썸네일 — `imageThumbUrl` 우선, 없으면 원본 URL
  static String? resolveListThumbnailUrl(
    String baseUrl, {
    String? imageThumbUrl,
    String? imageUrl,
  }) {
    final thumb = imageThumbUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return resolveImageUrl(baseUrl, thumb);
    }
    return resolveImageUrl(baseUrl, imageUrl);
  }

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
    final prepared = await prepareImageBytesForAnalyzeUploadAsync(bytes, filename);

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

      emitProgress('similar', '비슷한 문제 5개를 고르는 중…');
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
        'message': '유사 문제 준비 완료',
      });

      // finalize(저장)는 백그라운드로 보내고, 유사 문제는 바로 쓸 수 있게 반환한다.
      emitProgress('save', '결과 저장 중…');
      final provisional = AnalyzeResult(
        submission: SolutionSubmission(
          id: visionJson['submissionId'] as String? ?? '',
          userId: '',
          imageUrl: visionJson['imageUrl'] as String?,
          imageName: visionJson['imageName'] as String? ?? filename,
          createdAt: DateTime.now().toIso8601String(),
          analysis: SolutionAnalysis.fromJson(
            (tutorJson['analysis'] as Map?)?.cast<String, dynamic>() ?? {},
          ),
        ),
        problemSet: GeneratedProblemSet.fromJson(
          (similarJson['problemSet'] as Map?)?.cast<String, dynamic>() ?? {},
        ),
      );

      unawaited(() async {
        try {
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
          if (finalizeResponse.statusCode >= 400 && kDebugMode) {
            debugPrint(
              '[analyze] finalize failed: ${finalizeResponse.statusCode}',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[analyze] finalize background error: $e');
          }
        }
      }());

      return provisional;
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
    final prepared = await prepareImageBytesForAnalyzeUploadAsync(bytes, filename);
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
    if (s.contains('connection refused') && !kReleaseMode) {
      return '로컬 API 서버에 연결할 수 없습니다.\n터미널에서 npm run dev 를 실행해 주세요.';
    }
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

  Future<StartPracticeResult> startUnitPractice(String unitId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/practice/unit'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'unitId': unitId}),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '단원 연습을 시작하지 못했습니다.');
    }

    return StartPracticeResult.fromJson(body.cast<String, dynamic>());
  }

  Future<StartPracticeResult> startTrainingPractice({String? resumeSetId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/practice/training'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        if (resumeSetId != null) 'setId': resumeSetId,
      }),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '복습 훈련을 시작하지 못했습니다.');
    }

    return StartPracticeResult.fromJson(body.cast<String, dynamic>());
  }

  Future<TrainingFeedResponse> getTrainingFeed({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _trainingFeedCache.invalidate();
    } else if (_trainingFeedCache.isFresh) {
      return _trainingFeedCache.value!;
    } else if (_trainingFeedCache.inflight != null) {
      return _trainingFeedCache.inflight!;
    }

    final future = _fetchTrainingFeed();
    _trainingFeedCache.inflight = future;
    try {
      final feed = await future;
      _trainingFeedCache.store(feed);
      return feed;
    } finally {
      _trainingFeedCache.inflight = null;
    }
  }

  Future<TrainingFeedResponse> _fetchTrainingFeed() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/practice/feed'),
      headers: await _deviceHeaders(),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '훈련 피드를 불러오지 못했습니다.');
    }

    return TrainingFeedResponse.fromJson(body.cast<String, dynamic>());
  }

  Future<StartPracticeResult> startFeedPractice({
    required String feedItemId,
    String? bankItemId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/practice/feed/start'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'feedItemId': feedItemId,
        if (bankItemId != null) 'bankItemId': bankItemId,
      }),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '피드 문제를 시작하지 못했습니다.');
    }

    return StartPracticeResult.fromJson(body.cast<String, dynamic>());
  }

  /// 재도전 — 은행에서 아직 안 본 문제 우선, 부족하면 AI 생성
  Future<GeneratedProblemSet> retryPractice({
    required String submissionId,
    String? previousSetId,
    bool harder = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/practice/retry'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'submissionId': submissionId,
        if (previousSetId != null) 'previousSetId': previousSetId,
        if (harder) 'difficultyBias': 'harder',
      }),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '새 연습 문제를 불러오지 못했습니다.');
    }

    return GeneratedProblemSet.fromJson(
      (body['problemSet'] as Map).cast<String, dynamic>(),
    );
  }

  /// 현재 문항만 같은 유형·난이도대로 교체
  Future<GeneratedProblemSet> refreshPracticeProblem({
    required String setId,
    required String problemId,
    bool harder = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/practice/refresh-problem'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'setId': setId,
        'problemId': problemId,
        'harder': harder,
      }),
    );
    final body = _decode(response);

    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '문제를 교체하지 못했습니다.');
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

    // 답안 제출로 진도·통계가 바뀌므로 프로필 캐시를 무효화해
    // 진도 현황이 다음 조회 때 최신값을 반영하도록 한다.
    invalidateLearningProfileCache();

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

  Future<AppUser> signInWithOAuth(
    OAuthCredentialBundle credential, {
    bool signupOnly = false,
  }) async {
    final payload = <String, dynamic>{
      'provider': credential.provider,
      'intent': signupOnly ? 'signup' : 'login',
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

    // #region agent log
    await _agentLog(
      'H1',
      'api_client.dart:signInWithOAuth',
      'request',
      {
        'baseUrl': baseUrl,
        'provider': credential.provider,
        'hasIdToken': credential.idToken != null,
        'hasAccessToken': credential.accessToken != null,
      },
    );
    // #endregion

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/oauth'),
        headers: await _jsonHeaders(),
        body: jsonEncode(payload),
      );
      // #region agent log
      await _agentLog(
        'H4',
        'api_client.dart:signInWithOAuth',
        'response',
        {
          'status': response.statusCode,
          'bodyLen': response.body.length,
        },
      );
      // #endregion
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
    } catch (e) {
      // #region agent log
      await _agentLog(
        'H3',
        'api_client.dart:signInWithOAuth',
        'error',
        {
          'errorType': e.runtimeType.toString(),
          'error': e.toString().length > 280
              ? e.toString().substring(0, 280)
              : e.toString(),
        },
      );
      // #endregion
      rethrow;
    }
  }

  Future<MagicLinkSendResponse> sendMagicLink(
    String email, {
    bool signupOnly = false,
  }) async {
    // #region agent log
    await _agentLog(
      'H1',
      'api_client.dart:sendMagicLink',
      'request',
      {
        'baseUrl': baseUrl,
        'signupOnly': signupOnly,
      },
    );
    // #endregion

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/magic-link/send'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'email': email.trim(),
          'intent': signupOnly ? 'signup' : 'login',
        }),
      );
      // #region agent log
      await _agentLog(
        'H4',
        'api_client.dart:sendMagicLink',
        'response',
        {
          'status': response.statusCode,
          'bodyLen': response.body.length,
        },
      );
      // #endregion
      final body = _decode(response);
      if (response.statusCode >= 400) {
        throw ApiException(body['error'] as String? ?? '매직 링크 발송에 실패했습니다.');
      }

      AppUser? bypassUser;
      if (body['bypass'] == true &&
          body['token'] is String &&
          body['user'] is Map) {
        final token = body['token'] as String;
        bypassUser = AppUser.fromJson(
          (body['user'] as Map).cast<String, dynamic>(),
        );
        await authSession.setSession(token: token, user: bypassUser);
      }

      return MagicLinkSendResponse(
        message: body['message'] as String? ?? '메일함을 확인해 주세요.',
        devLink: body['devLink'] as String?,
        bypassUser: bypassUser,
      );
    } catch (e) {
      // #region agent log
      await _agentLog(
        'H3',
        'api_client.dart:sendMagicLink',
        'error',
        {
          'errorType': e.runtimeType.toString(),
          'error': e.toString().length > 280
              ? e.toString().substring(0, 280)
              : e.toString(),
        },
      );
      // #endregion
      rethrow;
    }
  }

  Future<AppUser> verifyMagicLink(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/magic-link/verify'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'token': token.trim()}),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '로그인에 실패했습니다.');
    }

    final sessionToken = body['token'] as String? ?? '';
    final user = AppUser.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
    await authSession.setSession(token: sessionToken, user: user);
    return user;
  }

  /// 로컬 개발 전용 — 빈 계정으로 JWT 로그인 (프로덕션 API는 404)
  Future<AppUser> devLogin(String accountId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/dev-login'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'accountId': accountId}),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(body['error'] as String? ?? '개발용 로그인에 실패했습니다.');
    }

    final token = body['token'] as String? ?? '';
    final user = AppUser.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
    await authSession.setSession(
      token: token,
      user: user,
      linkedStudents: const [],
    );
    return user;
  }

  /// 로컬 개발 전용 — 카카오/Apple OAuth 계정 즉시 로그인 (프로덕션 API는 404)
  Future<AppUser> devOAuthLogin(String accountId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/dev-oauth-login'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'accountId': accountId}),
      );
      final body = _decode(response);
      if (response.statusCode >= 400) {
        final error = body['error'] as String? ?? '개발용 OAuth 로그인에 실패했습니다.';
        if (response.statusCode == 404 && error == 'Not found') {
          throw ApiException(
            '개발용 OAuth는 로컬 API에서만 동작합니다.\n'
            'npm run dev:next 실행 후 yarn app 으로 앱을 띄워 주세요.\n'
            '(현재 API: $baseUrl)',
          );
        }
        throw ApiException(error);
      }

      final token = body['token'] as String? ?? '';
      final userJson = body['user'];
      if (userJson is! Map) {
        throw ApiException('서버 응답에 사용자 정보가 없습니다.');
      }
      final user = AppUser.fromJson(userJson.cast<String, dynamic>());
      final linkedStudents = ((body['linkedStudents'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => LinkedStudent.fromJson(item.cast<String, dynamic>()))
          .toList();

      await authSession.setSession(
        token: token,
        user: user,
        linkedStudents: linkedStudents,
      );
      return user;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_friendlyNetworkMessage(error));
    }
  }

  /// 로컬 개발 전용 — OAuth 테스트 계정 탈퇴·데이터 삭제 (프로덕션 API는 404)
  Future<String> devOAuthPurge(String accountId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/dev-oauth-purge'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'accountId': accountId}),
      );
      final body = _decode(response);
      if (response.statusCode >= 400) {
        final error = body['error'] as String? ?? '계정 삭제에 실패했습니다.';
        if (response.statusCode == 404 && body['alreadyDeleted'] == true) {
          return error;
        }
        if (response.statusCode == 404 && error == 'Not found') {
          throw ApiException(
            '개발용 OAuth 삭제는 로컬 API에서만 동작합니다.\n'
            'npm run dev:next 실행 후 yarn app 으로 앱을 띄워 주세요.\n'
            '(현재 API: $baseUrl)',
          );
        }
        throw ApiException(error);
      }

      final label = body['label'] as String? ?? accountId;
      if (body['alreadyDeleted'] == true) {
        return '$label — 이미 삭제됨';
      }
      return '$label — 탈퇴·데이터 삭제 완료';
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_friendlyNetworkMessage(error));
    }
  }

  Future<LearningProfile> _fetchLearningProfile({
    LearningProfileScope scope = LearningProfileScope.full,
  }) async {
    try {
      final query = scope == LearningProfileScope.summary ? '?scope=summary' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/learning/profile$query'),
        headers: await _authHeaders(),
      );
      final body = _decode(response);
      if (response.statusCode >= 400) {
        _handleAuthStatus(response.statusCode);
        throw ApiException(body['error'] as String? ?? '학습 프로필을 불러오지 못했습니다.');
      }

      final profileJson = (body['profile'] as Map).cast<String, dynamic>();
      return scope == LearningProfileScope.summary
          ? LearningProfile.fromSummaryJson(profileJson)
          : LearningProfile.fromJson(profileJson);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(_friendlyNetworkMessage(e));
    }
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
    int? age,
    String? grade,
    String? organizationName,
  }) async {
    final payload = <String, dynamic>{'role': role.apiValue};
    if (age != null && age >= 8 && age <= 99) {
      payload['age'] = age;
    }
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

  Future<AppUser> resetProfileRole() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/reset-profile'),
      headers: await _jsonHeaders(),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '역할 초기화에 실패했습니다.');
    }

    final user = AppUser.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
    await authSession.updateUser(user, linkedStudents: const []);
    return user;
  }

  /// 역할·연결 초기화 후 로그아웃 — 시작(가입) 화면으로.
  Future<void> signOutToAppStart() async {
    if (authSession.isSignedIn) {
      try {
        await resetProfileRole();
      } catch (_) {
        // 서버 초기화 실패해도 로컬 세션은 정리
      }
    }
    await authSession.clear();
  }

  Future<AppUser> updateProfile({
    required String displayName,
    String? grade,
    String? organizationName,
  }) async {
    final payload = <String, dynamic>{'displayName': displayName.trim()};
    if (grade != null && grade.trim().isNotEmpty) {
      payload['grade'] = grade.trim();
    }
    if (organizationName != null) {
      payload['organizationName'] = organizationName.trim();
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/api/auth/profile'),
      headers: await _jsonHeaders(),
      body: jsonEncode(payload),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '프로필 수정에 실패했습니다.');
    }

    final user = AppUser.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
    await authSession.updateUser(user);
    return user;
  }

  Future<AppUser> uploadProfileAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    final prepared = await prepareImageBytesForProfileUploadAsync(bytes, filename);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/auth/profile/avatar'),
    );
    request.headers.addAll(await _authHeaders());
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        prepared.bytes,
        filename: prepared.filename,
        contentType: _guessImageMediaType(prepared.filename),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(
        body['error'] as String? ?? '프로필 이미지 업로드에 실패했습니다.',
      );
    }

    final user = AppUser.fromJson(
      (body['user'] as Map).cast<String, dynamic>(),
    );
    await authSession.updateUser(user);
    return user;
  }

  Future<void> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/auth/account'),
      headers: await _authHeaders(),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '계정 탈퇴에 실패했습니다.');
    }
    await authSession.clear();
  }

  Future<({AppUser user, List<LinkedStudent> linkedStudents})> fetchMe() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/auth/me'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 8));
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

  Future<void> _upsertLinkedStudent(LinkedStudent student) async {
    final students = [...authSession.linkedStudents];
    final index = students.indexWhere((item) => item.id == student.id);
    if (index >= 0) {
      students[index] = student;
    } else {
      students.insert(0, student);
    }
    await authSession.setLinkedStudents(students);
  }

  Future<LinkedStudent> updateLinkedStudentLabel({
    required String studentId,
    String? guardianLabel,
  }) async {
    final trimmed = guardianLabel?.trim();
    final response = await http.patch(
      Uri.parse('$baseUrl/api/students/linked/$studentId'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'guardianLabel': trimmed == null || trimmed.isEmpty ? null : trimmed,
      }),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '표시 이름을 저장하지 못했습니다.');
    }

    final student = LinkedStudent.fromJson(
      (body['student'] as Map).cast<String, dynamic>(),
    );
    await _upsertLinkedStudent(student);
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

  Future<List<SubmissionSummary>> getSubmissionSummaries({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _submissionsCache.invalidate();
    } else if (_submissionsCache.isFresh) {
      return _submissionsCache.value!;
    } else if (_submissionsCache.inflight != null) {
      return _submissionsCache.inflight!;
    }

    final future = _fetchSubmissionSummaries();
    _submissionsCache.inflight = future;
    try {
      final list = await future;
      _submissionsCache.store(list);
      return list;
    } finally {
      _submissionsCache.inflight = null;
    }
  }

  Future<List<SubmissionSummary>> _fetchSubmissionSummaries() async {
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

  Future<AnalyzeResult> getSubmissionDetail(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/submissions/$id'),
      headers: await _authHeaders(),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) {
      _handleAuthStatus(response.statusCode);
      throw ApiException(body['error'] as String? ?? '분석 기록을 불러오지 못했습니다.');
    }

    final submission = SolutionSubmission.fromJson(
      (body['submission'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final problemSetJson = body['problemSet'];
    final problemSet = problemSetJson == null
        ? GeneratedProblemSet(
            id: '',
            submissionId: submission.id,
            title: '',
            learningGoal: '',
            problems: const [],
          )
        : GeneratedProblemSet.fromJson(
            (problemSetJson as Map).cast<String, dynamic>(),
          );

    return AnalyzeResult(submission: submission, problemSet: problemSet);
  }

  void _handleAuthStatus(int statusCode) {
    if (statusCode == 401 && authSession.isSignedIn) {
      authSession.clear();
      onUnauthorized?.call();
    }
  }

  Future<String> get deviceId => _deviceId;

  Future<String> get deviceScopedUserId async => 'device:${await _deviceId}';

  /// 디버그: 앱 시작 시 서버 연결 가능 여부 로그 (실기기 dev 전용).
  Future<void> debugPingLocalApi() async {
    await _agentLog(
      'H2',
      'api_client.dart:debugPingLocalApi',
      'startup',
      {'baseUrl': baseUrl},
    );
  }

  Future<void> _agentLog(
    String hypothesisId,
    String location,
    String message,
    Map<String, dynamic> data,
  ) async {
    if (kReleaseMode) return;
    // #region agent log
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/dev/client-log'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'hypothesisId': hypothesisId,
              'location': location,
              'message': message,
              'data': data,
              'runId': 'run1',
            }),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    // #endregion
  }

  Map<String, dynamic> _decode(http.Response response) {
    final raw = response.body.trim();
    if (raw.isEmpty) {
      throw ApiException(
        '서버 응답이 비어 있습니다. (HTTP ${response.statusCode}) '
        '앱이 가리키는 API 주소·배포 상태를 확인해 주세요.',
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      throw ApiException('서버 응답 형식이 올바르지 않습니다.');
    } catch (e) {
      if (e is ApiException) rethrow;
      final looksHtml =
          raw.startsWith('<!DOCTYPE') || raw.toLowerCase().startsWith('<html');
      if (looksHtml || response.statusCode == 404) {
        throw ApiException(
          '로그인 API를 찾을 수 없습니다. (HTTP ${response.statusCode}) '
          '서버에 최신 앱이 배포됐는지 확인해 주세요.',
        );
      }
      throw ApiException(
        '서버 응답을 읽을 수 없습니다. (HTTP ${response.statusCode})',
      );
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'X-Device-Id': await _deviceId,
      'X-App-Variant': appVariantHeader,
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
    final prefs = await getAppPrefs();
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

class MagicLinkSendResponse {
  const MagicLinkSendResponse({
    required this.message,
    this.devLink,
    this.bypassUser,
  });

  final String message;
  final String? devLink;
  /// devstudy*@wooyeol.com 등 bypass — 세션까지 이미 설정됨
  final AppUser? bypassUser;
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
