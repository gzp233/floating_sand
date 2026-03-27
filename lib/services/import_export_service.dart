import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/favorite_category.dart';
import '../models/favorite_item.dart';
import '../models/person_profile.dart';
import '../models/thought_note.dart';
import 'app_database.dart';
import 'export_download_helper.dart';
import 'managed_image_service.dart';

typedef ImportExportProgressCallback = void Function(
  double progress,
  String message,
);

class PickedImportSource {
  const PickedImportSource({
    required this.name,
    this.path,
    this.bytes,
  });

  final String name;
  final String? path;
  final List<int>? bytes;
}

/// 负责本地 JSON 与图片的 ZIP 导出和导入。
class ImportExportService {
  ImportExportService._();

  static final ImportExportService instance = ImportExportService._();

  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;

  Future<String> exportAllData({
    ImportExportProgressCallback? onProgress,
  }) async {
    _reportProgress(onProgress, 0.05, '正在读取本地数据');
    final snapshot = await _database.dumpData();
    final archive = Archive();
    _reportProgress(onProgress, 0.15, '正在整理备份内容');
    final payload = await buildPayloadFromSnapshot(
      snapshot,
      archive: archive,
      onProgress: (double progress, String message) {
        _reportProgress(onProgress, 0.15 + progress * 0.65, message);
      },
    );

    _reportProgress(onProgress, 0.82, '正在生成备份文件');
    final jsonBytes = utf8.encode(jsonEncode(payload));
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    _reportProgress(onProgress, 0.9, '正在压缩 ZIP');
    final zipBytes = ZipEncoder().encode(archive);

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'personal_record_$timestamp.zip';

    if (kIsWeb) {
      _reportProgress(onProgress, 0.96, '正在触发浏览器下载');
      await saveBytesAsDownload(
        bytes: zipBytes,
        fileName: fileName,
        mimeType: 'application/zip',
      );
      _reportProgress(onProgress, 1, '导出完成');
      return '浏览器下载已开始：$fileName';
    }

    _reportProgress(onProgress, 0.94, '正在选择导出位置');
    final exportDirectory = await _resolveExportDirectory();
    final targetFile = File(p.join(exportDirectory.path, fileName));
    _reportProgress(onProgress, 0.98, '正在写入 ZIP 文件');
    await targetFile.writeAsBytes(zipBytes, flush: true);
    _reportProgress(onProgress, 1, '导出完成');
    return targetFile.path;
  }

