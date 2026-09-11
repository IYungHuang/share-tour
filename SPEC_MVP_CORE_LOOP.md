# SPEC — 《Share Tour：奇葩旅行策展人》MVP 核心遊戲循環

狀態：**正式通過 (v3)** — 經資深軟體架構師與首席遊戲企劃聯合審查簽核：完成算術閉合、相機參數解耦、浮點取整規範、Slot 1 中繼語義與網紅疲勞連鎖修正
流程位置：`spec → 覆核 (完成) → plan → 覆核 → 執行計劃 → 覆核`
上位文件：`CROSS_CUTTING_CONSTRAINTS.md`、`CLAUDE.md`（牴觸時以其為準）

---

## 1. 目的與範圍

### 1.1 目的
依據《Share Tour：奇葩旅行策展人》MVP 產品戰略，建立單局 5～10 分鐘、純離線、可重玩（Replayability）的核心遊戲循環契約：
**「接委託 ➔ 選擇哲學 ➔ 採集素材 ➔ 夜間時間線編輯 ➔ 雙客戶 Review 審查 ➔ 局外裝備升級 ➔ 再來一局」**。

本 SPEC 提供一組**純領域（Pure Domain）、可秒級自動化測試驗證**的數值與行為契約，具備封閉無二義性的算術公式、時空沉浸感的時間線槽位（Time-Slot Narrative）與強烈的失敗重試慾望（Near Miss）。

### 1.2 本 SPEC 涵蓋
1. 主角「阿導」的單局 3+1 核心資源狀態機（HP, Budget, Theme, Hype），單局 Run 以 UUID 唯一識別（遵循 CC-1）。
2. 5 種固定旅行哲學（Travel Philosophy）的判定與標籤契合度加成規則。
3. 旅行素材（Travel Material）的屬性契約、絕景標記（isSpotlight）與腰包容量限制。
4. 辦公室夜晚 4 時段時間線編輯（晨/午/暮/夜）、槽位專屬倍率、標籤共鳴與「拉車疲勞」衝突。
5. 雙客戶（極限窮遊社畜、IG 網紅）100 分制滿意度審查引擎（反無聊懲罰、絕景打折機制、疲勞脫妝扣分、4 級結果：Perfect / Pass / Near Miss / Rejected）。
6. 三件套裝備（球鞋、相機、腰包）局外升級的純領域數值映射契約（相機倍率動態注入流水線）。
7. 單局結算（決定性重播，遵循 CC-3）、佣金發放與「再來一局（Restart Run）」生命週期。

### 1.3 本 SPEC 明確不涵蓋（Not MVP / Out of Scope）

| 項目 | 歸屬 / 處置 |
|---|---|
| **GPS 定位、真機喚醒、外部地圖 API** | **Phase 3（Reality Run）**；MVP 期間全面隔離旁路 |
| 地圖繪製、Sprite 渲染、視口平移縮放 | 畫面層 / 里程碑 M2 |
| 微動作（Runner 衝刺、Snapshot 快門）的具體 Flame 碰撞實作 | 引擎層 / 里程碑 M3 |
| 網路連線、雲端同步、社群、排行榜、創作者經濟 | Phase 4（明確禁止，見 CC-1、企劃書 §十六） |
| AI / LLM 動態生成委託 | Phase 4（MVP 採固定規格委託） |

### 1.4 名詞定義

