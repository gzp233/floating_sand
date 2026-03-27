import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floating_sand/models/favorite_category.dart';
import 'package:floating_sand/models/favorite_item.dart';
import 'package:floating_sand/models/person_profile.dart';
import 'package:floating_sand/models/thought_note.dart';
import 'package:floating_sand/services/app_database.dart';
import 'package:floating_sand/services/import_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportExportService payload codec', () {
    final ImportExportService service = ImportExportService.instance;
    late Directory tempDirectory;

    setUpAll(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'floating-sand-test',
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
      await AppDatabase.instance.usePreferencesStoreForTesting();
      await service.clearAllLocalData();
    });

    tearDown(() async {
      await service.clearAllLocalData();
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

    test('preserves structured snapshot fields across payload round trip', () async {
      final PersonProfile profile = PersonProfile()
        ..nickname = '林北'
        ..bio = '习惯把重要信息整理成卡片。'
        ..hobbies = <String>['摄影', '展览']
        ..personality = ProfilePersonality(
          summary: '偏好提前规划',
          values: '稳定、细致',
          tagsValue: <String>['耐心', '克制'],
        )
        ..customModules = <ProfileCustomModule>[
          ProfileCustomModule(title: '其他信息', content: '周末常去植物园'),
        ]
        ..photoPaths = <String>[
          'data:image/png;base64,${base64Encode(utf8.encode('profile-image'))}',
        ];

      final FavoriteCategory favoriteCategory = FavoriteCategory()..name = '灵感';

      final FavoriteItem favorite = FavoriteItem()
        ..title = '咖啡店参考'
        ..category = '灵感'
        ..body = '适合做空间氛围板'
        ..note = '重点看灯光和材质'
        ..referenceUrl = 'https://example.com/cafe'
        ..localImagePath =
            'data:image/png;base64,${base64Encode(utf8.encode('favorite-image'))}'
        ..createdAt = DateTime(2024, 4, 1, 10)
        ..updatedAt = DateTime(2024, 4, 1, 12);

      final ThoughtNote thought = ThoughtNote()
        ..title = '面试复盘'
        ..category = '工作'
        ..overview = '整理问答和补充材料'
        ..localImagePath =
            'data:image/png;base64,${base64Encode(utf8.encode('thought-cover'))}'
        ..createdAt = DateTime(2024, 5, 2, 9)
        ..updatedAt = DateTime(2024, 5, 2, 11)
        ..steps = <ThoughtStep>[
          ThoughtStep(
            title: '回看问题',
            detail: '记录没有答完整的点',
            possibleQuestion: '哪些回答最有说服力？',
            imagePath:
                'data:image/png;base64,${base64Encode(utf8.encode('step-image'))}',
          ),
        ];

      final AppDataSnapshot snapshot = AppDataSnapshot(
        profile: profile,
        categories: <FavoriteCategory>[favoriteCategory],
        favorites: <FavoriteItem>[favorite],
        thoughts: <ThoughtNote>[thought],
      );

      final Map<String, dynamic> payload = await service
          .buildPayloadFromSnapshot(snapshot);
      final AppDataSnapshot restored = await service.snapshotFromPayload(
        payload,
      );

      expect(restored.profile, isNotNull);
      expect(restored.profile!.nickname, '林北');
      expect(restored.profile!.photoPaths, hasLength(1));
      expect(
        restored.profile!.photoPaths.first,
        startsWith('data:image/png;base64,'),
      );

      expect(restored.categories, hasLength(1));
      expect(restored.categories.first.name, '灵感');

      expect(restored.favorites, hasLength(1));
      expect(
        restored.favorites.first.localImagePath,
        startsWith('data:image/png;base64,'),
      );
      expect(restored.favorites.first.referenceUrl, 'https://example.com/cafe');

      expect(restored.thoughts, hasLength(1));
      expect(restored.thoughts.first.category, '工作');
      expect(
        restored.thoughts.first.localImagePath,
        startsWith('data:image/png;base64,'),
      );
      expect(restored.thoughts.first.steps, hasLength(1));
      expect(
        restored.thoughts.first.steps.first.imagePath,
        startsWith('data:image/png;base64,'),
      );
    });

    test('preserves multiple top-level images across payload round trip', () async {
      final FavoriteItem favorite = FavoriteItem()
        ..title = '多图收藏'
        ..category = '灵感'
        ..imagePaths = <String>[
          'data:image/png;base64,${base64Encode(utf8.encode('favorite-1'))}',
          'data:image/png;base64,${base64Encode(utf8.encode('favorite-2'))}',
        ]
        ..localImagePath =
            'data:image/png;base64,${base64Encode(utf8.encode('favorite-1'))}';

      final ThoughtNote thought = ThoughtNote()
        ..title = '多图想法'
        ..imagePaths = <String>[
          'data:image/png;base64,${base64Encode(utf8.encode('thought-1'))}',
          'data:image/png;base64,${base64Encode(utf8.encode('thought-2'))}',
          'data:image/png;base64,${base64Encode(utf8.encode('thought-3'))}',
        ]
        ..localImagePath =
            'data:image/png;base64,${base64Encode(utf8.encode('thought-1'))}';

      final payload = await service.buildPayloadFromSnapshot(
        const AppDataSnapshot(
          profile: null,
          categories: <FavoriteCategory>[],
          favorites: <FavoriteItem>[],
          thoughts: <ThoughtNote>[],
        ),
      );
      payload['favorites'] = <FavoriteItem>[favorite]
          .map((FavoriteItem item) => item.toJson())
          .toList();
      payload['thoughts'] = <ThoughtNote>[thought]
          .map((ThoughtNote item) => item.toJson())
          .toList();

      final restored = await service.snapshotFromPayload(payload);

      expect(restored.favorites.single.imagePaths, hasLength(2));
      expect(
        restored.favorites.single.primaryImagePath,
        restored.favorites.single.imagePaths.first,
      );
      expect(restored.thoughts.single.imagePaths, hasLength(3));
      expect(
        restored.thoughts.single.primaryImagePath,
        restored.thoughts.single.imagePaths.first,
      );
    });

    test('keeps plain file paths when no archive entry exists', () async {
      final Map<String, dynamic> payload = <String, dynamic>{
        'profile': <String, dynamic>{
          'nickname': '测试',
          'photoPaths': <String>['images/profile/local-photo.png'],
        },
        'categories': <Map<String, dynamic>>[],
        'favorites': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': '本地文件',
            'category': '',
            'body': '',
            'note': '',
            'referenceUrl': '',
            'localImagePath': 'images/favorites/item.png',
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
          },
        ],
        'thoughts': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': '纯路径',
            'category': '',
            'overview': '',
            'localImagePath': 'images/thoughts/cover.png',
            'steps': <Map<String, dynamic>>[
              <String, dynamic>{
                'title': '步骤',
                'detail': '说明',
                'possibleQuestion': '',
                'imagePath': 'images/thoughts/step.png',
              },
            ],
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
          },
        ],
      };

      final AppDataSnapshot restored = await service.snapshotFromPayload(
        payload,
      );

      expect(restored.profile, isNotNull);
      expect(
        restored.profile!.photoPaths.single,
        'images/profile/local-photo.png',
      );
      expect(
        restored.favorites.single.localImagePath,
        'images/favorites/item.png',
      );
      expect(
        restored.thoughts.single.localImagePath,
        'images/thoughts/cover.png',
      );
      expect(
        restored.thoughts.single.steps.single.imagePath,
        'images/thoughts/step.png',
      );
    });

    test('imports a real zip file and restores archived images', () async {
      final archive = Archive();
      final payload = <String, dynamic>{
        'version': 1,
        'profile': <String, dynamic>{
          'nickname': 'ZIP 用户',
          'bio': '来自真实 ZIP 用例',
          'photoArchivePaths': <String>['images/profile/profile.png'],
          'photoPaths': <String>[],
          'personality': <String, dynamic>{
            'summary': '谨慎',
            'values': '真实',
            'tags': <String>['稳定'],
          },
          'hobbies': <String>['阅读'],
          'customModules': <Map<String, dynamic>>[],
          'updatedAt': DateTime(2024, 1, 1).toIso8601String(),
        },
        'categories': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '参考',
            'createdAt': DateTime(2024, 1, 1).toIso8601String(),
          },
        ],
        'favorites': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'title': 'ZIP 收藏',
            'category': '参考',
            'body': '来自压缩包',
            'note': '校验图片恢复',
            'referenceUrl': '',
            'localImagePath': '',
            'archiveImagePath': 'images/favorites/favorite.png',
            'createdAt': DateTime(2024, 1, 2).toIso8601String(),
            'updatedAt': DateTime(2024, 1, 2).toIso8601String(),
          },
        ],
        'thoughts': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'title': 'ZIP 想法',
            'category': '工作',
            'overview': '覆盖导入链路',
            'localImagePath': '',
            'archiveImagePath': 'images/thoughts/thought.png',
            'steps': <Map<String, dynamic>>[
              <String, dynamic>{
                'title': '步骤一',
                'detail': '导入真实 zip',
                'possibleQuestion': '图片是否落盘',
                'imagePath': '',
                'archiveImagePath': 'images/thought-steps/step.png',
              },
            ],
            'createdAt': DateTime(2024, 1, 3).toIso8601String(),
            'updatedAt': DateTime(2024, 1, 3).toIso8601String(),
          },
        ],
      };

      final profileBytes = <int>[1, 2, 3, 4];
      final favoriteBytes = <int>[5, 6, 7, 8];
      final thoughtBytes = <int>[9, 10, 11, 12];
      final stepBytes = <int>[13, 14, 15, 16];
      final jsonBytes = utf8.encode(jsonEncode(payload));

      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      archive.addFile(
        ArchiveFile(
          'images/profile/profile.png',
          profileBytes.length,
          profileBytes,
        ),
      );
      archive.addFile(
        ArchiveFile(
          'images/favorites/favorite.png',
          favoriteBytes.length,
          favoriteBytes,
        ),
      );
      archive.addFile(
        ArchiveFile(
          'images/thoughts/thought.png',
          thoughtBytes.length,
          thoughtBytes,
        ),
      );
      archive.addFile(
        ArchiveFile(
          'images/thought-steps/step.png',
          stepBytes.length,
          stepBytes,
        ),
      );

      final zipBytes = ZipEncoder().encode(archive);
      final zipFile = File('${tempDirectory.path}/fixture.zip');
      await zipFile.writeAsBytes(zipBytes, flush: true);

      await service.importFromZip(zipFile);
      final restored = await AppDatabase.instance.dumpData();

      expect(restored.profile, isNotNull);
      expect(restored.profile!.nickname, 'ZIP 用户');
      expect(restored.profile!.photoPaths.single, isNotEmpty);
      expect(File(restored.profile!.photoPaths.single).existsSync(), isTrue);

      expect(restored.categories.single.name, '参考');
      expect(restored.favorites.single.title, 'ZIP 收藏');
      expect(
        File(restored.favorites.single.localImagePath).existsSync(),
        isTrue,
      );

      expect(restored.thoughts.single.title, 'ZIP 想法');
      expect(
        File(restored.thoughts.single.localImagePath).existsSync(),
        isTrue,
      );
      expect(
        File(restored.thoughts.single.steps.single.imagePath).existsSync(),
        isTrue,
      );
    });

    test('imports zip payload from raw bytes', () async {
      final archive = Archive();
      final payload = <String, dynamic>{
        'version': 1,
        'profile': <String, dynamic>{
          'nickname': '字节导入',
          'bio': '直接用内存字节导入',
          'photoArchivePaths': <String>[],
          'photoPaths': <String>[],
          'personality': <String, dynamic>{
            'summary': '',
            'values': '',
            'tags': <String>[],
          },
          'hobbies': <String>[],
          'customModules': <Map<String, dynamic>>[],
          'updatedAt': DateTime(2024, 3, 1).toIso8601String(),
        },
        'categories': <Map<String, dynamic>>[],
        'favorites': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'title': '字节收藏',
            'category': '',
            'body': '来自 bytes',
            'note': '',
            'referenceUrl': '',
            'localImagePath': '',
            'createdAt': DateTime(2024, 3, 1).toIso8601String(),
            'updatedAt': DateTime(2024, 3, 1).toIso8601String(),
          },
        ],
        'thoughts': <Map<String, dynamic>>[],
      };
      final jsonBytes = utf8.encode(jsonEncode(payload));
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

      final zipBytes = ZipEncoder().encode(archive);
      await service.importFromZipBytes(zipBytes);

      final restored = await AppDatabase.instance.dumpData();
      expect(restored.profile, isNotNull);
      expect(restored.profile!.nickname, '字节导入');
      expect(restored.favorites.single.title, '字节收藏');
    });

    test(
      'reuses one stored image path for duplicate archive images across modules',
      () async {
        final archive = Archive();
        final payload = <String, dynamic>{
          'version': 1,
          'profile': <String, dynamic>{
            'nickname': '重复图用户',
            'bio': '',
            'photoArchivePaths': <String>['images/profile/shared.png'],
            'photoPaths': <String>[],
            'personality': <String, dynamic>{
              'summary': '',
              'values': '',
              'tags': <String>[],
            },
            'hobbies': <String>[],
            'customModules': <Map<String, dynamic>>[],
            'updatedAt': DateTime(2024, 2, 1).toIso8601String(),
          },
          'categories': <Map<String, dynamic>>[],
          'favorites': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'title': '收藏共享图',
              'category': '',
              'body': '',
              'note': '',
              'referenceUrl': '',
              'localImagePath': '',
              'archiveImagePath': 'images/favorites/shared-copy.png',
              'createdAt': DateTime(2024, 2, 1).toIso8601String(),
              'updatedAt': DateTime(2024, 2, 1).toIso8601String(),
            },
          ],
          'thoughts': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'title': '想法共享图',
              'category': '',
              'overview': '',
              'localImagePath': '',
              'archiveImagePath': 'images/thoughts/shared-another.png',
              'steps': <Map<String, dynamic>>[
                <String, dynamic>{
                  'title': '步骤一',
                  'detail': '',
                  'possibleQuestion': '',
                  'imagePath': '',
                  'archiveImagePath': 'images/thought-steps/shared-step.png',
                },
              ],
              'createdAt': DateTime(2024, 2, 1).toIso8601String(),
              'updatedAt': DateTime(2024, 2, 1).toIso8601String(),
            },
          ],
        };

        final sharedBytes = <int>[31, 32, 33, 34, 35];
        final jsonBytes = utf8.encode(jsonEncode(payload));

        archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
        archive.addFile(
          ArchiveFile(
            'images/profile/shared.png',
            sharedBytes.length,
            sharedBytes,
          ),
        );
        archive.addFile(
          ArchiveFile(
            'images/favorites/shared-copy.png',
            sharedBytes.length,
            sharedBytes,
          ),
        );
        archive.addFile(
          ArchiveFile(
            'images/thoughts/shared-another.png',
            sharedBytes.length,
            sharedBytes,
          ),
        );
        archive.addFile(
          ArchiveFile(
            'images/thought-steps/shared-step.png',
            sharedBytes.length,
            sharedBytes,
          ),
        );

        final zipBytes = ZipEncoder().encode(archive);
        final zipFile = File('${tempDirectory.path}/duplicate-fixture.zip');
        await zipFile.writeAsBytes(zipBytes, flush: true);

        await service.importFromZip(zipFile);
        final restored = await AppDatabase.instance.dumpData();
        final sharedPath = restored.profile!.photoPaths.single;

        expect(restored.favorites.single.localImagePath, sharedPath);
        expect(restored.thoughts.single.localImagePath, sharedPath);
        expect(restored.thoughts.single.steps.single.imagePath, sharedPath);
        expect(File(sharedPath).existsSync(), isTrue);
      },
    );
  });
}
