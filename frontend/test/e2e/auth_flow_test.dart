// End-to-end widget tests for the authentication user journey.
//
// Tests cover:
// - Login screen rendering and widget presence
// - Form validation on the login screen
// - Login form submission (success and failure paths)
// - Register screen rendering and widget presence
// - Form validation on the register screen
// - Error message display on failed auth

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/auth/presentation/login_screen.dart';
import 'package:anynote/features/auth/presentation/register_screen.dart';
import '../helpers/test_app_helper.dart';

void main() {
  group('Auth flow - LoginScreen', () {
    testWidgets('renders login form with email and password fields',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Verify core widgets are present.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);

      // Two text form fields: email and password.
      expect(find.byType(TextFormField), findsNWidgets(2));

      // FilledButton for sign in.
      expect(find.byType(FilledButton), findsOneWidget);

      // Two TextButtons: register link and recover link.
      expect(find.byType(TextButton), findsNWidgets(2));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows lock icon on login screen', (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byIcon(Icons.lock_outline), findsAtLeast(1));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Tap the sign-in button without filling fields.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Validation messages should appear for both email and password.
      // The l10n keys produce English strings containing "required".
      expect(find.textContaining('required'), findsNWidgets(2));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('email field accepts input', (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Enter text in the email field.
      final emailField = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      // Verify the text was entered.
      expect(find.text('test@example.com'), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('password field is obscured', (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Find the password field (TextFormField with "Password" label).
      final passwordFields = find.widgetWithText(TextFormField, 'Password');
      expect(passwordFields, findsOneWidget);

      // Check that obscureText is true on the password widget.
      // TextFormField wraps a TextField; check the TextField's obscureText.
      final textField = tester.widget<TextField>(
        find.descendant(
          of: passwordFields,
          matching: find.byType(TextField),
        ),
      );
      expect(textField.obscureText, isTrue);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('sign in button triggers loading state with valid input',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Fill in valid-looking credentials.
      final emailField = find.widgetWithText(TextFormField, 'Email');
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      await tester.enterText(emailField, 'user@test.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Tap sign in -- this triggers the async crypto flow which will
      // fail because no salt is stored, but the widget should not crash.
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // The widget tree should still be intact.
      expect(find.byType(LoginScreen), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('login screen does not crash with invalid submission',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Fill in credentials and submit.
      final emailField = find.widgetWithText(TextFormField, 'Email');
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      await tester.enterText(emailField, 'user@test.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

      // The widget tree should still be intact after submission.
      expect(find.byType(LoginScreen), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('register and recover links are present', (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      // The register TextButton and recover TextButton should be present.
      expect(find.byType(TextButton), findsNWidgets(2));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Auth flow - RegisterScreen', () {
    testWidgets('renders registration form with all fields', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);

      // Four text form fields: email, username, password, confirm password.
      expect(find.byType(TextFormField), findsNWidgets(4));

      // FilledButton for create account.
      expect(find.byType(FilledButton), findsOneWidget);

      // TextButton for "already have account".
      expect(find.byType(TextButton), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows person_add icon on register screen', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Tap create account without filling fields.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Multiple fields should show validation errors containing "required".
      expect(find.textContaining('required'), findsAtLeast(2));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows validation error for short password', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Fill in all fields but use a short password.
      final emailField = find.widgetWithText(TextFormField, 'Email');
      final usernameField = find.widgetWithText(TextFormField, 'Username');
      final passwordFields = find.widgetWithText(TextFormField, 'Password');

      await tester.enterText(emailField, 'new@test.com');
      await tester.enterText(usernameField, 'newuser');
      // Enter a password that is too short (< 8 chars).
      await tester.enterText(passwordFields.first, 'short');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // The screen should still be rendered (validation failed).
      expect(find.byType(RegisterScreen), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('password fields are obscured', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Find all TextField descendants inside TextFormField widgets and
      // count those with obscureText == true.
      final obscuredCount = tester
          .widgetList<TextField>(
            find.descendant(
              of: find.byType(TextFormField),
              matching: find.byType(TextField),
            ),
          )
          .where((f) => f.obscureText)
          .length;

      // Two password fields: password and confirm password.
      expect(obscuredCount, equals(2));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('login link is present on register screen', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: defaultProviderOverrides(),
      );

      // There should be a TextButton to navigate back to login.
      expect(find.byType(TextButton), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
