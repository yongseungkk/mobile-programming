import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cooking_context.dart';
import '../models/recipe.dart';

enum RecommendationFailureKind {
  network,
  timeout,
  auth,
  quota,
  rateLimit,
  server,
  invalidResponse,
  configuration,
}

class RecommendationFailure implements Exception {
  const RecommendationFailure(this.kind, this.message, {this.retryable = true});
  final RecommendationFailureKind kind;
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

abstract class RecommendationService {
  bool get isDemo;
  Future<List<Recipe>> recommend(RecommendationRequest request);
  void dispose() {}
}

/// Calls your team backend. An OpenRouter API key never belongs in this app.
class HttpRecommendationService implements RecommendationService {
  HttpRecommendationService({
    required this.endpoint,
    http.Client? client,
    this.timeout = const Duration(seconds: 65),
    this.getAccessToken,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;
  final Uri endpoint;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final Future<String?> Function()? getAccessToken;
  @override
  bool get isDemo => false;
  @override
  Future<List<Recipe>> recommend(RecommendationRequest request) async {
    try {
      return await _send(request).timeout(timeout);
    } on TimeoutException {
      throw const RecommendationFailure(
        RecommendationFailureKind.timeout,
        '추천이 예상보다 오래 걸리고 있어요. 잠시 후 다시 시도해 주세요.',
      );
    } on http.ClientException {
      throw const RecommendationFailure(
        RecommendationFailureKind.network,
        '서버에 연결할 수 없어요. 네트워크와 서버 실행 상태를 확인해 주세요.',
      );
    } on FormatException {
      throw const RecommendationFailure(
        RecommendationFailureKind.invalidResponse,
        '추천 내용을 확인하지 못했어요. 다시 추천받아 주세요.',
      );
    } on TypeError {
      throw const RecommendationFailure(
        RecommendationFailureKind.invalidResponse,
        '추천 응답 형식이 올바르지 않아요. 다시 추천받아 주세요.',
      );
    }
  }

  Future<List<Recipe>> _send(RecommendationRequest request) async {
    final token = await getAccessToken?.call();
    final response = await _client.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(request.toJson()),
    );
    String? errorCode;
    if (response.statusCode != 200 && response.bodyBytes.length < 4096) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['error'] is String) {
          errorCode = body['error'] as String;
        }
      } catch (_) {
        /* Display only our own safe error messages below. */
      }
    }
    if (errorCode == 'invalid_ai_response' ||
        errorCode == 'incomplete_ai_response' ||
        errorCode == 'ai_response_too_large') {
      throw const RecommendationFailure(
        RecommendationFailureKind.invalidResponse,
        'AI가 올바른 추천 내용을 보내지 못했어요. 다시 시도해 주세요.',
      );
    }
    if (errorCode == 'server_not_configured') {
      throw const RecommendationFailure(
        RecommendationFailureKind.configuration,
        '서버의 API 키와 모델 설정이 필요해요.',
        retryable: false,
      );
    }
    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const RecommendationFailure(
          RecommendationFailureKind.auth,
          '접근 권한을 확인해 주세요. 로그인 또는 서버 인증 설정이 필요해요.',
          retryable: false,
        );
      case 402:
        throw const RecommendationFailure(
          RecommendationFailureKind.quota,
          'AI 이용 한도가 부족해요. 서버의 API 잔액을 확인해 주세요.',
          retryable: false,
        );
      case 429:
        throw const RecommendationFailure(
          RecommendationFailureKind.rateLimit,
          '요청이 잠시 몰렸어요. 조금 기다린 뒤 다시 시도해 주세요.',
        );
      case 400:
      case 404:
      case 422:
        throw const RecommendationFailure(
          RecommendationFailureKind.configuration,
          '요청 조건 또는 API 설정을 확인해 주세요.',
          retryable: false,
        );
      case 504:
        throw const RecommendationFailure(
          RecommendationFailureKind.timeout,
          'AI 서버의 응답 시간이 초과됐어요. 잠시 후 다시 시도해 주세요.',
        );
      default:
        throw const RecommendationFailure(
          RecommendationFailureKind.server,
          '추천 서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.',
        );
    }
    if (response.bodyBytes.length > 512 * 1024) {
      throw const FormatException('Response too large');
    }
    return parseRecipes(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      request,
    );
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