  Future<PickedImportSource?> pickImportSource() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
      dialogTitle: '选择要导入的备份 ZIP',
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) {
      return null;
    }

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('无法读取所选 ZIP 文件');
      }
      return PickedImportSource(name: file.name, bytes: bytes);
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    return PickedImportSource(name: file.name, path: path);
  }

  Future<String?> importFromPicker({
    ImportExportProgressCallback? onProgress,
  }) async {
    final source = await pickImportSource();
    if (source == null) {
      return null;
    }

    await importPickedSource(source, onProgress: onProgress);
    return source.path ?? source.name;
  }

  Future<void> importPickedSource(
    PickedImportSource source, {
    ImportExportProgressCallback? onProgress,
  }) async {
    final bytes = source.bytes;
    if (bytes != null) {
      await importFromZipBytes(bytes, onProgress: onProgress);
      return;
    }

    final path = source.path;
    if (path == null || path.isEmpty) {
      throw StateError('导入文件路径无效');
    }
    await importFromZip(File(path), onProgress: onProgress);
  }

  Future<void> importFromZip(
    File zipFile, {
    ImportExportProgressCallback? onProgress,
  }) async {
    _reportProgress(onProgress, 0.08, '正在读取 ZIP 文件');
    final bytes = await zipFile.readAsBytes();
    await importFromZipBytes(bytes, onProgress: onProgress);
  }

  Future<void> importFromZipBytes(
    List<int> bytes, {
    ImportExportProgressCallback? onProgress,
  }) async {
    _reportProgress(onProgress, 0.12, '正在解析 ZIP 内容');
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = archive.files
        .where((ArchiveFile file) => file.isFile)
        .toList();
    final dataEntry = files.firstWhere(
      (ArchiveFile file) => p.basename(file.name) == 'data.json',
      orElse: () => throw StateError('ZIP 中缺少 data.json'),
    );

    final rawJson = utf8.decode(dataEntry.content as List<int>);
    final payload = jsonDecode(rawJson) as Map<String, dynamic>;
    final imageEntries = <String, ArchiveFile>{
      for (final file in files) file.name: file,
    };
    _reportProgress(onProgress, 0.24, '正在清理旧图片');
    await _imageService.clearAllImages();
    final importedSnapshot = await snapshotFromPayload(
      payload,
      imageEntries: imageEntries,
      onProgress: (double progress, String message) {
        _reportProgress(onProgress, 0.24 + progress * 0.56, message);
      },
    );

    _reportProgress(onProgress, 0.88, '正在写入本地数据库');
    await _database.replaceAllData(importedSnapshot);
    _reportProgress(onProgress, 1, '导入完成');
  }

  Future<void> clearAllLocalData() async {
    await _database.clearAllData();
    await _imageService.clearAllImages();
  }

  @visibleForTesting
  Future<Map<String, dynamic>> buildPayloadFromSnapshot(
    AppDataSnapshot snapshot, {
    Archive? archive,
    ImportExportProgressCallback? onProgress,
  }) async {
    final activeArchive = archive ?? Archive();
    final exportedFavorites = <Map<String, dynamic>>[];
    final exportedThoughts = <Map<String, dynamic>>[];
    final totalUnits = math.max(
      1,
      (snapshot.profile == null ? 0 : 1) +
          snapshot.favorites.length +
          snapshot.thoughts.length,
    );
    var completedUnits = 0;

    void advance(String message) {
      completedUnits++;
      _reportProgress(onProgress, completedUnits / totalUnits, message);
    }

    final exportedProfile = snapshot.profile == null
        ? null
        : await _exportProfile(snapshot.profile!, activeArchive);
    if (snapshot.profile != null) {
      advance('正在整理个人档案');
    }

    for (final item in snapshot.favorites) {
      final archiveImagePaths = await _archiveImageListIfExists(
        archive: activeArchive,
        sourcePaths: item.imagePaths,
        archiveDirectory: 'images/favorites',
      );
      exportedFavorites.add(item.toJson(archiveImagePaths: archiveImagePaths));
      advance('正在整理收藏 ${exportedFavorites.length}/${snapshot.favorites.length}');
    }

    for (final item in snapshot.thoughts) {
      exportedThoughts.add(await _exportThought(item, activeArchive));
      advance('正在整理想法 ${exportedThoughts.length}/${snapshot.thoughts.length}');
    }

    if (snapshot.profile == null &&
        snapshot.favorites.isEmpty &&
        snapshot.thoughts.isEmpty) {
      _reportProgress(onProgress, 1, '没有需要导出的内容，正在生成空备份');
    }

    return <String, dynamic>{
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': exportedProfile,
      'categories': snapshot.categories
          .map((FavoriteCategory item) => item.toJson())
          .toList(),
      'favorites': exportedFavorites,
      'thoughts': exportedThoughts,
    };
  }

  @visibleForTesting
  Future<AppDataSnapshot> snapshotFromPayload(
    Map<String, dynamic> payload, {
    Map<String, ArchiveFile>? imageEntries,
    ImportExportProgressCallback? onProgress,
  }) async {
    final archiveFiles = imageEntries ?? <String, ArchiveFile>{};
    final importedFavorites = <FavoriteItem>[];
    final favoriteList = payload['favorites'] as List<dynamic>? ?? <dynamic>[];
    final thoughtList = payload['thoughts'] as List<dynamic>? ?? <dynamic>[];
    final profileJson = payload['profile'] as Map<String, dynamic>?;
    final profilePhotoCount =
        (profileJson?['photoArchivePaths'] as List<dynamic>? ?? <dynamic>[])
            .length;
    final totalUnits = math.max(
      1,
      favoriteList.length + thoughtList.length + math.max(profilePhotoCount, profileJson == null ? 0 : 1),
    );
    var completedUnits = 0;

    void advance(String message) {
      completedUnits++;
      _reportProgress(onProgress, completedUnits / totalUnits, message);
    }

    for (final item
        in favoriteList) {
      final json = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
      final resolvedImagePaths = await _restoreArchivePaths(
        _readArchivePathList(json, 'archiveImagePaths', 'archiveImagePath'),
        archiveFiles,
      );
      importedFavorites.add(
        FavoriteItem.fromJson(
          json,
          resolvedImagePaths: resolvedImagePaths,
          resolvedImagePath:
              resolvedImagePaths.isEmpty ? null : resolvedImagePaths.first,
        ),
      );
      advance('正在恢复收藏 ${importedFavorites.length}/${favoriteList.length}');
    }

    final importedThoughts = <ThoughtNote>[];
    for (final item in thoughtList) {
      final json = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
      final resolvedImagePaths = await _restoreArchivePaths(
        _readArchivePathList(json, 'archiveImagePaths', 'archiveImagePath'),
        archiveFiles,
      );
      final stepJsonList = (json['steps'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) =>
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList();
      for (final stepJson in stepJsonList) {
        stepJson['imagePath'] =
            await _restoreArchivePath(
              stepJson['archiveImagePath'] as String?,
              archiveFiles,
            ) ??
            stepJson['imagePath'];
      }
      json['steps'] = stepJsonList;
      importedThoughts.add(
        ThoughtNote.fromJson(
          json,
          resolvedImagePaths: resolvedImagePaths,
          resolvedImagePath:
              resolvedImagePaths.isEmpty ? null : resolvedImagePaths.first,
        ),
      );
      advance('正在恢复想法 ${importedThoughts.length}/${thoughtList.length}');
    }

    if (profileJson != null) {
      final photoEntries =
          (profileJson['photoArchivePaths'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList();
      if (photoEntries.isNotEmpty) {
        final photoPaths = <String>[];
        for (final archivePath in photoEntries) {
          final resolvedPath = await _restoreArchivePath(
            archivePath,
            archiveFiles,
          );
          if (resolvedPath != null && resolvedPath.isNotEmpty) {
            photoPaths.add(resolvedPath);
          }
          advance('正在恢复个人图片 ${photoPaths.length}/${photoEntries.length}');
        }
        profileJson['photoPaths'] = photoPaths;
      } else {
        advance('正在恢复个人档案');
      }
    }

    if (favoriteList.isEmpty && thoughtList.isEmpty && profileJson == null) {
      _reportProgress(onProgress, 1, '备份中没有可导入的数据');
    }

    return AppDataSnapshot(
      profile: profileJson == null
          ? null
          : PersonProfile.fromJson(Map<String, dynamic>.from(profileJson)),
      categories: (payload['categories'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => FavoriteCategory.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      favorites: importedFavorites,
      thoughts: importedThoughts,
    );
  }

  Future<Map<String, dynamic>> _exportProfile(
    PersonProfile profile,
    Archive archive,
  ) async {
    final json = profile.toJson();
    final archivePaths = <String>[];
    for (final path in profile.photoPaths) {
      final archivePath = await _archiveImageIfExists(
        archive: archive,
        sourcePath: path,
        archiveDirectory: 'images/profile',
      );
      if (archivePath != null) {
        archivePaths.add(archivePath);
      }
    }
    json['photoArchivePaths'] = archivePaths;
    return json;
  }

  Future<Map<String, dynamic>> _exportThought(
    ThoughtNote note,
    Archive archive,
  ) async {
    final archiveImagePaths = await _archiveImageListIfExists(
      archive: archive,
      sourcePaths: note.imagePaths,
      archiveDirectory: 'images/thoughts',
    );
    final json = note.toJson(archiveImagePaths: archiveImagePaths);
    final steps = <Map<String, dynamic>>[];
    for (final step in note.steps) {
      final stepImageArchivePath = await _archiveImageIfExists(
        archive: archive,
        sourcePath: step.imagePath,
        archiveDirectory: 'images/thought-steps',
      );
      final stepJson = step.toJson();
      stepJson['archiveImagePath'] = stepImageArchivePath;
      steps.add(stepJson);
    }
    json['steps'] = steps;
    return json;
  }

  Future<List<String>> _archiveImageListIfExists({
    required Archive archive,
    required List<String> sourcePaths,
    required String archiveDirectory,
  }) async {
    final archivedPaths = <String>[];
    for (final sourcePath in sourcePaths) {
      final archivePath = await _archiveImageIfExists(
        archive: archive,
        sourcePath: sourcePath,
        archiveDirectory: archiveDirectory,
      );
      if (archivePath != null && archivePath.isNotEmpty) {
        archivedPaths.add(archivePath);
      }
    }
    return archivedPaths;
  }

  Future<String?> _archiveImageIfExists({
    required Archive archive,
    required String sourcePath,
    required String archiveDirectory,
  }) async {
    if (sourcePath.isEmpty || sourcePath.startsWith('data:image/')) {
      return sourcePath.isEmpty ? null : sourcePath;
    }
    final imageFile = File(sourcePath);
    if (!await imageFile.exists()) {
      return null;
    }
    final imageBytes = await imageFile.readAsBytes();
    final archivePath = '$archiveDirectory/${p.basename(sourcePath)}';
    archive.addFile(ArchiveFile(archivePath, imageBytes.length, imageBytes));
    return archivePath;
  }

  ArchiveFile _findArchiveFile(
    Map<String, ArchiveFile> files,
    String archiveImagePath,
  ) {
    final directMatch = files[archiveImagePath];
    if (directMatch != null) {
      return directMatch;
    }

    for (final entry in files.entries) {
      if (entry.key.endsWith(archiveImagePath)) {
        return entry.value;
      }
    }
    throw StateError('备份中的图片文件缺失: $archiveImagePath');
  }

  Future<String?> _restoreArchivePath(
    String? archiveImagePath,
    Map<String, ArchiveFile> imageEntries,
  ) async {
    if (archiveImagePath == null || archiveImagePath.isEmpty) {
      return null;
    }
    if (archiveImagePath.startsWith('data:image/')) {
      return archiveImagePath;
    }
    final entry = _findArchiveFile(imageEntries, archiveImagePath);
    return _imageService.storeImportedBytes(
      bytes: entry.content as List<int>,
      originalName: p.basename(archiveImagePath),
    );
  }

  Future<List<String>> _restoreArchivePaths(
    List<String> archiveImagePaths,
    Map<String, ArchiveFile> imageEntries,
  ) async {
    final restoredPaths = <String>[];
    for (final archivePath in archiveImagePaths) {
      final restoredPath = await _restoreArchivePath(archivePath, imageEntries);
      if (restoredPath != null && restoredPath.isNotEmpty) {
        restoredPaths.add(restoredPath);
      }
    }
    return restoredPaths;
  }

  List<String> _readArchivePathList(
    Map<String, dynamic> json,
    String listKey,
    String legacyKey,
  ) {
    final rawList = json[listKey];
    if (rawList is List) {
      return rawList
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    final legacyValue = json[legacyKey]?.toString().trim() ?? '';
    return legacyValue.isEmpty ? <String>[] : <String>[legacyValue];
  }

  Future<Directory> _resolveExportDirectory() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择 ZIP 导出目录',
    );
    if (selected != null && selected.isNotEmpty) {
      return Directory(selected);
    }

    final documentDirectory = await getApplicationDocumentsDirectory();
    final fallbackDirectory = Directory(
      p.join(documentDirectory.path, 'exports'),
    );
    if (!fallbackDirectory.existsSync()) {
      await fallbackDirectory.create(recursive: true);
    }
    return fallbackDirectory;
  }

  void _reportProgress(
    ImportExportProgressCallback? onProgress,
    double progress,
    String message,
  ) {
    onProgress?.call(progress.clamp(0, 1), message);
  }
}
