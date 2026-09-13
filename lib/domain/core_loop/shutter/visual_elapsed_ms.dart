/// 視覺用的經過時間（AnimationController 的 dt 累積量）。
///
/// 與 [HeldMs] 型別不相容，兩者不共用建構路徑——這是 AC-M5-1.13 的
/// 型別隔離：判定路徑收不到這個型別，指示路徑也收不到 [HeldMs]。
class VisualElapsedMs {
  const VisualElapsedMs(this.value);

  final int value;
}
