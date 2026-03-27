import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/person_profile.dart';
import '../services/app_database.dart';
import '../services/managed_image_service.dart';
import '../widgets/reveal_motion.dart';
import '../widgets/section_card.dart';
import '../widgets/tappable_image.dart';

class ProfilePageController extends ChangeNotifier {
  bool _isEditing = false;
  bool _isSaving = false;
  VoidCallback? _onPrimaryAction;
  Future<void> Function()? _onCancel;

  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;

  void bind({
    required bool isEditing,
    required bool isSaving,
    required VoidCallback onPrimaryAction,
    required Future<void> Function() onCancel,
  }) {
    final changed = _isEditing != isEditing ||
        _isSaving != isSaving ||
        _onPrimaryAction != onPrimaryAction ||
        _onCancel != onCancel;
    _isEditing = isEditing;
    _isSaving = isSaving;
    _onPrimaryAction = onPrimaryAction;
    _onCancel = onCancel;
    if (changed) {
      notifyListeners();
    }
  }

  void unbind() {
    _onPrimaryAction = null;
    _onCancel = null;
  }

  void triggerPrimaryAction() {
    _onPrimaryAction?.call();
  }

  Future<void> triggerCancel() async {
    final cancel = _onCancel;
    if (cancel != null) {
      await cancel();
    }
  }
}

