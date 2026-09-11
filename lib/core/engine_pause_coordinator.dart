/// 巢狀彈窗的引擎暫停協調器（引用計數）。
///
/// 行前委託彈窗可以再開黑市彈窗，關閉內層時引擎不能恢復，否則玩家還在看
/// 彈窗、世界卻已經在背後跑。單純一個 bool 擋不住這種巢狀，計數錯一次就是
/// 引擎永久卡住或永久不暫停。
///
/// 純 Dart、不碰 Flame 與 Widget，因此這段協調邏輯本身可以被測試 —— 接線
/// 出過事的地方要有測試，不能只測元件。
class EnginePauseCoordinator {
  EnginePauseCoordinator({required this.onPause, required this.onResume});

  /// 由第一次 [acquire] 觸發。實際的附著與載入檢查留給呼叫端。
  final void Function() onPause;

  /// 由最後一次 [release] 觸發。
  final void Function() onResume;

  int _refCount = 0;

  /// 當前持有暫停的層數
  int get refCount => _refCount;

  bool get isPaused => _refCount > 0;

  /// 取得一層暫停。只有從 0 變 1 時才觸發 [onPause]。
  void acquire() {
    _refCount++;
    if (_refCount == 1) {
      onPause();
    }
  }

  /// 釋放一層暫停。只有歸零時才觸發 [onResume]。
  /// 多餘的釋放是無操作 —— 計數不會變成負數，也不會重複恢復。
  void release() {
    if (_refCount == 0) return;
    _refCount--;
    if (_refCount == 0) {
      onResume();
    }
  }
}
