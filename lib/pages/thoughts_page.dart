import 'package:flutter/material.dart';

import '../models/thought_note.dart';
import '../services/app_database.dart';
import '../services/managed_image_service.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/horizontal_choice_filters.dart';
import '../widgets/page_header.dart';
import '../widgets/reveal_motion.dart';
import '../widgets/section_card.dart';
import '../widgets/tappable_image.dart';
import 'editors/thought_editor_page.dart';
import 'thought_detail_page.dart';

/// 想法页，展示结构化步骤记录。
class ThoughtsPage extends StatefulWidget {
  const ThoughtsPage({super.key, required this.refreshSeed});

  final int refreshSeed;

  @override
  State<ThoughtsPage> createState() => _ThoughtsPageState();
}

enum _ThoughtSort { newest, oldest, title }

class _ThoughtsPageState extends State<ThoughtsPage> {
  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<ThoughtNote> _items = <ThoughtNote>[];
  List<String> _categories = <String>[];
  String? _selectedCategory;
  _ThoughtSort _sort = _ThoughtSort.newest;
  bool _onlyWithImages = false;
  bool _showFilters = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThoughts();
  }

  @override
  void didUpdateWidget(covariant ThoughtsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _loadThoughts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadThoughts() async {
    final items = await _database.getThoughts();
    final categories = await _database.getThoughtCategories();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _categories = categories;
      if (_selectedCategory != null &&
          !_categories.contains(_selectedCategory)) {
        _selectedCategory = null;
      }
      _isLoading = false;
    });
  }

  Future<void> _openEditor([ThoughtNote? note]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ThoughtEditorPage(note: note),
      ),
    );
    await _loadThoughts();
  }

  Future<void> _openDetail(ThoughtNote note) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ThoughtDetailPage(thoughtId: note.id),
      ),
    );
    await _loadThoughts();
  }

  Future<void> _deleteThought(ThoughtNote note) async {
    await _database.deleteThought(note.id);
    if (note.localImagePath.isNotEmpty) {
      await _imageService.deleteIfExists(note.localImagePath);
    }
    for (final step in note.steps) {
      if (step.imagePath.isNotEmpty) {
        await _imageService.deleteIfExists(step.imagePath);
      }
    }
    await _loadThoughts();
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _buildVisibleItems();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadThoughts,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: <Widget>[
                  const RevealMotion(
                    child: PageHeader(
                      eyebrow: 'THOUGHTS BOARD',
                      title: '把经验写成可执行步骤，而不是只留一句感受。',
                      description: '每条想法围绕一个主题展开，概述负责定调，步骤负责复用，可能问题负责提前卡位。',
                    ),
                  ),
                  RevealMotion(
                    delay: const Duration(milliseconds: 80),
                    child: SectionCard(
                      addTopDivider: false,
                      title: '筛选工具',
                      subtitle: '共 ${visibleItems.length} 条结果，可按分类与排序快速切换。',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              _ActionChipButton(
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
                              _ActionChipButton(
                                icon: Icons.restart_alt,
                                label: '重置条件',
                                onPressed: _hasActiveFilters
                                    ? () {
                                        _searchController.clear();
                                        setState(() {
                                          _selectedCategory = null;
                                          _onlyWithImages = false;
                                          _sort = _ThoughtSort.newest;
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
                                      labelText: '搜索标题、概述、分类或步骤',
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
                                  HorizontalChoiceFilters(
                                    options: _categories,
                                    selectedValue: _selectedCategory,
                                    onSelected: (String? value) {
                                      setState(() {
                                        _selectedCategory = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilterChip(
                                      label: const Text('仅看含图片记录'),
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
                                    children: _ThoughtSort.values.map((value) {
                                      return ChoiceChip(
                                        label: Text(_thoughtSortLabel(value)),
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
                    child: visibleItems.isEmpty
                        ? const Padding(
                            key: ValueKey<String>('thoughts-empty'),
                            padding: EdgeInsets.only(top: 60),
                            child: EmptyStateView(
                              title: '没有匹配的想法记录',
                              message: '可以先新增一条，或者调整当前搜索和筛选条件。',
                              icon: Icons.lightbulb_outline,
                            ),
                          )
                        : RevealMotion(
                            key: const ValueKey<String>('thoughts-list'),
                            delay: const Duration(milliseconds: 120),
                            child: SectionCard(
                              title: '记录列表',
                              subtitle: '优先保留可被复用的步骤和问题提示。',
                              child: Column(
                                children: List<Widget>.generate(
                                  visibleItems.length,
                                  (int index) {
                                    final item = visibleItems[index];
                                    return RevealMotion(
                                      delay: Duration(
                                        milliseconds: 150 + index * 40,
                                      ),
                                      child: _ThoughtRow(
                                        item: item,
                                        onOpen: () => _openDetail(item),
                                        onEdit: () => _openEditor(item),
                                        onDelete: () => _deleteThought(item),
                                        isLast:
                                            index == visibleItems.length - 1,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'thoughts-add-fab',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('新增想法'),
      ),
    );
  }

  List<ThoughtNote> _buildVisibleItems() {
    final keyword = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((ThoughtNote item) {
      final categoryMatched =
          _selectedCategory == null || item.category == _selectedCategory;
      if (!categoryMatched) {
        return false;
      }
      final hasAnyImage =
          item.localImagePath.trim().isNotEmpty ||
          item.steps.any(
            (ThoughtStep step) => step.imagePath.trim().isNotEmpty,
          );
      if (_onlyWithImages && !hasAnyImage) {
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

    switch (_sort) {
      case _ThoughtSort.oldest:
        filtered.sort(
          (ThoughtNote a, ThoughtNote b) => a.updatedAt.compareTo(b.updatedAt),
        );
      case _ThoughtSort.title:
        filtered.sort(
          (ThoughtNote a, ThoughtNote b) => a.title.compareTo(b.title),
        );
      case _ThoughtSort.newest:
        filtered.sort(
          (ThoughtNote a, ThoughtNote b) => b.updatedAt.compareTo(a.updatedAt),
        );
    }
    return filtered;
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _selectedCategory != null ||
        _onlyWithImages ||
        _sort != _ThoughtSort.newest;
  }

  String _thoughtSortLabel(_ThoughtSort value) {
    return switch (value) {
      _ThoughtSort.newest => '最新',
      _ThoughtSort.oldest => '最早',
      _ThoughtSort.title => '标题',
    };
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
          label: '仅看含图',
          onDeleted: () {
            setState(() {
              _onlyWithImages = false;
            });
          },
        ),
      );
    }
    if (_sort != _ThoughtSort.newest) {
      chips.add(
        _ActiveFilterChip(
          label: '排序: ${_thoughtSortLabel(_sort)}',
          onDeleted: () {
            setState(() {
              _sort = _ThoughtSort.newest;
            });
          },
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _ThoughtRow extends StatelessWidget {
  const _ThoughtRow({
    required this.item,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.isLast,
  });

  final ThoughtNote item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final imageCount = item.steps
        .where((ThoughtStep step) => step.imagePath.trim().isNotEmpty)
        .length;
    final questionCount = item.steps
        .where((ThoughtStep step) => step.possibleQuestion.trim().isNotEmpty)
        .length;
    final previewSteps = item.steps.take(2).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Material(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onOpen,
          splashColor: const Color(0xFF16302B).withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ThoughtPreview(imagePath: item.localImagePath),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                              ),
                              if (item.category.trim().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9EFE6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(item.category.trim()),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.overview.trim().isEmpty
                                ? '暂无概述'
                                : item.overview.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.55),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (String value) {
                        if (value == 'edit') {
                          onEdit();
                        } else {
                          onDelete();
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ThoughtMetaPill(label: '步骤 ${item.steps.length}'),
                    _ThoughtMetaPill(label: '步骤图 $imageCount'),
                    _ThoughtMetaPill(label: '问题提示 $questionCount'),
                  ],
                ),
                if (previewSteps.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F2EA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '步骤摘要',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: const Color(0xFF66746E),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        ...previewSteps.map((ThoughtStep step) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: step == previewSteps.last ? 0 : 10,
                            ),
                            child: _ThoughtStepSnippet(step: step),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThoughtPreview extends StatelessWidget {
  const _ThoughtPreview({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return TappableImage(
      path: imagePath,
      width: 104,
      height: 116,
      borderRadius: 18,
      placeholderIcon: Icons.route_outlined,
      placeholderColor: const Color(0xFFE4F2EE),
      iconColor: const Color(0xFF115E59),
    );
  }
}

class _ThoughtMetaPill extends StatelessWidget {
  const _ThoughtMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEE8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF4B5F58),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ThoughtStepSnippet extends StatelessWidget {
  const _ThoughtStepSnippet({required this.step});

  final ThoughtStep step;

  @override
  Widget build(BuildContext context) {
    final summary = step.detail.trim().isEmpty ? '未填写步骤说明' : step.detail.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFDCE8E2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.subdirectory_arrow_right, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                step.title.trim().isEmpty ? '未命名步骤' : step.title.trim(),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: const Color(0xFF627069),
                ),
              ),
            ],
          ),
        ),
        if (step.imagePath.trim().isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 2),
            child: Icon(
              Icons.image_outlined,
              size: 16,
              color: Color(0xFF627069),
            ),
          ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
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
