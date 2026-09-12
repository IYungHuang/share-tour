# SPEC — 《Share Tour：奇葩旅行策展人》MVP 玩法因果可視化與架構接線契約

狀態：**已簽核（v6，2026-09-12 由使用者明確簽核）**
流程位置：`spec (已簽核) → plan (已簽核) → 執行計劃 (已簽核) → 實作中`
上位文件：`CROSS_CUTTING_CONSTRAINTS.md`、`CLAUDE.md`、`SPEC_MVP_CORE_LOOP.md`（牴觸時以其為準）
相關文件：`SPEC_MVP_TIMELINE_UI.md`（**必須先完成增修，見 §6 前置條件**）、`SPEC_MVP_AMENDMENT_01.md`

> **v6 修訂摘要（相對 v5，使用者裁決 2026-09-12）**
> §5 第 3 款「禁止骨骼／粒子動畫」**撤銷**。該款以 `CLAUDE.md` §6（不引入新套件）為由，連帶禁止了不需要任何新套件的表現手法，把相依紀律誤擴張成表現手法禁令，是本案靜態觀感的制度來源。改為明確區分：新增相依套件仍禁止，使用引擎內建動畫能力則開放。本次修訂**不改動任何 AC、數值或領域契約**。

---

> **v5 修訂摘要（相對 v4，第二輪雙軌覆核修訂）**
> 第二輪企劃與工程雙軌覆核指出了 v4 的殘留矛盾與接線盲區，修訂如下：
> 1. **消除 `fatigue_hype_penalty` 孤兒代碼與軌道接線盲區**（覆核 P0-2）。相鄰軸軌道明確定義為四態同軌同階（社畜/一般負面 `💀 拉車疲勞`、網紅 Hype 負面 `💀 脫妝暴跌`、正面 `🎵 節奏互補`、混亂冒險 `⚡ 驚險連段`），確保 14 個 reasonCode 在 UI 皆有坑位可尋，杜絕 T7 守門測試必紅。
> 2. **修補 §2.4 最嚴重失分槽位邊界缺陷**（覆核 P0-5）。第 4 款新增邊界防護：遇「3 槽連續且全為絕景」時取第一個空槽位提示補足缺口；第 2 款明訂多疲勞對時取所有疲勞涉及槽位中最高 riskLevel 者。
> 3. **反無聊門檻引入階梯張力反饋**（覆核 P1-3）。編排期 HUD 雖不顯示總 Hype 數字，但提交列提供定性階梯（`< 120` 極度乏味、`120~167` 稍嫌平淡、`>= 168` 警示消褪），避免玩家在 168 門檻無預警墜落 25 分斷崖。
> 4. **六態表情具體視覺與氣泡文案定稿**（覆核 P1-6）。補齊六態（ecstatic 🤩 / pleased 😊 / neutral 😐 / stressed 😰 / furious 😡 / idle 💤）的 Icon/Emoji 規格與定性心態氣泡台詞。
> 5. **補齊 4 項玩家可見行為的驗收條件**（覆核 P1-7）。補足點擊頭像氣泡（`AC-CF-3.1`）、絕景 4 格 pip 動態亮燈（`AC-CF-3.2`）、反無聊警示越線消褪（`AC-CF-3.2`）、腰包抽屜清除 `🎯` 數值（`AC-CF-3.2`）。
> 6. **絕景階梯 4 格 pip 冠狀星芒與長按詳情規範**。第 4 格 pip 特別標記為冠狀星芒 `★`（暗示 +15% 暴擊躍升）；素材長按詳情（Inspect Sheet）保留原始 `🎯themeValue` 供進階比牌，卡面則維持純階梯符號防誤導。

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
2. **軸的分級依實測量級，不依直覺（落實 Rule 35）**
   消融實驗（全 32 張卡表 × 5 哲學 × 每組 4000 次隨機行程，逐規則關掉量滿意度變化）結果：

   | 規則 | 社畜 mean\|Δ\| | 社畜觸發率 | 網紅 mean\|Δ\| | 網紅觸發率 | 本 SPEC 分級 |
   |---|---|---|---|---|---|
   | 絕景階梯 | 0.00 | 0% | **17.44** | 84.2% | 主動軸 |
   | 預算超支 | **12.42** | 40.6% | 0.00 | 0% | 主動軸 |
   | 反無聊門檻 | 5.53（觸發即 −25） | 22.1% | 0.00 | 0% | 主動軸 |
   | 節奏互補 | 5.95 | 64.7% | 4.69 | 57.8% | 主動軸（與疲勞同軸正面） |
   | 同標籤共鳴 | 3.47（觸發時 25.0） | 13.9% | 4.98 | 81.7% | 環境（major） |
   | 時段契合 | 3.59 | 82.6% | 2.84 | 73.2% | 環境（minor） |
   | 哲學契合 | 3.17 | 90.0% | 2.39 | 76.3% | 主動軸 |
   | 疲勞 Theme 側 | 0.71 | 11.2% | 0.55 | 9.1% | 主動軸（與節奏同軸反面） |
   | 疲勞 Hype 側 | — | — | 0.76 | 9.5% | 主動軸 |
   | 純度 | 0.01 | 0.8% | 0.01 | 0.7% | 不做表現（§7.1） |

   - **主動（玩家操作直接改變、且量級足以被感知）**：相鄰高風險軸（疲勞／連段／節奏互補三態同軌）、哲學契合與排斥、預算硬約束、絕景階梯、反無聊門檻。
   - **環境（定性存在感，不標數字）**：同標籤共鳴、槽位時段契合。
   - 被排除者必須說明為何排除（見 §7）。**不得因為一條規則「小到不值得做表現」就靜靜留著它** —— 那是 Rule 35 的證據，該回頭檢討規則本身。
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
  adjacency,         // 相鄰槽位軸：疲勞 / 連段 / 節奏互補（同一條軸的三態）
  philosophySynergy, // 哲學契合與排斥
  budgetConstraint,  // 預算上限與超支
  spotlight,         // 絕景階梯（網紅端最大槓桿）
  boredom,           // 反無聊門檻（社畜端 25 分斷崖）
  ambient,           // 環境：同標籤共鳴、槽位時段契合
}

