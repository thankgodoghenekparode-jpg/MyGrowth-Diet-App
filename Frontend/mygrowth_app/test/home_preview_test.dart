import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygrowth_app/core/auth/auth_controller.dart';
import 'package:mygrowth_app/core/models/activity_models.dart';
import 'package:mygrowth_app/core/models/app_user.dart';
import 'package:mygrowth_app/core/network/api_client.dart';
import 'package:mygrowth_app/core/theme/app_theme.dart';
import 'package:mygrowth_app/features/more/member_home_screen.dart';
import 'package:mygrowth_app/features/progress/progress_providers.dart';

void main() {
  testWidgets('home screen lays out its content below the brand banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            const AppUser(
              id: 'u1',
              name: 'Grace Member',
              email: 'grace@example.com',
              role: 'MEMBER',
              status: 'ACTIVE',
            ),
          ),
          progressSummaryProvider.overrideWith(
            (ref) async => const ProgressSummary(
              totalActivities: 10,
              completedActivities: 4,
            ),
          ),
          apiClientProvider.overrideWithValue(
            ApiClient(baseUrl: 'https://example.com/api/v1'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: MemberHomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // A regression guard: the banner used to be laid out with an infinite
    // height, which pushed every other home element off-screen.
    expect(tester.takeException(), isNull);
    expect(find.text("Today's Activities"), findsOneWidget);
    expect(find.text('Your Growth Progress'), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);

    final activities = tester.getTopLeft(find.text("Today's Activities"));
    expect(activities.dy, lessThan(900));
  });
}
