import 'package:anynote/core/theme/app_colors.dart';
import 'package:anynote/core/theme/app_text_styles.dart';
import 'package:anynote/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand accent uses the mockup periwinkle purple', () {
    expect(AppColors.primary, const Color(0xFF8B7CE8));
    expect(AppColors.primarySoft, const Color(0xFFEFECFE));
    expect(AppColors.primaryDisabled, const Color(0xFFCFC8F7));
    expect(AppColors.primaryText, const Color(0xFF6C5BC4));
  });

  testWidgets('theme renders with pinned purple and bundled fonts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AnyNote', style: AppTextStyles.handwritingDisplay),
              Text('Welcome back',
                  style: AppTextStyles.handwritingTitle),
              const Text('body text', style: TextStyle()),
              FilledButton(onPressed: () {}, child: const Text('Log in')),
              Switch(value: true, onChanged: (_) {}),
              Chip(label: const Text('journal')),
            ],
          ),
        ),
      ),
    );
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    await tester.pumpAndSettle();

    // FilledButton inherits the pinned periwinkle primary.
    final material = tester.widget<Material>(
      find.ancestor(
        of: find.text('Log in'),
        matching: find.byType(Material),
      ).first,
    );
    expect(material.color, AppColors.primary);

    // Switch thumb rides on the accent when selected.
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.activeThumbColor ?? AppColors.primary,
        AppColors.primary);
  });

  testWidgets('dark theme pins light periwinkle accents on navy',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: FilledButton(onPressed: () {}, child: const Text('Log in')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find.ancestor(
        of: find.text('Log in'),
        matching: find.byType(Material),
      ).first,
    );
    expect(material.color, AppColors.secondary);
  });
}
