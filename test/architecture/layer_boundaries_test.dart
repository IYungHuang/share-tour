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

  test('domain 層不得反向相依外層或平台套件', () {
    // domain 是最內層：外層可以依賴它，它不得依賴外層。
    // 少了這條，`import 'package:share_tour/data/...'` 寫進 domain 也會全綠通過。
    const forbidden = [
      'package:share_tour/data/',
      'package:share_tour/state/',
      'package:share_tour/ui/',
      'package:share_tour/game/',
      'package:flutter_riverpod/',
      'package:shared_preferences/',
    ];

    final violations = <String>[];
    for (final file in dartFilesUnder('lib/domain')) {
      final source = file.readAsStringSync();
      for (final banned in forbidden) {
        if (source.contains("import '$banned") ||
            source.contains('import "$banned')) {
          violations.add('${file.path} → $banned');
        }
      }
      // 相對路徑寫法同樣要擋：'../../data/...'、'../../../state/...'
      final relative = RegExp(
        r'''import\s+['"](?:\.\./)+(data|state|ui|game)/''',
      );
      for (final match in relative.allMatches(source)) {
        violations.add('${file.path} → ${match.group(1)} (相對路徑)');
      }
    }

    expect(violations, isEmpty,
        reason: 'domain 層出現倒向相依：\n${violations.join('\n')}');
  });

  test('AC-CC-5.1 domain 的序列化結果不得夾帶原始座標鍵', () {
    // 產品承諾：原始 GPS 座標永不離開裝置。可持久化的只有已投影像素座標、
    // POI 打卡結果與不含原始座標的事件欄位。這條可靜態檢查，不靠人工複查。
    // 掃描含產生檔 (*.g.dart)，因為 JSON 鍵的字面值實際出現在那裡。
    const bannedKeys = ["'lat'", "'lng'", "'latitude'", "'longitude'"];

    final violations = <String>[];
    final dir = Directory('lib/domain');
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final key in bannedKeys) {
        if (source.contains('$key:') || source.contains('json[$key]')) {
          violations.add('${file.path} → JSON 鍵 $key');
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'domain 的序列化夾帶原始座標，違反 CC-5：\n${violations.join('\n')}');
  });
}
