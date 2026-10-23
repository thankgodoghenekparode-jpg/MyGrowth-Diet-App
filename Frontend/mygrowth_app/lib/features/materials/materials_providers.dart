import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/material_models.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/pagination.dart';

/// Search / filter / sort state for the Study Materials library.
class MaterialsFilters {
  const MaterialsFilters({
    this.search = '',
    this.category,
    this.month,
    this.sort = 'newest',
    this.page = 1,
  });

  final String search;
  final String? category;
  final int? month;
  final String sort; // newest | title
  final int page;

  MaterialsFilters copyWith({
    String? search,
    bool clearCategory = false,
    String? category,
    bool clearMonth = false,
    int? month,
    String? sort,
    int? page,
  }) {
    return MaterialsFilters(
      search: search ?? this.search,
      category: clearCategory ? null : (category ?? this.category),
      month: clearMonth ? null : (month ?? this.month),
      sort: sort ?? this.sort,
      page: page ?? this.page,
    );
  }
}

class MaterialsFiltersNotifier extends Notifier<MaterialsFilters> {
  @override
  MaterialsFilters build() => const MaterialsFilters();

  void setSearch(String value) =>
      state = state.copyWith(search: value, page: 1);

  void setCategory(String? value) => value == null
      ? state = state.copyWith(clearCategory: true, page: 1)
      : state = state.copyWith(category: value, page: 1);

  void setMonth(int? value) => value == null
      ? state = state.copyWith(clearMonth: true, page: 1)
      : state = state.copyWith(month: value, page: 1);

  void setSort(String value) => state = state.copyWith(sort: value, page: 1);

  void goToPage(int page) => state = state.copyWith(page: page);

  void reset() => state = const MaterialsFilters();
}

final materialsFiltersProvider =
    NotifierProvider<MaterialsFiltersNotifier, MaterialsFilters>(
  MaterialsFiltersNotifier.new,
);

/// Sensible default categories; the UI also surfaces any extra categories
/// the API returns on the current page.
const defaultMaterialCategories = <String>[
  'PDF',
  'AUDIO',
  'VIDEO',
  'STUDY_NOTES',
  'LITERATURE',
  'PRAYER_GUIDE',
  'SCRIPTURE_LINK',
  'CONFESSION',
  'OTHER',
];

/// The library page. [saved] is true for the "My Reading List" tab.
final materialsListProvider = FutureProvider.autoDispose
    .family<PagedResult<MaterialItem>, bool>(
  (ref, saved) async {
    final filters = ref.watch(materialsFiltersProvider);
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/materials', query: {
      'page': '${filters.page}',
      'pageSize': '20',
      if (filters.search.trim().isNotEmpty)
        'search': filters.search.trim(),
      if (filters.category != null) 'category': filters.category!,
      if (filters.month != null) 'month': '${filters.month}',
      'sort': filters.sort,
      if (saved) 'saved': 'true',
    });
    return _parsePaged(data);
  },
);

/// A single material for the detail screen.
final materialDetailProvider =
    FutureProvider.autoDispose.family<MaterialItem?, String>(
  (ref, id) async {
    final client = ref.watch(apiClientProvider);
    final data = await client.get('/materials/$id');
    if (data is Map<String, dynamic>) return MaterialItem.fromJson(data);
    return null;
  },
);

/// Tolerant parser: the envelope may arrive intact or already unwrapped to
/// a bare list by [ApiClient].
PagedResult<MaterialItem> _parsePaged(dynamic data) {
  if (data is List) {
    return PagedResult.fromList(data, MaterialItem.fromJson);
  }
  if (data is Map<String, dynamic>) {
    return PagedResult.fromJson(data, MaterialItem.fromJson);
  }
  return const PagedResult(
    items: [],
    page: 1,
    pageSize: 0,
    total: 0,
    totalPages: 1,
  );
}
