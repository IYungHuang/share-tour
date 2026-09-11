# SPEC — 《Share Tour：奇葩旅行策展人》Milestone M3：大世界 POI 踩線取材與探索接線

- 狀態：**正式簽核通過 (v2 - Formal Approval)** — 經首席遊戲企劃、主任架構師與資深前端工程師聯合審查核准，整合腰包滿額換牌、最後一搏透支、原子領域轉移、5 態資格狀態機與 360dp 佈局守護
- 流程位置：`spec → 覆核 (通過) → plan → 覆核 → 執行計劃 → 覆核`
- 上位文件：`CROSS_CUTTING_CONSTRAINTS.md`、`CLAUDE.md`、`SPEC_MVP_CORE_LOOP.md`（牴觸時以其為準）

---

## 1. 目的與範圍

### 1.1 目的
銜接既有的大世界地圖探索能力（Task C 之 GPS 定位／虛擬方向鍵行走）與單局核心策展機制（Task M1/M2 之阿導腰包與 4 槽位時間線編輯），建立實質的單局探索取材流動：
**「漫步大世界 ➔ 接近景點 POI ➔ 預覽代價與線索 ➔ 取材採集（支援腰包滿額換牌） ➔ 體力耗盡／主動返程 ➔ 開啟工作室策展」**。

徹底去除 Milestone M2 的 `[測試] 採集素材` 調試按鈕，讓玩家真實在大地圖中藉由移動與探訪獲取專屬旅行卡牌，並讓殘餘 HP 轉化為真實的牌組構築決策（Deckbuilding Drafting）。

### 1.2 本 SPEC 涵蓋
1. **阿導大世界踩線狀態（Field Trip State）**：大地圖頂部極簡 JRPG HUD（高 36dp，安全區整合），顯示當前 HP 條、Budget 預算與腰包使用數。
2. **POI 接近感應與 5 態資格狀態機（Proximity & 5-State Eligibility）**：
   - 距離 $\le 50.0$ 公尺時判定為在觸發範圍內（In Proximity）。
   - 景點卡按鈕提供 5 種封閉狀態：`ready`（可取材）、`outOfRange`（超距）、`alreadyGathered`（已踩線）、`inventoryFull`（滿額換牌）、`exhausted`（體力透支）。
3. **採集消耗、資訊透明與「最後一搏」契約**：
   - 景點卡透明預告代價：`⚡ 消耗 HP` 與 `💰 預算花費`。
   - 只要 HP $> 0$ 即允許發動取材；若扣減後小於 0 則 clamp 截斷為 0 並標記透支（最後一搏，Push Your Luck）。
4. **腰包滿額現場換牌（Replace & Discard Flow）**：
   - 踩線取材在腰包未滿（$< \text{maxCapacity}$）時直接入袋；
   - 在腰包已滿（$= \text{maxCapacity}$）時，彈出換牌抽屜，允許玩家【替換指定舊卡】或【放棄新卡】，杜絕「死體力（Dead HP）」陷阱。
5. **單局防刷與原子領域轉移（Atomic Domain Operation）**：
   - `CuratorRunState` 新增不可變欄位 `final Set<String> gatheredPoiIds`。
   - 踩線操作由原子領域方法一次性完成扣 HP、扣預算、入袋、記錄已採點，確保狀態全有或全無（All-or-Nothing）。
6. **體力透支強制返程與生命週期守護**：
   - HP 歸零時，`phase` 原子轉移為 `CuratorRunPhase.nightEditing`，鎖定大地圖探索輸入。
   - 自動開啟 `CuratorStudioModal`（具備重複彈窗防呆與 Flame 引擎掛起保護）。
   - HP $> 0$ 時手動開啟工作台僅為暫時檢視，`phase` 維持 `fieldTrip`。
7. **城市圖資素材解耦契約（City-as-DLC Decoupling）**：
   - 純領域抽象 `PoiMaterialResolver`，通用引擎零具名城市硬編碼。
   - 採「固定景點專屬卡牌優先，未命中時分類（Category）通用抽取 fallback」原則。
   - 提供純記憶體 `FakePoiMaterialResolver` 支援秒級測試。

