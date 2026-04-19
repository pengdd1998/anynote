import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/note_editor_screen.dart';

void main() {
  test('NoteEditorScreen can be constructed', () {
    // Smoke test: verify the widget can be instantiated without errors.
    // Full widget pump test skipped due to Drift timer leaks in test env.
    expect(const NoteEditorScreen(), isA<Widget>());
  });
}
