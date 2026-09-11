import '../../domain/core_loop/run/curator_run_phase.dart';
import '../../domain/core_loop/run/curator_run_state.dart';

/// 單局狀態轉移應該開啟哪一個彈窗。
enum CuratorModalRoute {
  /// 不開任何彈窗
  none,

  /// 行前委託（選哲學、進黑市）
  briefing,

  /// 夜間工作室（排時間線、呈送審查）
  studio,
}

/// 由狀態轉移決定要開哪個彈窗。
///
/// 這段判斷原本直接寫在 `main.dart` 的 `ref.listen` 裡，而整合測試自己抄了
/// 一份等價邏輯 —— 於是改 `main.dart` 不會讓任何測試變紅。抽成純函式之後
/// 兩邊共用同一份實作，接線本身才真的被測到。
CuratorModalRoute resolveCuratorModalRoute(
  CuratorRunState? previous,
  CuratorRunState next,
) {
  final enteredBriefing =
      next.phase == CuratorRunPhase.philosophizing &&
      previous?.phase != CuratorRunPhase.philosophizing;
  if (enteredBriefing) {
    return CuratorModalRoute.briefing;
  }

  final becameExhausted =
      next.isExhausted && (previous == null || !previous.isExhausted);
  if (becameExhausted) {
    return CuratorModalRoute.studio;
  }

  return CuratorModalRoute.none;
}
