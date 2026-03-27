import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/favorite_category.dart';
import '../models/favorite_item.dart';
import '../models/thought_note.dart';
import '../services/app_database.dart';
import '../widgets/category_manager_sheet.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/record_grid_card.dart';
import '../widgets/reveal_motion.dart';
import 'editors/favorite_editor_page.dart';
import 'editors/thought_editor_page.dart';
import 'favorite_detail_page.dart';
import 'thought_detail_page.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.refreshSeed});

  final int refreshSeed;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

enum _ThoughtSort { newest, oldest }

enum _FavoriteSort { newest, oldest }

class _RecordsPageState extends State<RecordsPage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 10;

  final AppDatabase _database = AppDatabase.instance;
  final ScrollController _thoughtScrollController = ScrollController();
  final ScrollController _favoriteScrollController = ScrollController();
  final TextEditingController _thoughtSearchController = TextEditingController();
  final TextEditingController _favoriteSearchController = TextEditingController();
  final FocusNode _thoughtSearchFocusNode = FocusNode();
  final FocusNode _favoriteSearchFocusNode = FocusNode();

  late final TabController _tabController;

  List<FavoriteCategory> _categories = <FavoriteCategory>[];
  List<ThoughtNote> _thoughts = <ThoughtNote>[];
  List<FavoriteItem> _favorites = <FavoriteItem>[];

  String? _selectedThoughtCategory;
  String? _selectedFavoriteCategory;
  String _thoughtQuery = '';
  String _favoriteQuery = '';
  bool _thoughtSearchActive = false;
  bool _favoriteSearchActive = false;
  bool _thoughtOnlyWithImages = false;
  bool _favoriteOnlyWithImages = false;
  _ThoughtSort _thoughtSort = _ThoughtSort.newest;
  _FavoriteSort _favoriteSort = _FavoriteSort.newest;
  int _visibleThoughtCount = _pageSize;
  int _visibleFavoriteCount = _pageSize;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _thoughtScrollController.addListener(_handleThoughtScroll);
    _favoriteScrollController.addListener(_handleFavoriteScroll);
    _thoughtSearchFocusNode.addListener(_handleThoughtFocusChanged);
    _favoriteSearchFocusNode.addListener(_handleFavoriteFocusChanged);
    _loadData(resetVisibleCounts: true);
  }

  @override
  void didUpdateWidget(covariant RecordsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _loadData(resetVisibleCounts: true);
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _thoughtScrollController
      ..removeListener(_handleThoughtScroll)
      ..dispose();
    _favoriteScrollController
      ..removeListener(_handleFavoriteScroll)
      ..dispose();
    _thoughtSearchController.dispose();
    _favoriteSearchController.dispose();
    _thoughtSearchFocusNode
      ..removeListener(_handleThoughtFocusChanged)
      ..dispose();
    _favoriteSearchFocusNode
      ..removeListener(_handleFavoriteFocusChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadData({bool resetVisibleCounts = false}) async {
    final categories = await _database.getFavoriteCategories();
    final thoughts = await _database.getThoughts();
    final favorites = await _database.getFavorites();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
      _thoughts = thoughts;
      _favorites = favorites;
      _selectedThoughtCategory = _normalizeSelectedCategory(
        _selectedThoughtCategory,
      );
      _selectedFavoriteCategory = _normalizeSelectedCategory(
        _selectedFavoriteCategory,
      );
      _visibleThoughtCount = _normalizeVisibleCount(
        resetVisibleCounts ? _pageSize : _visibleThoughtCount,
        thoughts.length,
      );
      _visibleFavoriteCount = _normalizeVisibleCount(
        resetVisibleCounts ? _pageSize : _visibleFavoriteCount,
        favorites.length,
      );
      _isLoading = false;
    });
  }

  int _normalizeVisibleCount(int requested, int total) {
    if (total <= 0) {
      return 0;
    }
    return requested.clamp(1, total);
  }

  String? _normalizeSelectedCategory(String? value) {
    if (value == null) {
      return null;
    }
    final exists = _categories.any(
      (FavoriteCategory item) => item.name == value,
    );
    return exists ? value : null;
  }

  void _handleTabChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    if (_tabController.indexIsChanging) {
      return;
    }
    if (_isThoughtTab && _thoughtSearchActive) {
      _revealSearchPanel(isThought: true);
    }
    if (!_isThoughtTab && _favoriteSearchActive) {
      _revealSearchPanel(isThought: false);
    }
  }

  void _handleThoughtScroll() {
    _loadMoreIfNeeded(isThought: true);
  }

  void _handleFavoriteScroll() {
    _loadMoreIfNeeded(isThought: false);
  }

  void _handleThoughtFocusChanged() {
    if (_thoughtSearchFocusNode.hasFocus) {
      _scrollFiltersIntoView(isThought: true);
    }
  }

  void _handleFavoriteFocusChanged() {
    if (_favoriteSearchFocusNode.hasFocus) {
      _scrollFiltersIntoView(isThought: false);
    }
  }

  bool get _isThoughtTab => _tabController.index == 0;

  List<String> get _categoryNames =>
      _categories.map((FavoriteCategory item) => item.name).toList();

  bool get _isCurrentSearchActive =>
      _isThoughtTab ? _thoughtSearchActive : _favoriteSearchActive;

  Future<void> _manageCategories() async {
    await openCategoryManagerPage(context, database: _database);
    await _loadData(resetVisibleCounts: true);
  }

  void _toggleSearchPanel() {
    if (_isThoughtTab) {
      final nextValue = !_thoughtSearchActive;
      setState(() {
        _thoughtSearchActive = nextValue;
      });
      if (nextValue) {
        _revealSearchPanel(isThought: true);
      } else {
        _thoughtSearchFocusNode.unfocus();
      }
      return;
    }

    final nextValue = !_favoriteSearchActive;
    setState(() {
      _favoriteSearchActive = nextValue;
    });
    if (nextValue) {
      _revealSearchPanel(isThought: false);
    } else {
      _favoriteSearchFocusNode.unfocus();
    }
  }

  void _revealSearchPanel({required bool isThought}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFiltersIntoView(isThought: isThought);
      final focusNode = isThought
          ? _thoughtSearchFocusNode
          : _favoriteSearchFocusNode;
      focusNode.requestFocus();
    });
  }

  Future<void> _scrollFiltersIntoView({required bool isThought}) async {
    final controller = isThought
        ? _thoughtScrollController
        : _favoriteScrollController;
    if (!controller.hasClients) {
      return;
    }
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _loadMoreIfNeeded({required bool isThought}) {
    final controller = isThought
        ? _thoughtScrollController
        : _favoriteScrollController;
    if (!controller.hasClients) {
      return;
    }
    final position = controller.position;
    if (position.pixels < position.maxScrollExtent - 240) {
      return;
    }
    final totalCount = isThought
        ? _buildVisibleThoughts().length
        : _buildVisibleFavorites().length;
    setState(() {
      if (isThought) {
        _visibleThoughtCount = math.min(
          totalCount,
          _visibleThoughtCount + _pageSize,
        );
      } else {
        _visibleFavoriteCount = math.min(
          totalCount,
          _visibleFavoriteCount + _pageSize,
        );
      }
    });
  }

  Future<void> _openThoughtEditor([ThoughtNote? note]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ThoughtEditorPage(note: note),
      ),
    );
    await _loadData(resetVisibleCounts: true);
  }

  Future<void> _openFavoriteEditor([FavoriteItem? item]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FavoriteEditorPage(item: item),
      ),
    );
    await _loadData(resetVisibleCounts: true);
  }

  Future<void> _openThoughtDetail(ThoughtNote note) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ThoughtDetailPage(thoughtId: note.id),
      ),
    );
    await _loadData(resetVisibleCounts: true);
  }

  Future<void> _openFavoriteDetail(FavoriteItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            FavoriteDetailPage(favoriteId: item.id),
      ),
    );
    await _loadData(resetVisibleCounts: true);
  }

  void _resetThoughtFilters() {
    _thoughtSearchController.clear();
    setState(() {
      _thoughtQuery = '';
      _selectedThoughtCategory = null;
      _thoughtSearchActive = false;
      _thoughtOnlyWithImages = false;
      _thoughtSort = _ThoughtSort.newest;
      _visibleThoughtCount = _normalizeVisibleCount(_pageSize, _thoughts.length);
    });
    _thoughtSearchFocusNode.unfocus();
  }

  void _resetFavoriteFilters() {
    _favoriteSearchController.clear();
    setState(() {
      _favoriteQuery = '';
      _selectedFavoriteCategory = null;
      _favoriteSearchActive = false;
      _favoriteOnlyWithImages = false;
      _favoriteSort = _FavoriteSort.newest;
      _visibleFavoriteCount = _normalizeVisibleCount(
        _pageSize,
        _favorites.length,
      );
    });
    _favoriteSearchFocusNode.unfocus();
  }

  List<ThoughtNote> _buildVisibleThoughts() {
    final keyword = _thoughtQuery.trim().toLowerCase();
    final filtered = _thoughts.where((ThoughtNote item) {
      if (_selectedThoughtCategory != null &&
          item.category != _selectedThoughtCategory) {
        return false;
      }
      final hasAnyImage = item.hasImages ||
          item.steps.any(
            (ThoughtStep step) => step.imagePath.trim().isNotEmpty,
          );
      if (_thoughtOnlyWithImages && !hasAnyImage) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      final stepText = item.steps
          .map(
            (ThoughtStep step) =>
                '${step.title} ${step.detail} ${step.possibleQuestion}',
          )
          .join(' ')
          .toLowerCase();
      final haystack =
          '${item.title} ${item.category} ${item.overview} $stepText'
              .toLowerCase();
      return haystack.contains(keyword);
    }).toList();

    switch (_thoughtSort) {
      case _ThoughtSort.oldest:
        filtered.sort(
          (ThoughtNote a, ThoughtNote b) => a.updatedAt.compareTo(b.updatedAt),
        );
      case _ThoughtSort.newest:
        filtered.sort(
          (ThoughtNote a, ThoughtNote b) => b.updatedAt.compareTo(a.updatedAt),
        );
    }
    return filtered;
  }

  List<FavoriteItem> _buildVisibleFavorites() {
    final keyword = _favoriteQuery.trim().toLowerCase();
    final filtered = _favorites.where((FavoriteItem item) {
      if (_selectedFavoriteCategory != null &&
          item.category != _selectedFavoriteCategory) {
        return false;
      }
      if (_favoriteOnlyWithImages && !item.hasImages) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      final haystack =
          '${item.title} ${item.category} ${item.body} ${item.note} ${item.referenceUrl}'
              .toLowerCase();
      return haystack.contains(keyword);
    }).toList();

    switch (_favoriteSort) {
      case _FavoriteSort.oldest:
        filtered.sort(
          (FavoriteItem a, FavoriteItem b) => a.updatedAt.compareTo(b.updatedAt),
        );
      case _FavoriteSort.newest:
        filtered.sort(
          (FavoriteItem a, FavoriteItem b) => b.updatedAt.compareTo(a.updatedAt),
        );
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final thoughtItems = _buildVisibleThoughts();
    final favoriteItems = _buildVisibleFavorites();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: RevealMotion(
              child: _RecordsTopBar(
                tabController: _tabController,
                onManageCategories: _manageCategories,
                onSearch: _toggleSearchPanel,
                searchActive: _isCurrentSearchActive,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      _buildThoughtsTab(thoughtItems),
                      _buildFavoritesTab(favoriteItems),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: _isThoughtTab ? 'records-thought-add' : 'records-favorite-add',
        onPressed: _isThoughtTab ? _openThoughtEditor : _openFavoriteEditor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildThoughtsTab(List<ThoughtNote> items) {
    final visibleCount = math.min(items.length, _visibleThoughtCount);
    final visibleItems = items.take(visibleCount).toList();
    return RefreshIndicator(
      onRefresh: () => _loadData(resetVisibleCounts: true),
      child: ListView(
        controller: _thoughtScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
        children: <Widget>[
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _RecordsFilterPanel(
              searchRow: _SearchFieldRow(
                controller: _thoughtSearchController,
                focusNode: _thoughtSearchFocusNode,
                hintText: '搜索标题、概述、步骤或问题提示',
                onChanged: (String value) {
                  setState(() {
                    _thoughtQuery = value;
                    _visibleThoughtCount = _normalizeVisibleCount(
                      _pageSize,
                      _thoughts.length,
                    );
                  });
                },
                onClear: () {
                  _thoughtSearchController.clear();
                  setState(() {
                    _thoughtQuery = '';
                  });
                },
                onReset: _hasActiveThoughtFilters ? _resetThoughtFilters : null,
              ),
              categoryFilters: _InlineSingleChoiceFilters(
                label: '分类',
                options: _categoryNames,
                selectedValue: _selectedThoughtCategory,
                onSelected: (String? value) {
                  setState(() {
                    _selectedThoughtCategory = value;
                    _visibleThoughtCount = _normalizeVisibleCount(
                      _pageSize,
                      _thoughts.length,
                    );
                  });
                },
                allLabel: '全部',
              ),
              actions: <Widget>[
                _InlineSingleChoiceFilters(
                  label: '排序',
                  options: _ThoughtSort.values.map(_thoughtSortLabel).toList(),
                  selectedValue: _thoughtSortLabel(_thoughtSort),
                  onSelected: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _thoughtSort =
                          value == _thoughtSortLabel(_ThoughtSort.oldest)
                          ? _ThoughtSort.oldest
                          : _ThoughtSort.newest;
                      _visibleThoughtCount = _normalizeVisibleCount(
                        _pageSize,
                        _thoughts.length,
                      );
                    });
                  },
                ),
                FilterChip(
                  label: const Text('仅看含图'),
                  selected: _thoughtOnlyWithImages,
                  showCheckmark: false,
                  onSelected: (bool value) {
                    setState(() {
                      _thoughtOnlyWithImages = value;
                      _visibleThoughtCount = _normalizeVisibleCount(
                        _pageSize,
                        _thoughts.length,
                      );
                    });
                  },
                ),
              ],
            ),
            crossFadeState: _thoughtSearchActive
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: items.isEmpty
                ? const Padding(
                    key: ValueKey<String>('records-thoughts-empty'),
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyStateView(
                      title: '还没有匹配的想法记录',
                      message: '先创建分类，再把经验整理成可回看的记录。',
                      icon: Icons.lightbulb_outline,
                    ),
                  )
                : Column(
                    key: const ValueKey<String>('records-thoughts-grid'),
                    children: <Widget>[
                      MasonryGridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleItems.length,
                        crossAxisCount: 2,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        itemBuilder: (BuildContext context, int index) {
                          final item = visibleItems[index];
                          return RevealMotion(
                            delay: Duration(milliseconds: 50 + index * 22),
                            child: RecordGridCard(
                              title: item.title,
                              category: item.category.isEmpty ? '未分类' : item.category,
                              imagePath: item.primaryImagePath,
                              placeholderIcon: Icons.route_outlined,
                              onOpen: () => _openThoughtDetail(item),
                            ),
                          );
                        },
                      ),
                      _LoadMoreHint(
                        showingCount: visibleItems.length,
                        totalCount: items.length,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab(List<FavoriteItem> items) {
    final visibleCount = math.min(items.length, _visibleFavoriteCount);
    final visibleItems = items.take(visibleCount).toList();
    return RefreshIndicator(
      onRefresh: () => _loadData(resetVisibleCounts: true),
      child: ListView(
        controller: _favoriteScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
        children: <Widget>[
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _RecordsFilterPanel(
              searchRow: _SearchFieldRow(
                controller: _favoriteSearchController,
                focusNode: _favoriteSearchFocusNode,
                hintText: '搜索标题、正文、备注或链接',
                onChanged: (String value) {
                  setState(() {
                    _favoriteQuery = value;
                    _visibleFavoriteCount = _normalizeVisibleCount(
                      _pageSize,
                      _favorites.length,
                    );
                  });
                },
                onClear: () {
                  _favoriteSearchController.clear();
                  setState(() {
                    _favoriteQuery = '';
                  });
                },
                onReset: _hasActiveFavoriteFilters
                    ? _resetFavoriteFilters
                    : null,
              ),
              categoryFilters: _InlineSingleChoiceFilters(
                label: '分类',
                options: _categoryNames,
                selectedValue: _selectedFavoriteCategory,
                onSelected: (String? value) {
                  setState(() {
                    _selectedFavoriteCategory = value;
                    _visibleFavoriteCount = _normalizeVisibleCount(
                      _pageSize,
                      _favorites.length,
                    );
                  });
                },
                allLabel: '全部',
              ),
              actions: <Widget>[
                _InlineSingleChoiceFilters(
                  label: '排序',
                  options: _FavoriteSort.values.map(_favoriteSortLabel).toList(),
                  selectedValue: _favoriteSortLabel(_favoriteSort),
                  onSelected: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _favoriteSort =
                          value == _favoriteSortLabel(_FavoriteSort.oldest)
                          ? _FavoriteSort.oldest
                          : _FavoriteSort.newest;
                      _visibleFavoriteCount = _normalizeVisibleCount(
                        _pageSize,
                        _favorites.length,
                      );
                    });
                  },
                ),
                FilterChip(
                  label: const Text('仅看含图'),
                  selected: _favoriteOnlyWithImages,
                  showCheckmark: false,
                  onSelected: (bool value) {
                    setState(() {
                      _favoriteOnlyWithImages = value;
                      _visibleFavoriteCount = _normalizeVisibleCount(
                        _pageSize,
                        _favorites.length,
                      );
                    });
                  },
                ),
              ],
            ),
            crossFadeState: _favoriteSearchActive
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: items.isEmpty
                ? const Padding(
                    key: ValueKey<String>('records-favorites-empty'),
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyStateView(
                      title: '还没有匹配的收藏内容',
                      message: '可以先整理分类，再把反复会看的内容放进来。',
                      icon: Icons.collections_bookmark_outlined,
                    ),
                  )
                : Column(
                    key: const ValueKey<String>('records-favorites-grid'),
                    children: <Widget>[
                      MasonryGridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleItems.length,
                        crossAxisCount: 2,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        itemBuilder: (BuildContext context, int index) {
                          final item = visibleItems[index];
                          return RevealMotion(
                            delay: Duration(milliseconds: 50 + index * 22),
                            child: RecordGridCard(
                              title: item.title,
                              category: item.category.isEmpty ? '未分类' : item.category,
                              imagePath: item.primaryImagePath,
                              placeholderIcon: Icons.collections_outlined,
                              onOpen: () => _openFavoriteDetail(item),
                            ),
                          );
                        },
                      ),
                      _LoadMoreHint(
                        showingCount: visibleItems.length,
                        totalCount: items.length,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveThoughtFilters {
    return _thoughtQuery.trim().isNotEmpty ||
        _selectedThoughtCategory != null ||
        _thoughtOnlyWithImages ||
        _thoughtSort != _ThoughtSort.newest;
  }

  bool get _hasActiveFavoriteFilters {
    return _favoriteQuery.trim().isNotEmpty ||
        _selectedFavoriteCategory != null ||
        _favoriteOnlyWithImages ||
        _favoriteSort != _FavoriteSort.newest;
  }

  String _thoughtSortLabel(_ThoughtSort value) {
    return switch (value) {
      _ThoughtSort.newest => '最新',
      _ThoughtSort.oldest => '最早',
    };
  }

  String _favoriteSortLabel(_FavoriteSort value) {
    return switch (value) {
      _FavoriteSort.newest => '最新',
      _FavoriteSort.oldest => '最早',
    };
  }
}

class _RecordsTopBar extends StatelessWidget {
  const _RecordsTopBar({
    required this.tabController,
    required this.onManageCategories,
    required this.onSearch,
    required this.searchActive,
  });

  final TabController tabController;
  final VoidCallback onManageCategories;
  final VoidCallback onSearch;
  final bool searchActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onManageCategories,
                  icon: const Icon(Icons.tune),
                  tooltip: '分类',
                ),
                Expanded(
                  child: TabBar(
                    controller: tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.label,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: const <Widget>[
                      Tab(text: '想法'),
                      Tab(text: '收藏'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSearch,
                  icon: Icon(
                    Icons.search,
                    color: searchActive ? colorScheme.primary : null,
                  ),
                  tooltip: '搜索',
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
      ],
    );
  }
}

class _RecordsFilterPanel extends StatelessWidget {
  const _RecordsFilterPanel({
    required this.searchRow,
    required this.categoryFilters,
    required this.actions,
  });

  final Widget searchRow;
  final Widget categoryFilters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          searchRow,
          const SizedBox(height: 10),
          categoryFilters,
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InlineSingleChoiceFilters extends StatelessWidget {
  const _InlineSingleChoiceFilters({
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.allLabel,
  });

  final String label;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String?> onSelected;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final chips = <Widget>[];
    if (allLabel != null) {
      chips.add(
        ChoiceChip(
          label: Text(allLabel!),
          selected: selectedValue == null,
          showCheckmark: false,
          onSelected: (_) => onSelected(null),
        ),
      );
    }
    for (final option in options) {
      chips.add(
        ChoiceChip(
          label: Text(option),
          selected: selectedValue == option,
          showCheckmark: false,
          onSelected: (_) => onSelected(option),
        ),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        Text('$label:', style: labelStyle),
        ...chips,
      ],
    );
  }
}

class _SearchFieldRow extends StatelessWidget {
  const _SearchFieldRow({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    required this.onReset,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 18),
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ResetFilterButton(onPressed: onReset),
      ],
    );
  }
}

class _ResetFilterButton extends StatelessWidget {
  const _ResetFilterButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.restart_alt, size: 14),
      label: const Text('重置'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _LoadMoreHint extends StatelessWidget {
  const _LoadMoreHint({
    required this.showingCount,
    required this.totalCount,
  });

  final int showingCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) {
      return const SizedBox.shrink();
    }
    final text = showingCount < totalCount
        ? '已显示 $showingCount / $totalCount，上滑继续加载'
        : '共 $totalCount 条';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}