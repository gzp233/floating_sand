import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floating_sand/models/favorite_item.dart';
import 'package:floating_sand/services/app_database.dart';
import 'package:floating_sand/services/managed_image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ManagedImageService imageService = ManagedImageService.instance;
  final AppDatabase database = AppDatabase.instance;
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'floating-sand-images',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return tempDirectory.path;
          }
          return tempDirectory.path;
        });
    await database.usePreferencesStoreForTesting();
  });

  tearDown(() async {
    await database.clearAllData();
    await imageService.clearAllImages();
  });

  tearDownAll(() async {
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'reuses the existing file when identical bytes are stored again',
    () async {
      final firstPath = await imageService.storeImportedBytes(
        bytes: <int>[1, 2, 3, 4],
        originalName: 'first.png',
      );
      final secondPath = await imageService.storeImportedBytes(
        bytes: <int>[1, 2, 3, 4],
        originalName: 'second.png',
      );

      expect(firstPath, secondPath);
      expect(File(firstPath).existsSync(), isTrue);
    },
  );

  test('does not delete an image that is still referenced', () async {
    final sharedPath = await imageService.storeImportedBytes(
      bytes: <int>[7, 8, 9, 10],
      originalName: 'shared.png',
    );

    await database.replaceAllData(
      AppDataSnapshot(
        profile: null,
        categories: const [],
        favorites: <FavoriteItem>[
          FavoriteItem(id: 1, title: 'A', localImagePath: sharedPath),
        ],
        thoughts: const [],
      ),
    );

    await imageService.deleteIfExists(sharedPath);
    expect(File(sharedPath).existsSync(), isTrue);

    await database.clearAllData();
    await imageService.deleteIfExists(sharedPath);
    expect(File(sharedPath).existsSync(), isFalse);
  });

  test('cleanupUnusedImages removes orphaned files only', () async {
    final orphanPath = await imageService.storeImportedBytes(
      bytes: <int>[11, 12, 13, 14],
      originalName: 'orphan.png',
    );
    final keptPath = await imageService.storeImportedBytes(
      bytes: <int>[21, 22, 23, 24],
      originalName: 'kept.png',
    );

    await database.replaceAllData(
      AppDataSnapshot(
        profile: null,
        categories: const [],
        favorites: <FavoriteItem>[
          FavoriteItem(id: 1, title: 'A', localImagePath: keptPath),
        ],
        thoughts: const [],
      ),
    );

    final deletedCount = await imageService.cleanupUnusedImages();

    expect(deletedCount, 1);
    expect(File(orphanPath).existsSync(), isFalse);
    expect(File(keptPath).existsSync(), isTrue);
  });

  test('cleanupUnusedImages keeps all referenced images in a multi-image item', () async {
    final keptPathA = await imageService.storeImportedBytes(
      bytes: <int>[31, 32, 33, 34],
      originalName: 'kept-a.png',
    );
    final keptPathB = await imageService.storeImportedBytes(
      bytes: <int>[41, 42, 43, 44],
      originalName: 'kept-b.png',
    );
    final orphanPath = await imageService.storeImportedBytes(
      bytes: <int>[51, 52, 53, 54],
      originalName: 'orphan-b.png',
    );

    await database.replaceAllData(
      AppDataSnapshot(
        profile: null,
        categories: const [],
        favorites: <FavoriteItem>[
          FavoriteItem(
            id: 1,
            title: 'Multi',
            imagePaths: <String>[keptPathA, keptPathB],
            localImagePath: keptPathA,
          ),
        ],
        thoughts: const [],
      ),
    );

    final deletedCount = await imageService.cleanupUnusedImages();

    expect(deletedCount, 1);
    expect(File(keptPathA).existsSync(), isTrue);
    expect(File(keptPathB).existsSync(), isTrue);
    expect(File(orphanPath).existsSync(), isFalse);
  });
}
