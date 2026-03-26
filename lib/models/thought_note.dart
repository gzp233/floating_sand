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
    this.localImagePath = '',
    List<ThoughtStep>? stepsValue,
    DateTime? createdAtValue,
    DateTime? updatedAtValue,
  }) : steps = stepsValue ?? <ThoughtStep>[],
       createdAt = createdAtValue ?? DateTime.now(),
       updatedAt = updatedAtValue ?? DateTime.now();

  Id id;
  String title;
  String category;
  String overview;
  String localImagePath;
  List<ThoughtStep> steps;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson({String? archiveImagePath}) {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category,
      'overview': overview,
      'localImagePath': localImagePath,
      'archiveImagePath': archiveImagePath,
      'steps': steps.map((ThoughtStep item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ThoughtNote fromJson(
    Map<String, dynamic> json, {
    String? resolvedImagePath,
  }) {
    return ThoughtNote(
      id: (json['id'] as num?)?.toInt() ?? Isar.autoIncrement,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      localImagePath:
          resolvedImagePath ?? (json['localImagePath'] as String? ?? ''),
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
