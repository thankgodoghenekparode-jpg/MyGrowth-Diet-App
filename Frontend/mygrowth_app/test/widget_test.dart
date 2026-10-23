// Smoke test for the sign-in screen, the first surface a member or
// administrator sees when the app launches.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mygrowth_app/features/auth/login_screen.dart';

void main() {
  testWidgets('sign-in screen renders its primary controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}
