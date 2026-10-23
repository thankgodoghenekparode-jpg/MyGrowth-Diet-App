import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/pagination.dart';
import '../../core/widgets/toast.dart';

/// Page size used by every paginated admin list.
const int adminPageSize = 20;

/// Padding for admin screens: mobile page padding on phones, roomier on
/// wider shells.
EdgeInsets adminPadding(BuildContext context) => Breakpoints.isCompact(context)
    ? AppSpacing.pagePaddingMobile
    : const EdgeInsets.all(AppSpacing.xl);

/// Tolerant single-object parse.
Map<String, dynamic> asJsonMap(dynamic data) =>
    data is Map<String, dynamic> ? data : const {};

/// Tolerant list parse: handles both `[{...}]` and `{data:[{...}],meta:{...}}`.
List<Map<String, dynamic>> jsonMaps(dynamic data) {
  if (data is List) {
    return data.whereType<Map<String, dynamic>>().toList();
  }
  if (data is Map<String, dynamic>) {
    final items = data['data'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

/// Parses either response envelope into a [PagedResult].
PagedResult<T> pagedFrom<T>(
  dynamic data,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (data is Map<String, dynamic>) {
    return PagedResult.fromJson(data, fromJson);
  }
  if (data is List) {
    return PagedResult.fromList(data, fromJson);
  }
  return const PagedResult(
    items: [],
    page: 1,
    pageSize: 0,
    total: 0,
    totalPages: 1,
  );
}

/// Parses a list, silently skipping items that don't match the shape.
List<T> safeMapList<T>(
  dynamic data,
  T Function(Map<String, dynamic>) fromJson,
) {
  final out = <T>[];
  for (final item in jsonMaps(data)) {
    try {
      out.add(fromJson(item));
    } catch (_) {
      // Skip malformed rows rather than failing the whole list.
    }
  }
  return out;
}

/// Returns the first non-null value found among [keys].
dynamic pickKey(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null) return value;
  }
  return null;
}

/// Numeric lookup across alternative backend key names.
num? pickNum(Map<String, dynamic> map, List<String> keys) {
  final value = pickKey(map, keys);
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

/// List-of-maps lookup across alternative backend key names.
List<Map<String, dynamic>> pickMaps(Map<String, dynamic> map, List<String> keys) {
  final value = pickKey(map, keys);
  if (value is List) {
    return value.whereType<Map<String, dynamic>>().toList();
  }
  return const [];
}

/// Stringify that never throws on odd payloads.
String strOf(dynamic value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

/// Metrics show an em dash when the payload doesn't include the stat.
String statOrDash(dynamic value) {
  if (value == null) return '—';
  if (value is String && value.trim().isEmpty) return '—';
  return value.toString();
}

DateTime? dateOf(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

String fmtDate(DateTime? date) =>
    date == null ? '—' : DateFormat('d MMM yyyy').format(date);

String fmtDateTime(DateTime? date) =>
    date == null ? '—' : DateFormat('d MMM yyyy · HH:mm').format(date);

/// Accepts either a 0..1 ratio or a 0..100 percentage.
String percentText(num? value) {
  if (value == null) return '—';
  final pct = value <= 1.0 ? value * 100 : value;
  final rounded = pct == pct.roundToDouble() ? 0 : 1;
  return '${pct.toStringAsFixed(rounded)}%';
}

double percentValue(num? value) {
  if (value == null) return 0;
  final pct = value <= 1.0 ? value * 100 : value;
  return (pct / 100).clamp(0.0, 1.0);
}

String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Full month name for a 1-based month number (safe for odd input).
String monthNameOf(int month) =>
    (month >= 1 && month <= 12) ? _monthNames[month - 1] : '$month';

/// Converts `bibleReadingGuidance` → `Bible Reading Guidance`.
String humanizeKey(String key) {
  final spaced = key
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim();
  return spaced
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

const Map<String, String> _categoryLabels = {
  'prayer': 'Prayer',
  'scripture_reading': 'Scripture Reading',
  'bible_study': 'Bible Study',
  'literature_reading': 'Literature Reading',
  'proverbs_reading': 'Proverbs Reading',
  'fasting_and_prayer': 'Fasting & Prayer',
  'prayer_and_affirmations': 'Prayer & Affirmations',
  'confessions_declarations': 'Confessions & Declarations',
  'audio_message': 'Audio Message',
  'prayer_partner_session': 'Prayer Partner Session',
  'personal_reflection': 'Personal Reflection',
  'custom': 'Custom',
};

/// Label for one of the 12 standard activity category keys.
String activityCategoryLabel(String key) =>
    _categoryLabels[key] ?? humanizeStatus(key);

/// Debounced search box: fires [onChanged] ~450ms after typing stops.
class AdminSearchField extends StatefulWidget {
  const AdminSearchField({
    super.key,
    required this.onChanged,
    this.label = 'Search',
    this.hint = 'Type to search…',
  });

  final ValueChanged<String> onChanged;
  final String label;
  final String hint;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _fire([String? value]) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      widget.onChanged((value ?? _controller.text).trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: _controller,
      hint: widget.hint,
      prefixIcon: Icons.search_rounded,
      textInputAction: TextInputAction.search,
      suffix: _controller.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Clear search',
              onPressed: () {
                _controller.clear();
                _fire('');
                setState(() {});
              },
            ),
      onChanged: (_) {
        setState(() {});
        _fire();
      },
      onSubmitted: (value) {
        _debounce?.cancel();
        widget.onChanged(value.trim());
      },
    );
  }
}

enum AdminBannerTone { info, warning, navy, gold }

/// Inline banner used for privacy notes, read-only explanations, etc.
class AdminBanner extends StatelessWidget {
  const AdminBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.tone = AdminBannerTone.info,
  });

  final String text;
  final IconData icon;
  final AdminBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      AdminBannerTone.info => (AppColors.infoSurface, AppColors.info),
      AdminBannerTone.warning => (AppColors.warningSurface, AppColors.warning),
      AdminBannerTone.navy => (AppColors.navy50, AppColors.navy700),
      AdminBannerTone.gold => (AppColors.gold100, AppColors.gold600),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.controlRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive metric grid: one column on phones, more as width allows.
Widget metricGrid(BuildContext context, List<Widget> children) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 980
          ? 4
          : width >= 660
              ? 3
              : width >= 440
                  ? 2
                  : 1;
      final itemWidth =
          (width - (columns - 1) * AppSpacing.sm) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final child in children) SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

/// Circular initials avatar used across admin member and report views.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.navy100,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(
        initialsFor(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.navy800,
        ),
      ),
    );
  }
}

