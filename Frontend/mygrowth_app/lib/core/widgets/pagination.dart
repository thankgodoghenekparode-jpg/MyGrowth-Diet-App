import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_buttons.dart';

/// "Load more" footer for paginated server-side lists.
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    this.totalItems,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int? totalItems;

  bool get _hasPrev => page > 1 && onPrevious != null;
  bool get _hasNext => page < totalPages && onNext != null;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIconButton(
            icon: Icons.chevron_left_rounded,
            onPressed: _hasPrev ? onPrevious : null,
            tooltip: 'Previous page',
            filled: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              totalItems == null
                  ? 'Page $page of $totalPages'
                  : 'Page $page of $totalPages · $totalItems items',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          AppIconButton(
            icon: Icons.chevron_right_rounded,
            onPressed: _hasNext ? onNext : null,
            tooltip: 'Next page',
            filled: true,
          ),
        ],
      ),
    );
  }
}

/// Standard response envelope helpers.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final data = json['data'] as List<dynamic>? ?? const [];
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return PagedResult(
      items: data
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      page: (meta['page'] as num?)?.toInt() ?? 1,
      pageSize: (meta['pageSize'] as num?)?.toInt() ?? data.length,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  factory PagedResult.fromList(
    List<dynamic> list,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final items = list
        .map((e) => itemFromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return PagedResult(
      items: items,
      page: 1,
      pageSize: items.length,
      total: items.length,
      totalPages: 1,
    );
  }
}