| 詞 | 定義 |
|---|---|
| **Run（單局）** | 從接下委託開始，經踩線取材、夜間編輯、客戶審查至結算的一輪完整遊戲過程（5～10 分鐘），以 UUID 作為實體識別碼（CC-1）。 |
| **阿導 (Guide Dao)** | 玩家操作的唯一主角，毒舌但熱愛旅行的奇葩策展人。 |
| **HP** | 阿導的體力資源。踩線或遭遇事件會消耗；HP 歸零則體力透支強制提前回辦公室。受球鞋裝備擴充上限。 |
| **Budget** | 本局旅行開銷預算。各素材與行動需扣除預算；直接決定窮遊社畜的滿意度。 |
| **Theme** | 本趟旅行的靈魂主題分數（0～100）。反映所選素材與當局旅行哲學的契合程度。 |
| **Hype** | 本趟旅行的亮點熱度分數。由絕景、高人氣或驚奇素材累積；直接決定 IG 網紅的滿意度。 |
| **Travel Philosophy** | 本局選定的旅行哲學（如午夜探索、美食朝聖），規範素材的加減分偏好。 |
| **Travel Material** | 踩線取得的旅行素材單元，具備標籤、數值、花費與風險。 |
| **時間線槽位 (Slot)** | 行程表固定擁有的 4 個具備旅行時間語義的有序槽位（晨/午/暮/夜）。 |
| **Near Miss（差一點）** | 客戶滿意度未達 Pass，但落在高分臨界區（如 60～69 分），激發玩家立刻再來一局。 |

---

## 2. 需求與行為契約

### REQ-ML-01 主角與單局資源狀態機 `[P0]`
1. 單局開始時，阿導的初始資源依委託規定初始化：
   - `runId`：由客戶端產生之 UUID（遵循 CC-1）。
   - `HP`：基礎上限為 100（受球鞋等級提升至 115 / 130），起始等於上限。
   - `Budget`：起始金額由委託客戶給定（社畜給予 2000 円，網紅給予 8000 円）。
   - `Theme`：起始為 50。
   - `Hype`：起始為 0。
2. 資源邊界約束：
   - `HP` 介於 `[0, maxHp]`。若 HP 降至 0，當前踩線階段立即終止，阿導強制返回辦公室進入夜間編輯階段。
   - `Budget` 可為負數（即「赤字/超支」），超支金額會以懲罰倍率重扣社畜滿意度。
   - `Theme` 介於 `[0, 100]`。
   - `Hype` 最小值為 0，無嚴格上限。

### REQ-ML-02 五大固定旅行哲學契約 `[P0]`
1. 單局開始接單後，玩家必須從 5 種哲學中選擇 1 種作為本局指針：
   - `midnight`（🌙 午夜探索）：偏好 `#深夜`、`#怪談`、`#孤獨` 標籤。
   - `slow`（☕ 慢旅行）：偏好 `#放空`、`#老街`、`#偶然` 標籤。
   - `gourmet`（🍜 美食朝聖）：偏好 `#深夜食堂`、`#地道`、`#銅板美食` 標籤。
   - `antiTourism`（🏚️ 反觀光）：偏好 `#巷弄秘境`、`#無人`、`#廢墟` 標籤；**排斥** `#大眾名店`。
   - `chaos`（🩸 混亂冒險）：偏好 `#高風險`、`#突發`、`#奇葩` 標籤。
2. 契合度加權規則：
   - 素材若帶有該哲學的 1 個或多個「偏好標籤」，其 `themeValue` 結算時獲得一次性 `+50%` 加成（四捨五入，不重複疊加）。
   - 素材若帶有該哲學的「排斥標籤」，其 `themeValue` 結算時扣除 `50%`，且額外扣除當局 Theme 5 點。
   - 偏好與排斥互斥；若同時命中，以排斥懲罰為準。不偏好也不排斥的中性素材，按原本 `themeValue` 結算。

### REQ-ML-03 旅行素材與腰包容量限制 `[P0]`
1. 每個旅行素材（`TravelMaterial`）必須具備以下不可變欄位：
   - `id`（String，唯一代碼）
   - `name`（String，素材名稱）
   - `tags`（List<String>，主題標籤）
   - `themeValue`（int，基礎主題分，≥ 0）
   - `hypeValue`（int，基礎熱度分，≥ 0）
   - `isSpotlight`（bool，是否為絕景/焦點地標）
   - `storyValue`（int，故事厚度 1～5 星；結算時每 1 星額外折算 5 點佣金）
   - `cost`（int，花費金額，≥ 0）
   - `riskLevel`（int，風險等級，1～5 星）
