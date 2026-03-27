import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_category.dart';
import '../models/favorite_item.dart';
import '../models/person_profile.dart';
import '../models/thought_note.dart';

/// 统一管理 Isar 数据库的初始化与增删改查。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const String _webStorageKey = 'personal_record_web_storage';

  Isar? _isar;
  SharedPreferences? _preferences;
  bool _forcePreferencesStore = false;

  Future<void> initialize() async {
    if (_useWebStore && _preferences != null) {
      return;
    }

    if (!_useWebStore && _isar != null && _isar!.isOpen) {
      return;
    }

    if (_useWebStore) {
      _preferences = await SharedPreferences.getInstance();
      return;
    }

    final schemas = <CollectionSchema>[
      PersonProfileSchema,
      FavoriteCategorySchema,
      FavoriteItemSchema,
      ThoughtNoteSchema,
    ];

    final directory = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      schemas,
      directory: directory.path,
      name: 'personal_record_db',
    );
  }

  bool get _useWebStore => kIsWeb || _forcePreferencesStore;

  @visibleForTesting
  Future<void> usePreferencesStoreForTesting() async {
    _forcePreferencesStore = true;
    _preferences = await SharedPreferences.getInstance();
  }

  Isar get database {
    final isar = _isar;
    if (isar == null || !isar.isOpen) {
      throw StateError('数据库尚未初始化');
    }
    return isar;
  }

  Future<PersonProfile?> getProfile() async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      return snapshot.profile;
    }
    return database.personProfiles.get(1);
  }

  Future<void> saveProfile(PersonProfile profile) async {
    profile.id = 1;
    profile.updatedAt = DateTime.now();
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      await _writeWebSnapshot(
        AppDataSnapshot(
          profile: profile,
          categories: snapshot.categories,
          favorites: snapshot.favorites,
          thoughts: snapshot.thoughts,
        ),
      );
      return;
    }
    await database.writeTxn(() async {
      await database.personProfiles.put(profile);
    });
  }

  Future<List<FavoriteItem>> getFavorites() async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final items = List<FavoriteItem>.from(snapshot.favorites);
      items.sort(
        (FavoriteItem a, FavoriteItem b) => b.updatedAt.compareTo(a.updatedAt),
      );
      return items;
    }
    final items = await database.favoriteItems.where().findAll();
    items.sort(
      (FavoriteItem a, FavoriteItem b) => b.updatedAt.compareTo(a.updatedAt),
    );
    return items;
  }

  Future<List<FavoriteCategory>> getFavoriteCategories() async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final items = List<FavoriteCategory>.from(snapshot.categories);
      items.sort(
        (FavoriteCategory a, FavoriteCategory b) =>
            a.createdAt.compareTo(b.createdAt),
      );
      return items;
    }
    final items = await database.favoriteCategorys.where().findAll();
    items.sort(
      (FavoriteCategory a, FavoriteCategory b) =>
          a.createdAt.compareTo(b.createdAt),
    );
    return items;
  }

  Future<FavoriteCategory> saveFavoriteCategory(
    FavoriteCategory category,
  ) async {
    final normalizedName = category.name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('分类名称不能为空');
    }

    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final items = List<FavoriteCategory>.from(snapshot.categories);
      final duplicate = items.any(
        (FavoriteCategory current) =>
            current.id != category.id && current.name == normalizedName,
      );
      if (duplicate) {
        throw StateError('分类已存在');
      }

      final assignedCategory = category.id == Isar.autoIncrement
          ? FavoriteCategory(
              id: _nextWebId(
                items.map((FavoriteCategory current) => current.id),
              ),
              name: normalizedName,
              createdAtValue: category.createdAt,
            )
          : FavoriteCategory(
              id: category.id,
              name: normalizedName,
              createdAtValue: category.createdAt,
            );
      final targetIndex = items.indexWhere(
        (FavoriteCategory current) => current.id == assignedCategory.id,
      );
      if (targetIndex == -1) {
        items.add(assignedCategory);
      } else {
        items[targetIndex] = assignedCategory;
      }
      await _writeWebSnapshot(
        AppDataSnapshot(
          profile: snapshot.profile,
          categories: items,
          favorites: snapshot.favorites,
          thoughts: snapshot.thoughts,
        ),
      );
      return assignedCategory;
    }

    final duplicate = await database.favoriteCategorys
        .filter()
        .nameEqualTo(normalizedName)
        .findFirst();
    if (duplicate != null && duplicate.id != category.id) {
      throw StateError('分类已存在');
    }

    final storedCategory = FavoriteCategory(
      id: category.id,
      name: normalizedName,
      createdAtValue: category.createdAt,
    );
    await database.writeTxn(() async {
      storedCategory.id = await database.favoriteCategorys.put(storedCategory);
    });
    return storedCategory;
  }

  Future<void> deleteFavoriteCategory(Id id) async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final categoryName = _categoryNameById(snapshot.categories, id) ?? '';
      final isInUse = categoryName.isNotEmpty &&
          (snapshot.favorites.any(
                (FavoriteItem item) => item.category == categoryName,
              ) ||
              snapshot.thoughts.any(
                (ThoughtNote item) => item.category == categoryName,
              ));
      if (isInUse) {
        throw StateError('该分类下还有想法或收藏，无法删除');
      }
      final categories = snapshot.categories
          .where((FavoriteCategory item) => item.id != id)
          .toList();
      await _writeWebSnapshot(
        AppDataSnapshot(
          profile: snapshot.profile,
          categories: categories,
          favorites: snapshot.favorites,
          thoughts: snapshot.thoughts,
        ),
      );
      return;
    }

    final category = await database.favoriteCategorys.get(id);
    final categoryName = category?.name;
    if (categoryName != null && categoryName.isNotEmpty) {
      final favoriteInUse = await database.favoriteItems
          .filter()
          .categoryEqualTo(categoryName)
          .findFirst();
      final thoughtInUse = await database.thoughtNotes
          .filter()
          .categoryEqualTo(categoryName)
          .findFirst();
      if (favoriteInUse != null || thoughtInUse != null) {
        throw StateError('该分类下还有想法或收藏，无法删除');
      }
    }
    await database.writeTxn(() async {
      await database.favoriteCategorys.delete(id);
    });
  }

  Future<void> saveFavorite(FavoriteItem item) async {
    item.updatedAt = DateTime.now();
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final items = List<FavoriteItem>.from(snapshot.favorites);
      final index = items.indexWhere(
        (FavoriteItem current) => current.id == item.id,
      );
      final assignedItem = index == -1 && item.id == Isar.autoIncrement
          ? FavoriteItem(
              id: _nextWebId(items.map((FavoriteItem current) => current.id)),
              title: item.title,
              category: item.category,
              body: item.body,
              imagePaths: item.imagePaths,
              localImagePath: item.localImagePath,
              referenceUrl: item.referenceUrl,
              note: item.note,
              createdAtValue: item.createdAt,
              updatedAtValue: item.updatedAt,
            )
          : item;
      final targetIndex = items.indexWhere(
        (FavoriteItem current) => current.id == assignedItem.id,
      );
      if (targetIndex == -1) {
        items.add(assignedItem);
      } else {
        items[targetIndex] = assignedItem;
      }
      await _writeWebSnapshot(
        AppDataSnapshot(
          profile: snapshot.profile,
          categories: snapshot.categories,
          favorites: items,
          thoughts: snapshot.thoughts,
        ),
      );
      return;
    }
    await database.writeTxn(() async {
      await database.favoriteItems.put(item);
    });
  }

  Future<void> deleteFavorite(Id id) async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final items = snapshot.favorites
          .where((FavoriteItem item) => item.id != id)
          .toList();
      await _writeWebSnapshot(
        AppDataSnapshot(
          profile: snapshot.profile,
          categories: snapshot.categories,
          favorites: items,
          thoughts: snapshot.thoughts,
        ),
      );
      return;
    }
    await database.writeTxn(() async {
      await database.favoriteItems.delete(id);
    });
  }

  Future<FavoriteItem?> getFavoriteById(Id id) async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      for (final item in snapshot.favorites) {
        if (item.id == id) {
          return item;
        }
      }
      return null;
    }
    return database.favoriteItems.get(id);
  }

  Future<List<ThoughtNote>> getThoughts() async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final items = List<ThoughtNote>.from(snapshot.thoughts);
      items.sort(
        (ThoughtNote a, ThoughtNote b) => b.updatedAt.compareTo(a.updatedAt),
      );
      return items;
    }
    final items = await database.thoughtNotes.where().findAll();
    items.sort(
      (ThoughtNote a, ThoughtNote b) => b.updatedAt.compareTo(a.updatedAt),
    );
    return items;
  }

  Future<List<String>> getThoughtCategories() async {
    final categories = await getFavoriteCategories();
    return categories.map((FavoriteCategory item) => item.name).toList();
  }

  Future<Map<String, int>> getCategoryUsageCounts() async {
    final favorites = await getFavorites();
    final thoughts = await getThoughts();
    final counts = <String, int>{};
    for (final item in favorites) {
      final category = item.category.trim();
      if (category.isEmpty) {
        continue;
      }
      counts[category] = (counts[category] ?? 0) + 1;
    }
    for (final item in thoughts) {
      final category = item.category.trim();
      if (category.isEmpty) {
        continue;
      }
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> saveThought(ThoughtNote note) async {
    note.updatedAt = DateTime.now();
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final items = List<ThoughtNote>.from(snapshot.thoughts);
      final index = items.indexWhere(
        (ThoughtNote current) => current.id == note.id,
      );
      final assignedNote = index == -1 && note.id == Isar.autoIncrement
          ? ThoughtNote(
              id: _nextWebId(items.map((ThoughtNote current) => current.id)),
              title: note.title,
              category: note.category,
              overview: note.overview,
              imagePaths: note.imagePaths,
              localImagePath: note.localImagePath,
              stepsValue: note.steps,
              createdAtValue: note.createdAt,
              updatedAtValue: note.updatedAt,
            )
          : note;
      final targetIndex = items.indexWhere(
        (ThoughtNote current) => current.id == assignedNote.id,
      );
      if (targetIndex == -1) {
        items.add(assignedNote);
      } else {
        items[targetIndex] = assignedNote;
      }
      await _writeWebSnapshot(
        AppDataSnapshot(
          profile: snapshot.profile,
          categories: snapshot.categories,
          favorites: snapshot.favorites,
          thoughts: items,
        ),
      );
      return;
    }
    await database.writeTxn(() async {
      await database.thoughtNotes.put(note);
    });
  }

  Future<void> deleteThought(Id id) async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      final items = snapshot.thoughts
          .where((ThoughtNote item) => item.id != id)
          .toList();
      await _writeWebSnapshot(
        AppDataSnapshot(
          profile: snapshot.profile,
          categories: snapshot.categories,
          favorites: snapshot.favorites,
          thoughts: items,
        ),
      );
      return;
    }
    await database.writeTxn(() async {
      await database.thoughtNotes.delete(id);
    });
  }

  Future<ThoughtNote?> getThoughtById(Id id) async {
    if (_useWebStore) {
      final snapshot = await _readWebSnapshot();
      for (final item in snapshot.thoughts) {
        if (item.id == id) {
          return item;
        }
      }
      return null;
    }
    return database.thoughtNotes.get(id);
  }

  Future<AppDataSnapshot> dumpData() async {
    return AppDataSnapshot(
      profile: await getProfile(),
      categories: await getFavoriteCategories(),
      favorites: await getFavorites(),
      thoughts: await getThoughts(),
    );
  }

  Future<void> replaceAllData(AppDataSnapshot snapshot) async {
    if (_useWebStore) {
      await _writeWebSnapshot(snapshot);
      return;
    }
    await database.writeTxn(() async {
      await database.personProfiles.clear();
      await database.favoriteCategorys.clear();
      await database.favoriteItems.clear();
      await database.thoughtNotes.clear();

      if (snapshot.profile != null) {
        await database.personProfiles.put(snapshot.profile!);
      }
      if (snapshot.categories.isNotEmpty) {
        await database.favoriteCategorys.putAll(snapshot.categories);
      }
      if (snapshot.favorites.isNotEmpty) {
        await database.favoriteItems.putAll(snapshot.favorites);
      }
      if (snapshot.thoughts.isNotEmpty) {
        await database.thoughtNotes.putAll(snapshot.thoughts);
      }
    });
  }

  Future<void> clearAllData() async {
    if (_useWebStore) {
      await _writeWebSnapshot(
        const AppDataSnapshot(
          profile: null,
          categories: <FavoriteCategory>[],
          favorites: <FavoriteItem>[],
          thoughts: <ThoughtNote>[],
        ),
      );
      return;
    }
    await database.writeTxn(() async {
      await database.personProfiles.clear();
      await database.favoriteCategorys.clear();
      await database.favoriteItems.clear();
      await database.thoughtNotes.clear();
    });
  }

  Future<AppDataSummary> getSummary() async {
    final profile = await getProfile();
    final categories = await getFavoriteCategories();
    final favorites = await getFavorites();
    final thoughts = await getThoughts();

    return AppDataSummary(
      hasProfile: profile != null,
      categoryCount: categories.length,
      favoriteCount: favorites.length,
      imageCount: (profile?.photoPaths.length ?? 0) +
          favorites.fold<int>(
            0,
            (int total, FavoriteItem item) => total + item.imagePaths.length,
          ) +
          thoughts.fold<int>(0, (int total, ThoughtNote item) {
            final stepImageCount = item.steps
                .where((ThoughtStep step) => step.imagePath.trim().isNotEmpty)
                .length;
            return total + item.imagePaths.length + stepImageCount;
          }),
      thoughtCount: thoughts.length,
    );
  }

  Future<AppDataSnapshot> _readWebSnapshot() async {
    final preferences = _preferences;
    if (preferences == null) {
      throw StateError('Web 存储尚未初始化');
    }

    final raw = preferences.getString(_webStorageKey);
    if (raw == null || raw.isEmpty) {
      return const AppDataSnapshot(
        profile: null,
        categories: <FavoriteCategory>[],
        favorites: <FavoriteItem>[],
        thoughts: <ThoughtNote>[],
      );
    }

    final json = jsonDecode(raw) as Map<String, dynamic>;
    final profileJson = json['profile'] as Map<String, dynamic>?;
    final categories = (json['categories'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) => FavoriteCategory.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList();
    final favorites = (json['favorites'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) => FavoriteItem.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList();
    final thoughts = (json['thoughts'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) => ThoughtNote.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList();

    return AppDataSnapshot(
      profile: profileJson == null
          ? null
          : PersonProfile.fromJson(Map<String, dynamic>.from(profileJson)),
      categories: categories,
      favorites: favorites,
      thoughts: thoughts,
    );
  }

  Future<void> _writeWebSnapshot(AppDataSnapshot snapshot) async {
    final preferences = _preferences;
    if (preferences == null) {
      throw StateError('Web 存储尚未初始化');
    }

    final payload = <String, dynamic>{
      'profile': snapshot.profile?.toJson(),
      'categories': snapshot.categories
          .map((FavoriteCategory item) => item.toJson())
          .toList(),
      'favorites': snapshot.favorites
          .map((FavoriteItem item) => item.toJson())
          .toList(),
      'thoughts': snapshot.thoughts
          .map((ThoughtNote item) => item.toJson())
          .toList(),
    };
    await preferences.setString(_webStorageKey, jsonEncode(payload));
  }

  String? _categoryNameById(List<FavoriteCategory> categories, Id id) {
    for (final item in categories) {
      if (item.id == id) {
        return item.name;
      }
    }
    return null;
  }

  int _nextWebId(Iterable<int> ids) {
    var maxId = 0;
    for (final id in ids) {
      if (id > maxId && id != Isar.autoIncrement) {
        maxId = id;
      }
    }
    return maxId + 1;
  }
}

class AppDataSnapshot {
  const AppDataSnapshot({
    required this.profile,
    required this.categories,
    required this.favorites,
    required this.thoughts,
  });

  final PersonProfile? profile;
  final List<FavoriteCategory> categories;
  final List<FavoriteItem> favorites;
  final List<ThoughtNote> thoughts;
}

class AppDataSummary {
  const AppDataSummary({
    required this.hasProfile,
    required this.categoryCount,
    required this.favoriteCount,
    required this.imageCount,
    required this.thoughtCount,
  });

  final bool hasProfile;
  final int categoryCount;
  final int favoriteCount;
  final int imageCount;
  final int thoughtCount;
}