/// 档案页，默认以只读方式展示，进入编辑后可维护照片与补充信息。
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.refreshSeed,
    required this.controller,
  });

  final int refreshSeed;
  final ProfilePageController controller;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _personalitySummaryController =
      TextEditingController();
  final TextEditingController _valuesController = TextEditingController();
  final TextEditingController _personalityTagsController =
      TextEditingController();
  final TextEditingController _hobbiesController = TextEditingController();

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSaving = false;
  bool _isEditing = false;
  List<_ModuleDraft> _modules = <_ModuleDraft>[];
  List<String> _photoPaths = <String>[];
  final Set<String> _pendingCleanupPaths = <String>{};

  @override
  void initState() {
    super.initState();
    _syncControllerState();
    _loadProfile(showBlockingLoader: true);
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.unbind();
      _syncControllerState();
    }
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _loadProfile(showBlockingLoader: false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _personalitySummaryController.dispose();
    _valuesController.dispose();
    _personalityTagsController.dispose();
    _hobbiesController.dispose();
    for (final module in _modules) {
      module.dispose();
    }
    widget.controller.unbind();
    super.dispose();
  }

  Future<void> _loadProfile({required bool showBlockingLoader}) async {
    setState(() {
      if (showBlockingLoader) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
    });
    final profile = await _database.getProfile() ?? PersonProfile();
    _applyProfile(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _isRefreshing = false;
      _isEditing = false;
    });
    _syncControllerState();
  }

  void _applyProfile(PersonProfile profile) {
    _nicknameController.text = profile.nickname;
    _bioController.text = profile.bio;
    _personalitySummaryController.text = profile.personality.summary;
    _valuesController.text = profile.personality.values;
    _personalityTagsController.text = profile.personality.tags.join('，');
    _hobbiesController.text = profile.hobbies.join('，');
    _photoPaths = List<String>.from(profile.photoPaths);
    for (final module in _modules) {
      module.dispose();
    }
    _modules = profile.customModules.map(_toDraft).toList();
    _pendingCleanupPaths.clear();
  }

  _ModuleDraft _toDraft(ProfileCustomModule module) {
    return _ModuleDraft(
      title: TextEditingController(text: module.title),
      content: TextEditingController(text: module.content),
    );
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });
    _syncControllerState();

    final profile = PersonProfile(
      id: 1,
      nickname: _nicknameController.text.trim(),
      bio: _bioController.text.trim(),
      photoPathsValue: _photoPaths,
      personalityValue: ProfilePersonality(
        summary: _personalitySummaryController.text.trim(),
        values: _valuesController.text.trim(),
        tagsValue: _splitInput(_personalityTagsController.text),
      ),
      hobbiesValue: _splitInput(_hobbiesController.text),
      customModulesValue: _modules
          .map(
            (_ModuleDraft item) => ProfileCustomModule(
              title: item.title.text.trim(),
              content: item.content.text.trim(),
            ),
          )
          .where(
            (ProfileCustomModule item) =>
                item.title.isNotEmpty || item.content.isNotEmpty,
          )
          .toList(),
    );

    await _database.saveProfile(profile);
    await _imageService.cleanupUnusedImages(
      candidatePaths: _pendingCleanupPaths,
    );
    _pendingCleanupPaths.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });
    _syncControllerState();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('个人档案已保存')));
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    _syncControllerState();
  }

  void _addModule() {
    setState(() {
      _modules = <_ModuleDraft>[
        ..._modules,
        _ModuleDraft(
          title: TextEditingController(),
          content: TextEditingController(),
        ),
      ];
    });
  }

  void _removeModule(int index) {
    final target = _modules[index];
    setState(() {
      _modules = List<_ModuleDraft>.from(_modules)..removeAt(index);
    });
    target.dispose();
  }

  Future<void> _pickPhoto() async {
    final selected = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (selected == null) {
      return;
    }
    final storedPath = await _imageService.storePickedImage(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _photoPaths = <String>[..._photoPaths, storedPath];
    });
  }

  Future<void> _removePhoto(String path) async {
    _pendingCleanupPaths.add(path);
    if (!mounted) {
      return;
    }
    setState(() {
      _photoPaths = _photoPaths.where((String item) => item != path).toList();
    });
  }

  Future<void> _cancelEditing() async {
    await _loadProfile(showBlockingLoader: false);
  }

  void _syncControllerState() {
    widget.controller.bind(
      isEditing: _isEditing,
      isSaving: _isSaving,
      onPrimaryAction: _isEditing ? _saveProfile : _startEditing,
      onCancel: _cancelEditing,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          RevealMotion(
            child: _ProfileSectionFrame(
              child: SectionCard(
                addTopDivider: false,
                title: '基础信息',
                subtitle: '姓名称呼、一段简介和个人照片，优先保持真实和清晰。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_isEditing) ...<Widget>[
                      TextField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(labelText: '昵称 / 称呼'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bioController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: '个人简介'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('添加个人照片'),
                      ),
                      const SizedBox(height: 14),
                    ] else
                      _ReadOnlyBlock(
                        items: <_ReadOnlyItem>[
                          _ReadOnlyItem(
                            label: '昵称',
                            value: _nicknameController.text,
                          ),
                          _ReadOnlyItem(
                            label: '简介',
                            value: _bioController.text,
                          ),
                        ],
                      ),
                    _PhotoGallery(
                      paths: _photoPaths,
                      editable: _isEditing,
                      onRemove: _removePhoto,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          RevealMotion(
            delay: const Duration(milliseconds: 70),
            child: _ProfileSectionFrame(
              child: SectionCard(
                addTopDivider: false,
                title: '个性与兴趣',
                subtitle: '用易扫描的结构保留自我描述，而不是写成长段自述。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _isEditing
                      ? <Widget>[
                          TextField(
                            controller: _personalitySummaryController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: '个性概述',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _valuesController,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: '价值观'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _personalityTagsController,
                            decoration: const InputDecoration(
                              labelText: '个性标签（逗号分隔）',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _hobbiesController,
                            decoration: const InputDecoration(
                              labelText: '兴趣爱好（逗号分隔）',
                            ),
                          ),
                        ]
                      : <Widget>[
                          _ReadOnlyBlock(
                            items: <_ReadOnlyItem>[
                              _ReadOnlyItem(
                                label: '个性概述',
                                value: _personalitySummaryController.text,
                              ),
                              _ReadOnlyItem(
                                label: '价值观',
                                value: _valuesController.text,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _TagGroup(
                            title: '个性标签',
                            tags: _splitInput(_personalityTagsController.text),
                          ),
                          const SizedBox(height: 16),
                          _TagGroup(
                            title: '兴趣爱好',
                            tags: _splitInput(_hobbiesController.text),
                          ),
                        ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          RevealMotion(
            delay: const Duration(milliseconds: 130),
            child: _ProfileSectionFrame(
              child: SectionCard(
                addTopDivider: false,
                title: '其他信息',
                subtitle: '除了固定档案外，其余内容都以独立模块补充，避免主信息区过载。',
                trailing: _isEditing
                    ? TextButton.icon(
                        onPressed: _addModule,
                        icon: const Icon(Icons.add),
                        label: const Text('新增模块'),
                      )
                    : null,
                child: _modules.isEmpty && !_isEditing
                    ? const Text('还没有补充信息')
                    : Column(
                        children: List<Widget>.generate(_modules.length, (
                          int index,
                        ) {
                          final module = _modules[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _modules.length - 1 ? 0 : 16,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.all(16),
                              color: Colors.white,
                              child: _isEditing
                                  ? Column(
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: TextField(
                                                controller: module.title,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: '模块标题',
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _removeModule(index),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: module.content,
                                          maxLines: 5,
                                          decoration: const InputDecoration(
                                            labelText: '模块内容',
                                          ),
                                        ),
                                      ],
                                    )
                                  : _ReadOnlyBlock(
                                      items: <_ReadOnlyItem>[
                                        _ReadOnlyItem(
                                          label:
                                              module.title.text.trim().isEmpty
                                              ? '未命名模块'
                                              : module.title.text.trim(),
                                          value: module.content.text,
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        }),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _splitInput(String value) {
    return value
        .split(RegExp(r'[，,、\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

}

class _ModuleDraft {
  _ModuleDraft({required this.title, required this.content});

  final TextEditingController title;
  final TextEditingController content;

  void dispose() {
    title.dispose();
    content.dispose();
  }
}

class _ReadOnlyItem {
  const _ReadOnlyItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _ReadOnlyBlock extends StatelessWidget {
  const _ReadOnlyBlock({required this.items});

  final List<_ReadOnlyItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (_ReadOnlyItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.value.trim().isEmpty ? '未填写' : item.value.trim(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          Text('未填写', style: Theme.of(context).textTheme.titleMedium)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (String item) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({
    required this.paths,
    required this.editable,
    required this.onRemove,
  });

  final List<String> paths;
  final bool editable;
  final Future<void> Function(String path) onRemove;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return Text(
        editable ? '还没有添加照片' : '未上传照片',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      children: paths.map((String path) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: path == paths.last ? 0 : 12),
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              children: <Widget>[
                _ProfileImage(path: path),
                if (editable)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: colorScheme.scrim.withValues(alpha: 0.66),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onRemove(path),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AdaptiveTappableImage(
      path: path,
      maxWidth: double.infinity,
      fallbackHeight: 240,
      borderRadius: 0,
      placeholderIcon: Icons.person_outline,
      placeholderColor: colorScheme.secondaryContainer,
      iconColor: colorScheme.onSecondaryContainer,
    );
  }
}

class _ProfileSectionFrame extends StatelessWidget {
  const _ProfileSectionFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: child,
      ),
    );
  }
}
