import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/accessibility/a11y_utils.dart';

void main() {
  // ---------------------------------------------------------------------------
  // compositeColor
  // ---------------------------------------------------------------------------

  group('A11yUtils.compositeColor', () {
    test('returns background when foreground is fully transparent', () {
      final result = A11yUtils.compositeColor(
        const Color.from(alpha: 0.0, red: 1.0, green: 0.0, blue: 0.0),
        const Color.from(alpha: 1.0, red: 0.0, green: 0.0, blue: 1.0),
      );
      expect(result.a, 1.0);
      expect(result.r, closeTo(0.0, 0.001));
      expect(result.g, closeTo(0.0, 0.001));
      expect(result.b, closeTo(1.0, 0.001));
    });

    test('returns foreground when foreground is fully opaque', () {
      final result = A11yUtils.compositeColor(
        const Color.from(alpha: 1.0, red: 1.0, green: 0.0, blue: 0.0),
        const Color.from(alpha: 1.0, red: 0.0, green: 0.0, blue: 1.0),
      );
      expect(result.a, 1.0);
      expect(result.r, closeTo(1.0, 0.001));
      expect(result.g, closeTo(0.0, 0.001));
      expect(result.b, closeTo(0.0, 0.001));
    });

    test('blends semi-transparent foreground over white background', () {
      // 50% opaque red over white should yield ~pink.
      final result = A11yUtils.compositeColor(
        const Color.from(alpha: 0.5, red: 1.0, green: 0.0, blue: 0.0),
        const Color.from(alpha: 1.0, red: 1.0, green: 1.0, blue: 1.0),
      );
      expect(result.a, 1.0);
      expect(result.r, closeTo(1.0, 0.001));
      expect(result.g, closeTo(0.5, 0.001));
      expect(result.b, closeTo(0.5, 0.001));
    });

    test('blends semi-transparent blue over black background', () {
      final result = A11yUtils.compositeColor(
        const Color.from(alpha: 0.5, red: 0.0, green: 0.0, blue: 1.0),
        const Color.from(alpha: 1.0, red: 0.0, green: 0.0, blue: 0.0),
      );
      expect(result.a, 1.0);
      expect(result.r, closeTo(0.0, 0.001));
      expect(result.g, closeTo(0.0, 0.001));
      expect(result.b, closeTo(0.5, 0.001));
    });

    test('result is always fully opaque', () {
      final result = A11yUtils.compositeColor(
        const Color.from(alpha: 0.3, red: 0.2, green: 0.8, blue: 0.4),
        const Color.from(alpha: 1.0, red: 0.9, green: 0.1, blue: 0.5),
      );
      expect(result.a, 1.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ensureTouchTarget
  // ---------------------------------------------------------------------------

  group('A11yUtils.ensureTouchTarget', () {
    testWidgets('wraps child in SizedBox with default 48x48', (tester) async {
      final key = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.ensureTouchTarget(
              child: SizedBox(key: key, width: 20, height: 20),
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 48.0);
      expect(sizedBox.height, 48.0);
    });

    testWidgets('uses custom minSize', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.ensureTouchTarget(
              minSize: 56.0,
              child: const SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 56.0);
      expect(sizedBox.height, 56.0);
    });

    testWidgets('centers the child within the box', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.ensureTouchTarget(
              child: const Text('tap'),
            ),
          ),
        ),
      );

      // The widget tree should have a Center between SizedBox and child.
      expect(find.byType(Center), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // ensureMinTouchSize
  // ---------------------------------------------------------------------------

  group('A11yUtils.ensureMinTouchSize', () {
    testWidgets('wraps child in ConstrainedBox with minWidth and minHeight',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.ensureMinTouchSize(
              child: const SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );

      final constrainedBox =
          tester.widget<ConstrainedBox>(find.byType(ConstrainedBox));
      final constraints = constrainedBox.constraints;
      expect(constraints.minWidth, 48.0);
      expect(constraints.minHeight, 48.0);
    });

    testWidgets('uses custom minSize', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.ensureMinTouchSize(
              minSize: 64.0,
              child: const SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );

      final constrainedBox =
          tester.widget<ConstrainedBox>(find.byType(ConstrainedBox));
      expect(constrainedBox.constraints.minWidth, 64.0);
      expect(constrainedBox.constraints.minHeight, 64.0);
    });

    testWidgets('centers the child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.ensureMinTouchSize(
              child: const Text('tap'),
            ),
          ),
        ),
      );

      expect(find.byType(Center), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // touchTarget (alias)
  // ---------------------------------------------------------------------------

  group('A11yUtils.touchTarget', () {
    testWidgets('behaves identically to ensureTouchTarget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.touchTarget(
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 48.0);
      expect(sizedBox.height, 48.0);
    });
  });

  // ---------------------------------------------------------------------------
  // labeledButton
  // ---------------------------------------------------------------------------

  group('A11yUtils.labeledButton', () {
    testWidgets('wraps child with Semantics button=true and correct label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.labeledButton(
              label: 'Delete note',
              child: const Icon(Icons.delete),
            ),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.label, 'Delete note');
    });
  });

  // ---------------------------------------------------------------------------
  // labeledIcon
  // ---------------------------------------------------------------------------

  group('A11yUtils.labeledIcon', () {
    testWidgets('wraps child with Semantics and correct label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.labeledIcon(
              label: 'Sync status',
              child: const Icon(Icons.cloud_done),
            ),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.label, 'Sync status');
    });
  });

  // ---------------------------------------------------------------------------
  // labeledTextField
  // ---------------------------------------------------------------------------

  group('A11yUtils.labeledTextField', () {
    testWidgets('wraps child with Semantics textField=true and label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.labeledTextField(
              label: 'Search notes',
              hint: 'Type to search',
              child: const TextField(),
            ),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.textField, isTrue);
      expect(semantics.properties.label, 'Search notes');
      expect(semantics.properties.hint, 'Type to search');
    });

    testWidgets('works without hint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.labeledTextField(
              label: 'Title',
              child: const TextField(),
            ),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.textField, isTrue);
      expect(semantics.properties.label, 'Title');
    });
  });

  // ---------------------------------------------------------------------------
  // semanticCard
  // ---------------------------------------------------------------------------

  group('A11yUtils.semanticCard', () {
    testWidgets('wraps child with MergeSemantics and Semantics button=true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.semanticCard(
              label: 'Note: Shopping list, updated 2h ago',
              child: const Text('Shopping list'),
            ),
          ),
        ),
      );

      expect(find.byType(MergeSemantics), findsOneWidget);
      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.label, 'Note: Shopping list, updated 2h ago');
    });

    testWidgets('sets button=false when isButton is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.semanticCard(
              label: 'Info card',
              isButton: false,
              child: const Text('Info'),
            ),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.button, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // semanticButton
  // ---------------------------------------------------------------------------

  group('A11yUtils.semanticButton', () {
    testWidgets('wraps with Semantics button=true and enabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.semanticButton(
              label: 'Create note',
              onTap: () => tapped = true,
              child: const Text('Create'),
            ),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.enabled, isTrue);
      expect(semantics.properties.label, 'Create note');

      // Tap the gesture detector.
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('disables tap when enabled=false', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A11yUtils.semanticButton(
              label: 'Disabled action',
              enabled: false,
              onTap: () => tapped = true,
              child: const Text('Disabled'),
            ),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.enabled, isFalse);

      // GestureDetector.onTap should be null when disabled, so tapping does nothing.
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // focusBorderDecoration
  // ---------------------------------------------------------------------------

  group('A11yUtils.focusBorderDecoration', () {
    test('returns InputDecoration with labelText and hintText', () {
      final decoration = A11yUtils.focusBorderDecoration(
        labelText: 'Title',
        hintText: 'Enter title',
      );
      expect(decoration.labelText, 'Title');
      expect(decoration.hintText, 'Enter title');
    });

    test('sets filled to true', () {
      final decoration = A11yUtils.focusBorderDecoration();
      expect(decoration.filled, isTrue);
    });

    test('uses default focus color when none provided', () {
      // Verify the method does not throw and returns a valid decoration.
      final decoration = A11yUtils.focusBorderDecoration();
      expect(decoration.focusedBorder, isA<OutlineInputBorder>());
    });

    test('uses provided focusColor in focused border', () {
      const customColor = Color(0xFF00FF00);
      final decoration = A11yUtils.focusBorderDecoration(
        focusColor: customColor,
      );
      final focusedBorder =
          decoration.focusedBorder as OutlineInputBorder;
      final borderSide = focusedBorder.borderSide;
      expect(borderSide.color, customColor);
      expect(borderSide.width, 2.0);
    });

    test('includes prefixIcon when provided', () {
      final icon = const Icon(Icons.search);
      final decoration = A11yUtils.focusBorderDecoration(
        prefixIcon: icon,
      );
      expect(decoration.prefixIcon, icon);
    });
  });
}
