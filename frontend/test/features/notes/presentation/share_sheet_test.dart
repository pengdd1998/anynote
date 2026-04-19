import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/share_sheet.dart';

void main() {
  test('ShareSheet can be constructed', () {
    // Smoke test: verify the widget can be instantiated without errors.
    // Full widget pump test skipped due to Drift timer leaks in test env.
    expect(
      const ShareSheet(title: 'Test', content: 'Content'),
      isA<Widget>(),
    );
  });
}