/// 供 UI 轉譯為表情的客戶即時心態
/// idle 專供「尚未達提交門檻」，不得與 neutral（Near Miss）共用
enum ClientImpression { ecstatic, pleased, neutral, stressed, furious, idle }

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
| `fatigue_spike` | 相鄰兩槽 `riskLevel >= 3` | `timeline_itinerary.dart:262-264` `fatiguePairs`，Theme −10／對 | negative / major |
| `fatigue_hype_penalty` | 同上，**且**本局客戶為 `hypeInfluencer`，**且**哲學未反轉 | `client_review_engine.dart:111-112,118` Hype −`round(targetHype × 14%)`／對 | negative / major |
| `chaotic_combo` | 同上，**且**客戶為 `hypeInfluencer`，**且** `philosophy.turnsAdjacentHighRiskIntoHypeCombo` | `client_review_engine.dart:111-112,116` Hype **+**同值／對 | positive / major |
| `rhythm_complement` | 相鄰一高一低風險 | `timeline_itinerary.dart:256-258` `rhythmActivePairs`，Theme +10／對 | positive / major |
| `philosophy_repelled` | 素材命中 `repelledTags` | `travel_philosophy.dart:58-66` 貢獻 `−70% × themeValue` | negative / major |
| `philosophy_matched_major` | 素材命中 ≥2 個 `preferredTags` | `travel_philosophy.dart:68-81` 貢獻 `90~92% × themeValue` | positive / major |
| `philosophy_matched_minor` | 素材命中 1 個 `preferredTags` | `travel_philosophy.dart:82-88` 貢獻 `40% × themeValue` | positive / minor |
| `budget_overrun_minor` | `0 < overrunRatio <= 0.15` | `client_review_engine.dart:37-43` 超支比例扣分 | negative / minor |
| `budget_overrun_major` | `overrunRatio > 0.15` | 同上 | negative / major |
| `spotlight_shortfall` | 客戶為 `hypeInfluencer` 且 `spotlightCount < 4` | `client_review_engine.dart:9,121-124` `spotlightLadder` 未達頂階 | negative / `spotlightCount <= 1` 為 major，否則 minor |
| `spotlight_full` | 客戶為 `hypeInfluencer` 且 `spotlightCount >= 4` | 同上，乘數達 `1.00` | positive / major |
| `boredom_risk` | 客戶為 `budgetWorker` 且 `totalHype < client.boredomThreshold` | `client_review_engine.dart:49-50`、`client_spec.dart:40` 固定 −25 | negative / major |
| `tag_synergy` | 相鄰後者與前者共享標籤 | `timeline_itinerary.dart:244-250` `comboActiveSlots`，後者 Hype ×1.2 | positive / major |
| `ambient_slot_affinity` | Slot 0/1/3 命中時段條件 | `timeline_slot.dart:16-43` `evaluateSlotBonus`，Theme +5 | positive / minor |