2. 踩線腰包容量（`materialInventoryCapacity`）：
   - 阿導隨身腰包單局能攜帶回辦公室的素材總數有嚴格上限。
   - 基礎上限為 6 件，可藉由局外裝備「腰包」擴充至 8 或 10 件。
   - 若腰包已滿，玩家取得新素材時必須立即二選一：**「替換既有素材」** 或 **「放棄新素材」**。

### REQ-ML-04 辦公室夜間時間線編輯契約 (4-Slot Timeline Narrative) `[P0]`
1. 進入辦公室後，玩家從腰包素材中挑選並排列至**恰好 4 個具備旅行語義的時間線槽位**：
   - **Slot 0（08:00 🌅 晨曦啟程）**：條件需同時滿足 `riskLevel <= 2` 且帶有（`#散步` 或 `#早餐`）標籤，額外獎勵 `+5 Theme`。
   - **Slot 1（12:00 ☀️ 午後漫遊）**：偏好低風險 (`riskLevel <= 2`) 且帶有（`#美食` 或 `#老街` 或 `#銅板美食`）標籤，若符合額外獎勵 `+5 Theme`（象徵午間中繼充飽電力）。
   - **Slot 2（17:00 🌇 黃昏高潮）**：**亮點倍率槽位！** 放入此槽位的素材，其 `hypeValue` 乘以注入的 `cameraMultiplier`（相機 Lv.1 為 1.5x、Lv.2 為 1.8x、Lv.3 為 2.2x）。
   - **Slot 3（22:00 🌙 深夜餘韻）**：滿足 `riskLevel >= 3` 或帶有（`#深夜`、`#小酌`）標籤時，獎勵 `+5 Theme`（命中多項不重複累加，上限 +5）。
2. 提交條件：
   - 必須填滿 **恰好 4 個槽位** 方可提交審查（`canSubmit == true`）。
3. 時間軸相鄰連鎖與衝突規則（針對相鄰對 $(0,1), (1,2), (2,3)$ 判定）：
   - **同標籤共鳴 (Tag Synergy)**：後者槽位與前一槽位若具備至少 1 個相同標籤，後者素材之 `hypeValue` 享有 `+20%` 連鎖加成（四捨五入）。Slot 0 無前置槽位，不享有此加成。
   - **節奏互補 (Rhythm Synergy)**：相鄰兩槽位若恰好為一高風險 (`riskLevel >= 3`) 與一低風險 (`riskLevel <= 2`)，獲得 `+10 Theme` 節奏流暢加分。
   - **🚨 拉車疲勞 (Friction Penalty)**：相鄰兩槽位若**皆為高風險 (`riskLevel >= 3`)**，觸發「拉車太趕、體力透支」，每次疲勞扣除 `10 Theme`；對網紅客戶額外扣除 `15 Hype`（「行程趕到脫妝，濾鏡都救不回來」）。
4. 數值匯總流水線（Pipeline，每個槽位獨立四捨五入取整）：
   - `totalCost = sum(materials.cost)`
   - 針對槽位 $i \in [0, 3]$：
     $$\text{slotHype}[i] = \text{round}\left((i == 2 \ ? \ \text{material}[i].\text{hype} \times \text{cameraMultiplier} \ : \ \text{material}[i].\text{hype}) \times (\text{hasTagCombo}[i] \ ? \ 1.2 \ : \ 1.0)\right)$$
   - `totalHype = sum(slotHype)`
   - 針對槽位 $i \in [0, 3]$：
     $$\text{materialTheme}[i] = \text{round}(\text{material}[i].\text{themeValue} \times \text{preferenceMultiplier})$$
   - `finalTheme = clamp(50 + sum(materialTheme) + slotThemeBonuses + rhythmBonuses - fatiguePenalties, 0, 100)`
   - `totalStory = sum(materials.storyValue)`

