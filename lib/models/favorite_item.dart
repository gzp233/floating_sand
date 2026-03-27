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
    String localImagePath = '',
    List<String> imagePaths = const <String>[],
    this.referenceUrl = '',
    this.note = '',
    DateTime? createdAtValue,
    DateTime? updatedAtValue,
  })  : imagePaths = _normalizeImagePaths(imagePaths, localImagePath),
        localImagePath = _primaryImagePath(imagePaths, localImagePath),
        createdAt = createdAtValue ?? DateTime.now(),
        updatedAt = updatedAtValue ?? DateTime.now();

  Id id;
  String title;
  String category;
  String body;
  List<String> imagePaths;
  String localImagePath;
  String referenceUrl;
  String note;
  DateTime createdAt;
  DateTime updatedAt;

  @ignore
  String get primaryImagePath =>
      imagePaths.isEmpty ? localImagePath : imagePaths.first;

  @ignore
  bool get hasImages => imagePaths.isNotEmpty || localImagePath.trim().isNotEmpty;

  Map<String, dynamic> toJson({List<String>? archiveImagePaths}) {
    final encodedImagePaths = imagePaths.isEmpty && localImagePath.trim().isNotEmpty
        ? <String>[localImagePath]
        : imagePaths;
    final encodedArchivePaths = archiveImagePaths ?? <String>[];
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category,
      'body': body,
      'imagePaths': encodedImagePaths,
      'localImagePath': localImagePath,
      'archiveImagePaths': encodedArchivePaths,
      'archiveImagePath': encodedArchivePaths.isEmpty ? null : encodedArchivePaths.first,
      'referenceUrl': referenceUrl,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static FavoriteItem fromJson(
    Map<String, dynamic> json, {
    String? resolvedImagePath,
    List<String>? resolvedImagePaths,
  }) {
    final parsedImagePaths = _stringListFromJson(json['imagePaths']);
    final imagePaths =
        resolvedImagePaths != null && resolvedImagePaths.isNotEmpty
        ? resolvedImagePaths
        :
        (parsedImagePaths.isEmpty
            ? _normalizeImagePaths(
                resolvedImagePath == null || resolvedImagePath.isEmpty
                    ? null
                    : <String>[resolvedImagePath],
                json['localImagePath'] as String? ?? '',
              )
            : parsedImagePaths);
    return FavoriteItem(
      id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      body: json['body'] as String? ?? json['content'] as String? ?? '',
      imagePaths: imagePaths,
      localImagePath: imagePaths.isEmpty
          ? (resolvedImagePath ?? (json['localImagePath'] as String? ?? ''))
          : imagePaths.first,
      referenceUrl: json['referenceUrl'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAtValue: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAtValue: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static List<String> _normalizeImagePaths(
    List<String>? imagePaths,
    String legacyPath,
  ) {
    final normalized = <String>[];
    for (final path in imagePaths ?? <String>[]) {
      final trimmed = path.trim();
      if (trimmed.isEmpty || normalized.contains(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    final legacyTrimmed = legacyPath.trim();
    if (normalized.isEmpty && legacyTrimmed.isNotEmpty) {
      normalized.add(legacyTrimmed);
    }
    return normalized;
  }

  static String _primaryImagePath(List<String>? imagePaths, String legacyPath) {
    final normalized = _normalizeImagePaths(imagePaths, legacyPath);
    return normalized.isEmpty ? '' : normalized.first;
  }

  static List<String> _stringListFromJson(dynamic value) {
    if (value is! List) {
      return <String>[];
    }
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }
}