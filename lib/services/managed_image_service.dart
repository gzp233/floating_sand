import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/thought_note.dart';
import 'app_database.dart';

/// 管理应用内部图片目录，仅在数据库中保存本地路径。
class ManagedImageService {
  ManagedImageService._();

  static final ManagedImageService instance = ManagedImageService._();
  final AppDatabase _database = AppDatabase.instance;

  Future<Directory> get imageDirectory async {
    final documentDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documentDirectory.path, 'favorite_images'),
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> storePickedImage(XFile image) async {
    final bytes = await image.readAsBytes();
    return _storeBytes(bytes: bytes, extension: p.extension(image.path));
  }

  Future<String> storeImportedBytes({
    required List<int> bytes,
    required String originalName,
  }) async {
    return _storeBytes(bytes: bytes, extension: p.extension(originalName));
  }

  Future<void> deleteIfExists(
    String path, {
    int allowedRetainedReferences = 0,
  }) async {
    if (kIsWeb) {
      return;
    }

    if (path.isEmpty) {
      return;
    }
    final referenceCount = await _countImageReferences(path);
    if (referenceCount > allowedRetainedReferences) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> clearAllImages() async {
    if (kIsWeb) {
      return;
    }

    final directory = await imageDirectory;
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<int> cleanupUnusedImages({Iterable<String>? candidatePaths}) async {
    if (kIsWeb) {
      return 0;
    }

    final directory = await imageDirectory;
    final referencedPaths = await _referencedImagePaths();
    final allowedPaths = candidatePaths
      ?.where((String item) => item.isNotEmpty)
      .toSet();

    var deletedCount = 0;
    for (final file in directory.listSync().whereType<File>()) {
      final path = file.path;
      if (allowedPaths != null && !allowedPaths.contains(path)) {
        continue;
      }
      if (referencedPaths.contains(path)) {
        continue;
      }
      if (await file.exists()) {
        await file.delete();
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<String> _storeBytes({
    required List<int> bytes,
    required String extension,
  }) async {
    if (kIsWeb) {
      return _toDataUri(bytes, extension);
    }

    final directory = await imageDirectory;
    final hash = sha256.convert(bytes).toString();
    final existingPath = _findExistingPathByHash(directory, hash);
    if (existingPath != null) {
      return existingPath;
    }

    final fileName = _buildFileName(hash, extension);
    final target = File(p.join(directory.path, fileName));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<int> _countImageReferences(String path) async {
    final referencedPaths = await _referencedImagePaths();
    return referencedPaths.where((String item) => item == path).length;
  }

  Future<List<String>> _referencedImagePaths() async {
    final snapshot = await _database.dumpData();
    final paths = <String>[];

    final profile = snapshot.profile;
    if (profile != null) {
      paths.addAll(profile.photoPaths.where((String item) => item.isNotEmpty));
    }

    paths.addAll(
      snapshot.favorites.expand(
        (item) => item.imagePaths.where((String path) => path.isNotEmpty),
      ),
    );

    for (final thought in snapshot.thoughts) {
      paths.addAll(
        thought.imagePaths.where((String item) => item.isNotEmpty),
      );
      paths.addAll(
        thought.steps
            .map((ThoughtStep step) => step.imagePath)
            .where((String item) => item.isNotEmpty),
      );
    }

    return paths;
  }

  String? _findExistingPathByHash(Directory directory, String hash) {
    final matches = directory
        .listSync()
        .whereType<File>()
        .where(
          (File file) => p.basenameWithoutExtension(file.path) == 'img_$hash',
        )
        .toList();
    if (matches.isEmpty) {
      return null;
    }
    return matches.first.path;
  }

  String _buildFileName(String hash, String extension) {
    final normalizedExtension = extension.isEmpty ? '.jpg' : extension;
    return 'img_$hash$normalizedExtension';
  }

  String _toDataUri(List<int> bytes, String extension) {
    final mimeType = switch (extension.toLowerCase()) {
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }
}
