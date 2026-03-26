import 'package:isar/isar.dart';

part 'favorite_category.g.dart';

/// 收藏分类，用于编辑页选择与管理。
@collection
class FavoriteCategory {
  FavoriteCategory({
    this.id = Isar.autoIncrement,
    this.name = '',
    DateTime? createdAtValue,
  }) : createdAt = createdAtValue ?? DateTime.now();

  Id id;
  String name;
  DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static FavoriteCategory fromJson(Map<String, dynamic> json) {
    return FavoriteCategory(
      id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
      name: json['name'] as String? ?? '',
      createdAtValue: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}