共 **14** 個代碼。補充約束：

- `overrunRatio = (totalCost - client.targetBudget) / client.targetBudget`，`targetBudget` 一律取**本局指派客戶**（社畜 2000 / 網紅 8000），禁止硬編碼。
- **`philosophy_repelled` 與 `philosophy_matched_*` 互斥**：`travel_philosophy.dart:58` 命中排斥標籤即短路返回，同一素材不可能同時產出兩者。UI 不得同時渲染。
- 素材命中 0 個 `preferredTags` 且未命中 `repelledTags` 時**不產出事實**（該素材貢獻為 0，畫面留白即是誠實）。
- `spotlight_shortfall` 只呈現**還差幾張**（以 4 格 pip 表示 `spotlightCount`，第 4 格標記冠狀星芒暗示大滿貫爆點），**不得**呈現乘數數值。卡面既有的 `⭐` 標記（`compact_slot_card.dart:158`、`waist_bag_drawer.dart:159`）維持不變，本條是把它接到後果上。
- `boredom_risk` 領域層是**斷崖而非斜坡**（固定 −25），故事實本身只有觸發／未觸發兩態；但為守護策展掌控感、避免無預警斷崖，編排期提交列提供前置階梯張力警示（見 §3.1.2）。
- `ambient_slot_affinity` 必須涵蓋 Slot 0（低風險 + `#散步`/`#早餐`）、Slot 1（低風險 + `#美食`/`#老街`/`#銅板美食`）、Slot 3（高風險或 `#深夜`/`#小酌`）。**只做 Slot 0 不算完成**：另外兩槽的 +5 會繼續黑箱。
- Slot 2（黃昏）無固定 Theme 加成，其相機倍率屬裝備資訊而非排列因果，不產出 `CausalFact`。
- **相鄰槽位軸的四態必須共用同一視覺階級**：`fatigue_spike`（社畜/一般負面，`💀 拉車疲勞`）、`fatigue_hype_penalty`（網紅負面，`💀 脫妝暴跌`）、`rhythm_complement`（正面，`🎵 節奏互補`）、`chaotic_combo`（正面，`⚡ 驚險連段`）源自同一個相鄰關係與哲學檢定，四態同軌同階（同尺寸、同層級，僅符號與色彩不同）。把負面做成醒目骷髏、正面做成微光，會讓玩家系統性高估疲勞、低估節奏 —— 那是另一種形式的畫面說謊。

### 2.3 客戶即時心態（禁止第二套計分）

`clientImpression` **必須**由既有純函式導出，不得自訂門檻：

```
satisfaction = ClientReviewEngine.evaluate(
  client: state.client, stats: currentStats, philosophy: state.philosophy,
).satisfaction
```

分桶**必須以 `report.outcome` 為準，不得以 `satisfaction` 自訂門檻**：兩位客戶的評等分界不同（社畜 Rejected `< 60`、網紅 `< 50`，見 `client_review_engine.dart:58,136,145`），照統一門檻切會讓社畜 55 分時表情顯示 Near Miss 而實際是退件。

| `ReviewOutcome` | ClientImpression | 視覺圖示 (Icon) | 定性心態氣泡台詞範例 |
|---|---|:---:|---|
| `perfect` | `ecstatic` | 🤩 | 「太棒了！這簡直是為我量身打造的完美行程！」 |
| `pass` | `pleased` | 😊 | 「很不錯呢，有打中我的期待，通過！」 |
| `nearMiss` | `neutral` | 😐 | 「還行吧，但總覺得差了那麼一點點...」 |
| `rejected` 且 `satisfaction >= 30` | `stressed` | 😰 | 「這真的不行...雖然有些亮點，但整體問題太大。」 |
| `rejected` 且 `satisfaction < 30` | `furious` | 😡 | 「完全不知所云！這是在整我嗎？立刻重排！」 |
| `canSubmit == false` | `idle` | 💤 | 「阿導，行程還沒排完呢，我先瞇一下...」 |

`rejected` 拆兩態是為了湊滿五態表情，兩者都落在「會被退件」的語意內，不會讓表情暗示比實際更好的結果。