/// A full-height sheet (dialog on wide screens) containing [child].
Future<void> showAdminSheet({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (Breakpoints.isExpanded(context)) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(child: builder(dialogContext)),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
          ),
          child: builder(sheetContext),
        ),
      ),
    ),
  );
}

/// Bottom sheet with copyable text — honest label, no fake file downloads.
Future<void> showCopyableSheet(
  BuildContext context, {
  required String title,
  required String body,
  String note =
      'This is exactly what the server returned. Copy it into a spreadsheet '
      'or document — the app can’t save files directly from the browser yet.',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              AppIconButton(
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(note, style: Theme.of(sheetContext).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Container(
            constraints: const BoxConstraints(maxHeight: 340),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppSpacing.controlRadius,
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                body,
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Copy report summary',
            icon: Icons.copy_rounded,
            expand: true,
            variant: AppButtonVariant.outlined,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: body));
              if (sheetContext.mounted) {
                Toast.success(sheetContext, 'Copied to clipboard.');
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// Renders an arbitrary JSON payload as readable, indented text.
String formatJsonCopyable(dynamic data, {String indent = ''}) {
  if (data is Map) {
    if (data.isEmpty) return '$indent(empty)';
    final buffer = StringBuffer();
    data.forEach((key, value) {
      if (value is Map || value is List) {
        buffer.writeln('$indent$key:');
        buffer.write(formatJsonCopyable(value, indent: '$indent  '));
      } else {
        buffer.writeln('$indent$key: ${strOf(value, '—')}');
      }
    });
    return buffer.toString();
  }
  if (data is List) {
    if (data.isEmpty) return '$indent(none)';
    final buffer = StringBuffer();
    for (var i = 0; i < data.length; i++) {
      final element = data[i];
      if (element is Map || element is List) {
        buffer.writeln('$indent[${i + 1}]');
        buffer.write(formatJsonCopyable(element, indent: '$indent  '));
      } else {
        buffer.writeln('$indent- ${strOf(element, '—')}');
      }
    }
    return buffer.toString();
  }
  return '$indent${strOf(data, '—')}\n';
}
