# 日夜時間系統驗收與零回歸報告 (Day/Night Diurnal Cycle System Acceptance Report)

## 1. 系統實施概要

本系統依據遊戲企劃、架構師與技術負責人三方研討結論及 `PLAN_DAY_NIGHT_SYSTEM.md`，在獨立 worktree 分支（`feature/day-night-cycle`）完成實施，徹底解決了原本光照階梯式突變、生活作息時段限制（防卡死）以及 4 槽位時間線與大世界探索割裂問題。

### 核心模組架構
- **純領域層（零框架相依）**：
  - [`TourPeriod`](file:///Users/appgongyong/share_tour_day_night/lib/domain/core_loop/time/tour_period.dart)：四幕時段（dawn 06:00, midday 11:00, dusk 16:00 📷, night 19:00+），嚴格對應時間線 4 槽位。
  - [`AmbientLightingProfile`](file:///Users/appgongyong/share_tour_day_night/lib/domain/core_loop/time/game_time_snapshot.dart)：5 關鍵錨點連續色溫平滑插值引擎（純數學 ARGB lerp，零 `package:flutter/` 或 `dart:ui` 相依）。
  - [`GameTimeSnapshot`](file:///Users/appgongyong/share_tour_day_night/lib/domain/core_loop/time/game_time_snapshot.dart)：不可變遊戲時間數值實體。
  - [`CuratorRunProgressionDriver`](file:///Users/appgongyong/share_tour_day_night/lib/domain/core_loop/time/curator_run_progression_driver.dart)：單局平滑推移驅動器（70% 體力消耗 + 30% 背包進度加權；深夜剪輯鎖定 24:00）。
  - [`RealtimeGpsDriver`](file:///Users/appgongyong/share_tour_day_night/lib/domain/core_loop/time/realtime_gps_driver.dart)：真實本地時鐘與 24 分鐘縮時展示模式驅動器。
  - [`DiurnalResonanceRule`](file:///Users/appgongyong/share_tour_day_night/lib/domain/core_loop/time/diurnal_resonance_rule.dart)：時段順行採集體力折讓規則（契合折讓 3 HP，底線保底 $\ge 1$ HP，杜絕免費採集）。
- **Flame 渲染層**：
  - [`TimeOfDayLightingComponent`](file:///Users/appgongyong/share_tour_day_night/lib/game/components/time_of_day_lighting_component.dart)：連續 Lerp 色溫疊加與 0.5Hz 燈籠呼吸微動（Lantern Breathing），`render()` 週期維持 0 bytes 堆疊配置。
- **狀態與 UI 層**：
  - [`gameTimeProvider`](file:///Users/appgongyong/share_tour_day_night/lib/state/core_loop/game_time_controller.dart)：單一真理源 Riverpod Provider。
  - [`CuratorFieldHud`](file:///Users/appgongyong/share_tour_day_night/lib/ui/core_loop/field/curator_field_hud.dart)：動態時段指針膠囊、虛擬時間與黃昏 📷 標記。
  - [`AttractionDetailCard`](file:///Users/appgongyong/share_tour_day_night/lib/ui/core_loop/field/attraction_detail_card.dart)：時段共鳴綠色折讓文案透明化預覽，確認採集時傳遞當前時段。

---

## 2. 驗收門檻與回歸檢驗結果

| 檢驗項目 | 執行指令 | 檢驗結果 |
|---|---|---|
| **代碼靜態分析** | `flutter analyze` | **0 issues** (Pass) |
| **全套自動化測試** | `flutter test` | **568 passed, 0 failed, 2 skipped** (Pass) |
| **架構分層邊界** | `flutter test test/architecture/layer_boundaries_test.dart` | **5 passed, 0 failed** (Domain 零框架相依 Pass) |
| **Amendment-01 平衡包** | `dart run tool/search_mvp_balance.dart` | **4,612,800 種行程全數通過** (Pass) |
| **GPS 與圖資凍結管線** | `git diff e847f04 -- lib/domain/location/projection/map_manifest.dart lib/game/map_module/manifests/taiwan_map_manifest.dart lib/domain/location/pipeline lib/data/location` | **0 diff** (嚴格未修改 Pass) |

---

## 3. 提交歷史 (Git Commits)

- `1f546e0`: `feat(time): add dual-track diurnal time drivers and domain snapshots`
- `1803573`: `feat(time): implement diurnal stamina resonance gathering discounts`
- `92bd157`: `feat(lighting): upgrade lighting component with continuous lerp and lantern breathing`
- `6260da5`: `feat(ui): connect diurnal time state with HUD and gathering preview`
- `[HEAD]`: `docs(time): verify diurnal cycle system acceptance and zero-regression`
