import 'package:flutter/material.dart';

import '../models/favorite_category.dart';
import '../services/app_database.dart';

Future<void> openCategoryManagerPage(
  BuildContext context, {
  required AppDatabase database,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => CategoryManagerPage(database: database),
    ),
  );
}

class CategoryManagerPage extends StatefulWidget {
  const CategoryManagerPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<CategoryManagerPage> createState() => _CategoryManagerPageState();
}

class _CategoryManagerPageState extends State<CategoryManagerPage> {
  final TextEditingController _nameController = TextEditingController();

  List<FavoriteCategory> _categories = <FavoriteCategory>[];
  Map<String, int> _usageCounts = <String, int>{};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await widget.database.getFavoriteCategories();
    final usageCounts = await widget.database.getCategoryUsageCounts();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
      _usageCounts = usageCounts;
      _isLoading = false;
    });
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
      _nameController.clear();
      await _loadCategories();
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
    try {
      await widget.database.deleteFavoriteCategory(category.id);
      await _loadCategories();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: '新增分类'),
                      onSubmitted: (_) => _isSaving ? null : _createCategory(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : _createCategory,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_categories.isEmpty)
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
                      final usageCount = _usageCounts[category.name] ?? 0;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${category.name} ($usageCount)'),
                        trailing: IconButton(
                          onPressed: usageCount == 0
                              ? () => _deleteCategory(category)
                              : null,
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