### REQ-ML-05 雙客戶 100 分制審查引擎 `[P0]`
1. 本 SPEC 實作兩位核心委託客戶，審查輸出為 **100 分制滿意度（Satisfaction Score）**：

   #### 客戶 A：極限窮遊社畜 (Budget Worker)
   - 委託目標：`targetBudget = 2000`，`minTheme = 60`。
   - 滿意度計算公式（超支每 10 円重扣 2 分）：
     $$\text{BudgetScore (滿分 70)} = \begin{cases} 70 & \text{if } \text{totalCost} \le 2000 \\ \max(0, 70 - \lfloor\frac{\text{totalCost} - 2000}{10}\rfloor \times 2) & \text{if } \text{totalCost} > 2000 \end{cases}$$
     $$\text{ThemeScore (滿分 30)} = \min\left(30, \text{round}\left(\frac{\text{finalTheme}}{60} \times 30\right)\right)$$
     $$\text{BoredomPenalty} = \begin{cases} 25 & \text{if } \text{totalHype} < 30 \\ 0 & \text{otherwise} \end{cases}$$
     $$\text{Satisfaction} = \text{clamp}(\text{BudgetScore} + \text{ThemeScore} - \text{BoredomPenalty}, 0, 100)$$

   #### 客戶 B：IG 網紅 (Hype Influencer)
   - 委託目標：`targetHype = 150`，追求絕景衝擊與無疲勞氛圍。
   - 滿意度計算公式：
     $$\text{FatigueHypePenalty} = \text{fatigueCount} \times 15$$
     $$\text{NetHype} = \max(0, \text{totalHype} - \text{FatigueHypePenalty})$$
     $$\text{SpotlightMultiplier} = \begin{cases} 1.0 & \text{if any material has } isSpotlight == true \\ 0.5 & \text{otherwise (無絕景打五折)} \end{cases}$$
     $$\text{EffectiveHype} = \text{round}(\text{NetHype} \times \text{SpotlightMultiplier})$$
     $$\text{ThemeFactor} = 0.7 + 0.3 \times \frac{\text{finalTheme}}{100}$$
     $$\text{Satisfaction} = \min\left(100, \text{round}\left(\frac{\text{EffectiveHype}}{150} \times 100 \times \text{ThemeFactor}\right)\right)$$

2. 四級審查判定輸出（Review Outcome）：
   - **🎉 完美通關 (Perfect)**：$\text{Satisfaction} \ge 90$。發放 150% 佣金 + 客戶吹捧台詞。
   - **👌 普通驗收 (Pass)**：$70 \le \text{Satisfaction} < 90$。發放 100% 佣金 + 標準過關台詞。
   - **⚠️ 差一點 (Near Miss)**：
     - 社畜：$60 \le \text{Satisfaction} < 70$（超支僅 10%～20% 左右或差點坐牢）。
     - 網紅：$50 \le \text{Satisfaction} < 70$（高 Hype 但缺絕景打五折或略有疲勞落在此區）。
     - 發放 30% 慰問金 + 「只差臨門一腳！」的激勵台詞。
   - **❌ 慘遭退件 (Rejected)**：$\text{Satisfaction} < 60$（社畜）或 $< 50$（網紅）。發放 0 佣金 + 毒舌反饋。
3. 佣金收益結算（決定性重播，CC-3）：
   - 基準佣金：社畜 1000 幣，網紅 2000 幣。
   - `earnedCoins = round(baseCommission * outcomeRate) + (totalStory * 5)`。

### REQ-ML-06 局外三件套裝備養成契約 (Meta Progression) `[P0]`
1. 局外提供三件可升級裝備，每件最高 3 級，升級需消耗玩家累積的佣金（Coins）：
   - **👟 球鞋 (Sneakers)**：直接擴充阿導單局初始與上限 HP。
     - Lv.1：HP 上限 = 100。
     - Lv.2：HP 上限 = 115。
     - Lv.3：HP 上限 = 130。
   - **📷 相機 (Camera)**：注入時間線流水線之黃昏槽位 `cameraMultiplier`。
     - Lv.1：`cameraMultiplier` = 1.5。
     - Lv.2：`cameraMultiplier` = 1.8。
     - Lv.3：`cameraMultiplier` = 2.2。
   - **🎒 腰包 (Waist Bag)**：擴充取材攜帶容量。
     - Lv.1：隨身素材容量上限 = 6。
     - Lv.2：隨身素材容量上限 = 8。
     - Lv.3：隨身素材容量上限 = 10。
