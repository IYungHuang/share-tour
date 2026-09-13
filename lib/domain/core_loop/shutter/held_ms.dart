/// 判定用的持續時間，只接受兩個 `Duration` 相減——不接受裸 `int`。
///
/// 這是型別隔離的核心（AC-M5-1.13）：`indicatorState` 用的是不相容的
/// [VisualElapsedMs]，兩者無隱式轉換，視覺 dt 無法順手餵進判定路徑。
/// 建構子要求呼叫端交出兩個原始時戳（理應源自 `PointerEvent.timeStamp`），
/// 而不是一個已經算好的整數，藉此在型別層面提示「這個數字要從哪來」。
class HeldMs {
  HeldMs({required Duration downTimeStamp, required Duration upTimeStamp})
      : _ms = (upTimeStamp - downTimeStamp).inMilliseconds;

  final int _ms;

  int toInt() => _ms;
}
