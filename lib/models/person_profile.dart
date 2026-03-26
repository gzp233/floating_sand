import 'package:isar/isar.dart';

part 'person_profile.g.dart';

/// 个人档案，包含基础资料、照片、个性和扩展模块等核心信息。
@collection
class PersonProfile {
  PersonProfile({
    this.id = 1,
    this.nickname = '',
    this.bio = '',
    List<String>? photoPathsValue,
    ProfilePersonality? personalityValue,
    List<String>? hobbiesValue,
    List<ProfileCustomModule>? customModulesValue,
    DateTime? updatedAtValue,
  }) : personality = personalityValue ?? ProfilePersonality(),
       photoPaths = photoPathsValue ?? <String>[],
       hobbies = hobbiesValue ?? <String>[],
       customModules = customModulesValue ?? <ProfileCustomModule>[],
       updatedAt = updatedAtValue ?? DateTime.now();

  Id id;
  String nickname;
  String bio;
  List<String> photoPaths;
  ProfilePersonality personality;
  List<String> hobbies;
  List<ProfileCustomModule> customModules;
  DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'nickname': nickname,
      'bio': bio,
      'photoPaths': photoPaths,
      'personality': personality.toJson(),
      'hobbies': hobbies,
      'customModules': customModules
          .map((ProfileCustomModule item) => item.toJson())
          .toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static PersonProfile fromJson(Map<String, dynamic> json) {
    return PersonProfile(
      id: (json['id'] as num?)?.toInt() ?? 1,
      nickname: json['nickname'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      photoPathsValue: _stringListFromJson(json['photoPaths']),
      personalityValue: ProfilePersonality.fromJson(
        (json['personality'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      hobbiesValue: _stringListFromJson(json['hobbies']),
      customModulesValue:
          (json['customModules'] as List<dynamic>? ?? <dynamic>[])
              .map(
                (dynamic item) => ProfileCustomModule.fromJson(
                  Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
                ),
              )
              .toList(),
      updatedAtValue:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static List<String> _stringListFromJson(dynamic value) {
    return (value as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }
}

/// 个性信息，使用嵌套对象便于单独维护结构。
@embedded
class ProfilePersonality {
  ProfilePersonality({
    this.summary = '',
    this.values = '',
    List<String>? tagsValue,
  }) : tags = tagsValue ?? <String>[];

  String summary;
  String values;
  List<String> tags;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'summary': summary,
      'values': values,
      'tags': tags,
    };
  }

  static ProfilePersonality fromJson(Map<String, dynamic> json) {
    return ProfilePersonality(
      summary: json['summary'] as String? ?? '',
      values: json['values'] as String? ?? '',
      tagsValue: PersonProfile._stringListFromJson(json['tags']),
    );
  }
}

/// 自定义个人模块，可按需扩展档案信息。
@embedded
class ProfileCustomModule {
  ProfileCustomModule({this.title = '', this.content = ''});

  String title;
  String content;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'title': title, 'content': content};
  }

  static ProfileCustomModule fromJson(Map<String, dynamic> json) {
    return ProfileCustomModule(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}
