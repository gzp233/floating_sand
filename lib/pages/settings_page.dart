import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/app_database.dart';
import '../services/managed_image_service.dart';
import '../widgets/reveal_motion.dart';
import '../widgets/section_card.dart';

/// 设置页，展示数据概况与本地数据管理入口。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.refreshSeed,
    required this.onExport,
    required this.onImport,
    required this.onClearData,
  });

  final int refreshSeed;
  final Future<void> Function() onExport;
  final Future<void> Function() onImport;
  final Future<void> Function() onClearData;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;
  late Future<_SettingsViewData> _viewDataFuture;

  @override
  void initState() {
    super.initState();
    _viewDataFuture = _loadViewData();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      setState(() {
        _viewDataFuture = _loadViewData();
      });
    }
  }

  Future<_SettingsViewData> _loadViewData() async {
    final summary = await _database.getSummary();
    final managedImageCount = await _resolveManagedImageCount();
    if (kIsWeb) {
      return _SettingsViewData(
        summary: summary,
        storagePath: '当前浏览器的本地存储',
        managedImageCount: managedImageCount,
      );
    }
    final documents = await getApplicationDocumentsDirectory();
    return _SettingsViewData(
      summary: summary,
      storagePath: documents.path,
      managedImageCount: managedImageCount,
    );
  }

  Future<int> _resolveManagedImageCount() async {
    if (kIsWeb) {
      return 0;
    }
    final directory = await _imageService.imageDirectory;
    return directory.listSync().whereType<File>().length;
  }

  void _refreshViewData() {
    if (!mounted) {
      return;
    }
    setState(() {
      _viewDataFuture = _loadViewData();
    });
  }

  Future<void> _handleImport() async {
    await widget.onImport();
    _refreshViewData();
  }

  Future<void> _handleClearData() async {
    await widget.onClearData();
    _refreshViewData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('设置'),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_SettingsViewData>(
          future: _viewDataFuture,
          builder:
              (BuildContext context, AsyncSnapshot<_SettingsViewData> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: <Widget>[
                  RevealMotion(
                    child: SectionCard(
                      addTopDivider: false,
                      title: '数据总览',
                      subtitle: '先看规模，再决定是否导出或清理。',
                      child: _SummaryStrip(data: data),
                    ),
                  ),
                  RevealMotion(
                    delay: const Duration(milliseconds: 80),
                    child: SectionCard(
                      title: '导出与导入',
                      subtitle: kIsWeb
                          ? '导出 ZIP 时会直接触发浏览器下载，导入后会自动恢复本地图片引用。'
                          : '导出 JSON 与图片 ZIP，导入时自动恢复本地图片路径。',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: widget.onExport,
                            icon: const Icon(Icons.archive_outlined),
                            label: const Text('导出所有数据为 ZIP'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _handleImport,
                            icon: const Icon(Icons.unarchive_outlined),
                            label: const Text('从 ZIP 导入数据'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  RevealMotion(
                    delay: const Duration(milliseconds: 160),
                    child: SectionCard(
                      title: '本地数据管理',
                      subtitle: kIsWeb
                          ? 'Web 端数据保存在浏览器本地存储，清空站点数据后内容也会一起移除。'
                          : '应用文档目录用于保存 Isar 数据库文件与已托管图片。',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: kIsWeb
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '当前存储方式',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        data.storagePath,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Web 端没有独立文件目录，刷新浏览器或清空站点数据都可能影响本地内容。',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(height: 1.6),
                                      ),
                                    ],
                                  )
                                : SelectableText(data.storagePath),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _handleClearData,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('清空本地数据'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                );
              },
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.data});

  final _SettingsViewData data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 32,
      runSpacing: 20,
      children: <Widget>[
        _SummaryMetric(
          label: '个人档案',
          value: data.summary.hasProfile ? '已填写' : '未填写',
        ),
        _SummaryMetric(label: '分类总数', value: '${data.summary.categoryCount}'),
        _SummaryMetric(label: '收藏总数', value: '${data.summary.favoriteCount}'),
        _SummaryMetric(label: '图片数量', value: '${data.summary.imageCount}'),
        _SummaryMetric(label: '托管图片', value: '${data.managedImageCount}'),
        _SummaryMetric(label: '想法总数', value: '${data.summary.thoughtCount}'),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsViewData {
  const _SettingsViewData({
    required this.summary,
    required this.storagePath,
    required this.managedImageCount,
  });

  final AppDataSummary summary;
  final String storagePath;
  final int managedImageCount;
}
