import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';

import '../../models/favorite_category.dart';
import '../../models/thought_note.dart';
import '../../services/app_database.dart';
import '../../services/managed_image_service.dart';
import '../../widgets/category_manager_sheet.dart';
import '../../widgets/editable_image_grid.dart';
import '../../widgets/tappable_image.dart';

/// 想法编辑页，支持分类、主图和步骤图片。
class ThoughtEditorPage extends StatefulWidget {
  const ThoughtEditorPage({super.key, this.note});

  final ThoughtNote? note;

  @override
  State<ThoughtEditorPage> createState() => _ThoughtEditorPageState();
}

class _ThoughtEditorPageState extends State<ThoughtEditorPage> {
  static const int _maxImageCount = 9;

  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _overviewController = TextEditingController();

  List<FavoriteCategory> _categories = <FavoriteCategory>[];
  String? _selectedCategory;
  late List<ThoughtStep> _steps;
  List<String> _imagePaths = <String>[];
  bool _isSaving = false;
  bool _isLoadingCategories = true;
  final Set<String> _pendingCleanupPaths = <String>{};

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController.text = note?.title ?? '';
    _selectedCategory = note?.category.trim().isEmpty ?? true
      ? null
      : note?.category;
    _overviewController.text = note?.overview ?? '';
    _imagePaths = List<String>.from(note?.imagePaths ?? <String>[]);
    _steps = List<ThoughtStep>.from(note?.steps ?? <ThoughtStep>[]);
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _overviewController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await _database.getFavoriteCategories();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
      if (_selectedCategory != null &&
          !_categories.any(
            (FavoriteCategory item) => item.name == _selectedCategory,
          )) {
        _selectedCategory = null;
      }
    });
  }

  Future<void> _manageCategories() async {
    await openCategoryManagerPage(context, database: _database);
    await _loadCategories();
  }

  Future<void> _pickCoverImages() async {
    if (_imagePaths.length >= _maxImageCount) {
      _showMessage('最多上传 $_maxImageCount 张图片');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: kIsWeb,
      dialogTitle: '选择图片',
    );
    final selectedFiles = result?.files ?? <PlatformFile>[];
    if (selectedFiles.isEmpty) {
      return;
    }

    final remainingSlots = _maxImageCount - _imagePaths.length;
    final nextPaths = List<String>.from(_imagePaths);
    for (final file in selectedFiles.take(remainingSlots)) {
      final storedPath = await _storePlatformFile(file);
      if (!nextPaths.contains(storedPath)) {
        nextPaths.add(storedPath);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _imagePaths = nextPaths;
    });

    if (selectedFiles.length > remainingSlots) {
      _showMessage('最多保留 $_maxImageCount 张图片，其余已忽略');
    }
  }

  Future<String> _storePlatformFile(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('无法读取所选图片');
      }
      return _imageService.storeImportedBytes(
        bytes: bytes,
        originalName: file.name,
      );
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw StateError('无法读取所选图片');
    }
    return _imageService.storePickedImage(XFile(path));
  }

  Future<void> _removeCoverImageAt(int index) async {
    final originalPath = _imagePaths[index];
    if (originalPath.isNotEmpty) {
      _pendingCleanupPaths.add(originalPath);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _imagePaths.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      _showMessage('请输入标题');
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      _showMessage('请选择分类');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final existing = widget.note;
    final note = ThoughtNote(
      id: existing?.id ?? Isar.autoIncrement,
      title: _titleController.text.trim(),
      category: _selectedCategory!.trim(),
      overview: _overviewController.text.trim(),
      imagePaths: _imagePaths,
      localImagePath: _imagePaths.isEmpty ? '' : _imagePaths.first,
      stepsValue: _steps,
      createdAtValue: existing?.createdAt ?? DateTime.now(),
    );

    await _database.saveThought(note);
    await _imageService.cleanupUnusedImages(
      candidatePaths: _pendingCleanupPaths,
    );
    _pendingCleanupPaths.clear();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _addOrEditStep([int? index]) async {
    final current = index == null ? null : _steps[index];
    final result = await showModalBottomSheet<ThoughtStep>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _ThoughtStepEditorSheet(
          imagePicker: _imagePicker,
          imageService: _imageService,
          initialStep: current,
        );
      },
    );

    if (result == null || result.title.trim().isEmpty) {
      return;
    }
    setState(() {
      if (index == null) {
        _steps = <ThoughtStep>[..._steps, result];
      } else {
        final current = _steps[index];
        if (current.imagePath.isNotEmpty &&
            current.imagePath != result.imagePath) {
          _pendingCleanupPaths.add(current.imagePath);
        }
        _steps[index] = result;
      }
    });
  }

  Future<void> _deleteStep(int index) async {
    final step = _steps[index];
    if (step.imagePath.isNotEmpty) {
      _pendingCleanupPaths.add(step.imagePath);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _steps.removeAt(index);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新增想法' : '编辑想法'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _manageCategories,
            icon: const Icon(Icons.tune),
            label: const Text('分类管理'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '标题'),
          ),
          const SizedBox(height: 12),
          if (_isLoadingCategories)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              items: _categories
                  .map(
                    (FavoriteCategory item) => DropdownMenuItem<String>(
                      value: item.name,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              decoration: const InputDecoration(labelText: '分类'),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _manageCategories,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(_categories.isEmpty ? '先创建分类' : '管理分类'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _overviewController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '概述'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pickCoverImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _imagePaths.isEmpty
                  ? '添加配图（选填，最多 $_maxImageCount 张）'
                  : '继续添加配图（${_imagePaths.length}/$_maxImageCount）',
            ),
          ),
          if (_imagePaths.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            EditableImageGrid(
              paths: _imagePaths,
              onRemove: _removeCoverImageAt,
              maxItemWidth: 106,
            ),
          ],
          const SizedBox(height: 20),
          _EditableListSection<ThoughtStep>(
            title: '步骤列表',
            actionLabel: '新增步骤',
            items: _steps,
            onAdd: () => _addOrEditStep(),
            onEdit: _addOrEditStep,
            onDelete: _deleteStep,
            itemBuilder: (ThoughtStep item) => _StepPreview(step: item),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('保存想法'),
          ),
        ],
      ),
    );
  }
}

