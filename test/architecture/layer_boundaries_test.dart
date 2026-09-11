import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// domain 層必須零框架相依，否則 TDD 迴圈需要模擬器，會慢到不可用。
/// 這條規則靠人自律守不住，所以用測試強制。
void main() {
  const forbiddenInDomain = [
    'package:flutter/',
    'dart:ui',
    'package:flame/',
    'package:geolocator/',
    'package:vector_math/vector_math_64.dart',
  ];

  List<File> dartFilesUnder(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .toList();
  }

  test('domain 層不得相依框架型別', () {
    final violations = <String>[];
    for (final file in dartFilesUnder('lib/domain')) {
      final source = file.readAsStringSync();
      for (final banned in forbiddenInDomain) {
        if (source.contains("import '$banned") ||
            source.contains('import "$banned')) {
          violations.add('${file.path} → $banned');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'domain 層出現框架相依：\n${violations.join('\n')}');
  });

  test('通用引擎不得引用具名城市模組', () {
    final violations = <String>[];
    final generic = [
      ...dartFilesUnder('lib/domain'),
      ...dartFilesUnder('lib/state'),
      File('lib/game/universal_overworld_game.dart'),
    ].where((f) => f.existsSync());

    for (final file in generic) {
      final source = file.readAsStringSync();
      if (source.contains('taiwan') ||
          source.contains('Taiwan') ||
          source.contains('kyoto') ||
          source.contains('Kyoto')) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty,
        reason: '通用引擎硬編碼了特定城市（如 Taiwan / Kyoto）：\n${violations.join('\n')}');
  });

  test('domain 與 state 層不得引用遊戲數值模組', () {
    final violations = <String>[];
    for (final file in [
      ...dartFilesUnder('lib/domain/location'),
      ...dartFilesUnder('lib/data/location'),
    ]) {
      final source = file.readAsStringSync();
      if (source.contains("import 'package:share_tour/domain/stats/") ||
          source.contains('SurvivalStats')) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty,
        reason: '任務 C 直接碰觸遊戲數值，違反單一寫入點：\n${violations.join('\n')}');
  });
}
