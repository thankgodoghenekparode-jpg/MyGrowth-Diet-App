import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/daily_diet_models.dart';
import 'daily_diet_providers.dart';

class DailyDevotionScreen extends ConsumerWidget {
  const DailyDevotionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = dailyDietDateISO(DateTime.now());
    final daily = ref.watch(dailyDietProvider(date));
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Devotion')),
      body: daily.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load today’s devotion. $error')),
        data: (bundle) {
          final devotionalSections = bundle.sections.where((section) {
            final key = '${section.key} ${section.label}'.toLowerCase();
            return section.behaviour == DailyDietBehaviour.text ||
                key.contains('read') ||
                key.contains('bible') ||
                key.contains('devotion') ||
                key.contains('study');
          }).toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'A moment to grow each day',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                bundle.programme?.title ?? 'Today · ${bundle.date}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              if (devotionalSections.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_stories_outlined, size: 32),
                        const SizedBox(height: 12),
                        const Text(
                          'No devotion has been posted for today yet.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/diet'),
                          icon: const Icon(Icons.today_outlined),
                          label: const Text('Open Daily Diet'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...devotionalSections.map(
                  (section) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(section.content?.title ?? section.label),
                      subtitle: Text(
                        [
                          if (section.content?.reading case final String reading
                              when reading.isNotEmpty)
                            reading,
                          if (section.content?.hasBody ?? false)
                            section.content!.body!,
                          if (section.content?.topic case final String topic
                              when topic.isNotEmpty)
                            topic,
                          if (section.content?.teachings.isNotEmpty ?? false)
                            section.content!.teachings.join('\n'),
                          if (section.content == null &&
                              section.description != null)
                            section.description!,
                        ].join('\n\n'),
                      ),
                      isThreeLine: true,
                      trailing: Icon(
                        section.isCompleted
                            ? Icons.check_circle
                            : Icons.chevron_right,
                      ),
                      onTap: () => context.push(
                        '/daily-diet/section/${section.id}?date=$date',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.go('/diet'),
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('View the full daily plan'),
              ),
            ],
          );
        },
      ),
    );
  }
}