class _ThoughtStepEditorSheet extends StatefulWidget {
  const _ThoughtStepEditorSheet({
    required this.imagePicker,
    required this.imageService,
    this.initialStep,
  });

  final ImagePicker imagePicker;
  final ManagedImageService imageService;
  final ThoughtStep? initialStep;

  @override
  State<_ThoughtStepEditorSheet> createState() =>
      _ThoughtStepEditorSheetState();
}

class _ThoughtStepEditorSheetState extends State<_ThoughtStepEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailController;
  late final TextEditingController _questionController;
  late String _imagePath;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialStep?.title ?? '',
    );
    _detailController = TextEditingController(
      text: widget.initialStep?.detail ?? '',
    );
    _questionController = TextEditingController(
      text: widget.initialStep?.possibleQuestion ?? '',
    );
    _imagePath = widget.initialStep?.imagePath ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final selected = await widget.imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (selected == null) {
      return;
    }
    final storedPath = await widget.imageService.storePickedImage(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _imagePath = storedPath;
    });
  }

  Future<void> _removeImage() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _imagePath = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          Text(
            widget.initialStep == null ? '新增步骤' : '编辑步骤',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '步骤标题'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '步骤说明'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '可能问题（选填）'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_imagePath.isEmpty ? '添加步骤图片（选填）' : '更换步骤图片'),
          ),
          if (_imagePath.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _PreviewImage(path: _imagePath, height: 160),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _removeImage,
                child: const Text('移除图片'),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                ThoughtStep(
                  title: _titleController.text.trim(),
                  detail: _detailController.text.trim(),
                  possibleQuestion: _questionController.text.trim(),
                  imagePath: _imagePath,
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _EditableListSection<T> extends StatelessWidget {
  const _EditableListSection({
    required this.title,
    required this.actionLabel,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.itemBuilder,
  });

  final String title;
  final String actionLabel;
  final List<T> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('暂无内容', style: Theme.of(context).textTheme.bodyMedium)
            else
              ...List<Widget>.generate(items.length, (int index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: itemBuilder(items[index]),
                  trailing: Wrap(
                    spacing: 4,
                    children: <Widget>[
                      IconButton(
                        onPressed: () => onEdit(index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => onDelete(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StepPreview extends StatelessWidget {
  const _StepPreview({required this.step});

  final ThoughtStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(step.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(step.detail.isEmpty ? '未填写步骤说明' : step.detail),
        if (step.possibleQuestion.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text('可能问题：${step.possibleQuestion.trim()}'),
        ],
        if (step.imagePath.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          _PreviewImage(path: step.imagePath, height: 100),
        ],
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.path, required this.height});

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    final previewWidth = (MediaQuery.sizeOf(context).width - 40).clamp(
      160.0,
      240.0,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: TappableImage(
        path: path,
        width: previewWidth,
        height: height,
        borderRadius: 18,
        fit: BoxFit.contain,
        placeholderIcon: Icons.image_outlined,
      ),
    );
  }
}
