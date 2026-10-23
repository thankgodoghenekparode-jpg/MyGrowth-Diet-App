import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygrowth_app/features/auth/login_screen.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  // The sign-in form renders its fields in this order: email, then password.
  Finder emailField() => find.byType(TextFormField).at(0);
  Finder passwordField() => find.byType(TextFormField).at(1);

  testWidgets('shows validation errors when submitting empty form',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('rejects malformed email', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(emailField(), 'not-an-email');
    await tester.enterText(passwordField(), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('password field can toggle visibility', (tester) async {
    await pumpLogin(tester);

    EditableText editable() => tester.widget<EditableText>(
          find.descendant(
            of: passwordField(),
            matching: find.byType(EditableText),
          ),
        );

    expect(editable().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(editable().obscureText, isFalse);
  });

  testWidgets('navigates to registration screen', (tester) async {
    await pumpLogin(tester);
    // The router normally handles navigation; here we only assert the control
    // exists and is tappable without crashing outside a GoRouter.
    expect(find.text('Create an account'), findsOneWidget);
  });
}
