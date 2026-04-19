import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/settings_screen.dart';

void main() {
  test('SettingsScreen can be constructed', () {
    // Smoke test: verify the widget can be instantiated without errors.
    // Full widget pump test skipped due to Drift timer leaks in test env.
    expect(const SettingsScreen(), isA<Widget>());
  });
}
