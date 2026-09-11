import '../events/curator_event.dart';
import 'curator_save_data.dart';

/// 存檔持久化抽象介面 (CLAUDE.md 核准之三大抽象介面之一)
/// 純 Dart 定義，完全不依賴 Flutter、Flame 或特定資料庫技術。
///
/// 存檔是 append-only 事件日誌 (CC-3)：寫入一律追加，既有事件不得修改或刪除，
/// 最終狀態由 [replayCuratorEvents] 重播得出。介面刻意不提供「覆寫整包最終狀態」
/// 的操作 —— 那會讓事件日誌失去唯一真實來源的地位，且遠端後端無法稽核。
abstract class PersistenceRepository {
  /// 依 seq 遞增順序讀出完整事件日誌。無存檔時回傳空清單。
  Future<List<CuratorEvent>> loadEvents();

  /// 追加事件。實作不得修改或刪除既有事件。
  Future<void> appendEvents(List<CuratorEvent> events);

  /// 重播事件日誌得出的局外存檔狀態。
  /// 日誌為空時自行建立 profileCreated 事件並落地，回傳初始存檔。
  Future<CuratorSaveData> loadSave();

  /// 清除存檔資料 (供測試重置環境)
  Future<void> clearSave();
}
