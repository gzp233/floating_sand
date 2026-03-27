import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:floating_sand/models/favorite_category.dart';
import 'package:floating_sand/models/favorite_item.dart';
import 'package:floating_sand/models/thought_note.dart';

Future<void> main(List<String> args) async {
  final config = _MockGenerationConfig.fromArgs(args);
  if (config.showHelp) {
    stdout.writeln(_MockGenerationConfig.usage);
    return;
  }

  final random = Random();
  final categories = _createCategories(
    random: random,
    categoryCount: config.categoryCount,
  );
  final imagePool = _createImagePool(
    random: random,
    imageCount: config.imagePoolSize,
  );

  final favorites = List<FavoriteItem>.generate(config.favoriteCount, (
    int index,
  ) {
    final category = categories[random.nextInt(categories.length)].name;
    final imagePaths = _pickImagePaths(
      random: random,
      pool: imagePool,
      maxCount: 3,
      probability: 0.62,
    );
    return FavoriteItem(
      title: _buildFavoriteTitle(category, index),
      category: category,
      body: _buildParagraph(random, 2 + random.nextInt(3)),
      imagePaths: imagePaths,
      localImagePath: imagePaths.isEmpty ? '' : imagePaths.first,
      referenceUrl: 'https://example.com/item/${index + 1}',
      note: _buildParagraph(random, 1 + random.nextInt(2)),
      createdAtValue: _randomPastDate(random),
      updatedAtValue: _randomPastDate(random),
    );
  });

  final thoughts = List<ThoughtNote>.generate(config.thoughtCount, (
    int index,
  ) {
    final category = categories[random.nextInt(categories.length)].name;
    final imagePaths = _pickImagePaths(
      random: random,
      pool: imagePool,
      maxCount: 2,
      probability: 0.58,
    );
    final steps = List<ThoughtStep>.generate(
      2 + random.nextInt(4),
      (int stepIndex) => ThoughtStep(
        title: _buildStepTitle(stepIndex),
        detail: _buildParagraph(random, 1 + random.nextInt(2)),
        possibleQuestion: _questionPool[random.nextInt(_questionPool.length)],
        imagePath: _pickSingleImagePath(
          random: random,
          pool: imagePool,
          probability: 0.32,
        ),
      ),
    );
    return ThoughtNote(
      title: _buildThoughtTitle(category, index),
      category: category,
      overview: _buildParagraph(random, 2 + random.nextInt(2)),
      imagePaths: imagePaths,
      localImagePath: imagePaths.isEmpty ? '' : imagePaths.first,
      stepsValue: steps,
      createdAtValue: _randomPastDate(random),
      updatedAtValue: _randomPastDate(random),
    );
  });

  final payload = <String, dynamic>{
    'version': 2,
    'exportedAt': DateTime.now().toIso8601String(),
    'profile': null,
    'categories': categories.map((FavoriteCategory item) => item.toJson()).toList(),
    'favorites': favorites
        .map(
          (FavoriteItem item) => item.toJson(
            archiveImagePaths: item.imagePaths,
          ),
        )
        .toList(),
    'thoughts': thoughts.map(_exportThought).toList(),
  };

  final archive = Archive();
  final jsonBytes = utf8.encode(jsonEncode(payload));
  archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
  final zipBytes = ZipEncoder().encode(archive);

  final outputFile = config.resolveOutputFile();
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(zipBytes, flush: true);

  stdout.writeln(
    'Mock ZIP 已生成：${favorites.length} 条收藏，${thoughts.length} 条想法，'
    '${categories.length} 个分类，${imagePool.length} 张图片。',
  );
  if (config.keepExisting) {
    stdout.writeln('已兼容接受 --keep-existing 参数；但 ZIP 导入到应用时会替换当前数据。');
  }
  stdout.writeln('输出文件：${outputFile.path}');
}

class _MockGenerationConfig {
  const _MockGenerationConfig({
    required this.favoriteCount,
    required this.thoughtCount,
    required this.categoryCount,
    required this.imagePoolSize,
    required this.keepExisting,
    required this.showHelp,
    this.outputPath,
  });

