import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';

import '../../models/favorite_category.dart';
import '../../models/favorite_item.dart';
import '../../services/app_database.dart';
import '../../services/managed_image_service.dart';
import '../../widgets/tappable_image.dart';

/// 收藏编辑页，统一维护图文收藏。
class FavoriteEditorPage extends StatefulWidget {
  const FavoriteEditorPage({super.key, this.item});

  final FavoriteItem? item;

  @override
  State<FavoriteEditorPage> createState() => _FavoriteEditorPageState();
}

class _FavoriteEditorPageState extends State<FavoriteEditorPage> {
  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _referenceUrlController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<FavoriteCategory> _categories = <FavoriteCategory>[];
  String? _selectedCategory;
  String _imagePath = '';
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
      _imagePath = item.localImagePath;
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

  Future<void> _pickImage() async {
    final selected = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (selected == null) {
      return;
    }

    final originalPath = _imagePath;
    final storedPath = await _imageService.storePickedImage(selected);
    if (originalPath.isNotEmpty && originalPath != storedPath) {
      _pendingCleanupPaths.add(originalPath);
    }

    setState(() {
      _imagePath = storedPath;
    });
  }

  Future<void> _removeImage() async {
    final originalPath = _imagePath;
    if (originalPath.isNotEmpty) {
      _pendingCleanupPaths.add(originalPath);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _imagePath = '';
    });
  }

  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _CategoryManagerSheet(
          database: _database,
          categories: _categories,
        );
      },
    );
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
      localImagePath: _imagePath,
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
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_imagePath.isEmpty ? '添加图片（选填）' : '更换图片'),
          ),
          if (_imagePath.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _FavoritePreview(path: _imagePath),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _removeImage,
                child: const Text('移除图片'),
              ),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetMaxHeight = MediaQuery.of(context).size.height * 0.72;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SizedBox(
          height: sheetMaxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('分类管理', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: '新增分类'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : _createCategory,
                    child: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('还没有分类'),
                )
              else
                Expanded(
                  child: ListView.separated(
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
        ),
      ),
    );
  }
}

class _FavoritePreview extends StatelessWidget {
  const _FavoritePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final availableWidth = constraints.maxWidth;
        final previewWidth = availableWidth > 280
            ? 280.0
            : availableWidth * 0.72;
        return Align(
          alignment: Alignment.centerLeft,
          child: TappableImage(
            path: path,
            width: previewWidth,
            height: previewWidth * 0.74,
            borderRadius: 18,
            placeholderIcon: Icons.image_outlined,
          ),
        );
      },
    );
  }
}