### 1.3 本 SPEC 明確不涵蓋（Out of Scope）
- 微動作衝刺、快門 QTE 敏捷檢定（規劃於後續微動作里程碑）。
- 實體隨機遭遇戰鬥、黑市商人。
- 即時聯網與好友位置分享（CC-1 嚴格禁止）。
- 複雜路網 A* 自動尋路（延後，遵循 CLAUDE.md §3）。

---

## 2. 需求與行為契約

### REQ-M3-01 阿導大世界踩線狀態與 HUD `[P0]`
1. **頂部極簡 HUD（`CuratorFieldHud`）**：
   - 於畫面頂部 SafeArea 內呈現高度 36~40dp 之單列像素風格 HUD。
   - 整合三大核心指標：
     - **HP 條**：`[❤️ HP 85/100]`，附視覺化血條，綠/黃/紅動態顏色。
     - **預算 (Budget)**：`[💰 ¥ 5,000]`，赤字時呈現警示紅色。
     - **腰包使用量**：`[👝 3/6]`。
   - 在 360dp 螢幕下寬度自適應，不可與大地圖可視區產生遮擋衝突。
2. **診斷面板降級**：既有 Task C 之 `_RetroHudOverlay` 降級為 Debug 模式下可收折的懸浮按鈕，避免壓迫玩家主介面。

### REQ-M3-02 POI 景點接近判定與 5 態資格狀態機 `[P0]`
1. **距離判定**：
   - 依據小人世界位置（`renderedPixel`）與景點像素座標，計算實際地理直線距離（公尺）。
   - 距離 $\le 50.0$ 公尺時為「在觸發範圍內（In Proximity）」。
2. **5 態資格枚舉（`GatheringEligibility`）**：
   景點詳細資訊卡（`_AttractionDetailCard`）之取材按鈕嚴格依以下狀態機渲染：
   - `ready`：距離 $\le 50$m、未採集、HP $> 0$、腰包未滿 $\rightarrow$ 亮綠色「📸 踩線取材 (⚡-12 HP / 💰¥0)」。
   - `inventoryFull`：距離 $\le 50$m、未採集、HP $> 0$、腰包已滿 $\rightarrow$ 亮橘色「👝 踩線並換牌 (⚡-12 HP)」。
   - `alreadyGathered`：該景點 ID 已存在於 `gatheredPoiIds` $\rightarrow$ 灰色「✅ 本日已踩線」。
   - `outOfRange`：距離 $> 50$m $\rightarrow$ 灰色「距離太遠 (需 < 50m)」。
   - `exhausted`：阿導 HP $\le 0$ $\rightarrow$ 灰色「💤 體力已透支」。
3. **資訊透明化**：
   - 卡片必須清晰標註該景點對應素材之預告：預估消耗 HP（$\Delta\text{HP} = 10 + \text{riskLevel} \times 2$）與預算花費（$\text{cost}$）。
   - 若命中當局旅行哲學偏好標籤，點亮徽章「🎯 契合當前哲學」。
4. **渲染效能隔離**：
   - 單一景點按鈕狀態透過 Selector 訂閱；
   - 地圖多標記的高光特效由 Flame `AttractionLayerComponent` 在 Canvas 渲染時計算向量距離平方，嚴禁全域 Riverpod 高頻廣播。

### REQ-M3-03 踩線取材行為、原子轉移與換牌契約 `[P0]`
1. **原子領域轉移契約（`CuratorRunState`）**：
   - 實體新增不可變欄位：`final Set<String> gatheredPoiIds;`（初始為空集合）。
   - 領域方法定義：
     ```dart
     CuratorRunState gatherPoiMaterial({
       required String poiId,
       required TravelMaterial material,
     });

     CuratorRunState replaceGatheredMaterial({
       required String poiId,
       required int dropIndex,
       required TravelMaterial newMaterial,
     });
     ```
