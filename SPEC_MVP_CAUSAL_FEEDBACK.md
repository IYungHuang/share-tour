# SPEC — 《Share Tour：奇葩旅行策展人》MVP 玩法因果可視化與架構接線契約

狀態：**Draft v3（依現況程式碼實查校正）** — 待簽核
流程位置：`spec → 覆核 → plan → 覆核 → 執行計劃 → 覆核`
上位文件：`CROSS_CUTTING_CONSTRAINTS.md`、`CLAUDE.md`、`SPEC_MVP_CORE_LOOP.md`（牴觸時以其為準）
相關文件：`SPEC_MVP_TIMELINE_UI.md`（**必須先完成增修，見 §6 前置條件**）、`SPEC_MVP_AMENDMENT_01.md`

> **v3 修訂摘要（相對 v2）**
> v2 的因果語意與現況程式碼有五處對不上，照 v2 施工會做出「畫面與計分不一致」的第二套真相。v3 全面改為以實查結果為準：
> 1. **刪除雙客戶常駐變臉**。單局只有一個指派客戶（`curator_run_state.dart:158`、`curator_studio_modal.dart:117`），另一位客戶的表情對本局收益無意義。
> 2. **刪除自訂心態矩陣**，改用既有純函式 `ClientReviewEngine.evaluate()` 即時試算滿意度後分桶。表情因此**不可能**與結算評等分歧。
> 3. **架構守門改為執行期斷言**。v2 的字串掃描驗不到 reasonCode，是它自己要消滅的假綠燈。
> 4. **因果事實對齊真實計分**：疲勞的 Theme 側與 Hype 側分開；Hype 側只存在於網紅審查；槽位加成涵蓋 Slot 0/1/3 而非僅清晨；補上既有的同標籤共鳴。
> 5. **`purity_bonus` 退出可視化**，移入 §7 待決問題（實值 1 分，依 Rule 35 應先檢討存廢）。

---

## 1. 目的與背景

### 1.1 問題診斷：認知鏈條的斷裂

玩家目前處於「白天隨機採集、夜晚盲盒排列、結算莫名被罰」。問題貫穿四個節點：

| 遊戲歷程節點 | 玩家痛點 | 現況缺失 | 本 SPEC 解法 |
|---|---|---|---|
| **0. 白天採集期** | 不知素材夜晚會引發災難 | 素材只標 `riskLevel: 4`，與夜間疲勞割裂 | **採集語意貫通**：白天卡面打上 `[💀 拉車隱患]` |
| **1. 行前與手冊（命名）** | 不知道概念存在與規則由來 | 術語未世界觀化，只在扣分時突兀出現 | **Codex 命名與直通**：徽章點擊即開 Tooltip |
| **2. 夜間編排（預告）** | 排程不知後果；全給數字則退化為試算表 | 無即時預告，或精確算式破壞策展直覺（Rule 12/26） | **序數階梯符號（Pip）** + **客戶即時變臉** |
| **3. 結算與微調（歸因）** | 被退件卻不知差距在哪；微調後忘記哪張錯 | 無局域溯源，返回微調後資訊蒸發 | **局域單點歸因** + **微調焦點光暈** |

### 1.2 核心設計原則

1. **因果事實必須是計分規則的投影，不得是第二套規則。**
   每一條 `CausalFact` 都對應 `TimelineItinerary.calculateStats` 或 `ClientReviewEngine` 中一段**已存在**的計算。禁止為了畫面好看而發明領域層沒有的因果。違反此條就是製造「畫面說謊」。
2. **三條主動演繹軸 + 環境被動微光（落實 Rule 35）**
   - 主動（玩家可操作）：相鄰高風險（疲勞／連段）、哲學契合與排斥、預算硬約束。
   - 被動（環境定性存在感，不標數字）：槽位時段契合、節奏互補、同標籤共鳴。
3. **階梯式定性符號（Ordinal Pip）**：編排期只呈現**方向與來源**，不呈現**量級**。守住 Rule 12 —— 全數字化的取捨是算術，不是痛苦的選擇。
4. **表情不得與結算分歧**：客戶表情由 `ClientReviewEngine.evaluate()` 的 `satisfaction` 分桶導出，與最終評等同源。
5. **架構機械檢查**：每個因果代碼必須由執行期測試證明其在 UI 可見，杜絕 `rhythmActivePairs` 式死碼。

