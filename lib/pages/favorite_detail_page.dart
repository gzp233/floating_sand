import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/favorite_item.dart';
import '../services/app_database.dart';
import '../widgets/section_card.dart';
import '../widgets/tappable_image.dart';
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
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading || item == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: <Widget>[
                if (item.localImagePath.trim().isNotEmpty) ...<Widget>[
                  TappableImage(
                    path: item.localImagePath,
                    width: double.infinity,
                    height: 240,
                    borderRadius: 28,
                    placeholderIcon: Icons.collections_outlined,
                  ),
                  const SizedBox(height: 18),
                ],
                SectionCard(
                  addTopDivider: false,
                  title: item.title,
                  subtitle: item.category.trim().isEmpty
                      ? '未分类'
                      : item.category.trim(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _DetailMetaRow(
                        label: '创建时间',
                        value: _formatDateTime(item.createdAt),
                      ),
                      const SizedBox(height: 10),
                      _DetailMetaRow(
                        label: '最近更新',
                        value: _formatDateTime(item.updatedAt),
                      ),
                    ],
                  ),
                ),
                if (item.body.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '正文',
                    subtitle: '完整保存原始内容，方便回看。',
                    child: Text(
                      item.body.trim(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.7),
                    ),
                  ),
                ],
                if (item.note.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '备注',
                    subtitle: '你补充的判断与使用场景。',
                    child: Text(
                      item.note.trim(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.7),
                    ),
                  ),
                ],
                if (item.referenceUrl.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '引用链接',
                    subtitle: '原始来源地址。',
                    child: SelectableText(
                      item.referenceUrl.trim(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: const Color(0xFF355C54),
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

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF76827D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF22342F)),
          ),
        ),
      ],
    );
  }
}