**未達提交門檻**：`stats.canSubmit == false`（不足 3 槽或不連續）時為 **`idle`**，不得沿用 `neutral`。
現行提交門檻是 3 槽連續（`timeline_itinerary.dart:138-161`），玩家排下第 1、2 張卡時必然落在此區 —— 佔整個編排流程約一半。`neutral` 同時是 `nearMiss` 的表情，共用會讓玩家分不清「還沒排完」與「差一點過關」。`idle` 的視覺應明確表達「還在等行程」（如打盹、背對、整體灰階），而非一個中性評價。

> 過了門檻之後回饋密度是足夠的：實測單卡替換有 **43.7%（社畜）/ 40.4%（網紅）** 會改變表情分桶。
>
> 另記錄一項不屬本 SPEC 範圍的觀察：網紅端實際只會用到三態（`furious` 0.0%、`stressed` 1.9%，因退件門檻 50 而平均分 77）。若要五態均衡需動評等門檻，屬 `SPEC_MVP_AMENDMENT_01` 範疇。

此設計同時取消了 v2 的防詐欺補丁 —— 表情與結算同源，結構上不可能分歧，無需額外門檻。

### 2.4 最嚴重失分槽位（`primaryCulpritSlot`）

決定性優先序。**通則：任何平手一律取索引較小者**，全條無例外。

1. 若超支：取已填槽位中 `cost` 最高者（平手取索引較小者）。
2. 否則若有疲勞對：取所有疲勞對涉及之槽位中 `riskLevel` 最高者（平手取索引較小者）。
3. 否則若有 `philosophy_repelled`：取索引最小的命中槽位。
4. 否則若客戶為 `hypeInfluencer` 且 `spotlight_shortfall` 成立：取索引最小的非絕景已填槽位；若已填槽位全為絕景，則取第一個空槽位（提示填滿第 4 槽以補足絕景缺口）；若皆無則為 `null`。
5. 否則為 `null`。

> v4 統一為平手取索引較小者；v5 補齊第 4 款「3 槽全為絕景」時的邊界防護，避免 `.firstWhere` 無元素拋出例外，並給出合理解法。

---

## 3. 介面行為契約

### 3.1 編排期（`CuratorStudioModal`）

1. **客戶意圖頭像（單一）**：工作台頂部呈現**本局指派客戶**頭像，`Key('client_expression')`，依 `clientImpression` 六態切換，點擊彈出定性心態氣泡（以 `personaName` 稱呼，點擊空白消褪）。**不得**在編排期呈現未指派客戶的表情 —— 客戶於開局隨機指派（`curator_run_state.dart:89-90`），玩家不選，另一位的反應不驅動任何決策。
2. **符號光軌**：
   - 相鄰槽位軸四態同軌同階：`💀 拉車疲勞`（社畜/一般負面）／`💀 脫妝暴跌`（網紅 Hype 負面）／`🎵 節奏互補`（正）／`⚡ 驚險連段`（正，限網紅 × 混亂冒險）。
   - 槽位卡片階梯徽章：`★ 契合` / `★★ 強烈共鳴` / `💢 排斥` / `⚠️ 超支·輕度` / `🚨 超支·爆表`。
   - 絕景階梯以 **4 格 pip** 呈現當前 `spotlightCount`，第 4 格以冠狀星芒 `★` 呈現（暗示達成 1.00 之大滿貫暴擊跳升）；未達 4 格時附 `📉` 記號，全滿時附 `🌟` 記號；**不得顯示乘數**。
   - 社畜局 `boredom_risk` 階梯張力警示：提交列呈現定性警示 —— `totalHype < 120` 時顯示 `🚨 極度乏味`，`120 <= totalHype < 168` 時顯示 `⚠️ 稍嫌平淡`，`>= 168` 時警示即時消褪；不顯示 −25 數字。
   - 環境層（不標數字）：`[共鳴]`（同標籤）、`[時段契合]` 金色微光（Slot 0/1/3）。
3. **數字揭露邊界**：編排期不得顯示 Theme／Hype 的**計分結果**數值與加減量。
   - **允許保留**：`🔥hypeValue`（base 值確實會進 `slotEffectiveHypes`，是誠實的比較基準）、相機倍率膠囊、成本與預算上限。
   - **必須移除** 卡面 `🎯themeValue`（`compact_slot_card.dart:191`、`waist_bag_drawer.dart:159`）：它是未經哲學係數換算的 base 值，實際貢獻為 `40% / 90% / 92% / −70%`（`travel_philosophy.dart:62,72,78,84`）。玩家看到 `🎯35` 的卡在錯的哲學下實際貢獻是 −25 —— 保留一個會誤導的數字，比不給數字更糟。改以 `★ / ★★ / 💢` 定性階梯取代。
   - **長按詳情（Inspect Sheet）**：長按素材卡彈出的詳情抽屜保留原始 `🎯themeValue` 與哲學係數計算說明，兼顧卡面防誤導與深度比牌需求。

