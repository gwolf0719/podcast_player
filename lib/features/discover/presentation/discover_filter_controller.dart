// 這個檔案負責管理探索頁的分類與排序狀態，提供 UI 取得目前條件以及更新邏輯。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 代表探索頁的排序選項，保留原始排名或改依節目名稱排序。
enum DiscoverSortOption {
  /// 依照熱門榜原始排名顯示。
  ranking,

  /// 依照節目名稱 (A-Z) 排序。
  title,
}

/// 探索頁的篩選狀態資料，包含選取的分類與排序選項。
class DiscoverFilterState {
  const DiscoverFilterState({
    this.selectedCategory,
    this.sortOption = DiscoverSortOption.ranking,
  });

  /// 使用者選取的分類標籤，null 代表顯示全部分類。
  final String? selectedCategory;

  /// 使用者選取的排序選項。
  final DiscoverSortOption sortOption;

  /// 建立新的狀態物件，並可指定更新的欄位。
  DiscoverFilterState copyWith({
    String? selectedCategory,
    DiscoverSortOption? sortOption,
    bool resetCategory = false,
  }) {
    return DiscoverFilterState(
      selectedCategory: resetCategory ? null : (selectedCategory ?? this.selectedCategory),
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

/// 提供探索頁面使用的狀態控制器，負責更新分類與排序條件。
final discoverFilterControllerProvider =
    StateNotifierProvider<DiscoverFilterController, DiscoverFilterState>((ref) {
  return DiscoverFilterController();
}, name: 'discoverFilterControllerProvider');

/// 探索頁的分類與排序控制器，透過 Riverpod StateNotifier 封裝狀態更新。
class DiscoverFilterController extends StateNotifier<DiscoverFilterState> {
  DiscoverFilterController() : super(const DiscoverFilterState());

  /// 更新選取的分類，傳入 null 代表顯示全部分類。
  void updateCategory(String? category) {
    state = state.copyWith(selectedCategory: category, resetCategory: category == null);
  }

  /// 切換排序條件。
  void updateSortOption(DiscoverSortOption option) {
    state = state.copyWith(sortOption: option);
  }

  /// 重設所有篩選條件為預設值。
  void reset() {
    state = const DiscoverFilterState();
  }
}