2. 升級花費矩陣：Lv.1 ➔ Lv.2 需 500 幣；Lv.2 ➔ Lv.3 需 1500 幣。

### REQ-ML-07 單局結算與生命週期契約 (Run Lifecycle) `[P0]`
1. 結算完成後，系統產出不可變的單局結算報告事件（`RunSettledReport`），欄位包含 `runId` (UUID)、滿意度、評判等級、獲得佣金與客戶台詞，滿足決定性重播（CC-3）。
2. 提供 `Restart Run` 操作：
   - 保留玩家的總佣金累積與已升級裝備等級。
   - 完整清空並重置局內狀態（HP 回滿、Budget 重新發放、Theme 重置為 50、清空腰包與 4 槽位）。
   - 開啟新一局委託與哲學選擇。

---

## 3. 驗收條件 (Acceptance Criteria)

### AC-ML-1 資源狀態機
- **AC-ML-1.1** 球鞋為 Lv.1 時，新局阿導 HP 恆為 100；球鞋升至 Lv.2 時，新局阿導 HP 恆為 115。
- **AC-ML-1.2** 扣除 HP 至小於等於 0 時，狀態旗標 `isExhausted` 變為 true，且 HP 截斷為 0。
- **AC-ML-1.3** 花費超過 Budget 時，允許 Budget 呈現負數（如 -300）。
- **AC-ML-1.4** Theme 增加超過 100 時自動 clamp 至 100；扣至負數時 clamp 至 0。

### AC-ML-2 旅行哲學適配
- **AC-ML-2.1** 選定 `midnight` 哲學時，素材基礎 themeValue 為 10 且帶有 `#深夜`，其計算貢獻為 15（+50%）。
- **AC-ML-2.2** 選定 `antiTourism` 哲學時，素材帶有 `#大眾名店`，其計算貢獻減半且額外扣除總 Theme 5 點。
- **AC-ML-2.3** 中性素材按原始 themeValue 計算，不觸發額外獎懲。

### AC-ML-3 腰包容量限制
- **AC-ML-3.1** 當腰包裝備為 Lv.1 時，最多容納 6 個素材；達到 6 個後無法直接加入第 7 個。
- **AC-ML-3.2** 執行替換時，被剔除的素材移出腰包，新素材成功存入，總數維持 6。
- **AC-ML-3.3** 升級至 Lv.2 後，容量上限擴增為 8。

### AC-ML-4 時間線 4 槽位編輯器
- **AC-ML-4.1** 槽位填入少於 4 件時，`canSubmit` 為 false；恰好填滿 4 槽位時為 true。
- **AC-ML-4.2** 放入 Slot 2（黃昏槽位）的素材，其基礎 Hype 享有 1.5x 倍率（相機 Lv.1: cameraMultiplier = 1.5）。
- **AC-ML-4.3** 相鄰兩槽位具備相同標籤時，後者 Hype 享有 20% Combo 加成（獨立 round 取整）。
- **AC-ML-4.4（拉車疲勞）** 相鄰兩槽位之 riskLevel 皆 ≥ 3 時，Theme 扣除 10 點。
- **AC-ML-4.5（晨曦偏好）** Slot 0 放入帶有 `#散步` 且 riskLevel ≤ 2 的素材，Theme 獲得額外 5 點晨曦加分；若 riskLevel ≥ 3 則不給分。
- **AC-ML-4.6（午後中繼）** Slot 1 放入帶有 `#美食` 且 riskLevel ≤ 2 的素材，Theme 獲得額外 5 點午後加分。