### 3.2 結算面板（`ReviewSettlementModal`）

1. **分母與係數一律取自資料，禁止硬編碼**。現行畫面有四處寫死且已與引擎不符：

   | 位置 | 現行畫面文字 | 引擎實際值 |
   |---|---|---|
   | `review_settlement_modal.dart:525` | `預算得分 … / 70` | `/ 44`（`client_review_engine.dart:32`） |
   | `:526` | `主題契合得分 … / 30` | `/ 56`（`:46`） |
   | `:529` | `反無聊懲罰 (Hype<30)` | `Hype < 168`（`client_spec.dart:40,49`） |
   | `:553` | `絕景打折提醒　無絕景打五折` | `×0.70`，且是四階階梯；該行的 `hasNoSpotlight = spotlightMultiplier < 1.0` 在持有 1~3 張絕景時同樣成立，文案與條件雙錯（`:9,121-124`） |

   本案的立案原則是「畫面不得與計分分歧」。這四處是現役畫面上最直接的反例，必須在本案內修正，改由 `report.subscores` 與 `ClientSpec` 取值。
2. **局域因果歸因**：標明具體失分位置（超支元兇槽位與金額、疲勞時段對、絕景缺口張數）。
3. **客群頁籤保留，但歸因限定指派客戶**：`client_tab_budgetWorker` / `client_tab_hypeInfluencer`（`:154,:162`）維持有效 —— 它會以 `ClientReviewEngine` 真的重算另一位客戶（`:83-98`），是免費的教學面，且佣金發放受 `curator_run_state.dart:358` 的客戶比對守衛保護。
   **但歸因區塊與 `primaryCulpritSlot` 恆以本局指派客戶計算**（超支判定用 `client.targetBudget`，兩位客戶差 4 倍）。切到非指派頁籤時，歸因區塊必須隱藏或明確標示「此為另一位客戶的試算，不含歸因」，否則會出現「評等屬 A 客戶、元兇槽位屬 B 客戶」的新說謊面。
4. **微調焦點繼承**：Near Miss / Rejected 點擊「🔧 返回微調」時，將 `primaryCulpritSlot` 帶回工作台，該槽位外圍呈現 `Key('highlight_culprit_slot')` 琥珀色呼吸光暈，直至玩家操作該槽位後消褪。

### 3.3 策展手冊與即時直通

1. **徽章即 Codex 入口**：所有因果徽章可點擊，依 `reasonCode` 彈出詞條 Tooltip。
2. **採集語意貫通**：白天 POI 取材卡面（`attraction_detail_card.dart`）與替換清單（`gathering_replace_bottom_sheet.dart`）中，`material.hasFatigueRisk` 為真時標註 `[💀 拉車隱患]`。

---

## 4. 驗收條件（AC）

### 4.1 領域層因果報告（AC-CF-1）

