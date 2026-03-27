import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/favorite_item.dart';
import '../services/app_database.dart';
import '../services/managed_image_service.dart';
import '../widgets/image_carousel.dart';
import '../widgets/section_card.dart';
import 'editors/favorite_editor_page.dart';

/// 收藏详情页，负责查看完整内容并从详情进入编辑。
class FavoriteDetailPage extends StatefulWidget {
  const FavoriteDetailPage({super.key, required this.favoriteId});

  final Id favoriteId;

  @override
  State<FavoriteDetailPage> createState() => _FavoriteDetailPageState();
}

class _FavoriteDetailPageState extends State<FavoriteDetailPage> {
  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;

  FavoriteItem? _item;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    final item = await _database.getFavoriteById(widget.favoriteId);
    if (!mounted) {
      return;
    }
    if (item == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _item = item;
      _isLoading = false;
    });
  }

  Future<void> _openEditor() async {
    final currentItem = _item;
    if (currentItem == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            FavoriteEditorPage(item: currentItem),
      ),
    );
    await _loadItem();
  }

  Future<void> _deleteItem() async {
    final item = _item;
    if (item == null) {
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('删除收藏'),
              content: const Text('删除后将移除这条收藏及其关联图片，是否继续？'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    await _database.deleteFavorite(item.id);
    for (final path in item.imagePaths.toSet()) {
      await _imageService.deleteIfExists(path);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item?.title ?? '收藏详情'),
        actions: <Widget>[
          if (item != null)
            TextButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑'),
            ),
          if (item != null)
            TextButton.icon(
              onPressed: _deleteItem,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading || item == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
              children: <Widget>[
                if (item.imagePaths.isNotEmpty) ...<Widget>[
                  ImageCarousel(
                    paths: item.imagePaths,
                    height: 280,
                    borderRadius: 0,
                    itemSpacing: 0,
                    placeholderIcon: Icons.collections_outlined,
                  ),
                  const SizedBox(height: 18),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SectionCard(
                    addTopDivider: false,
                    title: item.title,
                    subtitle: item.category.trim().isEmpty
                        ? '未分类'
                        : item.category.trim(),
                    child: _TimeSummaryRow(
                      createdAt: _formatDateTime(item.createdAt),
                      updatedAt: _formatDateTime(item.updatedAt),
                    ),
                  ),
                ),
                if (item.body.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SectionCard(
                      title: '正文',
                      subtitle: '完整保存原始内容，方便回看。',
                      child: Text(
                        item.body.trim(),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.7),
                      ),
                    ),
                  ),
                ],
                if (item.note.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SectionCard(
                      title: '备注',
                      subtitle: '你补充的判断与使用场景。',
                      child: Text(
                        item.note.trim(),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.7),
                      ),
                    ),
                  ),
                ],
                if (item.referenceUrl.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SectionCard(
                      title: '引用链接',
                      subtitle: '原始来源地址。',
                      child: SelectableText(
                        item.referenceUrl.trim(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _TimeSummaryRow extends StatelessWidget {
  const _TimeSummaryRow({required this.createdAt, required this.updatedAt});

  final String createdAt;
  final String updatedAt;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: <Widget>[
        _TimePill(label: '创建时间', value: createdAt),
        _TimePill(label: '最近更新', value: updatedAt),
      ],
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$label：',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