---

## 2. 行為契約與領域模型

### 2.1 因果語意事實模型（`domain/core_loop/causal/causal_fact.dart`）

> **約束**：純 Dart，嚴禁 import `package:flutter`、`dart:ui` 或 `package:flame`。遵循 CC-3 決定性計算（無時鐘、無亂數、無外部狀態）。

```dart
enum ImpactDirection { positive, negative }

enum ImpactIntensity { minor, major }

enum CausalDomain {
  fatigueAdjacency,  // 相鄰高風險（疲勞／連段）
  philosophySynergy, // 哲學契合與排斥
  budgetConstraint,  // 預算上限與超支
  ambient,           // 被動環境：槽位契合、節奏互補、同標籤共鳴
}

/// 供 UI 轉譯為表情的客戶即時心態
enum ClientImpression { ecstatic, pleased, neutral, stressed, furious }

class CausalFact {
  final CausalDomain domain;
  final ImpactDirection direction;
  final ImpactIntensity intensity;
  final int? slotIndex;          // 單槽位事實（0~3）
  final (int, int)? pairIndices; // 相鄰槽位對事實
  final String sourceSignifier;  // 顯示符號，如 '💀 拉車疲勞'
  final String reasonCode;       // Codex 查詢鍵，如 'fatigue_spike'
}

class ItineraryCausalReport {
  final List<CausalFact> facts;
  final ClientImpression clientImpression; // 本局指派客戶（單一）
  final bool hasFatigue;
  final bool isOverBudget;
  final int? primaryCulpritSlot;           // 最嚴重失分槽位，供微調光暈繼承
}
```

**相等性**：兩個類別皆須覆寫 `operator ==` 與 `hashCode`。`facts` 為 `List`，Dart 預設 List 相等為 identity，**必須手寫逐項比對與 `Object.hashAll`**；`domain/` 不得 import `package:flutter`，故不可使用 `listEquals`。

### 2.2 因果導出規則（每條均標註其對應的既有計算）

| reasonCode | 觸發條件 | 對應既有計算 | 方向／強度 |
|---|---|---|---|
| `fatigue_spike` | 相鄰兩槽 `riskLevel >= 3` | `timeline_itinerary.dart` `fatiguePairs`，Theme −10／對 | negative / major |
| `fatigue_hype_penalty` | 同上，**且**本局客戶為 `hypeInfluencer`，**且**哲學未反轉 | `client_review_engine.dart:112` Hype −14% `targetHype`／對 | negative / major |
| `chaotic_combo` | 同上，**且**客戶為 `hypeInfluencer`，**且** `philosophy.turnsAdjacentHighRiskIntoHypeCombo` | `client_review_engine.dart:114` Hype **+**14% `targetHype`／對 | positive / major |
| `philosophy_repelled` | 素材命中 `repelledTags` | `travel_philosophy.dart` 貢獻 `−70% × themeValue` | negative / major |
| `philosophy_matched_major` | 素材命中 ≥2 個 `preferredTags` | 貢獻 `90~92% × themeValue` | positive / major |
| `philosophy_matched_minor` | 素材命中 1 個 `preferredTags` | 貢獻 `40% × themeValue` | positive / minor |
| `budget_overrun_minor` | `0 < overrunRatio <= 0.15` | `_evaluateBudgetWorker` 超支比例扣分 | negative / minor |
| `budget_overrun_major` | `overrunRatio > 0.15` | 同上 | negative / major |
| `tag_synergy` | 相鄰後者與前者共享標籤 | `comboActiveSlots`，後者 Hype ×1.2 | positive / minor |
| `ambient_slot_affinity` | Slot 0/1/3 命中時段條件 | `TimelineSlotType.evaluateSlotBonus`，Theme +5 | positive / minor |
| `ambient_rhythm_flow` | 相鄰一高一低風險 | `rhythmActivePairs`，Theme +10／對 | positive / minor |

共 **11** 個代碼。補充約束：

