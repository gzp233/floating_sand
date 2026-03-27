import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/import_export_service.dart';
import '../widgets/reveal_motion.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'settings_page.dart';

/// 应用主壳层，负责底部导航与个人页侧边栏。
class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImportExportService _importExportService = ImportExportService.instance;
  final ProfilePageController _profilePageController = ProfilePageController();

  int _currentIndex = 0;
  int _refreshSeed = 0;
  bool _isBusy = false;

  bool get _showProfileDrawer => _currentIndex == 1;

  @override
  void dispose() {
    _profilePageController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final confirmed = await _confirmAction(
      title: '导出 ZIP',
      message: '会把当前档案、收藏、想法和图片打包成 ZIP 备份，是否继续？',
      confirmLabel: '导出',
    );
    if (!confirmed) {
      return;
    }

    final path = await _runProgressAction<String>(
      title: '正在导出 ZIP',
      initialMessage: '准备导出数据',
      action: (ImportExportProgressCallback reportProgress) {
        return _importExportService.exportAllData(onProgress: reportProgress);
      },
    );
    if (path == null) {
      return;
    }
    _showMessage(kIsWeb ? path : '数据已导出到: $path');
  }

  Future<void> _handleImport() async {
    if (_isBusy) {
      return;
    }

    final source = await _importExportService.pickImportSource();
    if (source == null) {
      _showMessage('已取消导入');
      return;
    }

    final importPath = await _runProgressAction<String>(
      title: '正在导入 ZIP',
      initialMessage: '准备恢复本地数据',
      action: (ImportExportProgressCallback reportProgress) async {
        await _importExportService.importPickedSource(
          source,
          onProgress: reportProgress,
        );
        return source.path ?? source.name;
      },
    );
    if (importPath == null) {
      return;
    }
    setState(() {
      _refreshSeed++;
    });
    _showMessage('导入完成: $importPath');
  }

  Future<void> _handleClearData() async {
    final confirmed = await _confirmAction(
      title: '清空本地数据',
      message: '这会删除档案、分类、收藏、想法和本地图片，是否继续？',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }

    await _runBusyAction(() async {
      await _importExportService.clearAllLocalData();
      setState(() {
        _refreshSeed++;
      });
      _showMessage('本地数据已清空');
    });
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: destructive
                              ? FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFB33A3A),
                                )
                              : null,
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SettingsPage(
          refreshSeed: _refreshSeed,
          onExport: _handleExport,
          onImport: _handleImport,
          onClearData: _handleClearData,
        ),
      ),
    );
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      await action();
    } catch (error) {
      _showMessage('操作失败: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<T?> _runProgressAction<T>({
    required String title,
    required String initialMessage,
    required Future<T> Function(ImportExportProgressCallback reportProgress)
    action,
  }) async {
    if (_isBusy) {
      return null;
    }

    final progressNotifier = ValueNotifier<_ProgressState>(
      _ProgressState(progress: 0, message: initialMessage),
    );

    setState(() {
      _isBusy = true;
    });

    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext context) {
          return PopScope(
            canPop: false,
            child: ValueListenableBuilder<_ProgressState>(
              valueListenable: progressNotifier,
              builder: (
                BuildContext context,
                _ProgressState state,
                Widget? child,
              ) {
                return AlertDialog(
                  title: Text(title),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LinearProgressIndicator(value: state.progress),
                      const SizedBox(height: 14),
                      Text(state.message),
                      const SizedBox(height: 8),
                      Text(
                        '${(state.progress * 100).round()}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 16));

    try {
      final result = await action((double progress, String message) {
        progressNotifier.value = _ProgressState(
          progress: progress,
          message: message,
        );
      });
      progressNotifier.value = const _ProgressState(
        progress: 1,
        message: '操作完成',
      );
      return result;
    } catch (error) {
      _showMessage('操作失败: $error');
      return null;
    } finally {
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
      progressNotifier.dispose();
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = <Widget>[
      RecordsPage(refreshSeed: _refreshSeed),
      ProfilePage(
        refreshSeed: _refreshSeed,
        controller: _profilePageController,
      ),
    ];

    return Stack(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const <Color>[Color(0xFF101614), Color(0xFF1A221F)]
                  : const <Color>[Color(0xFFF3F1EB), Color(0xFFEEE8DE)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -120,
                right: -80,
                child: IgnorePointer(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark
                              ? const Color(0xFF355148)
                              : const Color(0xFFBFCFC8))
                          .withValues(alpha: isDark ? 0.22 : 0.26),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 70,
                left: -100,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark
                              ? const Color(0xFF4D3E2D)
                              : const Color(0xFFDCCFB9))
                          .withValues(alpha: isDark ? 0.18 : 0.24),
                    ),
                  ),
                ),
              ),
              Scaffold(
                key: _scaffoldKey,
                backgroundColor: Colors.transparent,
                appBar: _showProfileDrawer
                    ? AppBar(
                        automaticallyImplyLeading: false,
                        leading: IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                        title: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.18),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                          child: Text(
                            _titles[_currentIndex],
                            key: ValueKey<int>(_currentIndex),
                          ),
                        ),
                        actions: <Widget>[
                          AnimatedBuilder(
                            animation: _profilePageController,
                            builder: (BuildContext context, Widget? child) {
                              final isEditing = _profilePageController.isEditing;
                              final isSaving = _profilePageController.isSaving;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (isEditing)
                                    TextButton(
                                      onPressed: isSaving
                                          ? null
                                          : _profilePageController.triggerCancel,
                                      child: const Text('取消'),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: FilledButton(
                                      onPressed: isSaving
                                          ? null
                                          : _profilePageController.triggerPrimaryAction,
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(76, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                      ),
                                      child: isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(isEditing ? '保存' : '编辑'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      )
                    : null,
                drawer: _showProfileDrawer
                    ? Drawer(
                        child: SafeArea(
                          child: Column(
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '个人档案侧栏',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '主题、设置、备份和清理都从这里进入，主导航只保留记录本身。',
                                        style: TextStyle(height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '主题',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: SegmentedButton<ThemeMode>(
                                        showSelectedIcon: false,
                                        segments: const <ButtonSegment<ThemeMode>>[
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.system,
                                            label: Text('系统'),
                                            icon: Icon(Icons.brightness_auto_outlined),
                                          ),
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.light,
                                            label: Text('亮色'),
                                            icon: Icon(Icons.light_mode_outlined),
                                          ),
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.dark,
                                            label: Text('暗色'),
                                            icon: Icon(Icons.dark_mode_outlined),
                                          ),
                                        ],
                                        selected: <ThemeMode>{widget.themeMode},
                                        onSelectionChanged: (Set<ThemeMode> selection) {
                                          if (selection.isEmpty) {
                                            return;
                                          }
                                          _handleThemeModeChanged(selection.first);
                                        },
                                      ),
                                    ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.settings_outlined),
                                title: const Text('设置'),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _openSettingsPage();
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
                body: RevealMotion(
                  key: ValueKey<int>(_currentIndex),
                  duration: const Duration(milliseconds: 320),
                  child: IndexedStack(index: _currentIndex, children: pages),
                ),
                bottomNavigationBar: _CompactTextNavigationBar(
                  currentIndex: _currentIndex,
                  onSelected: (int index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        IgnorePointer(
          ignoring: !_isBusy,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _isBusy ? 1 : 0,
            child: ColoredBox(
              color: colorScheme.scrim.withValues(alpha: isDark ? 0.56 : 0.18),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }

  void _handleThemeModeChanged(ThemeMode? value) {
    if (value == null || value == widget.themeMode) {
      return;
    }
    widget.onThemeModeChanged(value);
  }
}

const List<String> _titles = <String>['记录', '个人档案'];

class _ProgressState {
  const _ProgressState({required this.progress, required this.message});

  final double progress;
  final String message;
}

class _CompactTextNavigationBar extends StatelessWidget {
  const _CompactTextNavigationBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labels = <String>['记录', '个人'];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 46,
          child: Row(
            children: List<Widget>.generate(labels.length, (int index) {
              final isSelected = currentIndex == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(index),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: isSelected
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                      child: Text(labels[index]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
