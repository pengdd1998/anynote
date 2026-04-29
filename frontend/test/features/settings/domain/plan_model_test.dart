import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/domain/plan_model.dart';

void main() {
  // ===========================================================================
  // PlanType enum
  // ===========================================================================

  group('PlanType', () {
    test('has all three enum values', () {
      expect(PlanType.values,
          containsAll([PlanType.free, PlanType.pro, PlanType.lifetime]),);
      expect(PlanType.values.length, 3);
    });

    test('unknown string via fromJson defaults to free', () {
      final info = PlanInfo.fromJson({'plan': 'unknown_plan_xyz'});
      expect(info.plan, PlanType.free);
    });

    test('empty string via fromJson defaults to free', () {
      final info = PlanInfo.fromJson({'plan': ''});
      expect(info.plan, PlanType.free);
    });

    test('null plan via fromJson defaults to free', () {
      final info = PlanInfo.fromJson({});
      expect(info.plan, PlanType.free);
    });
  });

  // ===========================================================================
  // PlanLimits
  // ===========================================================================

  group('PlanLimits', () {
    test('default values from empty JSON', () {
      final limits = PlanLimits.fromJson({});

      expect(limits.maxNotes, 500);
      expect(limits.maxCollections, 20);
      expect(limits.aiDailyQuota, 50);
      expect(limits.maxStorageBytes, 104857600); // 100 * 1024 * 1024
      expect(limits.maxDevices, 2);
      expect(limits.canCollaborate, isFalse);
      expect(limits.canPublish, isTrue);
    });

    test('custom values from JSON', () {
      final limits = PlanLimits.fromJson({
        'max_notes': 1000,
        'can_collaborate': true,
      });

      expect(limits.maxNotes, 1000);
      expect(limits.maxCollections, 20); // default
      expect(limits.aiDailyQuota, 50); // default
      expect(limits.maxStorageBytes, 104857600); // default
      expect(limits.maxDevices, 2); // default
      expect(limits.canCollaborate, isTrue);
      expect(limits.canPublish, isTrue); // default
    });

    test('fully custom values from JSON', () {
      final limits = PlanLimits.fromJson({
        'max_notes': 9999,
        'max_collections': 100,
        'ai_daily_quota': 500,
        'max_storage_bytes': 10737418240,
        'max_devices': 10,
        'can_collaborate': true,
        'can_publish': false,
      });

      expect(limits.maxNotes, 9999);
      expect(limits.maxCollections, 100);
      expect(limits.aiDailyQuota, 500);
      expect(limits.maxStorageBytes, 10737418240);
      expect(limits.maxDevices, 10);
      expect(limits.canCollaborate, isTrue);
      expect(limits.canPublish, isFalse);
    });

    test('equality with same values', () {
      final a = PlanLimits.fromJson({'max_notes': 1000});
      final b = PlanLimits.fromJson({'max_notes': 1000});

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality with different values', () {
      final a = PlanLimits.fromJson({'max_notes': 500});
      final b = PlanLimits.fromJson({'max_notes': 1000});

      expect(a, isNot(equals(b)));
    });

    test('copyWith preserves unspecified fields', () {
      final original = PlanLimits.fromJson({
        'max_notes': 1000,
        'can_collaborate': true,
      });

      final copied = original.copyWith();

      expect(copied.maxNotes, 1000);
      expect(copied.maxCollections, 20);
      expect(copied.aiDailyQuota, 50);
      expect(copied.maxStorageBytes, 104857600);
      expect(copied.maxDevices, 2);
      expect(copied.canCollaborate, isTrue);
      expect(copied.canPublish, isTrue);
    });

    test('copyWith overrides specified fields', () {
      final original = PlanLimits.fromJson({});

      final copied = original.copyWith(
        maxNotes: 9999,
        canCollaborate: true,
      );

      expect(copied.maxNotes, 9999);
      expect(copied.maxCollections, 20); // preserved default
      expect(copied.canCollaborate, isTrue);
      expect(copied.canPublish, isTrue); // preserved default
    });

    test('equality is identity-safe', () {
      const limits = PlanLimits(
        maxNotes: 500,
        maxCollections: 20,
        aiDailyQuota: 50,
        maxStorageBytes: 104857600,
        maxDevices: 2,
        canCollaborate: false,
        canPublish: true,
      );

      // Same value constructed differently.
      final fromJson = PlanLimits.fromJson({});
      expect(limits, equals(fromJson));
    });
  });

  // ===========================================================================
  // PlanInfo
  // ===========================================================================

  group('PlanInfo', () {
    test('parse from JSON with free plan', () {
      final info = PlanInfo.fromJson(<String, dynamic>{
        'plan': 'free',
        'limits': <String, dynamic>{},
        'ai_daily_used': 10,
        'storage_bytes': 50000,
        'note_count': 200,
      });

      expect(info.plan, PlanType.free);
      expect(info.limits.maxNotes, 500);
      expect(info.aiDailyUsed, 10);
      expect(info.storageBytes, 50000);
      expect(info.noteCount, 200);
    });

    test('parse from JSON with pro plan', () {
      final info = PlanInfo.fromJson(<String, dynamic>{
        'plan': 'pro',
        'limits': <String, dynamic>{'max_notes': 10000},
        'ai_daily_used': 100,
        'storage_bytes': 1073741824,
        'note_count': 500,
      });

      expect(info.plan, PlanType.pro);
      expect(info.limits.maxNotes, 10000);
    });

    test('parse from JSON with lifetime plan', () {
      final info = PlanInfo.fromJson(<String, dynamic>{
        'plan': 'lifetime',
        'limits': <String, dynamic>{},
      });

      expect(info.plan, PlanType.lifetime);
    });

    test('fromJson defaults for missing fields', () {
      final info = PlanInfo.fromJson({});

      expect(info.plan, PlanType.free);
      expect(info.limits.maxNotes, 500);
      expect(info.aiDailyUsed, 0);
      expect(info.storageBytes, 0);
      expect(info.noteCount, 0);
    });

    test('displayName returns correct strings', () {
      expect(
        PlanInfo.fromJson({'plan': 'free'}).displayName,
        'Free',
      );
      expect(
        PlanInfo.fromJson({'plan': 'pro'}).displayName,
        'Pro',
      );
      expect(
        PlanInfo.fromJson({'plan': 'lifetime'}).displayName,
        'Lifetime',
      );
    });

    test('equality with same values', () {
      final json = <String, dynamic>{
        'plan': 'pro',
        'limits': <String, dynamic>{'max_notes': 1000},
        'ai_daily_used': 25,
        'storage_bytes': 9999,
        'note_count': 42,
      };
      final a = PlanInfo.fromJson(json);
      final b = PlanInfo.fromJson(json);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality with different values', () {
      final a = PlanInfo.fromJson({'plan': 'free'});
      final b = PlanInfo.fromJson({'plan': 'pro'});

      expect(a, isNot(equals(b)));
    });

    test('copyWith preserves unspecified fields', () {
      final original = PlanInfo.fromJson(<String, dynamic>{
        'plan': 'pro',
        'limits': <String, dynamic>{'max_notes': 1000},
        'ai_daily_used': 25,
        'storage_bytes': 9999,
        'note_count': 42,
      });

      final copied = original.copyWith();

      expect(copied.plan, PlanType.pro);
      expect(copied.limits.maxNotes, 1000);
      expect(copied.aiDailyUsed, 25);
      expect(copied.storageBytes, 9999);
      expect(copied.noteCount, 42);
    });

    test('copyWith overrides specified fields', () {
      final original = PlanInfo.fromJson({
        'plan': 'free',
        'ai_daily_used': 0,
      });

      final copied = original.copyWith(
        plan: PlanType.lifetime,
        aiDailyUsed: 99,
      );

      expect(copied.plan, PlanType.lifetime);
      expect(copied.aiDailyUsed, 99);
      expect(copied.storageBytes, 0); // preserved
      expect(copied.noteCount, 0); // preserved
    });
  });
}
