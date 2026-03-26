import 'package:isar/isar.dart';

part 'favorite_item.g.dart';

/// 收藏项，统一使用图文结构存储。
@collection
class FavoriteItem {
  FavoriteItem({
    this.id = Isar.autoIncrement,
    this.title = '',
    this.category = '',
    this.body = '',
    this.localImagePath = '',
    this.referenceUrl = '',
    this.note = '',
    DateTime? createdAtValue,
    DateTime? updatedAtValue,
  })  : createdAt = createdAtValue ?? DateTime.now(),
        updatedAt = updatedAtValue ?? DateTime.now();

  Id id;
  String title;
  String category;
  String body;
  String localImagePath;
  String referenceUrl;
  String note;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson({String? archiveImagePath}) {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category,
      'body': body,
      'localImagePath': localImagePath,
      'archiveImagePath': archiveImagePath,
      'referenceUrl': referenceUrl,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static FavoriteItem fromJson(
    Map<String, dynamic> json, {
    String? resolvedImagePath,
  }) {
    return FavoriteItem(
      id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      body: json['body'] as String? ?? json['content'] as String? ?? '',
      localImagePath:
          resolvedImagePath ?? (json['localImagePath'] as String? ?? ''),
      referenceUrl: json['referenceUrl'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAtValue: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAtValue: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}