- `overrunRatio = (totalCost - client.targetBudget) / client.targetBudget`，`targetBudget` 一律取**本局指派客戶**（社畜 2000 / 網紅 8000），禁止硬編碼。
- 素材命中 0 個 `preferredTags` 且未命中 `repelledTags` 時**不產出事實**（該素材貢獻為 0，畫面留白即是誠實）。
- `ambient_slot_affinity` 必須涵蓋 Slot 0（低風險 + `#散步`/`#早餐`）、Slot 1（低風險 + `#美食`/`#老街`/`#銅板美食`）、Slot 3（高風險或 `#深夜`/`#小酌`）。**只做 Slot 0 不算完成**：另外兩槽的 +5 會繼續黑箱。
- Slot 2（黃昏）無固定 Theme 加成，其相機倍率屬裝備資訊而非排列因果，不產出 `CausalFact`。

### 2.3 客戶即時心態（禁止第二套計分）

`clientImpression` **必須**由既有純函式導出，不得自訂門檻：

```
satisfaction = ClientReviewEngine.evaluate(
  client: state.client, stats: currentStats, philosophy: state.philosophy,
).satisfaction
```

分桶**必須以 `report.outcome` 為準，不得以 `satisfaction` 自訂門檻**：兩位客戶的評等分界不同（社畜 Rejected `< 60`、網紅 `< 50`，見 `client_review_engine.dart:58,138`），照統一門檻切會讓社畜 55 分時表情顯示 Near Miss 而實際是退件。

| `ReviewOutcome` | ClientImpression |
|---|---|
| `perfect` | `ecstatic` |
| `pass` | `pleased` |
| `nearMiss` | `neutral` |
| `rejected` 且 `satisfaction >= 30` | `stressed` |
| `rejected` 且 `satisfaction < 30` | `furious` |

`rejected` 拆兩態是為了湊滿五態表情，兩者都落在「會被退件」的語意內，不會讓表情暗示比實際更好的結果。

**未達提交門檻保護**：`stats.canSubmit == false`（不足 3 槽或不連續）時鎖定為 `neutral`，避免空排程即顯示暴怒。

此設計同時取消了 v2 的防詐欺補丁 —— 表情與結算同源，結構上不可能分歧，無需額外門檻。

### 2.4 最嚴重失分槽位（`primaryCulpritSlot`）

決定性優先序，同分取索引最小者：

1. 若超支：取已填槽位中 `cost` 最高者。
2. 否則若有疲勞對：取該對中 `riskLevel` 較高者（同值取後者，即較晚時段）。
3. 否則若有 `philosophy_repelled`：取第一個命中排斥標籤的槽位。
4. 否則為 `null`。

---

## 3. 介面行為契約

### 3.1 編排期（`CuratorStudioModal`）

1. **客戶意圖頭像（單一）**：工作台頂部呈現**本局指派客戶**頭像，`Key('client_expression')`，依 `clientImpression` 五態切換，點擊彈出定性心態氣泡。**不得**呈現未指派客戶的表情。
2. **符號光軌與環境微光**：
   - 槽位卡片浮現階梯徽章：`★ 契合` / `★★ 強烈共鳴` / `⚠️ 超支·輕度` / `🚨 超支·爆表` / `💢 排斥`。
   - 相鄰處渲染 `💀 拉車疲勞`；客戶為網紅且哲學為混亂冒險時，同時渲染 `⚡ 驚險連段`。
   - 環境微光（不標數字）：Slot 0/1/3 命中時段時邊框金色微光 `[時段契合]`；相鄰一高一低時軌道藍色微光 `[律動]`；相鄰同標籤時 `[共鳴]`。
3. **數字揭露邊界**（見 §6 前置條件）：編排期不得顯示 Theme／Hype 的**計分結果**數值與加減量。允許保留：素材卡面自身的固定屬性（`🔥hypeValue`、`🎯themeValue`）、相機倍率膠囊、成本與預算上限。前者是牌面資訊，後者是硬約束，皆非取捨算術。

### 3.2 結算面板（`ReviewSettlementModal`）

1. **局域因果歸因**：標明具體失分位置（超支元兇槽位與金額、疲勞時段對）。
2. **微調焦點繼承**：Near Miss / Rejected 點擊「🔧 返回微調」時，將 `primaryCulpritSlot` 帶回工作台，該槽位外圍呈現 `Key('highlight_culprit_slot')` 琥珀色呼吸光暈，直至玩家操作該槽位後消褪。
3. **禁止求解器**：不得呈現「把某卡換成某卡」的全域最佳解建議。

### 3.3 策展手冊與即時直通

1. **徽章即 Codex 入口**：所有因果徽章可點擊，依 `reasonCode` 彈出詞條 Tooltip。
2. **採集語意貫通**：白天 POI 取材卡面與替換清單中，`material.hasFatigueRisk` 為真時標註 `[💀 拉車隱患]`。

