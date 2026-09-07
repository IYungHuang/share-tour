import 'package:wakelock_plus/wakelock_plus.dart';

/// 螢幕喚醒鎖的最小包裝。
///
/// 不是抽象——`wakelock_plus` 永遠只有開／關兩個狀態，沒有第二種正式生產
/// 行為需要切換，不構成「擋住已知會變的軸」。這一層純粹是讓 NFR-5（dispose
/// 時外部副作用必須釋放）可在無真機的條件下測試，比照 `Clock` 的定位。
class WakelockControl {
  Future<void> enable() => WakelockPlus.enable();
  Future<void> disable() => WakelockPlus.disable();
}
