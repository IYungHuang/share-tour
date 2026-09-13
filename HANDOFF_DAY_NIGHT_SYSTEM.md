# 日夜時間系統 (Day/Night Diurnal Cycle System) 明日接手交接報告 (Handoff)

**產出時間**：2026-09-13 01:25 (GMT+8)  
**狀態**：✅ 核心功能 100% 完工、驗收測試全數通過、實機驗證完成、乾淨隔離於獨立 Worktree

---

## 1. 分支與 Worktree 目錄配置 (Workspace Mapping)

因實施期間主目錄有其他工作 Session 正在施工，為避免干擾，日夜時間系統在獨立 Worktree 進行完整開發與驗證：

| 工作區角色 | 本地路徑 | 當前分支 | 狀態說明 |
|---|---|---|---|
| **主工作目錄** | `/Users/appgongyong/share_tour` | `feature/mvp-amendment-01` | 其他 Session 施工中（有未提交檔案與素材資產，請勿擅自覆蓋） |
| **日夜系統 Worktree** | `/Users/appgongyong/share_tour_day_night` | `feature/day-night-cycle` | **日夜系統開發基地**，所有功能已提交且工作區乾淨（clean） |

---

## 2. 提交清單與功能架構 (Commits on `feature/day-night-cycle`)

基於 `e847f04` 依序推進的原子提交：

1. [`1f546e0`](file:///Users/appgongyong/share_tour_day_night/lib/domain/core_loop/time/tour_period.dart) **feat(time): add dual-track diurnal time drivers and domain snapshots**
   - 建立四幕時段枚舉 `TourPeriod`（dawn 06:00, midday 11:00, dusk 16:00 📷, night 19:00+）。
   - 建立零框架相依色溫插值引擎 `AmbientLightingProfile`（純 Dart ARGB 插值，遵守 Layer Boundary）。
   - 建立雙軌時鐘驅動器：`CuratorRunProgressionDriver`（70% HP 消耗 + 30% 腰包進度平滑推進）與 `RealtimeGpsDriver`（GPS 與 24 分鐘縮時展示模式）。
2. [`1803573`](file:///Users/appgongyong/share_tour_day_night/lib/domain/core_loop/time/diurnal_resonance_rule.dart) **feat(time): implement diurnal stamina resonance gathering discounts**
   - 實作時段順行體力共鳴規則 `DiurnalResonanceRule`：契合時段標籤取材現折 3 HP（最低保底 1 HP）。
3. [`92bd157`](file:///Users/appgongyong/share_tour_day_night/lib/game/components/time_of_day_lighting_component.dart) **feat(lighting): upgrade lighting component with continuous lerp and lantern breathing**
   - Flame 渲染組件支援 `timeSnapshotGetter`，實現無突波平滑 Lerp 色溫與 0.5Hz 燈籠呼吸微動（Lantern Breathing），維持 `render()` 0 bytes 堆疊配置。
4. [`6260da5`](file:///Users/appgongyong/share_tour_day_night/lib/state/core_loop/game_time_controller.dart) **feat(ui): connect diurnal time state with HUD and gathering preview**
   - 建立 `gameTimeProvider` 單一真理源。
   - 頂部常駐 HUD `CuratorFieldHud` 接線動態時鐘指針、虛擬時刻與黃昏 📷 標記。
   - 取材卡 `AttractionDetailCard` 顯示綠色時段共鳴折讓文案與實際扣額。
5. [`ace34d5`](file:///Users/appgongyong/share_tour_day_night/DAY_NIGHT_CYCLE_ACCEPTANCE_REPORT.md) **docs(time): verify diurnal cycle system acceptance and zero-regression**
   - 產出全套驗收報告 `DAY_NIGHT_CYCLE_ACCEPTANCE_REPORT.md`。
6. [`7ec0c28`](file:///Users/appgongyong/share_tour_day_night/lib/state/location/location_providers.dart) **fix(overworld): fix LocationNotifier late re-init and elevate AttractionDetail z-order**
   - **實機除錯修正**：移除 `LocationNotifier` 內部欄位的 `final` 限制，防止地圖切換 re-build 時拋出 `LateInitializationError` 導致方向鍵失效。
   - **圖層調整**：調整 `GameWidget` overlays 的 Z-order，將 `AttractionDetail` 移至 `DPad` 與 `ModeToggle` 之上，防止右側按鈕遮擋取材點擊。

---

## 3. 驗收門檻檢驗數據 (Verification Matrix)

在 Worktree 目錄 `/Users/appgongyong/share_tour_day_night` 驗證結果：

- **靜態分析**：`flutter analyze` $\to$ **0 issues**。
- **全套測試**：`flutter test` $\to$ **568 passed, 0 failed, 2 skipped**。
- **架構分層測試**：`flutter test test/architecture/layer_boundaries_test.dart` $\to$ **5 passed, 0 failed**。
- **平衡包檢驗**：`dart run tool/search_mvp_balance.dart` $\to$ **4,612,800 種手牌全數合格，Fingerprint `2c65f064ae3c55bf` 一致**。
- **凍結資產檢查**：`git diff e847f04 -- ...` $\to$ **0 diff**。
- **實體機運作**：Android (CPH2783) 安裝測試通過，阿導方向鍵行走與時段共鳴扣額皆實測正常。

---

## 4. 明日接手作業 SOP (Action Protocol for Tomorrow)

### 步驟 A：確認主目錄狀態
1. 到 `/Users/appgongyong/share_tour` 檢查另一個 session 的施工狀態。
2. 若該 session 已經施工完成並將變更提交（Commit），即可準備進行分支合併。

### 步驟 B：執行合併
在主目錄切換或合併分支：
```bash
cd /Users/appgongyong/share_tour
git merge feature/day-night-cycle
```

### 步驟 C：潛在衝突排解方針 (Conflict Resolution Guide)
若發生衝突，可能集中於：
1. `lib/main.dart`：
   - 保留 `UniversalOverworldGame` 內的 `timeSnapshotGetter: () => ref.read(gameTimeProvider)`。
   - 保留 `initialActiveOverlays` 內 `AttractionDetail` 置於頂層的順序。
2. `lib/state/location/location_providers.dart`：
   - 確保 `LocationNotifier` 內的欄位保持 `late LocationController _controller;`（**不要帶 `final`**）。

### 步驟 D：合併後煙霧測試
```bash
cd /Users/appgongyong/share_tour
flutter analyze
flutter test
```
確認 0 issues 與全數通過。

### 步驟 E：清理臨時 Worktree
合併完成且驗證無誤後，可刪除 Worktree：
```bash
cd /Users/appgongyong/share_tour
git worktree remove /Users/appgongyong/share_tour_day_night
```
