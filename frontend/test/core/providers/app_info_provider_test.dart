import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:anynote/core/providers/app_info_provider.dart';

void main() {
  // ===========================================================================
  // appInfoProvider
  // ===========================================================================

  group('appInfoProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('provider is a FutureProvider<PackageInfo>', () {
      // Verify the provider type.
      final asyncValue = container.read(appInfoProvider);
      expect(asyncValue, isA<AsyncValue<PackageInfo>>());
    });

    test('resolves to a PackageInfo instance', () async {
      final info = await container.read(appInfoProvider).future;

      expect(info, isA<PackageInfo>());
    });

    test('PackageInfo has non-empty appName', () async {
      final info = await container.read(appInfoProvider).future;

      // In test environment, PackageInfo.fromPlatform() returns defaults
      // from the package_info_plus test setup. The app name should be a
      // non-empty string.
      expect(info.appName, isNotEmpty);
    });

    test('PackageInfo has non-empty packageName', () async {
      final info = await container.read(appInfoProvider).future;

      expect(info.packageName, isNotEmpty);
    });

    test('PackageInfo has version string', () async {
      final info = await container.read(appInfoProvider).future;

      // Version can be any string (including 'unknown' in test env).
      expect(info.version, isNotNull);
    });

    test('PackageInfo has buildNumber', () async {
      final info = await container.read(appInfoProvider).future;

      expect(info.buildNumber, isNotNull);
    });

    test('provider is readable synchronously as AsyncValue', () {
      // Before the future resolves, the provider should be in loading state.
      final asyncValue = container.read(appInfoProvider);
      // It can be either AsyncLoading or AsyncData depending on timing.
      expect(asyncValue, isA<AsyncValue<PackageInfo>>());
    });

    test('provider caches the result after first read', () async {
      final info1 = await container.read(appInfoProvider).future;
      final info2 = await container.read(appInfoProvider).future;

      // Both reads should return the same PackageInfo instance (cached).
      expect(identical(info1, info2), isTrue);
    });

    test('multiple containers can independently resolve the provider', () async {
      final container2 = ProviderContainer();
      addTearDown(() => container2.dispose());

      final info1 = await container.read(appInfoProvider).future;
      final info2 = await container2.read(appInfoProvider).future;

      // Both should resolve successfully (possibly different instances but
      // same content since they come from the same platform).
      expect(info1.appName, info2.appName);
      expect(info1.packageName, info2.packageName);
      expect(info1.version, info2.version);
    });
  });
}
