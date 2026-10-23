import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/pagination.dart';
import '../../core/widgets/section_header.dart';
import 'admin_member_model.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Admin member directory with server-side search, status/role filters and
/// pagination (`GET /admin/users`).
class AdminMembersScreen extends ConsumerWidget {
  const AdminMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MembersBody();
  }
}

class _MembersBody extends ConsumerStatefulWidget {
  const _MembersBody();

  @override
  ConsumerState<_MembersBody> createState() => _MembersBodyState();
}

class _MembersBodyState extends ConsumerState<_MembersBody> {
  int _page = 1;
  String _search = '';
  String _status = '';
  String _role = '';

  void _setFilter(void Function() apply) {
    setState(() {
      apply();
      _page = 1;
    });
  }

  DropdownMenuItem<String> _item(String value, String label) =>
      DropdownMenuItem<String>(value: value, child: Text(label));

  @override
  Widget build(BuildContext context) {
    final query = (
      page: _page,
      search: _search,
      status: _status,
      role: _role,
    );
    final result = ref.watch(adminMembersProvider(query));
    final compact = Breakpoints.isCompact(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminMembersProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          SectionHeader(
            title: 'Members',
            subtitle: 'Search, review and support ministry members',
            icon: Icons.people_outlined,
          ),

          // ---------------------------------------------------- filters
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSearchField(
                  hint: 'Name or email…',
                  onChanged: (value) =>
                      _setFilter(() => _search = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SizedBox(
                      width: compact ? double.infinity : 220,
                      child: AppDropdown<String>(
                        label: 'Status',
                        value: _status,
                        items: [
                          _item('', 'All statuses'),
                          _item('PENDING', 'Pending approval'),
                          _item('ACTIVE', 'Active'),
                          _item('SUSPENDED', 'Suspended'),
                        ],
                        onChanged: (value) =>
                            _setFilter(() => _status = value ?? ''),
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 220,
                      child: AppDropdown<String>(
                        label: 'Role',
                        value: _role,
                        items: [
                          _item('', 'All roles'),
                          _item('MEMBER', 'Member'),
                          _item('ADMIN', 'Admin'),
                          _item('MAIN_ADMIN', 'Main Admin'),
                        ],
                        onChanged: (value) =>
                            _setFilter(() => _role = value ?? ''),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ------------------------------------------------------ list
          result.when(
            loading: () => const CardListSkeleton(count: 5),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminMembersProvider(query)),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No members found',
                    message: _search.isEmpty && _status.isEmpty && _role.isEmpty
                        ? 'Members will appear here once they register.'
                        : 'No members match the current search and filters.',
                    actionLabel: _search.isEmpty &&
                            _status.isEmpty &&
                            _role.isEmpty
                        ? 'Refresh'
                        : 'Clear filters',
                    onAction: () {
                      setState(() {
                        _search = '';
                        _status = '';
                        _role = '';
                        _page = 1;
                      });
                      ref.invalidate(adminMembersProvider(query));
                    },
                  ),
                );
              }
              return Column(
                children: [
                  for (final member in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _MemberCard(
                        member: member,
                        onTap: () => context.go('/admin/members/${member.id}'),
                      ),
                    ),
                  PaginationFooter(
                    page: page.page,
                    totalPages: page.totalPages,
                    totalItems: page.total,
                    onPrevious: () => setState(() => _page -= 1),
                    onNext: () => setState(() => _page += 1),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});

  final AdminMember member;
  final VoidCallback onTap;

  AppBadgeTone get _roleTone => switch (member.role) {
        'MAIN_ADMIN' => AppBadgeTone.navy,
        'ADMIN' => AppBadgeTone.gold,
        _ => AppBadgeTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: member.name),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name.isEmpty ? 'Unnamed member' : member.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    StatusBadge(
                      label: humanizeStatus(member.status),
                      tone: badgeToneFor(member.status),
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: member.roleLabel,
                      tone: _roleTone,
                      small: true,
                    ),
                    Text(
                      'Joined ${fmtDate(member.createdAt)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}
