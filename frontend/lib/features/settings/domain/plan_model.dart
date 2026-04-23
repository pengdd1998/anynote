/// Plan types matching the backend domain.
enum PlanType { free, pro, lifetime }

/// Plan limits returned from the backend.
class PlanLimits {
  final int maxNotes;
  final int maxCollections;
  final int aiDailyQuota;
  final int maxStorageBytes;
  final int maxDevices;
  final bool canCollaborate;
  final bool canPublish;

  const PlanLimits({
    required this.maxNotes,
    required this.maxCollections,
    required this.aiDailyQuota,
    required this.maxStorageBytes,
    required this.maxDevices,
    required this.canCollaborate,
    required this.canPublish,
  });

  factory PlanLimits.fromJson(Map<String, dynamic> json) => PlanLimits(
        maxNotes: json['max_notes'] as int? ?? 500,
        maxCollections: json['max_collections'] as int? ?? 20,
        aiDailyQuota: json['ai_daily_quota'] as int? ?? 50,
        maxStorageBytes: json['max_storage_bytes'] as int? ?? 100 * 1024 * 1024,
        maxDevices: json['max_devices'] as int? ?? 2,
        canCollaborate: json['can_collaborate'] as bool? ?? false,
        canPublish: json['can_publish'] as bool? ?? true,
      );
}

/// Full plan info returned by GET /api/v1/plan.
class PlanInfo {
  final PlanType plan;
  final PlanLimits limits;
  final int aiDailyUsed;
  final int storageBytes;
  final int noteCount;

  const PlanInfo({
    required this.plan,
    required this.limits,
    required this.aiDailyUsed,
    required this.storageBytes,
    required this.noteCount,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) => PlanInfo(
        plan: _parsePlan(json['plan'] as String? ?? 'free'),
        limits:
            PlanLimits.fromJson(json['limits'] as Map<String, dynamic>? ?? {}),
        aiDailyUsed: json['ai_daily_used'] as int? ?? 0,
        storageBytes: json['storage_bytes'] as int? ?? 0,
        noteCount: json['note_count'] as int? ?? 0,
      );

  /// Display-friendly name for the plan.
  String get displayName => switch (plan) {
        PlanType.free => 'Free',
        PlanType.pro => 'Pro',
        PlanType.lifetime => 'Lifetime',
      };
}

PlanType _parsePlan(String s) => switch (s) {
      'pro' => PlanType.pro,
      'lifetime' => PlanType.lifetime,
      _ => PlanType.free,
    };