  factory _MockGenerationConfig.fromArgs(List<String> args) {
    var favoriteCount = 100;
    var thoughtCount = 100;
    var categoryCount = 12;
    var imagePoolSize = 36;
    var keepExisting = false;
    var showHelp = false;
    String? outputPath;

    for (final arg in args) {
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
        continue;
      }
      if (arg == '--keep-existing') {
        keepExisting = true;
        continue;
      }
      if (arg.startsWith('--favorites=')) {
        favoriteCount = int.tryParse(arg.split('=').last) ?? favoriteCount;
        continue;
      }
      if (arg.startsWith('--thoughts=')) {
        thoughtCount = int.tryParse(arg.split('=').last) ?? thoughtCount;
        continue;
      }
      if (arg.startsWith('--categories=')) {
        categoryCount = int.tryParse(arg.split('=').last) ?? categoryCount;
        continue;
      }
      if (arg.startsWith('--images=')) {
        imagePoolSize = int.tryParse(arg.split('=').last) ?? imagePoolSize;
        continue;
      }
      if (arg.startsWith('--output=')) {
        outputPath = arg.split('=').last.trim();
      }
    }

    return _MockGenerationConfig(
      favoriteCount: favoriteCount,
      thoughtCount: thoughtCount,
      categoryCount: categoryCount,
      imagePoolSize: imagePoolSize,
      keepExisting: keepExisting,
      showHelp: showHelp,
      outputPath: outputPath,
    );
  }

  static const String usage = '用法: flutter pub run bin/generate_mock_data.dart '
      '[--favorites=100] [--thoughts=100] [--categories=12] [--images=36] '
      '[--keep-existing] [--output=/absolute/path/mock_data.zip]';

  final int favoriteCount;
  final int thoughtCount;
  final int categoryCount;
  final int imagePoolSize;
  final bool keepExisting;
  final bool showHelp;
  final String? outputPath;

  File resolveOutputFile() {
    final explicitOutput = outputPath;
    if (explicitOutput != null && explicitOutput.isNotEmpty) {
      return File(explicitOutput);
    }
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return File(
      '${Directory.current.path}${Platform.pathSeparator}mock_data_$timestamp.zip',
    );
  }
}

List<FavoriteCategory> _createCategories({
  required Random random,
  required int categoryCount,
}) {
  final safeCount = max(1, categoryCount);
  final seeds = List<String>.from(_categorySeeds)..shuffle(random);
  final categories = <FavoriteCategory>[];

  for (var index = 0; index < safeCount; index++) {
    final base = seeds[index % seeds.length];
    final suffix = index >= seeds.length ? ' ${index + 1}' : '';
    categories.add(
      FavoriteCategory(
        id: index + 1,
        name: '$base$suffix',
      ),
    );
  }
  return categories;
}

List<String> _createImagePool({
  required Random random,
  required int imageCount,
}) {
  final safeCount = max(1, imageCount);
  final paths = <String>[];
  for (var index = 0; index < safeCount; index++) {
    final bytes = _buildSolidPngBytes(
      width: 96 + random.nextInt(80),
      height: 96 + random.nextInt(120),
      red: 40 + random.nextInt(190),
      green: 40 + random.nextInt(190),
      blue: 40 + random.nextInt(190),
    );
    paths.add(_toDataUri(bytes));
  }
  return paths;
}

List<String> _pickImagePaths({
  required Random random,
  required List<String> pool,
  required int maxCount,
  required double probability,
}) {
  if (pool.isEmpty || random.nextDouble() > probability) {
    return <String>[];
  }
  final shuffled = List<String>.from(pool)..shuffle(random);
  final count = min(maxCount, pool.length);
  if (count <= 0) {
    return <String>[];
  }
  return shuffled.take(1 + random.nextInt(count)).toList();
}

Map<String, dynamic> _exportThought(ThoughtNote note) {
  final json = note.toJson(archiveImagePaths: note.imagePaths);
  json['steps'] = note.steps.map((ThoughtStep step) {
    final stepJson = step.toJson();
    stepJson['archiveImagePath'] = step.imagePath;
    return stepJson;
  }).toList();
  return json;
}

String _toDataUri(List<int> bytes) {
  return 'data:image/png;base64,${base64Encode(bytes)}';
}

