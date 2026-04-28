import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';

/// API client for communicating with the AnyNote backend.
///
/// All endpoints return JSON. SSE streaming is handled separately.
///
/// ## TLS Certificate Pinning
///
/// This client intentionally does NOT implement TLS certificate pinning.
/// AnyNote is designed as a self-hosted application where users deploy their
/// own backend server and manage their own TLS certificates. Pinning a
/// specific certificate would break connectivity whenever users renew or
/// change their server certificates. Since all synced content is end-to-end
/// encrypted (XChaCha20-Poly1305) client-side before transit, a TLS
/// interception attack only reveals encrypted blobs -- the server never has
/// access to plaintext user data.
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  String? _accessToken;

  /// Completer used as a mutex to prevent concurrent token refresh attempts.
  Completer<String?>? _refreshCompleter;

  ApiClient({required String baseUrl})
      : _secureStorage = const FlutterSecureStorage(),
        _dio = Dio(
          BaseOptions(
            baseUrl: _normalizeBaseUrl(baseUrl),
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 120), // Long for SSE
            sendTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  /// Normalize the base URL: trim trailing slashes and validate format.
  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('API base URL must not be empty');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.hasScheme)) {
      throw ArgumentError('Invalid API base URL: $url');
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  /// The base URL used for API requests.
  String get baseUrl => _dio.options.baseUrl;

  // ── Auth ──────────────────────────────────────────

  void setAccessToken(String token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  void clearAccessToken() {
    _accessToken = null;
  }

  /// Store the refresh token in secure storage.
  Future<void> storeRefreshToken(String token) async {
    await _secureStorage.write(key: 'refresh_token', value: token);
  }

  /// Read the stored refresh token from secure storage.
  Future<String?> getStoredRefreshToken() async {
    return _secureStorage.read(key: 'refresh_token');
  }

  /// Store the access token in secure storage for persistence across restarts.
  Future<void> storeAccessTokenSecure(String token) async {
    await _secureStorage.write(key: 'access_token', value: token);
  }

  /// Load tokens from secure storage into memory. Call during app startup.
  Future<void> loadStoredTokens() async {
    final accessToken = await _secureStorage.read(key: 'access_token');
    if (accessToken != null) {
      _accessToken = accessToken;
    }
  }

  /// Attempt to refresh the access token using the stored refresh token.
  /// Uses a Completer-based mutex to ensure only one refresh runs at a time.
  /// Returns the new access token on success, or null on failure.
  Future<String?> tryRefreshToken() async {
    // If a refresh is already in progress, wait for it and reuse the result.
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      // Use a fresh Dio instance without interceptors to avoid recursive refresh.
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: _dio.options.connectTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
      );

      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String;

      // Store new tokens in secure storage.
      await _secureStorage.write(key: 'access_token', value: newAccessToken);
      await _secureStorage.write(key: 'refresh_token', value: newRefreshToken);

      // Update in-memory token.
      _accessToken = newAccessToken;

      _refreshCompleter!.complete(newAccessToken);
      return newAccessToken;
    } catch (e) {
      // Refresh failed -- clear all tokens.
      debugPrint('[ApiClient] token refresh failed: $e');
      await _clearAllTokens();
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Clear all stored tokens and redirect to login.
  Future<void> _clearAllTokens() async {
    _accessToken = null;
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }

  /// Public logout method: clears in-memory access token and removes both
  /// tokens from secure storage.
  Future<void> logout() async {
    await _clearAllTokens();
  }

  // ── Auth API ──────────────────────────────────────

  Future<AuthResponse> register(RegisterRequest req) async {
    final res = await _dio.post('/api/v1/auth/register', data: req.toJson());
    final authRes = AuthResponse.fromJson(res.data);
    setAccessToken(authRes.accessToken);
    await storeAccessTokenSecure(authRes.accessToken);
    await storeRefreshToken(authRes.refreshToken);
    return authRes;
  }

  Future<AuthResponse> login(LoginRequest req) async {
    final res = await _dio.post('/api/v1/auth/login', data: req.toJson());
    final authRes = AuthResponse.fromJson(res.data);
    setAccessToken(authRes.accessToken);
    await storeAccessTokenSecure(authRes.accessToken);
    await storeRefreshToken(authRes.refreshToken);
    return authRes;
  }

  Future<AuthResponse> refreshToken(String refreshToken) async {
    final res = await _dio.post(
      '/api/v1/auth/refresh',
      data: {
        'refresh_token': refreshToken,
      },
    );
    final authRes = AuthResponse.fromJson(res.data);
    setAccessToken(authRes.accessToken);
    return authRes;
  }

  /// Get the current authenticated user's profile.
  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/api/v1/auth/me');
    return res.data as Map<String, dynamic>;
  }

  /// Fetch the per-user recovery salt from the server.
  /// No authentication required (public endpoint, rate-limited by IP).
  /// Returns null if the user has no recovery salt (legacy accounts).
  Future<Uint8List?> getRecoverySalt(String email) async {
    final res = await _dio.get(
      '/api/v1/auth/recovery-salt',
      queryParameters: {'email': email},
    );
    final data = res.data as Map<String, dynamic>;
    final saltBase64 = data['recovery_salt'] as String?;
    if (saltBase64 == null || saltBase64.isEmpty) return null;
    return base64Decode(saltBase64);
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

  // ── Device Management API ─────────────────────────

  /// Register this sync device with the server (upsert).
  Future<DeviceDto> registerSyncDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final res = await _dio.post(
      '/api/v1/device-identity/register',
      data: {
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': platform,
      },
    );
    return DeviceDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// List all devices registered for the current user.
  Future<List<DeviceDto>> listDevices() async {
    final res = await _dio.get('/api/v1/device-identity');
    return (res.data as List)
        .map((d) => DeviceDto.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// Delete a registered device.
  Future<void> deleteDevice(String deviceId) async {
    await _dio.delete('/api/v1/device-identity/$deviceId');
  }

  /// Recover account using recovery key.
  Future<void> recoverAccount({
    required String email,
    required String recoveryKey,
    required String newPassword,
  }) async {
    await _dio.post('/api/v1/auth/recover', data: {
      'email': email,
      'recovery_key': recoveryKey,
      'new_password': newPassword,
    });
  }

  // ── AI Proxy API ──────────────────────────────────

  /// Stream AI proxy response. Returns a Dio Response for SSE parsing.
  Future<Response<ResponseBody>> aiProxyStream(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    return _dio.post(
      '/api/v1/ai/proxy',
      data: body,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );
  }

  /// Non-streaming AI proxy call.
  Future<Map<String, dynamic>> aiProxy(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    final res = await _dio.post(
      '/api/v1/ai/proxy',
      data: body,
      cancelToken: cancelToken,
    );
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

  Future<Map<String, dynamic>> createLlmConfig(
    Map<String, dynamic> config,
  ) async {
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

  // ── Share API ─────────────────────────────────────

  /// Create a shared note. Returns {id, url}.
  Future<Map<String, dynamic>> createShare(Map<String, dynamic> req) async {
    final res = await _dio.post('/api/v1/share', data: req);
    return res.data as Map<String, dynamic>;
  }

  /// Get a shared note by ID. No authentication required.
  Future<Map<String, dynamic>> getSharedNote(String shareId) async {
    final res = await _dio.get('/api/v1/share/$shareId');
    return res.data as Map<String, dynamic>;
  }

  /// Fetch the public discovery feed. No authentication required.
  Future<List<Map<String, dynamic>>> discoverFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      '/api/v1/share/discover',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Toggle a reaction on a shared note. Requires authentication.
  Future<Map<String, dynamic>> toggleReaction(
    String shareId,
    String reactionType,
  ) async {
    final res = await _dio.post(
      '/api/v1/share/$shareId/react',
      data: {'reaction_type': reactionType},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Device Registration API ────────────────────────

  /// Register a device token for push notifications.
  Future<void> registerDevice(String token, String platform) async {
    await _dio.post(
      '/api/v1/devices/register',
      data: {
        'token': token,
        'platform': platform,
      },
    );
  }

  /// Unregister a device token.
  Future<void> unregisterDevice(String token) async {
    await _dio.post(
      '/api/v1/devices/unregister',
      data: {
        'token': token,
      },
    );
  }

  // ── Plan API ───────────────────────────────────────

  /// Get the current user's plan, limits, and usage.
  Future<Map<String, dynamic>> getPlan() async {
    final res = await _dio.get('/api/v1/plan');
    return res.data as Map<String, dynamic>;
  }

  /// Upgrade the current user's plan.
  Future<Map<String, dynamic>> upgradePlan(
    String plan, {
    String? paymentRef,
  }) async {
    final res = await _dio.post(
      '/api/v1/plan/upgrade',
      data: {
        'plan': plan,
        if (paymentRef != null) 'payment_ref': paymentRef,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Note Links API ─────────────────────────────────

  /// Create note links in batch.
  Future<Map<String, dynamic>> createNoteLinks(
    List<Map<String, dynamic>> links,
  ) async {
    final res = await _dio.post(
      '/api/v1/notes/links',
      data: {'links': links},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Get backlinks for a note.
  Future<Map<String, dynamic>> getNoteBacklinks(String noteId) async {
    final res = await _dio.get('/api/v1/notes/$noteId/backlinks');
    return res.data as Map<String, dynamic>;
  }

  /// Get outbound links for a note.
  Future<Map<String, dynamic>> getNoteOutboundLinks(String noteId) async {
    final res = await _dio.get('/api/v1/notes/$noteId/links');
    return res.data as Map<String, dynamic>;
  }

  /// Get the full note graph for the current user.
  Future<Map<String, dynamic>> getNoteGraph() async {
    final res = await _dio.get('/api/v1/notes/graph');
    return res.data as Map<String, dynamic>;
  }

  /// Delete a note link.
  Future<void> deleteNoteLink(String sourceId, String targetId) async {
    await _dio.delete('/api/v1/notes/links/$sourceId/$targetId');
  }

  // ── AI Agent API ───────────────────────────────────

  /// Execute an AI agent action.
  Future<Map<String, dynamic>> executeAgentAction(
    Map<String, dynamic> req,
  ) async {
    final res = await _dio.post('/api/v1/ai/agent', data: req);
    return res.data as Map<String, dynamic>;
  }

  // ── Profile API ────────────────────────────────────

  /// Get a user's public profile by username.
  Future<Map<String, dynamic>> getPublicProfile(String username) async {
    final res = await _dio.get('/api/v1/profile/$username');
    return res.data as Map<String, dynamic>;
  }

  /// Update the authenticated user's profile.
  Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    required String bio,
    required bool publicProfileEnabled,
  }) async {
    final res = await _dio.put(
      '/api/v1/profile',
      data: {
        'display_name': displayName,
        'bio': bio,
        'public_profile_enabled': publicProfileEnabled,
      },
    );
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
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Do not attempt refresh for the refresh endpoint itself.
      if (err.requestOptions.path == '/api/v1/auth/refresh') {
        await _client._clearAllTokens();
        handler.reject(err);
        return;
      }

      final refreshToken = await _client.getStoredRefreshToken();
      if (refreshToken == null) {
        // No refresh token available, clear state and redirect to login.
        await _client._clearAllTokens();
        _navigateToLogin();
        handler.reject(err);
        return;
      }

      // Attempt to refresh the token (mutex ensures only one concurrent attempt).
      final newAccessToken = await _client.tryRefreshToken();

      if (newAccessToken != null) {
        // Refresh succeeded -- retry the original request with the new token.
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        try {
          final retryResponse = await _client._dio.fetch(err.requestOptions);
          handler.resolve(retryResponse);
        } on DioException catch (retryErr) {
          // Retry itself failed.
          handler.next(retryErr);
        }
      } else {
        // Refresh failed -- clear tokens and redirect to login.
        _navigateToLogin();
        handler.reject(err);
      }
    } else {
      handler.next(err);
    }
  }

  /// Navigate to the login screen using go_router's global key.
  void _navigateToLogin() {
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go('/auth/login');
    }
  }
}

// ── DTOs ─────────────────────────────────────────────

class RegisterRequest {
  final String email;
  final String username;
  final String authKeyHash;
  final String salt;
  final String recoveryKey;
  final String? recoverySalt;

  RegisterRequest({
    required this.email,
    required this.username,
    required this.authKeyHash,
    required this.salt,
    required this.recoveryKey,
    this.recoverySalt,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'username': username,
        'auth_key_hash': authKeyHash,
        'salt': salt,
        'recovery_key': recoveryKey,
        if (recoverySalt != null) 'recovery_salt': recoverySalt,
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

// ── Device Management DTOs ──

class DeviceDto {
  final String id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime lastSeen;

  DeviceDto({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSeen,
  });

  factory DeviceDto.fromJson(Map<String, dynamic> json) => DeviceDto(
        id: json['id'] as String,
        deviceId: json['device_id'] as String,
        deviceName: json['device_name'] as String,
        platform: json['platform'] as String,
        lastSeen: DateTime.parse(json['last_seen'] as String),
      );
}
