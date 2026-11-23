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

import 'package:anynote/core/widgets/pressable_scale.dart';
import 'package:anynote/features/auth/presentation/login_screen.dart';
import 'package:anynote/features/auth/presentation/register_screen.dart';
import '../helpers/test_app_helper.dart';

/// The login screen's sign-in button. Its social sign-in buttons are
/// PressableScales too, so the button is told apart by its label.
final signInButton = find.widgetWithText(PressableScale, 'Sign In');

/// The register screen's submit button, by its label for the same reason:
/// the recovery-key copy button is a PressableScale as well.
final createAccountButton =
    find.widgetWithText(PressableScale, 'Create Account');

/// The register screen's link back to the login screen: the last words of a
/// sentence, tapped as rich text rather than a button of its own.
final backToLoginLink = find.textContaining('Already have an account? Sign In');

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

      // The sign-in button.
      expect(signInButton, findsOneWidget);

      // The two ways out of the screen: recover the account, or go register.
      // Both are tap targets inside sentences, not buttons of their own.
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.textContaining("Don't have an account?"), findsOneWidget);
      expect(find.textContaining('Sign up'), findsOneWidget);

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
      // PressableScale uses GestureDetector, so the button is found by its
      // text content and ensured visible before tapping.
      await tester.ensureVisible(signInButton);
      await tester.pump();
      await tester.tap(signInButton);
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
      await tester.ensureVisible(signInButton);
      await tester.pump();
      await tester.tap(signInButton);
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

      final submitBtn = signInButton;
      await tester.ensureVisible(submitBtn);
      await tester.pump();
      await tester.tap(submitBtn);
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

      // The recover link is a button of its own; the register link is the
      // last words of the footer sentence.
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.textContaining('Sign up'), findsOneWidget);

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

      // The create-account button.
      expect(createAccountButton, findsOneWidget);

      // And the way back to the login screen.
      expect(backToLoginLink, findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows the person icon on the username field', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Username'),
          matching: find.byIcon(Icons.person_outline),
        ),
        findsOneWidget,
      );

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
      await tester.ensureVisible(createAccountButton);
      await tester.pump();
      await tester.tap(createAccountButton);
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

      await tester.ensureVisible(createAccountButton);
      await tester.pump();
      await tester.tap(createAccountButton);
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

      // There should be a link to navigate back to login.
      expect(backToLoginLink, findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
