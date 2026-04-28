/// Typed data models for API responses.
///
/// These replace the raw `Map<String, dynamic>` returns throughout the
/// settings providers, giving compile-time safety and self-documenting code.
library;

/// AI quota information from GET /api/v1/ai/quota.
class AiQuota {
  final String plan;
  final int dailyLimit;
  final int dailyUsed;
  final DateTime resetAt;

  const AiQuota({
    required this.plan,
    required this.dailyLimit,
    required this.dailyUsed,
    required this.resetAt,
  });

  factory AiQuota.fromJson(Map<String, dynamic> json) => AiQuota(
        plan: json['plan'] as String? ?? 'free',
        dailyLimit: json['daily_limit'] as int? ?? 0,
        dailyUsed: json['daily_used'] as int? ?? 0,
        resetAt: json['reset_at'] != null
            ? DateTime.parse(json['reset_at'] as String)
            : DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// How many requests are remaining today.
  int get remaining => dailyLimit - dailyUsed;

  /// Whether the quota has been exhausted.
  bool get isExhausted => dailyUsed >= dailyLimit;
}

/// Account information from GET /api/v1/auth/me.
class AccountInfo {
  final String id;
  final String email;
  final String username;
  final String plan;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountInfo({
    required this.id,
    required this.email,
    required this.username,
    required this.plan,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        plan: json['plan'] as String? ?? 'free',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

/// An LLM configuration from GET /api/v1/llm/configs.
class LlmConfig {
  final String id;
  final String name;
  final String provider;
  final String? baseUrl;
  final String model;
  final bool isDefault;
  final int maxTokens;
  final double temperature;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LlmConfig({
    required this.id,
    required this.name,
    required this.provider,
    this.baseUrl,
    required this.model,
    required this.isDefault,
    required this.maxTokens,
    required this.temperature,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        provider: json['provider'] as String,
        baseUrl: json['base_url'] as String?,
        model: json['model'] as String,
        isDefault: json['is_default'] as bool? ?? false,
        maxTokens: json['max_tokens'] as int? ?? 4096,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

/// A platform connection from GET /api/v1/platforms.
class PlatformConnection {
  final String id;
  final String platform;
  final String? platformUid;
  final String? displayName;
  final String status;
  final DateTime? lastVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlatformConnection({
    required this.id,
    required this.platform,
    this.platformUid,
    this.displayName,
    required this.status,
    this.lastVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlatformConnection.fromJson(Map<String, dynamic> json) =>
      PlatformConnection(
        id: json['id'] as String,
        platform: json['platform'] as String,
        platformUid: json['platform_uid'] as String?,
        displayName: json['display_name'] as String?,
        status: json['status'] as String? ?? 'disconnected',
        lastVerified: json['last_verified'] != null
            ? DateTime.parse(json['last_verified'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Whether the platform is currently connected.
  bool get isConnected => status == 'connected';
}

/// Sync status information from GET /api/v1/sync/status.
class SyncStatusInfo {
  final int latestVersion;
  final int totalItems;
  final DateTime? lastSyncedAt;

  const SyncStatusInfo({
    required this.latestVersion,
    required this.totalItems,
    this.lastSyncedAt,
  });

  factory SyncStatusInfo.fromJson(Map<String, dynamic> json) => SyncStatusInfo(
        latestVersion: json['latest_version'] as int? ?? 0,
        totalItems: json['total_items'] as int? ?? 0,
        lastSyncedAt: json['last_synced_at'] != null
            ? DateTime.parse(json['last_synced_at'] as String)
            : null,
      );
}