### AC-ML-5 雙客戶審查引擎
- **AC-ML-5.1（社畜滿分）** 提交給社畜的行程花費 ≤ 2000、finalTheme ≥ 60 且 totalHype ≥ 30，滿意度 ≥ 90，判定為 Perfect，發放 150% 佣金。
- **AC-ML-5.2（社畜反無聊打擊）** 提交給社畜的行程花費僅 0 円且 finalTheme = 70，但 totalHype 僅 15（< 30），觸發反無聊懲罰扣 25 分，滿意度為 75，無法達成 Perfect。
- **AC-ML-5.3（社畜 Near Miss）** 提交給社畜的行程花費 2160 円（超支 160 円，依每 10 円扣 2 分扣 32 分，BudgetScore 得 38 分），finalTheme = 60（ThemeScore 得 30 分），totalHype ≥ 30，滿意度為 68 分 ($38 + 30 = 68$)，判定為 Near Miss，發放 30% 慰問金。
- **AC-ML-5.4（網紅通關）** 提交給網紅的行程 totalHype 達 160、包含 1 件 isSpotlight 素材且無疲勞（finalTheme=100），滿意度 ≥ 90，判定為 Perfect。
- **AC-ML-5.5（網紅無絕景打五折 Near Miss）** 提交給網紅的行程 totalHype 高達 200、無疲勞（finalTheme=100），但完全不含 isSpotlight 素材，打五折後 effectiveHype = 100，滿意度為 67 分 ($100/150 \times 100 \times 1.0 = 67$)，恰好落入 Near Miss 區間，發放 30% 慰問金。
- **AC-ML-5.6（網紅疲勞脫妝退件）** 提交給網紅的行程雖然 totalHype = 120 且有絕景，但產生 2 次拉車疲勞（扣 30 Hype，剩 90 Hype），且 finalTheme 暴跌至 20（ThemeFactor = 0.76），effectiveHype = 90，滿意度為 46 分 ($90/150 \times 100 \times 0.76 = 45.6 \rightarrow 46$)，判定為 Rejected。

### AC-ML-6 局外裝備養成
- **AC-ML-6.1** 佣金餘額充足時可執行升級，扣除對應金額，裝備等級從 Lv.1 變為 Lv.2。
- **AC-ML-6.2** 佣金不足時升級拋出拒絕異常，金額與等級不變。
- **AC-ML-6.3** 已達 Lv.3 的裝備無法再升級。

### AC-ML-7 單局再來一局生命週期
- **AC-ML-7.1** 執行 `Restart Run` 後，新局的 HP 依球鞋等級回滿，Budget 重新發放，Theme 為 50，腰包與 4 槽位清空。
- **AC-ML-7.2** 執行 `Restart Run` 後，上一局所賺取的佣金累積與已升級裝備等級維持不變。

---

## 增修註記 01 —— 客戶具名（2026-09-12）

**上游**：`SPEC_MVP_CAUSAL_FEEDBACK.md` v3 §7.2
**生效狀態**：待因果 SPEC 簽核後隨其 T2 一併實作。

`REQ-ML-05` 的兩位客戶目前僅有職稱（`ClientSpec.displayName` = `極限窮遊社畜` / `IG 網紅`），但 `SPEC_MVP_TIMELINE_UI.md:103,107` 的結算文案早已以「小林」「安娜」稱呼他們。文件與程式碼的落差使得任何以人名撰寫的台詞都無處取值。

**變更**：`ClientSpec` 新增 `final String personaName`。

| `ClientType` | `personaName` | `displayName`（不變） |
|---|---|---|
| `budgetWorker` | `小林` | `極限窮遊社畜` |
| `hypeInfluencer` | `安娜` | `IG 網紅` |

**約束**：

- `displayName` 保留職稱語意，用於行前委託的客戶類型標示；`personaName` 用於一切由客戶本人發話的場合（審查台詞、編排期心態氣泡）。
- `ClientSpec.operator ==` 只比對 `type`，新增欄位不影響相等語意，無需同步修改。
- `ClientSpec` 為手寫純類別，不涉 `freezed`／`json_serializable`，不需重跑 codegen。
- 人名屬世界觀文案，**不得**出現具名城市（架構約束第 2 條）。
