import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/domain/plan_model.dart';
import 'package:anynote/features/settings/presentation/plan_screen.dart';
import 'package:anynote/features/settings/providers/plan_providers.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('PlanScreen', () {
    /// Helper to create a PlanInfo instance for a given plan type.
    PlanInfo makePlan(PlanType type) {
      return PlanInfo(
        plan: type,
        limits: PlanLimits(
          maxNotes: type == PlanType.free
              ? 500
              : type == PlanType.pro
                  ? 10000
                  : -1,
          maxCollections: type == PlanType.free ? 20 : -1,
          aiDailyQuota: type == PlanType.free
              ? 50
              : type == PlanType.pro
                  ? 500
                  : -1,
          maxStorageBytes: type == PlanType.free
              ? 100 * 1024 * 1024
              : type == PlanType.pro
                  ? 5 * 1024 * 1024 * 1024
                  : -1,
          maxDevices: type == PlanType.free
              ? 2
              : type == PlanType.pro
                  ? 5
                  : -1,
          canCollaborate: type != PlanType.free,
          canPublish: true,
        ),
        aiDailyUsed: 12,
        storageBytes: 15 * 1024 * 1024,
        noteCount: 42,
      );
    }

    /// Pump the screen with a plan override and extra time for async resolution.
    Future<TestAppHandle> pumpWithPlan(
      WidgetTester tester,
      PlanInfo plan,
    ) async {
      final handle = await pumpScreen(
        tester,
        const PlanScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          planInfoProvider.overrideWith(() => _FakePlanNotifier(plan)),
        ],
      );
      // Extra pump time to let AsyncNotifier resolve.
      await tester.pumpAndSettle();
      return handle;
    }

    testWidgets('shows loading indicator while plan loads', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PlanScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          planInfoProvider.overrideWith(() => _HangingPlanNotifier()),
        ],
      );
      addTearDown(() => handle.dispose());

      // Should show a CircularProgressIndicator while loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders plan content when data is available', (tester) async {
      final handle = await pumpWithPlan(tester, makePlan(PlanType.free));
      addTearDown(() => handle.dispose());

      // Should show the current plan banner. The l10n format is
      // "Current Plan: Free" (capital P).
      expect(find.text('Current Plan: Free'), findsOneWidget);

      // Should show usage stats.
      expect(find.text('Notes'), findsOneWidget);
      expect(find.textContaining('42'), findsWidgets);
      expect(find.text('AI Usage'), findsOneWidget);

      // Should show the compare plans section.
      expect(find.text('Compare Plans'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows upgrade and restore buttons for free plan',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final handle = await pumpWithPlan(tester, makePlan(PlanType.free));
      addTearDown(() => handle.dispose());

      // Should show the Upgrade button for free plan.
      expect(find.text('Upgrade'), findsOneWidget);

      // Should show the Restore Purchase button.
      expect(find.text('Restore Purchase'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows lifetime badge for lifetime plan', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final handle = await pumpWithPlan(tester, makePlan(PlanType.lifetime));
      addTearDown(() => handle.dispose());

      // Should show lifetime badge instead of upgrade buttons.
      // The l10n string is "Lifetime Member -- all features unlocked forever."
      expect(find.textContaining('Lifetime Member'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);

      // Should NOT show upgrade button for lifetime plan.
      expect(find.text('Upgrade'), findsNothing);

      await handle.dispose();
    });

    testWidgets('shows error message when plan fails to load', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PlanScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          planInfoProvider.overrideWith(() => _ErrorPlanNotifier()),
        ],
      );
      // Extra pump for error to resolve.
      await tester.pumpAndSettle();
      addTearDown(() => handle.dispose());

      // Should show the error message.
      expect(find.text('Unable to load plan info.'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('comparison table shows plan features', (tester) async {
      final handle = await pumpWithPlan(tester, makePlan(PlanType.pro));
      addTearDown(() => handle.dispose());

      // The comparison table should show plan names.
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Lifetime'), findsOneWidget);

      // Should show current plan label.
      expect(find.text('Current Plan: Pro'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('tapping upgrade opens plan selection dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final handle = await pumpWithPlan(tester, makePlan(PlanType.free));
      addTearDown(() => handle.dispose());

      // Tap the Upgrade button.
      await tester.tap(find.text('Upgrade'));
      await tester.pumpAndSettle();

      // A dialog should appear with plan selection options.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Select a Plan'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('restore purchase shows snackbar', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final handle = await pumpWithPlan(tester, makePlan(PlanType.free));
      addTearDown(() => handle.dispose());

      // Scroll down to make the Restore Purchase button visible, then tap it.
      await tester.scrollUntilVisible(
        find.text('Restore Purchase'),
        100.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Restore Purchase'));
      await tester.pumpAndSettle();

      // A SnackBar should appear.
      expect(find.byType(SnackBar), findsOneWidget);

      await handle.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

/// A plan notifier that immediately returns a given PlanInfo.
class _FakePlanNotifier extends AsyncNotifier<PlanInfo>
    implements PlanInfoNotifier {
  final PlanInfo _plan;

  _FakePlanNotifier(this._plan);

  @override
  Future<PlanInfo> build() async => _plan;

  @override
  Future<void> refresh() async {
    state = AsyncData(_plan);
  }

  @override
  Future<void> upgrade(PlanType plan) async {
    // No-op for tests.
  }

  @override
  Future<void> startCheckout(String plan) async {}

  @override
  Future<bool> restorePurchase() async => false;
}

/// A plan notifier that never resolves (stays loading).
class _HangingPlanNotifier extends AsyncNotifier<PlanInfo>
    implements PlanInfoNotifier {
  @override
  Future<PlanInfo> build() async {
    // Never completes.
    return Completer<PlanInfo>().future;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> upgrade(PlanType plan) async {}

  @override
  Future<void> startCheckout(String plan) async {}

  @override
  Future<bool> restorePurchase() async => false;
}

/// A plan notifier that throws an error.
class _ErrorPlanNotifier extends AsyncNotifier<PlanInfo>
    implements PlanInfoNotifier {
  @override
  Future<PlanInfo> build() async {
    throw Exception('Network error');
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> upgrade(PlanType plan) async {}

  @override
  Future<void> startCheckout(String plan) async {}

  @override
  Future<bool> restorePurchase() async => false;
}
