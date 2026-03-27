import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/thought_note.dart';
import '../services/app_database.dart';
import '../services/managed_image_service.dart';
import '../widgets/section_card.dart';
import '../widgets/tappable_image.dart';
import 'editors/thought_editor_page.dart';

/// 想法详情页，展示完整概述与步骤明细。
class ThoughtDetailPage extends StatefulWidget {
  const ThoughtDetailPage({super.key, required this.thoughtId});

  final Id thoughtId;

  @override
  State<ThoughtDetailPage> createState() => _ThoughtDetailPageState();
}

class _ThoughtDetailPageState extends State<ThoughtDetailPage> {
  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;

  ThoughtNote? _note;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final note = await _database.getThoughtById(widget.thoughtId);
    if (!mounted) {
      return;
    }
    if (note == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _note = note;
      _isLoading = false;
    });
  }

  Future<void> _openEditor() async {
    final currentNote = _note;
    if (currentNote == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ThoughtEditorPage(note: currentNote),
      ),
    );
    await _loadNote();
  }

  Future<void> _deleteNote() async {
    final note = _note;
    if (note == null) {
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('删除想法'),
              content: const Text('删除后将移除这条想法及其步骤图片，是否继续？'),
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

    await _database.deleteThought(note.id);
    if (note.localImagePath.isNotEmpty) {
      await _imageService.deleteIfExists(note.localImagePath);
    }
    for (final step in note.steps) {
      if (step.imagePath.isNotEmpty) {
        await _imageService.deleteIfExists(step.imagePath);
      }
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Scaffold(
      appBar: AppBar(
        title: Text(note?.title ?? '想法详情'),
        actions: <Widget>[
          if (note != null)
            TextButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑'),
            ),
          if (note != null)
            TextButton.icon(
              onPressed: _deleteNote,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading || note == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: <Widget>[
                if (note.localImagePath.trim().isNotEmpty) ...<Widget>[
                  AdaptiveTappableImage(
                    path: note.localImagePath,
                    borderRadius: 28,
                    fallbackHeight: 240,
                    placeholderIcon: Icons.route_outlined,
                    placeholderColor: const Color(0xFFE4F2EE),
                    iconColor: const Color(0xFF115E59),
                  ),
                  const SizedBox(height: 18),
                ],
                SectionCard(
                  addTopDivider: false,
                  title: note.title,
                  subtitle: note.category.trim().isEmpty
                      ? '未分类'
                      : note.category.trim(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _ThoughtStatChip(label: '步骤 ${note.steps.length}'),
                          _ThoughtStatChip(label: '图片 ${_countImages(note)}'),
                          _ThoughtStatChip(
                            label: '问题 ${_countQuestions(note)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TimeSummaryRow(
                        createdAt: _formatDateTime(note.createdAt),
                        updatedAt: _formatDateTime(note.updatedAt),
                      ),
                    ],
                  ),
                ),
                if (note.overview.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '概述',
                    subtitle: '先看主题，再决定是否深入步骤。',
                    child: Text(
                      note.overview.trim(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.7),
                    ),
                  ),
                ],
                if (note.steps.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '完整步骤',
                    subtitle: '逐条查看操作说明与可能问题。',
                    child: Column(
                      children: List<Widget>.generate(note.steps.length, (
                        int index,
                      ) {
                        final step = note.steps[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == note.steps.length - 1 ? 0 : 18,
                          ),
                          child: _ThoughtStepDetail(
                            index: index + 1,
                            step: step,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  int _countImages(ThoughtNote note) {
    return (note.localImagePath.trim().isNotEmpty ? 1 : 0) +
        note.steps
            .where((ThoughtStep step) => step.imagePath.trim().isNotEmpty)
            .length;
  }

  int _countQuestions(ThoughtNote note) {
    return note.steps
        .where((ThoughtStep step) => step.possibleQuestion.trim().isNotEmpty)
        .length;
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _ThoughtStatChip extends StatelessWidget {
  const _ThoughtStatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

class _ThoughtStepDetail extends StatelessWidget {
  const _ThoughtStepDetail({required this.index, required this.step});

  final int index;
  final ThoughtStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE8E2),
                  shape: BoxShape.circle,
                ),
                child: Text('$index'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title.trim().isEmpty ? '未命名步骤' : step.title.trim(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (step.detail.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              step.detail.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.7),
            ),
          ],
          if (step.imagePath.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            AdaptiveTappableImage(
              path: step.imagePath,
              borderRadius: 18,
              fallbackHeight: 180,
              placeholderIcon: Icons.image_outlined,
            ),
          ],
          if (step.possibleQuestion.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '可能问题：${step.possibleQuestion.trim()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.6,
                  color: const Color(0xFF4C5D58),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$label：',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF76827D),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF22342F)),
          ),
        ],
      ),
    );
  }
}