- [ ] **AC-CF-1.1**：相鄰兩槽 `riskLevel >= 3` 時產出 `fatigue_spike`（negative/major），`hasFatigue` 為 true。
- [ ] **AC-CF-1.2**：客戶為網紅且哲學為混亂冒險時，產出 `chaotic_combo`（positive）且**不**產出 `fatigue_hype_penalty`；`fatigue_spike`（Theme 側）仍須產出。
- [ ] **AC-CF-1.3**：客戶為社畜時，無論哲學為何皆**不**產出 `chaotic_combo` 或 `fatigue_hype_penalty`（Hype 側疲勞不存在於社畜審查）。
- [ ] **AC-CF-1.4**：動態預算 —— 社畜（2000）超支 10% 產出 `budget_overrun_minor`、超支 35% 產出 `budget_overrun_major`；同一份行程對網紅（8000）不產出任何超支事實。
- [ ] **AC-CF-1.5**：`clientImpression` 由 `ReviewOutcome` 導出且不得暗示比實際更好的結果 —— 逐一驗證 perfect→`ecstatic`、pass→`pleased`、nearMiss→`neutral`、rejected→`stressed`/`furious`；**並須包含一則社畜 `satisfaction` 落在 50~59 的案例**（該區間網紅為 Near Miss、社畜為 Rejected，是統一門檻分桶會出錯的地方）。
- [ ] **AC-CF-1.6**：`stats.canSubmit == false` 時 `clientImpression` 為 `idle`，且 `idle` 不等於 `neutral`。
- [ ] **AC-CF-1.7**：Slot 0、Slot 1、Slot 3 各自命中時段條件時，皆產出對應 `slotIndex` 的 `ambient_slot_affinity`（三槽皆須覆蓋）。
- [ ] **AC-CF-1.8**：`primaryCulpritSlot` 依 §2.4 優先序決定 —— 逐條驗證五款優先序，**並須包含一則平手案例**驗證「取索引較小者」。
- [ ] **AC-CF-1.9**：`ItineraryCausalReport` 與 `CausalFact` 的值相等成立 —— 兩份內容相同（含 `facts` 逐項相同）之報告 `==` 為真且 `hashCode` 相等。
- [ ] **AC-CF-1.10**：相鄰一高一低風險時產出 `rhythm_complement`（positive/major）；與 `fatigue_spike` 互斥（同一對槽位不可能同時產出）。
- [ ] **AC-CF-1.11**：網紅局 `spotlightCount` 為 0 產出 `spotlight_shortfall`（major）、為 2 產出 `spotlight_shortfall`（minor）、為 4 產出 `spotlight_full`（positive/major）；社畜局三種情況皆不產出。
- [ ] **AC-CF-1.12**：社畜局 `totalHype` 低於 `client.boredomThreshold` 時產出 `boredom_risk`（negative/major），高於時不產出；網紅局任何 Hype 皆不產出。
- [ ] **AC-CF-1.13**：素材同時命中 `repelledTags` 與 `preferredTags` 時，只產出 `philosophy_repelled`，不產出 `philosophy_matched_*`。

### 4.2 架構接線機械檢查（AC-CF-2）

- [ ] **AC-CF-2.1**：`causal_wiring_test.dart` 以**端到端**方式驗證 —— 對每個 `reasonCode`，構造一份**真實的 `TimelineItinerary` + philosophy + client**，經 `calculateStats → CausalReportBuilder.build → Widget` 完整鏈路後，斷言其 `sourceSignifier` 在畫面上可尋得。任一條零可見即失敗。
  > **禁止以人工建構的報告作為本條的唯一證據**：那只證明「UI 會畫交到它手上的事實」，不證明 builder 會從 stats 產出該事實。鏈條中間那段若沒被測到，就與 `rhythmActivePairs` 當年的病灶同型 —— 而消滅該病灶正是本案的立案理由。人工報告只能作為補充案例。
- [ ] **AC-CF-2.2**：`CuratorCodex` 對全部 14 個 `reasonCode` 皆有非空詞條。
  > 「不含具名城市」不另立 AC：`test/architecture/layer_boundaries_test.dart:42-54` 已對 `lib/domain` 全樹掃描，Codex 置於 `domain/core_loop/causal/` 自動涵蓋。
- [ ] **AC-CF-2.3**：`ItineraryStats` 的 `rhythmActivePairs`、`comboActiveSlots`、`fatiguePairs`、`slotThemeBonuses`、`spotlightCount` 五個擊穿欄位，各自至少有一條 AC-CF-2.1 的端到端案例證明其經由因果報告抵達畫面。
- [ ] **AC-CF-2.4**：`material.hasFatigueRisk` 為真時，取材卡面與替換清單皆渲染 `[💀 拉車隱患]`；為假時不渲染。
  > 此為 §1.1 表格第 0 列（白天採集期）的唯一解法，v3 漏立 AC。

### 4.3 編排期 UI（AC-CF-3）

- [ ] **AC-CF-3.1**：編排介面渲染帶 `Key('client_expression')` 的單一客戶頭像，畫面上**不存在**第二位客戶的表情元件；點擊頭像彈出符合當前 `clientImpression` 之定性心態氣泡，點擊空白消褪。
- [ ] **AC-CF-3.2**：編排期不得出現計分結果文字 —— 具體斷言：`LivePreviewHUD` 不含 `finalTheme` / `totalHype` 之渲染，光軌不含 `+20% Combo` 字樣，槽位卡片與腰包卡面不含 `🎯` 數值，畫面無 `+N` / `-N` 形式的加減分文字，絕景區不含乘數數值；絕景 4 格 pip 依 `spotlightCount` 動態點亮對應格數；社畜反無聊警示在 `totalHype >= 168` 時即時消褪。（`🔥hypeValue`、相機倍率、成本／預算不在此限，見 §3.1.3）
- [ ] **AC-CF-3.3**：點擊任一因果徽章，彈出對應 `reasonCode` 的 Codex 詞條 Tooltip。
- [ ] **AC-CF-3.4**：相鄰槽位軸的四態（`fatigue_spike` / `fatigue_hype_penalty` / `rhythm_complement` / `chaotic_combo`）渲染於同一軌道位置且視覺階級相同（同尺寸、同層級，僅色彩與符號不同）。

