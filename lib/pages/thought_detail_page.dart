import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/thought_note.dart';
import '../services/app_database.dart';
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
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading || note == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: <Widget>[
                if (note.localImagePath.trim().isNotEmpty) ...<Widget>[
                  TappableImage(
                    path: note.localImagePath,
                    width: double.infinity,
                    height: 240,
                    borderRadius: 28,
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _ThoughtStatChip(label: '步骤 ${note.steps.length}'),
                      _ThoughtStatChip(label: '图片 ${_countImages(note)}'),
                      _ThoughtStatChip(label: '问题 ${_countQuestions(note)}'),
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
            TappableImage(
              path: step.imagePath,
              width: double.infinity,
              height: 180,
              borderRadius: 18,
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
