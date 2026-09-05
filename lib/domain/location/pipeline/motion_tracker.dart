import '../../../core/time/clock.dart';
import '../models/location_status.dart';

/// 由「距上次事件過了多久」推導 motion 與 acquisition。
///
/// 兩者都用逾時判定而非由 Fix 到達判定。平台的距離門檻意味著玩家一停下來就
/// 不再推送 Fix，所以 Fix 驅動的規則在真機上永遠到不了 still——而餵 Fix 進去的
/// 單元測試會通過。這是最糟的一種失效：測試綠燈、產品壞掉。
///
/// acquisition 是雙向的，理由與它存在的理由相同：對玩家而言，「失去可信位置」
/// 與「還沒取得」是同一件事。在地下街，Fix 仍會抵達但因精度太差被丟棄，
/// 沒有這條的話 HUD 會顯示一切正常而小人不動。
///
/// 狀態在查詢時計算，不使用計時器：測試只要推進假時鐘，不需非同步等待。
class MotionTracker {
  MotionTracker({
    required Clock clock,
    required this.stillAfter,
    required this.acquiringAfter,
  })  : _clock = clock,
        _lastSignificantMove = null,
        _lastAcceptedFix = null;

  final Clock _clock;
  final Duration stillAfter;
  final Duration acquiringAfter;

  Duration? _lastSignificantMove;
  Duration? _lastAcceptedFix;

  void onSignificantMove() => _lastSignificantMove = _clock.elapsed;

  void onAcceptedFix() => _lastAcceptedFix = _clock.elapsed;

  MotionState get motion {
    final last = _lastSignificantMove;
    if (last == null) return MotionState.still;
    return _clock.elapsed - last > stillAfter
        ? MotionState.still
        : MotionState.moving;
  }

  AcquisitionState get acquisition {
    final last = _lastAcceptedFix;
    if (last == null) return AcquisitionState.acquiring;
    return _clock.elapsed - last > acquiringAfter
        ? AcquisitionState.acquiring
        : AcquisitionState.acquired;
  }

  /// 供診斷快照使用。
  int get secondsSinceLastSignificantMove {
    final last = _lastSignificantMove;
    if (last == null) return -1;
    return (_clock.elapsed - last).inSeconds;
  }
}
