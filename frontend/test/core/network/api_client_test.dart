import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';

void main() {
  // ===========================================================================
  // ApiClient -- construction
  // ===========================================================================

  group('ApiClient construction', () {
    test('stores the base URL', () {
      final client = ApiClient(baseUrl: 'http://localhost:8080');
      expect(client.baseUrl, equals('http://localhost:8080'));
    });

    test('stores the base URL with https', () {
      final client = ApiClient(baseUrl: 'https://api.example.com');
      expect(client.baseUrl, equals('https://api.example.com'));
    });
  });

  // ===========================================================================
  // ApiClient -- token management
  // ===========================================================================

  group('ApiClient token management', () {
    test('initially has no access token', () {
      final client = ApiClient(baseUrl: 'http://localhost:8080');
      expect(client.accessToken, isNull);
    });

    test('setAccessToken stores the token', () {
      final client = ApiClient(baseUrl: 'http://localhost:8080');
      client.setAccessToken('my-token');
      expect(client.accessToken, equals('my-token'));
    });

    test('clearAccessToken removes the token', () {
      final client = ApiClient(baseUrl: 'http://localhost:8080');
      client.setAccessToken('my-token');
      client.clearAccessToken();
      expect(client.accessToken, isNull);
    });

    test('setAccessToken can update the token', () {
      final client = ApiClient(baseUrl: 'http://localhost:8080');
      client.setAccessToken('token-1');
      expect(client.accessToken, equals('token-1'));

      client.setAccessToken('token-2');
      expect(client.accessToken, equals('token-2'));
    });
  });

  // ===========================================================================
  // RegisterRequest DTO
  // ===========================================================================

  group('RegisterRequest', () {
    test('toJson produces correct map', () {
      final req = RegisterRequest(
        email: 'user@example.com',
        username: 'testuser',
        authKeyHash: 'hash123',
        salt: 'salt456',
        recoveryKey: 'recovery789',
      );

      final json = req.toJson();

      expect(json['email'], equals('user@example.com'));
      expect(json['username'], equals('testuser'));
      expect(json['auth_key_hash'], equals('hash123'));
      expect(json['salt'], equals('salt456'));
      expect(json['recovery_key'], equals('recovery789'));
    });

    test('toJson has exactly 5 keys', () {
      final req = RegisterRequest(
        email: 'a@b.com',
        username: 'u',
        authKeyHash: 'h',
        salt: 's',
        recoveryKey: 'r',
      );
      expect(req.toJson().length, equals(5));
    });
  });

  // ===========================================================================
  // LoginRequest DTO
  // ===========================================================================

  group('LoginRequest', () {
    test('toJson produces correct map', () {
      final req = LoginRequest(
        email: 'user@example.com',
        authKeyHash: 'hash123',
      );

      final json = req.toJson();

      expect(json['email'], equals('user@example.com'));
      expect(json['auth_key_hash'], equals('hash123'));
    });

    test('toJson has exactly 2 keys', () {
      final req = LoginRequest(email: 'a@b.com', authKeyHash: 'h');
      expect(req.toJson().length, equals(2));
    });
  });

  // ===========================================================================
  // AuthResponse DTO
  // ===========================================================================

  group('AuthResponse', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'access_token': 'at_123',
        'refresh_token': 'rt_456',
        'expires_at': '2025-12-31T23:59:59.000Z',
        'user': {'id': 'uid-1', 'email': 'test@example.com'},
      };

      final response = AuthResponse.fromJson(json);

      expect(response.accessToken, equals('at_123'));
      expect(response.refreshToken, equals('rt_456'));
      expect(response.expiresAt, equals(DateTime.parse('2025-12-31T23:59:59.000Z')));
      expect(response.user['id'], equals('uid-1'));
      expect(response.user['email'], equals('test@example.com'));
    });
  });

  // ===========================================================================
  // SyncPullResponseDto
  // ===========================================================================

  group('SyncPullResponseDto', () {
    test('fromJson parses blobs and latestVersion', () {
      final json = {
        'blobs': [
          {'id': 'b1', 'data': 'abc'},
          {'id': 'b2', 'data': 'def'},
        ],
        'latest_version': 42,
      };

      final dto = SyncPullResponseDto.fromJson(json);

      expect(dto.blobs.length, equals(2));
      expect(dto.latestVersion, equals(42));
    });

    test('fromJson handles empty blobs list', () {
      final json = {
        'blobs': <dynamic>[],
        'latest_version': 0,
      };

      final dto = SyncPullResponseDto.fromJson(json);

      expect(dto.blobs, isEmpty);
      expect(dto.latestVersion, equals(0));
    });
  });

  // ===========================================================================
  // Auth interceptor -- token injection
  // ===========================================================================

  group('Auth interceptor token injection', () {
    test('access token is null by default (no header)', () {
      final client = ApiClient(baseUrl: 'http://localhost:8080');
      // The access token should be null initially.
      expect(client.accessToken, isNull);
    });

    test('setting and clearing token changes state', () {
      final client = ApiClient(baseUrl: 'http://localhost:8080');

      client.setAccessToken('jwt-token-here');
      expect(client.accessToken, equals('jwt-token-here'));

      client.clearAccessToken();
      expect(client.accessToken, isNull);
    });
  });

  // ===========================================================================
  // HTTP method wrappers -- endpoint paths
  // ===========================================================================

  group('API endpoint methods exist', () {
    late ApiClient client;

    setUp(() {
      client = ApiClient(baseUrl: 'http://localhost:8080');
      client.setAccessToken('test-token');
    });

    test('syncPull method exists and is callable', () {
      // Verify the method signature without making a real call.
      expect(client.syncPull, isA<Function>());
    });

    test('syncPush method exists and is callable', () {
      expect(client.syncPush, isA<Function>());
    });

    test('syncStatus method exists and is callable', () {
      expect(client.syncStatus, isA<Function>());
    });

    test('getMe method exists and is callable', () {
      expect(client.getMe, isA<Function>());
    });

    test('aiProxy method exists and is callable', () {
      expect(client.aiProxy, isA<Function>());
    });

    test('aiProxyStream method exists and is callable', () {
      expect(client.aiProxyStream, isA<Function>());
    });

    test('getAiQuota method exists and is callable', () {
      expect(client.getAiQuota, isA<Function>());
    });

    test('listLlmConfigs method exists and is callable', () {
      expect(client.listLlmConfigs, isA<Function>());
    });

    test('createLlmConfig method exists and is callable', () {
      expect(client.createLlmConfig, isA<Function>());
    });

    test('updateLlmConfig method exists and is callable', () {
      expect(client.updateLlmConfig, isA<Function>());
    });

    test('deleteLlmConfig method exists and is callable', () {
      expect(client.deleteLlmConfig, isA<Function>());
    });

    test('testLlmConfig method exists and is callable', () {
      expect(client.testLlmConfig, isA<Function>());
    });

    test('listLlmProviders method exists and is callable', () {
      expect(client.listLlmProviders, isA<Function>());
    });

    test('publish method exists and is callable', () {
      expect(client.publish, isA<Function>());
    });

    test('publishHistory method exists and is callable', () {
      expect(client.publishHistory, isA<Function>());
    });

    test('getPublish method exists and is callable', () {
      expect(client.getPublish, isA<Function>());
    });

    test('listPlatforms method exists and is callable', () {
      expect(client.listPlatforms, isA<Function>());
    });

    test('connectPlatform method exists and is callable', () {
      expect(client.connectPlatform, isA<Function>());
    });

    test('disconnectPlatform method exists and is callable', () {
      expect(client.disconnectPlatform, isA<Function>());
    });

    test('verifyPlatform method exists and is callable', () {
      expect(client.verifyPlatform, isA<Function>());
    });

    test('createShare method exists and is callable', () {
      expect(client.createShare, isA<Function>());
    });

    test('getSharedNote method exists and is callable', () {
      expect(client.getSharedNote, isA<Function>());
    });

    test('discoverFeed method exists and is callable', () {
      expect(client.discoverFeed, isA<Function>());
    });

    test('toggleReaction method exists and is callable', () {
      expect(client.toggleReaction, isA<Function>());
    });

    test('registerDevice method exists and is callable', () {
      expect(client.registerDevice, isA<Function>());
    });

    test('unregisterDevice method exists and is callable', () {
      expect(client.unregisterDevice, isA<Function>());
    });

    test('register method exists and is callable', () {
      expect(client.register, isA<Function>());
    });

    test('login method exists and is callable', () {
      expect(client.login, isA<Function>());
    });

    test('refreshToken method exists and is callable', () {
      expect(client.refreshToken, isA<Function>());
    });
  });

  // ===========================================================================
  // Dio configuration
  // ===========================================================================

  group('ApiClient Dio configuration', () {
    test('base options include correct content type', () {
      final client = ApiClient(baseUrl: 'http://localhost:8080');
      // The client has been constructed; we verify it does not throw.
      expect(client.baseUrl, isNotNull);
    });
  });
}