---

## 4. 驗收條件（AC）

### 4.1 領域層因果報告（AC-CF-1）

- [ ] **AC-CF-1.1**：相鄰兩槽 `riskLevel >= 3` 時產出 `fatigue_spike`（negative/major），`hasFatigue` 為 true。
- [ ] **AC-CF-1.2**：客戶為網紅且哲學為混亂冒險時，產出 `chaotic_combo`（positive）且**不**產出 `fatigue_hype_penalty`；`fatigue_spike`（Theme 側）仍須產出。
- [ ] **AC-CF-1.3**：客戶為社畜時，無論哲學為何皆**不**產出 `chaotic_combo` 或 `fatigue_hype_penalty`（Hype 側疲勞不存在於社畜審查）。
- [ ] **AC-CF-1.4**：動態預算 —— 社畜（2000）超支 10% 產出 `budget_overrun_minor`、超支 35% 產出 `budget_overrun_major`；同一份行程對網紅（8000）不產出任何超支事實。
- [ ] **AC-CF-1.5**：`clientImpression` 由 `ReviewOutcome` 導出且不得暗示比實際更好的結果 —— 逐一驗證 perfect→`ecstatic`、pass→`pleased`、nearMiss→`neutral`、rejected→`stressed`/`furious`；**並須包含一則社畜 `satisfaction` 落在 50~59 的案例**（該區間網紅為 Near Miss、社畜為 Rejected，是統一門檻分桶會出錯的地方）。
- [ ] **AC-CF-1.6**：`stats.canSubmit == false` 時 `clientImpression` 鎖定為 `neutral`。
- [ ] **AC-CF-1.7**：Slot 0、Slot 1、Slot 3 各自命中時段條件時，皆產出對應 `slotIndex` 的 `ambient_slot_affinity`（三槽皆須覆蓋）。
- [ ] **AC-CF-1.8**：`primaryCulpritSlot` 依 §2.4 優先序決定，同輸入重複計算結果恆等（決定性）。
- [ ] **AC-CF-1.9**：`ItineraryCausalReport` 與 `CausalFact` 的值相等成立 —— 兩份內容相同（含 `facts` 逐項相同）之報告 `==` 為真且 `hashCode` 相等。

### 4.2 架構接線機械檢查（AC-CF-2）

- [ ] **AC-CF-2.1**：`test/architecture/causal_wiring_test.dart` 以**執行期**方式驗證：建構一份含全部 11 個 `reasonCode` 的 `ItineraryCausalReport`，泵入工作台 Widget 後，每一條的 `sourceSignifier` 皆須在畫面上可尋得。任一條零可見即失敗。
  > 禁止以原始碼字串掃描替代：UI 消費的是 `CausalFact` 物件，不含 reasonCode 字面值，掃描必然得到假綠燈。
- [ ] **AC-CF-2.2**：`CuratorCodex` 對 11 個 `reasonCode` 皆有非空詞條；詞條文字不含具名城市（`taiwan`/`kyoto`）。
- [ ] **AC-CF-2.3**：`ItineraryStats` 的 `rhythmActivePairs`、`comboActiveSlots`、`fatiguePairs`、`slotThemeBonuses` 四個擊穿欄位，皆經由因果報告被 UI 消費（隨 AC-CF-2.1 一併覆蓋）。

### 4.3 編排期 UI（AC-CF-3）

- [ ] **AC-CF-3.1**：編排介面渲染帶 `Key('client_expression')` 的單一客戶頭像，且畫面上**不存在**第二位客戶的表情元件。
- [ ] **AC-CF-3.2**：編排期不得出現計分結果文字 —— 具體斷言：`LivePreviewHUD` 不含 `finalTheme` / `totalHype` 之渲染，光軌不含 `+20% Combo` 字樣，畫面無 `+N` / `-N` 形式的加減分文字。（素材牌面屬性、相機倍率、成本／預算不在此限，見 §3.1.3）
- [ ] **AC-CF-3.3**：點擊任一因果徽章，彈出對應 `reasonCode` 的 Codex 詞條 Tooltip。

### 4.4 結算與微調（AC-CF-4）

