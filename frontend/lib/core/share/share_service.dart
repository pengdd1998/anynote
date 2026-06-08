import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import '../crypto/encryptor.dart';
import '../network/api_client.dart';
import '../../main.dart';

/// Result of creating a shared note.
class ShareResult {
  /// Unique share identifier.
  /// For server shares: hex-encoded random ID from the server.
  /// For local-only shares: base64url-encoded random 16 bytes.
  final String id;

  /// Share URL.
  /// Server mode: https://server/api/v1/share/{id}#{base64url(key)}
  /// Local mode:  anynote://share/{base64url(payload)}#{base64url(key)}
  /// For password-protected shares the fragment is "pwd".
  final String shareLink;

  /// The encrypted payload (base64url-encoded), used for clipboard fallback.
  /// Empty for server-stored shares (data is on the server).
  final String payload;

  /// The share key in base64url encoding. Null for password-protected shares.
  final String? shareKey;

  /// When the share expires, or null for never.
  final DateTime? expiresAt;

  /// Whether the share is password-protected.
  final bool hasPassword;

  /// Whether the share is stored on the server (true) or self-contained (false).
  final bool isServerStored;

  ShareResult({
    required this.id,
    required this.shareLink,
    required this.payload,
    this.shareKey,
    this.expiresAt,
    required this.hasPassword,
    this.isServerStored = false,
  });