String _pickSingleImagePath({
  required Random random,
  required List<String> pool,
  required double probability,
}) {
  if (pool.isEmpty || random.nextDouble() > probability) {
    return '';
  }
  return pool[random.nextInt(pool.length)];
}

String _buildFavoriteTitle(String category, int index) {
  return '${_favoriteVerbs[index % _favoriteVerbs.length]}$category ${index + 1}';
}

String _buildThoughtTitle(String category, int index) {
  return '${_thoughtOpeners[index % _thoughtOpeners.length]}$category ${index + 1}';
}

String _buildStepTitle(int index) {
  return '步骤 ${index + 1}';
}

String _buildParagraph(Random random, int sentenceCount) {
  final buffer = StringBuffer();
  for (var index = 0; index < sentenceCount; index++) {
    final subject = _subjects[random.nextInt(_subjects.length)];
    final action = _actions[random.nextInt(_actions.length)];
    final detail = _details[random.nextInt(_details.length)];
    buffer.write('$subject$action$detail。');
  }
  return buffer.toString();
}

DateTime _randomPastDate(Random random) {
  final now = DateTime.now();
  return now.subtract(
    Duration(
      days: random.nextInt(320),
      hours: random.nextInt(24),
      minutes: random.nextInt(60),
    ),
  );
}

List<int> _buildSolidPngBytes({
  required int width,
  required int height,
  required int red,
  required int green,
  required int blue,
}) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    for (var x = 0; x < width; x++) {
      raw.add(<int>[red, green, blue, 255]);
    }
  }

  final compressed = ZLibEncoder().encode(raw.toBytes());
  final png = BytesBuilder();
  png.add(<int>[137, 80, 78, 71, 13, 10, 26, 10]);
  png.add(
    _buildPngChunk('IHDR', _buildIhdrData(width: width, height: height)),
  );
  png.add(_buildPngChunk('IDAT', compressed));
  png.add(_buildPngChunk('IEND', const <int>[]));
  return png.toBytes();
}

List<int> _buildIhdrData({required int width, required int height}) {
  final data = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  return data.buffer.asUint8List();
}

List<int> _buildPngChunk(String type, List<int> data) {
  final typeBytes = ascii.encode(type);
  final length = ByteData(4)..setUint32(0, data.length);
  final crcData = <int>[...typeBytes, ...data];
  final crc = ByteData(4)..setUint32(0, _crc32(crcData));
  return <int>[
    ...length.buffer.asUint8List(),
    ...typeBytes,
    ...data,
    ...crc.buffer.asUint8List(),
  ];
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final value in bytes) {
    crc ^= value;
    for (var index = 0; index < 8; index++) {
      final mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xedb88320 & mask);
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

const List<String> _categorySeeds = <String>[
  '效率',
  '娱乐',
  '设计',
  '旅行',
  '写作',
  '产品',
  '学习',
  '健康',
  '灵感',
  '摄影',
  '电影',
  '阅读',
  '音乐',
  '播客',
];

const List<String> _favoriteVerbs = <String>[
  '收藏',
  '保存',
  '摘录',
  '留档',
  '归档',
];

const List<String> _thoughtOpeners = <String>[
  '复盘',
  '想法',
  '观察',
  '记录',
  '总结',
];

const List<String> _subjects = <String>[
  '这条内容',
  '这个案例',
  '这次经历',
  '这个做法',
  '这个观点',
  '这个细节',
];

const List<String> _actions = <String>[
  '让我重新理解了',
  '提醒我关注',
  '适合继续拆解',
  '值得反复对照',
  '可以进一步延展到',
  '适合拿来验证',
];

const List<String> _details = <String>[
  '执行节奏和结果之间的关系',
  '用户反馈背后的真实需求',
  '信息密度过高时的表达方式',
  '日常记录和长期复盘的连接点',
  '视觉组织对理解效率的影响',
  '把零散输入整理成结构化材料的方法',
];

const List<String> _questionPool = <String>[
  '这件事真正有效的关键是什么？',
  '如果下次再做，第一步应该先改哪里？',
  '这条经验适用于哪些相似场景？',
  '有没有被忽略的边界条件？',
  '哪些部分值得继续沉淀成模板？',
];