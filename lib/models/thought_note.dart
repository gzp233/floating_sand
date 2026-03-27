import 'package:isar/isar.dart';

part 'thought_note.g.dart';

/// 想法记录，支持步骤和问题列表等结构化内容。
@collection
class ThoughtNote {
  ThoughtNote({
    this.id = Isar.autoIncrement,
    this.title = '',
    this.category = '',
    this.overview = '',
    String localImagePath = '',
    List<String> imagePaths = const <String>[],
    List<ThoughtStep>? stepsValue,
    DateTime? createdAtValue,
    DateTime? updatedAtValue,
  }) : imagePaths = _normalizeImagePaths(imagePaths, localImagePath),
       localImagePath = _primaryImagePath(imagePaths, localImagePath),
       steps = stepsValue ?? <ThoughtStep>[],
       createdAt = createdAtValue ?? DateTime.now(),
       updatedAt = updatedAtValue ?? DateTime.now();

  Id id;
  String title;
  String category;
  String overview;
  List<String> imagePaths;
  String localImagePath;
  List<ThoughtStep> steps;
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
      'overview': overview,
      'imagePaths': encodedImagePaths,
      'localImagePath': localImagePath,
      'archiveImagePaths': encodedArchivePaths,
      'archiveImagePath': encodedArchivePaths.isEmpty ? null : encodedArchivePaths.first,
      'steps': steps.map((ThoughtStep item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ThoughtNote fromJson(
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
    return ThoughtNote(
      id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      imagePaths: imagePaths,
      localImagePath: imagePaths.isEmpty
          ? (resolvedImagePath ?? (json['localImagePath'] as String? ?? ''))
          : imagePaths.first,
      stepsValue: (json['steps'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) =>
                ThoughtStep.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      createdAtValue:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAtValue:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
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

/// 单个流程步骤。
@embedded
class ThoughtStep {
  ThoughtStep({
    this.title = '',
    this.detail = '',
    this.possibleQuestion = '',
    this.imagePath = '',
  });

  String title;
  String detail;
  String possibleQuestion;
  String imagePath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'detail': detail,
      'possibleQuestion': possibleQuestion,
      'imagePath': imagePath,
    };
  }

  static ThoughtStep fromJson(Map<String, dynamic> json) {
    return ThoughtStep(
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      possibleQuestion: json['possibleQuestion'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
    );
  }
}
