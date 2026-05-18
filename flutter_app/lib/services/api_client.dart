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
import 'image_prepare_for_upload.dart';

/// iOS/Android: 긴 NDJSON 스트림 대신 짧은 HTTP 3회(vision→tutor→similar).
bool get _usePhasedAnalyze => !kIsWeb;

class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl = (baseUrl ?? resolveApiBaseUrl()).replaceAll(RegExp(r'/$'), ''),
      _deviceId = _loadOrCreateDeviceId() {
    if (kDebugMode) {
      debugPrint('[ApiClient] baseUrl=$baseUrl (debug→local unless API_BASE_URL set)');
    }
  }

  static const _deviceIdKey = 'anonymous_device_id';

  final String baseUrl;
  final Future<String> _deviceId;

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
    final deviceId = await _deviceId;

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
      visionRequest.headers['X-Device-Id'] = deviceId;
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
      var similarFinished = false;
      final similarBody = {
        'submissionId': visionJson['submissionId'],
        'problemSetId': visionJson['problemSetId'],
        'imageUrl': visionJson['imageUrl'],
        'imageName': visionJson['imageName'],
        'analysis': visionJson['analysis'],
        'fromVisionOcrOnly': true,
        'qualityMode': quality,
        'textDeploymentName': visionJson['textDeploymentName'],
        'visionDeploymentName': visionJson['visionDeploymentName'],
      };

      final tutorFuture = http
          .post(
            Uri.parse('$baseUrl/api/analyze/tutor'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Id': deviceId,
            },
            body: jsonEncode({
              'vision': visionJson['vision'],
              'qualityMode': quality,
              'textDeploymentName': visionJson['textDeploymentName'],
            }),
          )
          .timeout(const Duration(minutes: 3));

      final similarFuture = http
          .post(
            Uri.parse('$baseUrl/api/analyze/similar'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Id': deviceId,
            },
            body: jsonEncode(similarBody),
          )
          .timeout(const Duration(minutes: 3));

      tutorFuture.then((response) {
        if (response.statusCode < 400) {
          final json = _decodeMap(response);
          emitPartial({
            'type': 'partial',
            'step': 'tutor',
            'analysis': json['analysis'],
            'message': '풀이 중…',
          });
        }
      });

      similarFuture.then((response) {
        if (response.statusCode < 400) {
          similarFinished = true;
          final json = _decodeMap(response);
          emitPartial({
            'type': 'partial',
            'step': 'similar',
            'problemSet': json['problemSet'],
            'message': '유사 문제 만드는 중…',
          });
        }
      });

      final tutorResponse = await tutorFuture;
      final similarResponse = await similarFuture;

      final tutorJson = _decodeMap(tutorResponse);
      if (tutorResponse.statusCode >= 400) {
        throw ApiException(
          tutorJson['error'] as String? ?? '정답·오답 진단에 실패했습니다.',
        );
      }

      final similarJson = _decodeMap(similarResponse);
      if (similarResponse.statusCode >= 400) {
        throw ApiException(
          similarJson['error'] as String? ?? '유사 문제 생성에 실패했습니다.',
        );
      }

      emitPartial({
        'type': 'partial',
        'step': 'tutor',
        'analysis': tutorJson['analysis'],
        'message': '풀이 중…',
      });

      if (!similarFinished) {
        emitProgress('similar', '유사 문제 만드는 중…');
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
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Id': deviceId,
            },
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
    request.headers['X-Device-Id'] = await _deviceId;
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