- [ ] **AC-CF-4.1**：發生疲勞或超支時，歸因區塊標明具體時段對與元兇槽位。
- [ ] **AC-CF-4.2**：點擊「返回微調」後，工作台對應槽位呈現 `Key('highlight_culprit_slot')` 光暈；玩家對該槽位執行放置／移除／互換任一操作後，光暈消失。
- [ ] **AC-CF-4.3**：結算面板不含手牌替換建議文案。

合計 **18** 條 AC。

---

## 5. 邊界約束與非目標

1. **純領域零依賴**：`domain/core_loop/causal/` 嚴禁 import Flutter / Flame / `dart:ui`。
2. **禁止全域最優求解器**：不得計算或呈現最優替換建議。
3. **禁止骨骼／粒子動畫**：表情以靜態圖示切換呈現，不引入新套件（CLAUDE.md §6）。
4. **決定性（CC-3）**：策略提示文案若具隨機性，須接受注入 `Random?`。
5. **不改動計分規則**：本 SPEC 只可視化既有計算，**不得**新增或調整任何數值規則。數值調整走 `SPEC_MVP_AMENDMENT_01.md`。

---

## 6. 前置條件（施工前必須清償）

1. **`SPEC_MVP_TIMELINE_UI.md` 增修**：本 SPEC 的 AC-CF-3.2 與下列三條已簽核 AC 直接牴觸，必須先以增修作廢或改寫，否則兩份 SPEC 同時為真是不可能的：
   - `AC-UI-2.2`：光軌須包含 `+20% Combo` 文本 → 改為符號 `[共鳴]`。
   - `SPEC_MVP_TIMELINE_UI §2.2C`：HUD 須顯示 Cost / Hype / Theme 三項即時試算 → 只保留 Cost 與預算警示。
   - `SPEC_MVP_TIMELINE_UI §2.2C 客群視角切換器`：單局客戶已於行前指派，切換器造成認知混淆 → 移除。
   - `AC-UI-2.4`（Slot 2 顯示相機倍率）**不受影響**，維持有效。
2. **`SPEC_MVP_AMENDMENT_01.md` 收斂**：該增修正在調整 Theme／Hype 係數與提交規則。因果事實是計分規則的投影，規則未定前施工必返工。須等其完成並合入主線後，以最新程式碼為基線。

---

## 7. 已裁決事項

1. **`purity_bonus` 保留規則，但不做編排期徽章**（使用者裁決，2026-09-12）。
   `timeline_itinerary.dart:277` 的 `purityBonus = 1` **不是殘留值**：依 `PLAN_MVP_AMENDMENT_01.md:77`，D4（疲勞量級）+ D5（絕景階梯）+ D6（純度量級）為不可分開決定的**聯立求解**，1 是滿足 `AC-A1-3.2/3.3/3.6` 的確定性勝者，在數學上承重。刪除它會使 `AC-A1-3.2`（存在一位客戶使 3 槽純行程勝過全部 4 槽排列）失去機制，並迫使三維聯立重跑 —— 爆炸半徑跨進 `SPEC_MVP_AMENDMENT_01` 的施工範圍。
   同時它在**感知上不可見**（1 分），且它回答的問題是「該不該為了湊滿塞第 4 張不合哲學的卡」，屬**提交當下的一次性決定**，效果不隨排列方式改變 —— 不符合 §1.2 第 2 點「主動因果軸」的判準。故其回饋歸屬結算文案，由既有的 `AC-A1-3.5`（純度成立與失效時文案可區分）承接，本 SPEC 不重複規範。
2. **客戶具名採用**（使用者裁決，2026-09-12）。
   `小林`／`安娜` 已寫在已簽核的 `SPEC_MVP_TIMELINE_UI.md:103,107`，但 `ClientSpec` 無對應欄位。新增 `final String personaName`（`budgetWorker` → `小林`、`hypeInfluencer` → `安娜`）。表情氣泡、結算吐槽與行前簡報一律以人名稱呼，`displayName` 保留為職稱。
   `ClientSpec` 屬 `SPEC_MVP_CORE_LOOP.md` 管轄，須於該文件補增修註記（見 PLAN T0）。`ClientSpec.operator ==` 只比對 `type`，新增欄位不影響相等語意。
3. **Codex 歸屬層**：置於 `domain/core_loop/causal/`。`lib/data/` 現定義為「外部世界實作」，且 `lib/ui/` 目前零 `data/` 相依，不為一份靜態文案字典新開這條相依方向。
