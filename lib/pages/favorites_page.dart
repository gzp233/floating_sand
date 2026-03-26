import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/favorite_category.dart';
import '../models/favorite_item.dart';
import '../services/app_database.dart';
import '../services/managed_image_service.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/horizontal_choice_filters.dart';
import '../widgets/page_header.dart';
import '../widgets/reveal_motion.dart';
import '../widgets/section_card.dart';
import '../widgets/tappable_image.dart';
import 'favorite_detail_page.dart';
import 'editors/favorite_editor_page.dart';

/// 收藏页，按双列瀑布流展示图文收藏。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, required this.refreshSeed});

  final int refreshSeed;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<FavoriteItem> _items = <FavoriteItem>[];
  List<FavoriteCategory> _categories = <FavoriteCategory>[];
  String? _selectedCategory;
  _FavoriteSort _sort = _FavoriteSort.newest;
  bool _onlyWithImages = false;
  bool _showFilters = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didUpdateWidget(covariant FavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _loadFavorites();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _database.getFavorites();
    final categories = await _database.getFavoriteCategories();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = favorites;
      _categories = categories;
      if (_selectedCategory != null &&
          !_categories.any(
            (FavoriteCategory item) => item.name == _selectedCategory,
          )) {
        _selectedCategory = null;
      }
      _isLoading = false;
    });
  }

  Future<void> _openEditor([FavoriteItem? item]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FavoriteEditorPage(item: item),
      ),
    );
    await _loadFavorites();
  }

  Future<void> _openDetail(FavoriteItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            FavoriteDetailPage(favoriteId: item.id),
      ),
    );
    await _loadFavorites();
  }

  Future<void> _deleteItem(FavoriteItem item) async {
    await _database.deleteFavorite(item.id);
    if (item.localImagePath.isNotEmpty) {
      await _imageService.deleteIfExists(item.localImagePath);
    }
    await _loadFavorites();
  }

  Future<void> _manageCategories() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 28,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            child: _CategoryManagerSheet(
              database: _database,
              categories: _categories,
            ),
          ),
        );
      },
    );
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _buildVisibleItems();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFavorites,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: <Widget>[
                  const RevealMotion(
                    child: PageHeader(
                      eyebrow: 'CURATED ARCHIVE',
                      title: '把会反复回看的内容收进一个轻量但密度足够的收藏面。',
                      description: '所有收藏都使用统一图文结构，双列瀑布流优先帮助你快速扫图、扫标题、扫分类。',
                    ),
                  ),
                  RevealMotion(
                    delay: const Duration(milliseconds: 90),
                    child: SectionCard(
                      addTopDivider: false,
                      title: '筛选工具',
                      subtitle: '共 ${filteredItems.length} 条结果，可按关键词、分类和排序切换。',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              _FavoriteFilterAction(
                                icon: _showFilters
                                    ? Icons.filter_alt_off_outlined
                                    : Icons.filter_alt_outlined,
                                label: _showFilters ? '收起筛选' : '筛选',
                                onPressed: () {
                                  setState(() {
                                    _showFilters = !_showFilters;
                                  });
                                },
                              ),
                              _FavoriteFilterAction(
                                icon: Icons.tune,
                                label: '分类管理',
                                onPressed: _manageCategories,
                              ),
                              _FavoriteFilterAction(
                                icon: Icons.restart_alt,
                                label: '重置条件',
                                onPressed: _hasActiveFilters
                                    ? () {
                                        _searchController.clear();
                                        setState(() {
                                          _selectedCategory = null;
                                          _onlyWithImages = false;
                                          _sort = _FavoriteSort.newest;
                                          _showFilters = false;
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                          if (_hasActiveFilters) ...<Widget>[
                            const SizedBox(height: 12),
                            _buildActiveFilterSummary(),
                          ],
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      labelText: '搜索标题、正文、备注或链接',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon:
                                          _searchController.text.trim().isEmpty
                                          ? null
                                          : IconButton(
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {});
                                              },
                                              icon: const Icon(Icons.close),
                                              tooltip: '清空搜索',
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFilterChips(),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilterChip(
                                      label: const Text('仅看有图内容'),
                                      selected: _onlyWithImages,
                                      showCheckmark: false,
                                      onSelected: (bool value) {
                                        setState(() {
                                          _onlyWithImages = value;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '排序方式',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: const Color(0xFF61706A),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _FavoriteSort.values.map((value) {
                                      return ChoiceChip(
                                        label: Text(_favoriteSortLabel(value)),
                                        selected: _sort == value,
                                        showCheckmark: false,
                                        onSelected: (_) {
                                          setState(() {
                                            _sort = value;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            crossFadeState: _showFilters
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 220),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: filteredItems.isEmpty
                        ? const Padding(
                            key: ValueKey<String>('favorites-empty'),
                            padding: EdgeInsets.only(top: 60),
                            child: EmptyStateView(
                              title: '还没有收藏内容',
                              message: '先创建分类，再把图文内容沉淀进来。',
                              icon: Icons.collections_bookmark_outlined,
                            ),
                          )
                        : Padding(
                            key: const ValueKey<String>('favorites-grid'),
                            padding: const EdgeInsets.only(top: 18),
                            child: MasonryGridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredItems.length,
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              itemBuilder: (BuildContext context, int index) {
                                final item = filteredItems[index];
                                return RevealMotion(
                                  delay: Duration(
                                    milliseconds: 120 + index * 40,
                                  ),
                                  child: _FavoriteCard(
                                    item: item,
                                    onOpen: () => _openDetail(item),
                                    onEdit: () => _openEditor(item),
                                    onDelete: () => _deleteItem(item),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'favorites-add-fab',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('新增收藏'),
      ),
    );
  }

  Widget _buildFilterChips() {
    return HorizontalChoiceFilters(
      options: _categories.map((FavoriteCategory item) => item.name).toList(),
      selectedValue: _selectedCategory,
      onSelected: (String? value) {
        setState(() {
          _selectedCategory = value;
        });
      },
    );
  }

  Widget _buildActiveFilterSummary() {
    final chips = <Widget>[];
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: '关键词: $keyword',
          onDeleted: () {
            _searchController.clear();
            setState(() {});
          },
        ),
      );
    }
    if (_selectedCategory != null) {
      chips.add(
        _ActiveFilterChip(
          label: '分类: $_selectedCategory',
          onDeleted: () {
            setState(() {
              _selectedCategory = null;
            });
          },
        ),
      );
    }
    if (_onlyWithImages) {
      chips.add(
        _ActiveFilterChip(
          label: '仅看有图',
          onDeleted: () {
            setState(() {
              _onlyWithImages = false;
            });
          },
        ),
      );
    }
    if (_sort != _FavoriteSort.newest) {
      chips.add(
        _ActiveFilterChip(
          label: '排序: ${_favoriteSortLabel(_sort)}',
          onDeleted: () {
            setState(() {
              _sort = _FavoriteSort.newest;
            });
          },
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  List<FavoriteItem> _buildVisibleItems() {
    final keyword = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((FavoriteItem item) {
      final categoryMatched =
          _selectedCategory == null || item.category == _selectedCategory;
      if (!categoryMatched) {
        return false;
      }
      if (_onlyWithImages && item.localImagePath.trim().isEmpty) {
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

    switch (_sort) {
      case _FavoriteSort.oldest:
        filtered.sort(
          (FavoriteItem a, FavoriteItem b) =>
              a.updatedAt.compareTo(b.updatedAt),
        );
      case _FavoriteSort.title:
        filtered.sort(
          (FavoriteItem a, FavoriteItem b) => a.title.compareTo(b.title),
        );
      case _FavoriteSort.newest:
        filtered.sort(
          (FavoriteItem a, FavoriteItem b) =>
              b.updatedAt.compareTo(a.updatedAt),
        );
    }
    return filtered;
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _selectedCategory != null ||
        _onlyWithImages ||
        _sort != _FavoriteSort.newest;
  }

  String _favoriteSortLabel(_FavoriteSort value) {
    return switch (value) {
      _FavoriteSort.newest => '最新',
      _FavoriteSort.oldest => '最早',
      _FavoriteSort.title => '标题',
    };
  }
}

enum _FavoriteSort { newest, oldest, title }

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.item,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final FavoriteItem item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onOpen,
        splashColor: const Color(0xFF16302B).withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _FavoriteCover(item: item),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EFE6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(item.category.isEmpty ? '未分类' : item.category),
              ),
              if (item.body.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  item.body.trim(),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
              if (item.referenceUrl.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  item.referenceUrl.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (item.note.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  item.note.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == 'edit') {
                      onEdit();
                    } else {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('删除'),
                        ),
                      ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteCover extends StatelessWidget {
  const _FavoriteCover({required this.item});

  final FavoriteItem item;

  @override
  Widget build(BuildContext context) {
    if (item.localImagePath.trim().isNotEmpty) {
      return _AdaptiveFavoriteImage(path: item.localImagePath);
    }

    final previewHeight = 140.0 + (item.title.length % 4) * 18.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      constraints: BoxConstraints(minHeight: previewHeight),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFE9E0CF), Color(0xFFD7E6DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          item.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: const Color(0xFF1D2F2A),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveFavoriteImage extends StatefulWidget {
  const _AdaptiveFavoriteImage({required this.path});

  final String path;

  @override
  State<_AdaptiveFavoriteImage> createState() => _AdaptiveFavoriteImageState();
}

class _AdaptiveFavoriteImageState extends State<_AdaptiveFavoriteImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveFavoriteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _aspectRatio = null;
      _detachListener();
      _resolveImageSize();
    }
  }

  @override
  void dispose() {
    _detachListener();
    super.dispose();
  }

  void _resolveImageSize() {
    final provider = imageProviderFromPath(widget.path);
    if (provider == null) {
      return;
    }
    final stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (!mounted || width <= 0 || height <= 0) {
        return;
      }
      setState(() {
        _aspectRatio = width / height;
      });
      _detachListener();
    });
    _imageStream = stream;
    stream.addListener(_listener!);
  }

  void _detachListener() {
    final stream = _imageStream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 64;
        final height = _aspectRatio == null ? 160.0 : width / _aspectRatio!;
        return TappableImage(
          path: widget.path,
          width: width,
          height: height,
          borderRadius: 20,
          fit: BoxFit.cover,
          placeholderIcon: Icons.collections_outlined,
        );
      },
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 18),
      showCheckmark: false,
    );
  }
}

class _FavoriteFilterAction extends StatelessWidget {
  const _FavoriteFilterAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class _CategoryManagerSheet extends StatefulWidget {
  const _CategoryManagerSheet({
    required this.database,
    required this.categories,
  });

  final AppDatabase database;
  final List<FavoriteCategory> categories;

  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  final TextEditingController _nameController = TextEditingController();
  late List<FavoriteCategory> _categories;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categories = List<FavoriteCategory>.from(widget.categories);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await widget.database.saveFavoriteCategory(FavoriteCategory(name: name));
      final categories = await widget.database.getFavoriteCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _nameController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteCategory(FavoriteCategory category) async {
    await widget.database.deleteFavoriteCategory(category.id);
    final categories = await widget.database.getFavoriteCategories();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '分类管理',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '新增分类'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                child: FilledButton(
                  onPressed: _isSaving ? null : _createCategory,
                  child: const Text('添加'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _categories.isEmpty
                ? const Center(child: Text('还没有分类'))
                : ListView.separated(
                    itemCount: _categories.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final category = _categories[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(category.name),
                        trailing: IconButton(
                          onPressed: () => _deleteCategory(category),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
