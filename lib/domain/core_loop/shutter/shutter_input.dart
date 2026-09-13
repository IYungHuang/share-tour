import 'held_ms.dart';

/// 判定函式的輸入和型別（REQ-M5-01.7 規則 7）。
///
/// 逾時在型別上是輸入的一種，不存在能以 [HeldMs] 表達逾時的路徑
/// （AC-M5-1.6）——`TimedOut` 不攜帶任何時間資訊。
sealed class ShutterInput {
  const ShutterInput();
}

final class Pressed extends ShutterInput {
  const Pressed(this.heldMs);

  final HeldMs heldMs;
}

final class TimedOut extends ShutterInput {
  const TimedOut();
}
