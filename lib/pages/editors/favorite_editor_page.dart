import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';

import '../../models/favorite_category.dart';
import '../../models/favorite_item.dart';
import '../../services/app_database.dart';
import '../../services/managed_image_service.dart';
import '../../widgets/category_manager_sheet.dart';
import '../../widgets/editable_image_grid.dart';

/// 收藏编辑页，统一维护图文收藏。
class FavoriteEditorPage extends StatefulWidget {
  const FavoriteEditorPage({super.key, this.item});

  final FavoriteItem? item;

  @override
  State<FavoriteEditorPage> createState() => _FavoriteEditorPageState();
}

class _FavoriteEditorPageState extends State<FavoriteEditorPage> {
  static const int _maxImageCount = 9;

  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _referenceUrlController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<FavoriteCategory> _categories = <FavoriteCategory>[];
  String? _selectedCategory;
  List<String> _imagePaths = <String>[];
  bool _isSaving = false;
  bool _isLoadingCategories = true;
  final Set<String> _pendingCleanupPaths = <String>{};

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _titleController.text = item.title;
      _bodyController.text = item.body;
      _referenceUrlController.text = item.referenceUrl;
      _noteController.text = item.note;
      _selectedCategory = item.category.isEmpty ? null : item.category;
      _imagePaths = List<String>.from(item.imagePaths);
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _referenceUrlController.dispose();
    _noteController.dispose();
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

  Future<void> _pickImages() async {
    if (_imagePaths.length >= _maxImageCount) {
      _showError('最多上传 $_maxImageCount 张图片');
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

    setState(() {
      _imagePaths = nextPaths;
    });

    if (selectedFiles.length > remainingSlots && mounted) {
      _showError('最多保留 $_maxImageCount 张图片，其余已忽略');
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

  Future<void> _removeImageAt(int index) async {
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

  Future<void> _manageCategories() async {
    await openCategoryManagerPage(context, database: _database);
    await _loadCategories();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('请输入标题');
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      _showError('请选择分类');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final existing = widget.item;
    final item = FavoriteItem(
      id: existing?.id ?? Isar.autoIncrement,
      title: _titleController.text.trim(),
      category: _selectedCategory!.trim(),
      body: _bodyController.text.trim(),
      imagePaths: _imagePaths,
      localImagePath: _imagePaths.isEmpty ? '' : _imagePaths.first,
      referenceUrl: _referenceUrlController.text.trim(),
      note: _noteController.text.trim(),
      createdAtValue: existing?.createdAt ?? DateTime.now(),
    );

    await _database.saveFavorite(item);
    await _imageService.cleanupUnusedImages(
      candidatePaths: _pendingCleanupPaths,
    );
    _pendingCleanupPaths.clear();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? '新增收藏' : '编辑收藏'),
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
            controller: _bodyController,
            maxLines: 8,
            decoration: const InputDecoration(labelText: '正文（选填）'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _imagePaths.isEmpty
                  ? '添加图片（选填，最多 $_maxImageCount 张）'
                  : '继续添加图片（${_imagePaths.length}/$_maxImageCount）',
            ),
          ),
          if (_imagePaths.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            EditableImageGrid(
              paths: _imagePaths,
              onRemove: _removeImageAt,
              maxItemWidth: 106,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _referenceUrlController,
            decoration: const InputDecoration(labelText: '引用链接（选填）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '备注（选填）'),
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
            label: const Text('保存收藏'),
          ),
        ],
      ),
    );
  }
}
