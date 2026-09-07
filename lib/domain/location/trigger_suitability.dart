/// 觸發適用性門檻（REQ-C-18 規則 1）。精度 ≤ 此值的 Fix 標記為「適用於
/// 觸發判定」。目前與 [mileageQualityThreshold]（品質標記門檻，見
/// `pipeline/location_pipeline.dart`）同值，但刻意各自宣告——不共用單一
/// 常數：日後若放寬里程門檻，觸發契約不應跟著漂移。真正的風險不是共用
/// 一個值，是**隱式**共用一個值；三個名字加一條相等性斷言，使「它們分家」
/// 成為一次刻意的編輯，而不是被忽略的副作用。
const double triggerSuitabilityThreshold = 30;

/// 網格資格門檻（REQ-C-18 規則 1）。屬任務 A／B 的探索網格機制使用，
/// 本 SPEC 僅提供門檻常數，不定義網格本身。
const double gridEligibilityThreshold = 30;

/// 這筆位置是否夠精確，可用於觸發判定（AC-18.1、AC-18.2）。
bool isTriggerSuitable(double accuracyMeters) =>
    accuracyMeters <= triggerSuitabilityThreshold;
