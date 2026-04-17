import 'package:dio/dio.dart';

/// API client for communicating with the AnyNote backend.
///
/// All endpoints return JSON. SSE streaming is handled separately.
class ApiClient {
  final Dio _dio;
  String? _accessToken;

  ApiClient({required String baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120), // Long for SSE
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
          },
        )) {
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  // ── Auth ──────────────────────────────────────────

  void setAccessToken(String token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  void clearAccessToken() {
    _accessToken = null;
  }

  // ── Auth API ──────────────────────────────────────

  Future<AuthResponse> register(RegisterRequest req) async {
    final res = await _dio.post('/api/v1/auth/register', data: req.toJson());
    return AuthResponse.fromJson(res.data);
  }

  Future<AuthResponse> login(LoginRequest req) async {
    final res = await _dio.post('/api/v1/auth/login', data: req.toJson());
    final authRes = AuthResponse.fromJson(res.data);
    setAccessToken(authRes.accessToken);
    return authRes;
  }

  Future<AuthResponse> refreshToken(String refreshToken) async {
    final res = await _dio.post('/api/v1/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    final authRes = AuthResponse.fromJson(res.data);
    setAccessToken(authRes.accessToken);
    return authRes;
  }

  // ── Sync API ──────────────────────────────────────

  Future<SyncPullResponseDto> syncPull(int sinceVersion) async {
    final res = await _dio.get(
      '/api/v1/sync/pull',
      queryParameters: {'since': sinceVersion},
    );
    return SyncPullResponseDto.fromJson(res.data);
  }

  Future<dynamic> syncPush(dynamic req) async {
    final res = await _dio.post('/api/v1/sync/push', data: req);
    return res.data;
  }

  Future<Map<String, dynamic>> syncStatus() async {
    final res = await _dio.get('/api/v1/sync/status');
    return res.data as Map<String, dynamic>;
  }

  // ── AI Proxy API ──────────────────────────────────

  /// Stream AI proxy response. Returns a Dio Response for SSE parsing.
  Future<Response<ResponseBody>> aiProxyStream(Map<String, dynamic> body) async {
    return _dio.post(
      '/api/v1/ai/proxy',
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );
  }

  /// Non-streaming AI proxy call.
  Future<Map<String, dynamic>> aiProxy(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/v1/ai/proxy', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAiQuota() async {
    final res = await _dio.get('/api/v1/ai/quota');
    return res.data as Map<String, dynamic>;
  }

  // ── LLM Config API ────────────────────────────────

  Future<List<Map<String, dynamic>>> listLlmConfigs() async {
    final res = await _dio.get('/api/v1/llm/configs');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createLlmConfig(Map<String, dynamic> config) async {
    final res = await _dio.post('/api/v1/llm/configs', data: config);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLlmConfig(
    String id,
    Map<String, dynamic> config,
  ) async {
    final res = await _dio.put('/api/v1/llm/configs/$id', data: config);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteLlmConfig(String id) async {
    await _dio.delete('/api/v1/llm/configs/$id');
  }

  Future<Map<String, dynamic>> testLlmConfig(String id) async {
    final res = await _dio.post('/api/v1/llm/configs/$id/test');
    return res.data as Map<String, dynamic>;
  }

  Future<List<String>> listLlmProviders() async {
    final res = await _dio.get('/api/v1/llm/providers');
    return (res.data as List).cast<String>();
  }

  // ── Publish API ───────────────────────────────────

  Future<Map<String, dynamic>> publish(Map<String, dynamic> req) async {
    final res = await _dio.post('/api/v1/publish', data: req);
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> publishHistory() async {
    final res = await _dio.get('/api/v1/publish/history');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getPublish(String id) async {
    final res = await _dio.get('/api/v1/publish/$id');
    return res.data as Map<String, dynamic>;
  }

  // ── Platform API ──────────────────────────────────

  Future<List<Map<String, dynamic>>> listPlatforms() async {
    final res = await _dio.get('/api/v1/platforms');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> connectPlatform(String platform) async {
    final res = await _dio.post('/api/v1/platforms/$platform/connect');
    return res.data as Map<String, dynamic>;
  }

  Future<void> disconnectPlatform(String platform) async {
    await _dio.delete('/api/v1/platforms/$platform/connect');
  }

  Future<Map<String, dynamic>> verifyPlatform(String platform) async {
    final res = await _dio.post('/api/v1/platforms/$platform/verify');
    return res.data as Map<String, dynamic>;
  }
}

// ── Auth Interceptor ─────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final ApiClient _client;

  _AuthInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_client._accessToken != null) {
      options.headers['Authorization'] = 'Bearer ${_client._accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 && _client._accessToken != null) {
      // Token expired - could trigger refresh here
      _client.clearAccessToken();
    }
    handler.next(err);
  }
}

// ── DTOs ─────────────────────────────────────────────

class RegisterRequest {
  final String email;
  final String username;
  final String authKeyHash;
  final String salt;
  final String recoveryKey;

  RegisterRequest({
    required this.email,
    required this.username,
    required this.authKeyHash,
    required this.salt,
    required this.recoveryKey,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'username': username,
        'auth_key_hash': authKeyHash,
        'salt': salt,
        'recovery_key': recoveryKey,
      };
}

class LoginRequest {
  final String email;
  final String authKeyHash;

  LoginRequest({required this.email, required this.authKeyHash});

  Map<String, dynamic> toJson() => {
        'email': email,
        'auth_key_hash': authKeyHash,
      };
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final Map<String, dynamic> user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'],
        refreshToken: json['refresh_token'],
        expiresAt: DateTime.parse(json['expires_at']),
        user: json['user'] as Map<String, dynamic>,
      );
}

class SyncPullResponseDto {
  final List<dynamic> blobs;
  final int latestVersion;

  SyncPullResponseDto({required this.blobs, required this.latestVersion});

  factory SyncPullResponseDto.fromJson(Map<String, dynamic> json) =>
      SyncPullResponseDto(
        blobs: json['blobs'] as List,
        latestVersion: json['latest_version'] as int,
      );
}