2. **前置檢查與異常（Preconditions）**：
   - 若 `gatheredPoiIds.contains(poiId)`，拋出 `PoiAlreadyGatheredException`。
   - 若 `resources.isExhausted || resources.currentHp <= 0`，拋出 `CuratorExhaustedException`。
   - 在 `gatherPoiMaterial` 中，若 `inventory.isFull`，拋出 `InventoryFullException`。
3. **消耗、產出與「最後一搏」**：
   - 消耗計算：$\Delta\text{HP} = 10 + (\text{material.riskLevel} \times 2)$。
   - 若扣減後 $\text{currentHp} - \Delta\text{HP} \le 0$，HP 截斷為 0，且狀態自動轉移為 `isExhausted = true`。
   - Budget 扣除 `material.cost`（允許小於 0 呈現赤字）。
   - `gatheredPoiIds` 集合加入 `poiId`。
   - 素材加入腰包；若為 `replaceGatheredMaterial`，則移除 `dropIndex` 原素材並放入 `newMaterial`。
4. **腰包滿額換牌互動流**：
   - 當 `GatheringEligibility == inventoryFull` 時點擊按鈕，彈出「👝 腰包已滿！替換或放棄」微型抽屜。
   - 玩家點選欲捨棄之舊卡，呼叫 `replaceGatheredMaterial`；或點選「放棄」，則不扣任何資源，該景點維持未踩線。

### REQ-M3-04 體力透支、強制返程與生命週期守護 `[P0]`
1. **強制返程轉移**：
   - 當某次取材使 HP 降為 0，阿導 `isExhausted` 成立，單局 `phase` **原子推進至 `CuratorRunPhase.nightEditing`**。
   - 探索移動鎖定：透過宣告式 `canExploreProvider` 阻斷 D-Pad / GPS 對小人位置的更新。
2. **自動開啟工作台之生命週期守護**：
   - 監聽 `curatorRunControllerProvider`：當狀態自 `!isExhausted` 躍遷至 `isExhausted` 時：
     - 自動關閉當前景點資訊卡（`selectedAttraction.value = null`）。
     - 防重複開啟保護（Modal Guard）：檢查當前是否已有 Modal 呈現在路由棧。
     - 嚴格配對 Flame 引擎暫停：`game.pauseEngine()` ➔ `await showModalBottomSheet(...)` ➔ `game.resumeEngine()`。
3. **手動檢視工作台**：
   - HP $> 0$ 時，玩家點擊「📑 策展工作台」，`phase` 維持 `CuratorRunPhase.fieldTrip`。關閉後可繼續大世界探索。
   - 只有在工作台內部明確點擊「結束踩線，進入夜晚排程」按鈕，才手動推進至 `nightEditing`。

### REQ-M3-05 城市圖資素材解耦契約 `[P0]`
1. 通用狀態層與領域層不得含有特定城市（如 Taiwan / Kyoto）的具名引用。
2. 景點素材之供給透過純領域契約 `PoiMaterialResolver` 介面提供：
   ```dart
   abstract class PoiMaterialResolver {
     TravelMaterial? resolveMaterialFor(String poiId);
   }
   ```
3. 映射規則：
   - 優先比對景點專屬 ID（如 `tp_101` $\rightarrow$ 「台北101璀璨天際線」）。
   - 若未配置專屬卡牌，則依據該景點之 `AttractionCategory` 從通用特色池中提供。
   - 若 Resolver 回傳 `null`，該景點在領域層判定為不可採集，取材按鈕反灰。
4. 城市圖資模組（如台灣圖資或京都圖資）在宣告景點時，於 `ProviderScope.overrides` 註冊其適配器。

### REQ-M3-06 取材視覺反饋（Game Feel Juice） `[P1]`
1. 取材成功時，於 Flutter Overlay 層觸發輕量浮動反饋（`GatheringFloatingFeedbackOverlay`，1.2 秒）：
   - 紅色浮字：`-XX HP`
   - 金色/藍色浮字：`+ 👝 [素材名稱]`（若為 Spotlight 絕景額外呈現爆擊粒子標籤 `✨ SPOTLIGHT!`）。
   - 內建 `IgnorePointer`，確保浮動動畫不阻塞點擊。
   - 防連點節流（Spam-click Debounce）：按鈕點擊後於非同步完成前進入 loading 態。

