import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';
import '../domain/plan_model.dart';

// ── Plan Info ────────────────────────────────────────────

/// Async notifier that fetches and exposes plan info from the server.
class PlanInfoNotifier extends AsyncNotifier<PlanInfo> {
  @override
  Future<PlanInfo> build() async {
    final api = ref.read(apiClientProvider);
    final data = await api.getPlan();
    return PlanInfo.fromJson(data);
  }

  /// Refresh plan info from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiClientProvider);
      final data = await api.getPlan();
      return PlanInfo.fromJson(data);
    });
  }

  /// Upgrade the plan and refresh the state.
  Future<void> upgrade(PlanType plan) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiClientProvider);
      final planStr = switch (plan) {
        PlanType.pro => 'pro',
        PlanType.lifetime => 'lifetime',
        PlanType.free => 'free',
      };
      final data = await api.upgradePlan(planStr);
      return PlanInfo.fromJson(data);
    });
  }
}

final planInfoProvider = AsyncNotifierProvider<PlanInfoNotifier, PlanInfo>(
  PlanInfoNotifier.new,
);

// ── Profile Info ─────────────────────────────────────────

/// Async notifier that fetches and exposes the user's own profile.
class ProfileNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    // Profile data is part of account info; reuse the /auth/me endpoint
    // which includes display_name and bio.
    final api = ref.read(apiClientProvider);
    return api.getMe();
  }

  /// Update the user's profile.
  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required bool publicProfileEnabled,
  }) async {
    final api = ref.read(apiClientProvider);
    await api.updateProfile(
      displayName: displayName,
      bio: bio,
      publicProfileEnabled: publicProfileEnabled,
    );
    ref.invalidateSelf();
  }

  /// Refresh profile from the server.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Map<String, dynamic>>(
  ProfileNotifier.new,
);
