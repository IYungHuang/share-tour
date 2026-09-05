/// Fix 被丟棄的原因。用於診斷分類（REQ-C-14 規則 5）。
enum RejectionReason {
  /// 平台未量測精度——0.0 是佔位值，不是零誤差。
  unmeasuredAccuracy,
  accuracy,
  timestamp,
  speed,
}
