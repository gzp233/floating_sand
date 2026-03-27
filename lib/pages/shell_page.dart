import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/import_export_service.dart';
import '../services/managed_image_service.dart';
import '../widgets/reveal_motion.dart';
import 'favorites_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'thoughts_page.dart';

/// 应用主壳层，负责底部导航与个人页侧边栏。
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImportExportService _importExportService = ImportExportService.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;

  int _currentIndex = 0;
  int _refreshSeed = 0;
  bool _isBusy = false;

  bool get _showProfileDrawer => _currentIndex == 2;

  Future<void> _handleExport() async {
    final confirmed = await _confirmAction(
      title: '导出 ZIP',
      message: '会把当前档案、收藏、想法和图片打包成 ZIP 备份，是否继续？',
      confirmLabel: '导出',
    );
    if (!confirmed) {
      return;
    }

    await _runBusyAction(() async {
      final path = await _importExportService.exportAllData();
      _showMessage(kIsWeb ? path : '数据已导出到: $path');
    });
  }

  Future<void> _handleImport() async {
    await _runBusyAction(() async {
      final importPath = await _importExportService.importFromPicker();
      if (importPath == null) {
        _showMessage('已取消导入');
        return;
      }
      setState(() {
        _refreshSeed++;
      });
      _showMessage('导入完成: $importPath');
    });
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

  Future<int> _handleCleanupUnusedImages() async {
    var deletedCount = 0;
    await _runBusyAction(() async {
      deletedCount = await _imageService.cleanupUnusedImages();
    });
    return deletedCount;
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
          onCleanupUnusedImages: _handleCleanupUnusedImages,
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
    final pages = <Widget>[
      ThoughtsPage(refreshSeed: _refreshSeed),
      FavoritesPage(refreshSeed: _refreshSeed),
      ProfilePage(refreshSeed: _refreshSeed),
    ];

    return Stack(
      children: <Widget>[
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Color(0xFFF3F1EB), Color(0xFFEEE8DE)],
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
                      color: const Color(0xFFBFCFC8).withValues(alpha: 0.26),
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
                      color: const Color(0xFFDCCFB9).withValues(alpha: 0.24),
                    ),
                  ),
                ),
              ),
              Scaffold(
                key: _scaffoldKey,
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  leading: _showProfileDrawer
                      ? IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        )
                      : null,
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
                ),
                drawer: _showProfileDrawer
                    ? Drawer(
                        child: SafeArea(
                          child: Column(
                            children: <Widget>[
                              const Padding(
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
                                        '设置、备份和清理都从个人入口进入，主导航只保留记录本身。',
                                        style: TextStyle(height: 1.5),
                                      ),
                                    ],
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
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _currentIndex,
                  indicatorColor: const Color(0xFFDCCFB9),
                  onDestinationSelected: (int index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.lightbulb_outline),
                      selectedIcon: Icon(Icons.lightbulb),
                      label: '想法',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.collections_bookmark_outlined),
                      selectedIcon: Icon(Icons.collections_bookmark),
                      label: '收藏',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.badge_outlined),
                      selectedIcon: Icon(Icons.badge),
                      label: '个人',
                    ),
                  ],
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
            child: const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }
}

const List<String> _titles = <String>['想法记录', '收藏内容', '个人档案'];