### 4.4 結算與微調（AC-CF-4）

- [ ] **AC-CF-4.1**：發生疲勞、超支或絕景不足時，歸因區塊標明具體時段對、元兇槽位與缺口張數。
- [ ] **AC-CF-4.2**：點擊「返回微調」後，工作台對應槽位呈現 `Key('highlight_culprit_slot')` 光暈；玩家對該槽位執行放置／移除／互換任一操作後，光暈消失。
- [ ] **AC-CF-4.3**：結算面板的分母與係數全部取自 `report.subscores` 與 `ClientSpec` —— 具體斷言：社畜局呈現 `/ 44` 與 `/ 56`，反無聊標籤含 `client.boredomThreshold` 之值；網紅局在 `spotlightCount` 為 1~3 時不得出現「無絕景」字樣，且不得出現「五折」。
- [ ] **AC-CF-4.4**：切換至非指派客戶頁籤時，歸因區塊隱藏或標示為試算；`primaryCulpritSlot` 恆依指派客戶計算，不隨頁籤改變。

合計 **24** 條 AC。

> v3 的三條偏空 AC 已刪除：「結算不得含替換建議」（斷言一個從未實作的東西不存在，恆綠）移入 §5 非目標；「Codex 不含具名城市」（已被架構測試涵蓋）；「同輸入結果恆等」（對純函式是恆真敘述）。

---
## 5. 邊界約束與非目標

1. **純領域零依賴**：`domain/core_loop/causal/` 嚴禁 import Flutter / Flame / `dart:ui`。
2. **禁止全域最優求解器（Anti-Solver Policy）**：不得計算或呈現「把某卡換成某卡」的最優替換建議。找出它就是遊戲本身。
   （v3 曾為此立 AC，但那是斷言一個從未實作過的東西不存在，恆綠且玩家零感知 —— 降為非目標條款，不佔 AC 名額。）
3. **動畫自製，不引入新套件**：允許以 Flutter 內建 `AnimationController` / `Tween` / Implicit Animations 與 Flame 內建 `Effect`、`ParticleSystemComponent` 實作表情轉場、彈跳、震動、數字滾動與粒子效果。**`CLAUDE.md` §6 擋的是新增相依套件，不是動畫本身**；v5 以前把兩者混為一談，是過度延伸。骨骼動畫（Spine／Rive）因確實需要新套件，仍不在本 SPEC 範圍。
4. **決定性（CC-3）**：策略提示文案若具隨機性，須接受注入 `Random?`。`focusedCulpritSlot` 屬 UI 焦點狀態，**禁止寫入事件日誌**。
5. **不改動計分規則**：本 SPEC 只可視化既有計算，**不得**新增或調整任何數值規則。數值調整走 `SPEC_MVP_AMENDMENT_01.md`。

---

## 6. 前置條件（施工前必須清償）

1. **`SPEC_MVP_TIMELINE_UI.md` 增修**：本 SPEC 的 `AC-CF-3.2` 與下列已簽核條款直接牴觸，必須先以增修作廢或改寫：
   - `AC-UI-2.2`：光軌須包含 `+20% Combo` 文本 → 改為符號 `[共鳴]`。
   - `§2.2C`：HUD 須顯示 Cost / Hype / Theme 三項即時試算 → 只保留 Cost 與預算警示。
   - `§2.2C` 客群視角切換器 → 移除（客戶已於行前指派）。
   - `§2.2B` 卡面 `🎯35` 數值丸 → 改定性階梯（見 §3.1.3）。
   - `AC-UI-2.3`（疲勞警示 Key）、`AC-UI-2.4`（相機倍率）、`§2.3` 結算頁客群頁籤：**維持有效**。
