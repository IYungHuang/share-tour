import 'models/geo_fix.dart';
import 'models/location_status.dart';

/// 追蹤期間是否該抑制螢幕自動休眠（REQ-C-16 規則 1）。
///
/// 純函式，不啟動平台即可求值（NFR-1）。刻意**不接受 `powerMode`**：
/// REQ-C-11 規則 3 的五個 `suspended` 觸發條件中，四個已被本述詞的其他
/// 合取項排除（背景逾時↔前景、權限不可用與 `approximate`↔`permission ==
/// ready`、`mode == virtual`↔`mode == gps`），僅餘 Mini-game。若把
/// `powerMode == active` 納入，Mini-game 期間會錯誤地釋放喚醒——而那正是
/// 玩家全程注視螢幕的時刻。
bool shouldKeepAwake({
  required SourceMode mode,
  required PermissionState permission,
  required bool isForeground,
  required bool featureEnabled,
}) =>
    mode == SourceMode.gps &&
    permission == PermissionState.ready &&
    isForeground &&
    featureEnabled;