  ShareResult copyWith({
    String? id,
    String? shareLink,
    String? payload,
    String? shareKey,
    DateTime? expiresAt,
    bool? hasPassword,
    bool? isServerStored,
  }) {
    return ShareResult(
      id: id ?? this.id,
      shareLink: shareLink ?? this.shareLink,
      payload: payload ?? this.payload,
      shareKey: shareKey ?? this.shareKey,
      expiresAt: expiresAt ?? this.expiresAt,
      hasPassword: hasPassword ?? this.hasPassword,
      isServerStored: isServerStored ?? this.isServerStored,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareResult &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          shareLink == other.shareLink &&
          payload == other.payload &&
          shareKey == other.shareKey &&
          expiresAt == other.expiresAt &&
          hasPassword == other.hasPassword &&
          isServerStored == other.isServerStored;

  @override
  int get hashCode => Object.hash(
        id,
        shareLink,
        payload,
        shareKey,
        expiresAt,
        hasPassword,
        isServerStored,
      );
}

/// A decrypted shared note ready for display.
class DecryptedSharedNote {
  final String title;
  final String content;

  DecryptedSharedNote({
    required this.title,
    required this.content,
  });

  DecryptedSharedNote copyWith({
    String? title,
    String? content,
  }) {
    return DecryptedSharedNote(
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecryptedSharedNote &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          content == other.content;

  @override
  int get hashCode => Object.hash(title, content);
}

/// Service for creating and consuming shared notes.
///
/// Supports two modes:
///
/// **Server mode** (default): The encrypted blob is POSTed to
/// `/api/v1/share`. The server stores it and returns a share ID.
/// The share URL is: `https://server/api/v1/share/{id}#{key}`
/// The key stays in the URL fragment and is never sent to the server.
///
/// **Local mode** (fallback): The encrypted payload is fully self-contained
/// in the URL: `anynote://share/{base64url(nonce||ciphertext)}#{key}`
/// No network request is needed.
///
/// Both modes use the same crypto layer: XChaCha20-Poly1305 with a fresh
/// random key (or Argon2id-derived key for password-protected shares).
class ShareService {
  final ApiClient _api;

  /// Whether to use the server for share storage.
  /// When true, encrypted blobs are uploaded to the backend and a short URL
  /// is returned. Falls back to self-contained local mode on failure.
  static const bool _useServerStorage = true;

  ShareService(this._api);

  // ── Create ──────────────────────────────────────────

  /// Create a shared note from decrypted content.
  ///
  /// In server mode the encrypted blob is uploaded to the backend and a
  /// short share URL is returned. The decryption key stays in the URL
  /// fragment and is never sent to the server (zero-knowledge).
  ///
  /// Falls back to self-contained local mode if the server is unavailable.
  ///
  /// [plainTitle]   - The decrypted note title.
  /// [plainContent] - The decrypted note content.
  /// [password]     - Optional password for password-protected shares.
  /// [expiresHours] - Optional expiry in hours (null = never expires).
  /// [maxViews]     - Optional max number of views (server mode only).
  Future<ShareResult> createShare({
    required String plainTitle,
    required String plainContent,
    String? password,
    int? expiresHours,
    int? maxViews,
  }) async {
    final sodium = await SodiumSumoInit.init();

    // Generate a random share ID (16 bytes).
    final shareId = base64Url
        .encode(sodium.secureRandom(16).extractBytes())
        .replaceAll('=', '');

    // Generate or derive the share key.
    final Uint8List shareKeyBytes;
    final bool hasPassword = password != null && password.isNotEmpty;

    // Random salt for Argon2id (password-protected shares only).
    // Embedded in the encrypted content so it survives server ID reassignment.
    final Uint8List? argonSalt = hasPassword
        ? sodium.secureRandom(sodium.crypto.pwhash.saltBytes).extractBytes()
        : null;

    if (hasPassword && argonSalt != null) {
      shareKeyBytes =
          await _deriveKeyFromPassword(sodium, password, argonSalt);
    } else {
      shareKeyBytes = sodium
          .secureRandom(
            sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes,
          )
          .extractBytes();
    }

    // Encrypt title and content together as JSON with XChaCha20-Poly1305.
    final plaintext = jsonEncode({
      'title': plainTitle,
      'content': plainContent,
    });
    final encryptedBase64 = await Encryptor.encrypt(plaintext, shareKeyBytes);

    // For password-protected shares, prepend the Argon2id salt so it is
    // available during decryption regardless of the server-assigned share ID.
    final String finalEncryptedContent;
    if (hasPassword && argonSalt != null) {
      final encryptedRaw = base64Decode(encryptedBase64);
      finalEncryptedContent = base64Encode(
        Uint8List.fromList([...argonSalt, ...encryptedRaw]),
      );
    } else {
      finalEncryptedContent = encryptedBase64;
    }

    // Encode the share key.
    final shareKeyB64 = base64Url.encode(shareKeyBytes).replaceAll('=', '');

    // For password-protected shares, the fragment is "pwd" (no key included).
    final fragment = hasPassword ? 'pwd' : shareKeyB64;

    if (_useServerStorage) {
      // Server mode: POST encrypted data to the backend.
      // Title and content are encrypted together; we store the same blob in
      // both encrypted_content and encrypted_title fields for compatibility
      // with the server schema. The key is never sent.
      try {
        // For password-protected shares the server expects
        // share_key_hash = hex(SHA-256(password)) so it can verify the
        // password via X-Share-Password header without knowing the key.
        // For non-password shares the hash is for server-side reference only.
        final String shareKeyHashHex;
        if (hasPassword) {
          final pwDigest = crypto.sha256.convert(utf8.encode(password));
          shareKeyHashHex = pwDigest.toString();
        } else {
          final shareKeyHash = sodium.crypto.genericHash.call(
            message: shareKeyBytes,
            outLen: 32,
          );
          shareKeyHashHex = hexEncode(shareKeyHash);
        }

        final response = await _api.createShare({
          'encrypted_content': finalEncryptedContent,
          'encrypted_title': base64Url.encode(
            Uint8List.fromList(utf8.encode(plainTitle)),
          ),
          'share_key_hash': shareKeyHashHex,
          'has_password': hasPassword,
          if (expiresHours != null) 'expires_hours': expiresHours,
          if (maxViews != null) 'max_views': maxViews,
        });

        final serverId = response['id'] as String;
        final serverUrl = response['url'] as String;
        final apiBaseUrl = _api.baseUrl;

        // Build the share link using the server URL + key fragment.
        // The fragment (#key) is never sent to the server.
        final shareLink = '$apiBaseUrl$serverUrl#$fragment';

        return ShareResult(
          id: serverId,
          shareLink: shareLink,
          payload: '',
          shareKey: hasPassword ? null : shareKeyB64,
          expiresAt: expiresHours != null
              ? DateTime.now().toUtc().add(Duration(hours: expiresHours))
              : null,
          hasPassword: hasPassword,
          isServerStored: true,
        );
      } catch (e) {
        // Server unavailable -- fall through to self-contained mode.
        debugPrint(
            '[ShareService] server share creation failed, falling back to local mode: $e',);
      }
    }

    // Local-only (self-contained) mode: embed everything in the URL.
    final payloadBytes = <int>[
      ...base64Url.decode(base64Url.normalize(shareId)),
      ...base64Decode(finalEncryptedContent),
    ];
    final payload = base64Url.encode(Uint8List.fromList(payloadBytes));
    final shareLink = 'anynote://share/$payload#$fragment';

    return ShareResult(
      id: shareId,
      shareLink: shareLink,
      payload: payload,
      shareKey: hasPassword ? null : shareKeyB64,
      expiresAt: expiresHours != null
          ? DateTime.now().toUtc().add(Duration(hours: expiresHours))
          : null,
      hasPassword: hasPassword,
      isServerStored: false,
    );
  }

  // ── Decrypt ─────────────────────────────────────────

  /// Decrypt a shared note from a self-contained payload and key.
  ///
  /// [payload] - The base64url-encoded payload from the share URL path.
  /// [key]     - The base64url-encoded key from the URL fragment, or null
  ///             for password-protected shares.
  /// [password] - The password to derive the key from (for password-protected
  ///              shares). Ignored if [key] is provided.
  Future<DecryptedSharedNote> decryptSharedNote({
    required String payload,
    String? key,
    String? password,
  }) async {
    final sodium = await SodiumSumoInit.init();

    // Decode the payload.
    final payloadBytes = base64Url.decode(base64Url.normalize(payload));

    // Payload layout for key-based shares:
    //   shareId (16) || nonce (24) || ciphertext+tag
    // Payload layout for password-protected shares:
    //   shareId (16) || argonSalt (pwhash.saltBytes) || nonce (24) || ciphertext+tag
    final nonceLength = sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes;
    final saltLength = sodium.crypto.pwhash.saltBytes;

    if (payloadBytes.length < 16 + nonceLength + 16) {
      throw const FormatException('Share payload is too short');
    }

    // Determine the key and encrypted data offset.
    final Uint8List shareKeyBytes;
    final int encryptedOffset;
    if (key != null && key.isNotEmpty && key != 'pwd') {
      shareKeyBytes = base64Url.decode(base64Url.normalize(key));
      encryptedOffset = 16; // shareId only
    } else if (password != null && password.isNotEmpty) {
      // Extract the embedded Argon2id salt (bytes 16..16+saltLength).
      final salt = Uint8List.fromList(
        payloadBytes.sublist(16, 16 + saltLength),
      );
      shareKeyBytes = await _deriveKeyFromPassword(sodium, password, salt);
      encryptedOffset = 16 + saltLength; // shareId + salt
    } else {
      throw ArgumentError(
        'Either a key or a password must be provided to decrypt the shared note.',
      );
    }

    // Decrypt.
    final encryptedBase64 = base64Encode(payloadBytes.sublist(encryptedOffset));
    final plaintext = await Encryptor.decrypt(encryptedBase64, shareKeyBytes);
    final json = jsonDecode(plaintext) as Map<String, dynamic>;

    return DecryptedSharedNote(
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }

  /// Fetch a server-stored share and decrypt it.
  ///
  /// [shareId] - The server share ID (hex string).
  /// [key]     - The decryption key from the URL fragment (base64url), or null
  ///             for password-protected shares.
  /// [password] - Password for password-protected shares. Ignored if [key] is
  ///              provided.
  Future<DecryptedSharedNote> decryptServerSharedNote({
    required String shareId,
    String? key,
    String? password,
  }) async {
    // Fetch encrypted data from the server.
    // For password-protected shares, send the password header so the server
    // can verify access before returning the encrypted content.
    final response = await _api.getSharedNote(
      shareId,
      password: (key == null || key == 'pwd') ? password : null,
    );
    final encryptedContent = response['encrypted_content'] as String;

    // Determine the key.
    final Uint8List shareKeyBytes;
    final String actualEncryptedContent;
    if (key != null && key.isNotEmpty && key != 'pwd') {
      shareKeyBytes = base64Url.decode(base64Url.normalize(key));
      actualEncryptedContent = encryptedContent;
    } else if (password != null && password.isNotEmpty) {
      final sodium = await SodiumSumoInit.init();
      // Extract the embedded Argon2id salt from the first pwhash.saltBytes.
      final contentBytes = base64Decode(encryptedContent);
      final saltLength = sodium.crypto.pwhash.saltBytes;
      if (contentBytes.length < saltLength) {
        throw const FormatException(
          'Encrypted content too short for password-protected share',
        );
      }
      final salt = Uint8List.fromList(contentBytes.sublist(0, saltLength));
      shareKeyBytes = await _deriveKeyFromPassword(sodium, password, salt);
      // The actual encrypted data follows the salt.
      actualEncryptedContent = base64Encode(contentBytes.sublist(saltLength));
    } else {
      throw ArgumentError(
        'Either a key or a password must be provided to decrypt the shared note.',
      );
    }

    // Decrypt the content blob.
    final plaintext =
        await Encryptor.decrypt(actualEncryptedContent, shareKeyBytes);
    final json = jsonDecode(plaintext) as Map<String, dynamic>;

    return DecryptedSharedNote(
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }

  /// Fetch a server-stored share metadata (encrypted content, expiry, etc.)
  /// without attempting decryption. Useful for displaying share info before
  /// the user provides a password.
  Future<ServerShareInfo> fetchServerShare(String shareId) async {
    final response = await _api.getSharedNote(shareId);
    return ServerShareInfo(
      id: response['id'] as String,
      encryptedContent: response['encrypted_content'] as String,
      hasPassword: response['has_password'] as bool,
      expiresAt: response['expires_at'] != null
          ? DateTime.parse(response['expires_at'] as String)
          : null,
      viewCount: response['view_count'] as int,
      maxViews: response['max_views'] as int?,
    );
  }

  /// Parse a share URL and extract the payload/share info and key fragment.
  ///
  /// Supports both URL formats:
  /// - Server mode:  `https://server/api/v1/share/{id}#{key}`
  /// - Local mode:   `anynote://share/{payload}#{key}`
  ///
  /// Returns null if the URL is not a valid share link.
  static ParsedShareLink? parseShareLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Server mode: http(s)://host/api/v1/share/{id}#{fragment}
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.path.contains('/api/v1/share/')) {
      final segments = uri.pathSegments;
      // Expect [..., 'api', 'v1', 'share', '{id}']
      final shareIndex = segments.indexOf('share');
      if (shareIndex < 0 || shareIndex + 1 >= segments.length) return null;
      final shareId = segments[shareIndex + 1];
      if (shareId.isEmpty) return null;

      final fragment = uri.fragment;
      return ParsedShareLink(
        payload: shareId,
        keyFragment: fragment.isEmpty || fragment == 'pwd' ? null : fragment,
        isPasswordProtected: fragment.isEmpty || fragment == 'pwd',
        isServerShare: true,
      );
    }

    // Local mode: anynote://share/{payload}#{fragment}
    if (uri.scheme != 'anynote' || uri.host != 'share') return null;

    final payload = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (payload.isEmpty) return null;

    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;

    return ParsedShareLink(
      payload: payload,
      keyFragment: fragment == 'pwd' ? null : fragment,
      isPasswordProtected: fragment == 'pwd',
      isServerShare: false,
    );
  }

  // ── Key Derivation ──────────────────────────────────

  /// Derive a share key from a password using Argon2id.
  Future<Uint8List> _deriveKeyFromPassword(
    SodiumSumo sodium,
    String password,
    Uint8List salt,
  ) async {
    final passwordBytes = Int8List.fromList(utf8.encode(password));
    final key = sodium.crypto.pwhash.call(
      password: passwordBytes,
      salt: salt,
      outLen: 32,
      opsLimit: sodium.crypto.pwhash.opsLimitSensitive,
      memLimit: sodium.crypto.pwhash.memLimitModerate,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );

    final result = key.extractBytes();
    key.dispose();
    return result;
  }
}

/// Parsed components of a share URL.
class ParsedShareLink {
  /// The share payload or server share ID.
  /// For server shares this is the hex-encoded ID.
  /// For local shares this is the base64url-encoded encrypted payload.
  final String payload;

  /// The decryption key (base64url-encoded), or null if password-protected.
  final String? keyFragment;

  /// Whether the share requires a password to decrypt.
  final bool isPasswordProtected;

  /// Whether this share is stored on the server (vs self-contained).
  final bool isServerShare;

  ParsedShareLink({
    required this.payload,
    required this.keyFragment,
    required this.isPasswordProtected,
    this.isServerShare = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedShareLink &&
          runtimeType == other.runtimeType &&
          payload == other.payload &&
          keyFragment == other.keyFragment &&
          isPasswordProtected == other.isPasswordProtected &&
          isServerShare == other.isServerShare;

  @override
  int get hashCode => Object.hash(
        payload,
        keyFragment,
        isPasswordProtected,
        isServerShare,
      );
}

/// Metadata for a server-stored share (before decryption).
class ServerShareInfo {
  final String id;
  final String encryptedContent;
  final bool hasPassword;
  final DateTime? expiresAt;
  final int viewCount;
  final int? maxViews;

  ServerShareInfo({
    required this.id,
    required this.encryptedContent,
    required this.hasPassword,
    this.expiresAt,
    required this.viewCount,
    this.maxViews,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerShareInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          encryptedContent == other.encryptedContent &&
          hasPassword == other.hasPassword &&
          expiresAt == other.expiresAt &&
          viewCount == other.viewCount &&
          maxViews == other.maxViews;

  @override
  int get hashCode => Object.hash(
        id,
        encryptedContent,
        hasPassword,
        expiresAt,
        viewCount,
        maxViews,
      );
}

/// Encode a byte list as a hex string.
String hexEncode(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Riverpod provider for the ShareService.
final shareServiceProvider = Provider<ShareService>((ref) {
  final api = ref.watch(apiClientProvider);
  return ShareService(api);
});
