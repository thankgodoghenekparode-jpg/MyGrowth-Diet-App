import 'package:flutter/material.dart';

import '../../core/widgets/app_back_button.dart';
import 'notification_prefs_section.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(),
      title: const Text('Daily Reminders'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          'Choose when you would like a gentle reminder to read your devotion and follow your daily plan.',
        ),
        SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: NotificationPrefsSection(),
          ),
        ),
      ],
    ),
  );
}
