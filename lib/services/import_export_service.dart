import 'dart:convert';
import 'dart:io';

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

/// 负责本地 JSON 与图片的 ZIP 导出和导入。
class ImportExportService {
  ImportExportService._();

  static final ImportExportService instance = ImportExportService._();

  final AppDatabase _database = AppDatabase.instance;
  final ManagedImageService _imageService = ManagedImageService.instance;

  Future<String> exportAllData() async {
    final snapshot = await _database.dumpData();
    final archive = Archive();
    final payload = await buildPayloadFromSnapshot(snapshot, archive: archive);

    final jsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    final zipBytes = ZipEncoder().encode(archive);

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'personal_record_$timestamp.zip';

    if (kIsWeb) {
      await saveBytesAsDownload(
        bytes: zipBytes,
        fileName: fileName,
        mimeType: 'application/zip',
      );
      return '浏览器下载已开始：$fileName';
    }

    final exportDirectory = await _resolveExportDirectory();
    final targetFile = File(p.join(exportDirectory.path, fileName));
    await targetFile.writeAsBytes(zipBytes, flush: true);
    return targetFile.path;
  }

  Future<String?> importFromPicker() async {
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
      await importFromZipBytes(bytes);
      return file.name;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    await importFromZip(File(path));
    return path;
  }

  Future<void> importFromZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    await importFromZipBytes(bytes);
  }

  Future<void> importFromZipBytes(List<int> bytes) async {
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
    await _imageService.clearAllImages();
    final importedSnapshot = await snapshotFromPayload(
      payload,
      imageEntries: imageEntries,
    );

    await _database.replaceAllData(importedSnapshot);
  }

  Future<void> clearAllLocalData() async {
    await _database.clearAllData();
    await _imageService.clearAllImages();
  }

  @visibleForTesting
  Future<Map<String, dynamic>> buildPayloadFromSnapshot(
    AppDataSnapshot snapshot, {
    Archive? archive,
  }) async {
    final activeArchive = archive ?? Archive();
    final exportedFavorites = <Map<String, dynamic>>[];
    final exportedThoughts = <Map<String, dynamic>>[];
    final exportedProfile = snapshot.profile == null
        ? null
        : await _exportProfile(snapshot.profile!, activeArchive);

    for (final item in snapshot.favorites) {
      final archiveImagePath = await _archiveImageIfExists(
        archive: activeArchive,
        sourcePath: item.localImagePath,
        archiveDirectory: 'images/favorites',
      );
      exportedFavorites.add(item.toJson(archiveImagePath: archiveImagePath));
    }

    for (final item in snapshot.thoughts) {
      exportedThoughts.add(await _exportThought(item, activeArchive));
    }

    return <String, dynamic>{
      'version': 1,
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
  }) async {
    final archiveFiles = imageEntries ?? <String, ArchiveFile>{};
    final importedFavorites = <FavoriteItem>[];
    for (final item
        in (payload['favorites'] as List<dynamic>? ?? <dynamic>[])) {
      final json = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
      final resolvedImagePath = await _restoreArchivePath(
        json['archiveImagePath'] as String?,
        archiveFiles,
      );
      importedFavorites.add(
        FavoriteItem.fromJson(json, resolvedImagePath: resolvedImagePath),
      );
    }

    final importedThoughts = <ThoughtNote>[];
    for (final item in (payload['thoughts'] as List<dynamic>? ?? <dynamic>[])) {
      final json = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
      final resolvedImagePath = await _restoreArchivePath(
        json['archiveImagePath'] as String?,
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
        ThoughtNote.fromJson(json, resolvedImagePath: resolvedImagePath),
      );
    }

    final profileJson = payload['profile'] as Map<String, dynamic>?;
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
        }
        profileJson['photoPaths'] = photoPaths;
      }
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
    final archiveImagePath = await _archiveImageIfExists(
      archive: archive,
      sourcePath: note.localImagePath,
      archiveDirectory: 'images/thoughts',
    );
    final json = note.toJson(archiveImagePath: archiveImagePath);
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
}
