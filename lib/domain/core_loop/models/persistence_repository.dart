import 'curator_save_data.dart';

/// 存檔持久化抽象介面 (CLAUDE.md 核准之三大抽象介面之一)
/// 純 Dart 定義，完全不依賴 Flutter、Flame 或特定資料庫技術。
abstract class PersistenceRepository {
  /// 載入本機或遠端存檔。若無存檔或損毀，回傳初始預設 CuratorSaveData。
  Future<CuratorSaveData> loadSave();

  /// 保存存檔資料
  Future<void> save(CuratorSaveData data);

  /// 清除存檔資料 (供測試與重置帳號)
  Future<void> clearSave();
}