---

## 3. 驗收條件（Acceptance Criteria）

### AC-M3-1 阿導踩線狀態與 HUD 契約
- **AC-M3-1.1**：初始化踩線單局時，HUD 顯示初始 HP（100）、初始 Budget（依委託）、腰包使用數為 0，`phase` 為 `CuratorRunPhase.fieldTrip`。
- **AC-M3-1.2**：當小人像素位置變更並跨越景點 50m 邊界時，`attractionEligibilityProvider(poiId)` 狀態自 `outOfRange` 變更為 `ready`，且不觸發整個地圖 Widget 樹之全量 Rebuild。

### AC-M3-2 POI 感應範圍與 5 態資格
- **AC-M3-2.1**：小人與景點真實距離為 49.0 公尺（$\le 50$m）且未踩線、HP $> 0$、腰包未滿時，狀態為 `GatheringEligibility.ready`。
- **AC-M3-2.2**：小人與景點真實距離為 51.0 公尺（$> 50$m）時，狀態為 `GatheringEligibility.outOfRange`。
- **AC-M3-2.3**：切換選中景點至超距目標時，狀態立即變更為 `outOfRange`。

### AC-M3-3 踩線取材、消耗與最後一搏
- **AC-M3-3.1**：在 HP=100 時對 Risk 2 素材發動取材，HP 正確扣減 14 點至 86 點，腰包新增該素材，`gatheredPoiIds` 包含該景點 ID。
- **AC-M3-3.2**：若素材 Cost 為 1500，初始預算 2000 扣減為 500；若素材 Cost 為 3000，預算扣減為 -1000（赤字成立）。
- **AC-M3-3.3**：當阿導當前 HP 僅剩 5 點，對 Risk 3 素材（需 16 HP）發動取材，操作成功執行，HP 截斷為 0，`isExhausted` 為 true，觸發強制返程。

### AC-M3-4 腰包滿額現場換牌
- **AC-M3-4.1**：腰包達容量上限（6/6）且未踩線時，狀態為 `GatheringEligibility.inventoryFull`。
- **AC-M3-4.2**：在 `inventoryFull` 下執行 `gatherPoiMaterial` 拋出 `InventoryFullException` 且狀態無變更。
- **AC-M3-4.3**：在 `inventoryFull` 下執行 `replaceGatheredMaterial(dropIndex: 2, newMaterial: item)`，成功移除舊素材並加入新素材，HP 與 Budget 正常扣除，`gatheredPoiIds` 包含新景點 ID。

### AC-M3-5 單局防刷冷卻
- **AC-M3-5.1**：同一景點成功取材後，狀態變更為 `GatheringEligibility.alreadyGathered`。
- **AC-M3-5.2**：對已踩線之景點再次呼叫取材方法，拋出 `PoiAlreadyGatheredException`，HP、Budget 與腰包均零副作用。
- **AC-M3-5.3**：呼叫 `restartRun()` 後，`gatheredPoiIds` 清空，所有景點重置為初始資格。

### AC-M3-6 體力透支與流程推進
- **AC-M3-6.1**：取材使 HP 扣至 0 時，單局 `phase` 原子推進為 `CuratorRunPhase.nightEditing`，`canExploreProvider` 回傳 `false`。
- **AC-M3-6.2**：Widget 測試驗證：當 `phase == nightEditing` 觸發時，自動彈出 `CuratorStudioModal`，背景 Flame 引擎被 `pauseEngine()`。

### AC-M3-7 架構隔離與測試解耦
- **AC-M3-7.1**：`test/architecture/layer_boundaries_test.dart` 全數通過，通用領域與狀態層零具名城市硬編碼。
- **AC-M3-7.2**：使用純記憶體 `FakePoiMaterialResolver` 在純 `dart test` 環境下 1 秒內完成 AC-M3-1 至 AC-M3-6 之狀態斷言。