2. **`SPEC_MVP_AMENDMENT_01.md` 收斂**：該增修正在調整 Theme／Hype 係數與提交規則。因果事實是計分規則的投影，規則未定前施工必返工。須等其完成並合入主線後，以最新程式碼為基線。
3. **`AC-UI-3.2` / `AC-UI-3.3` 的歸屬**：兩條已被宣告推導失效，但 `SPEC_MVP_AMENDMENT_01` 只承接了 `AC-UI-1.4` 與 `AC-UI-2.5`（`SPEC_MVP_AMENDMENT_01.md:187,360`），這兩條目前**無主**。須指定承接者後才可施工，否則會留下兩條沒有任何 SPEC 負責的失效 AC。

---

## 7. 已裁決事項

1. **`purity_bonus` 保留規則，但不做任何表現**（使用者裁決，2026-09-12；理由於 v4 更正）。
   **v3 的理由是錯的**：v3 宣稱刪除它會使 `AC-A1-3.2` 失去機制並迫使 D4+D5+D6 三維聯立重跑。窮舉全卡表所有「3 契合卡 + 1 非契合卡」手牌 × 5 哲學 × 2 客戶 × 全部合法排列後反證：`purityBonus = 0` 時 `AC-A1-3.2` 仍有 **4792** 個見證組（`= 1` 時為 4917），`AC-A1-3.6` 五種哲學的 best3/best4 結果**一字不差**。真正承重的是契合度基準分的**平均分母**（`timeline_itinerary.dart:271-273`，`50 + round(sumContribution / filledCount)`）—— 丟掉第 4 張不合哲學的卡會抬高平均，與那 +1 無關。
   **保留的真正理由**：`AC-A1-3.4`（混入非契合素材時純度獎勵消失須可觀測）與 `AC-A1-3.5`（純度成立與失效的文案可區分）需要這個狀態存在。
   **不做表現的理由**：實測 mean |Δ| = **0.01**、觸發率 0.8%，遠低於感知門檻；且它回答的是「該不該為了湊滿塞第 4 張卡」這個提交當下的一次性決定，效果不隨排列方式改變，不符 §1.2 主動軸判準。回饋由既有的 `AC-A1-3.5` 結算文案承接。
2. **客戶具名採用**（使用者裁決，2026-09-12）。
   `小林`／`安娜` 已寫在已簽核的 `SPEC_MVP_TIMELINE_UI.md:103,107`，但 `ClientSpec` 無對應欄位。新增 `final String personaName`（`budgetWorker` → `小林`、`hypeInfluencer` → `安娜`）。表情氣泡、結算吐槽與行前簡報一律以人名稱呼，`displayName` 保留為職稱。
   `ClientSpec` 屬 `SPEC_MVP_CORE_LOOP.md` 管轄，須於該文件補增修註記。`ClientSpec.operator ==` 只比對 `type`，新增欄位不影響相等語意。
3. **Codex 歸屬層**：置於 `domain/core_loop/causal/`。`lib/data/` 現定義為「外部世界實作」，且 `lib/ui/` 目前零 `data/` 相依，不為一份靜態文案字典新開這條相依方向。
4. **結算頁客群頁籤保留**（v4 新增，見 §3.2.3）。編排期刪除雙客戶、結算期保留頁籤 —— 兩者不矛盾：編排期玩家不選客戶，另一位的表情是純噪音；結算期則是免費的教學面，且已經真的在重算。

---

## 8. 待回報事項（不在本 SPEC 範圍，記錄以免遺失）

1. **網紅端 `budget_overrun_*` 近乎死碼**：實測觸發率 0.0%（n=20000）。全卡表最貴四張合計 8700 円，須含 5000 円那張且其餘三張湊滿 3000 円才會超過 8000。依 Rule 35 建議兩級併一級，或標注為「網紅端預留」。屬卡表數值範疇。
2. **Rule 11 目前只在社畜端成立**：實測「加上第 4 張卡」對網紅**從不變差**（0.0%，n=20000），對社畜有 23.6% 變差且主要由預算驅動。「Theme Coherence 獎勵刪除」對安娜不存在。屬 `SPEC_MVP_AMENDMENT_01` 數值範疇。
3. **`ItineraryStats.operator ==` 漏了五個擊穿欄位**（`timeline_itinerary.dart:70-98` 不含 `fatiguePairs` / `comboActiveSlots` / `rhythmActivePairs` / `slotThemeBonuses` / `slotEffectiveHypes`）。目前不致命，但本案要用值相等抑制 rebuild，建議於 T1 順手補齊。
4. **`CLAUDE.md` §0 過期**：`dart test test/domain/` 不可用；「316 passed」實測為 **462 passed**。
