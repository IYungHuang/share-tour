import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/core_loop/models/curator_save_data.dart';
import '../../domain/core_loop/models/persistence_repository.dart';

/// 使用 SharedPreferences 的本機存檔儲存庫實作
class LocalPersistenceRepository implements PersistenceRepository {
  LocalPersistenceRepository({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// 主存檔鍵值
  static const String saveKey = 'curator_save_data_v1';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<CuratorSaveData> loadSave() async {
    final prefs = await _getPrefs();
    final rawJson = prefs.getString(saveKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return CuratorSaveData.initial();
    }

    try {
      final Map<String, dynamic> map = jsonDecode(rawJson) as Map<String, dynamic>;
      return CuratorSaveData.fromJson(map);
    } catch (e) {
      // 容錯機制：將損毀存檔移至 .bak 備份，防止資料滅失並避免未捕捉崩潰 (AC-M4-3.4)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupKey = 'save_corrupted_$timestamp.bak';
      await prefs.setString(backupKey, rawJson);

      return CuratorSaveData.initial();
    }
  }

  @override
  Future<void> save(CuratorSaveData data) async {
    final prefs = await _getPrefs();
    final jsonString = jsonEncode(data.toJson());
    await prefs.setString(saveKey, jsonString);
  }

  @override
  Future<void> clearSave() async {
    final prefs = await _getPrefs();
    await prefs.remove(saveKey);
  }
}
