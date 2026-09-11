# 執行計劃 — MVP 玩法因果可視化與架構接線

> **For agentic workers:** REQUIRED SUBSKILL: 以 `superpowers:executing-plans` 逐任務執行。動碼前用 `superpowers:using-git-worktrees`；每個行為變更用 `superpowers:test-driven-development`；每次宣告完成前用 `superpowers:verification-before-completion`。

**狀態**：v3 待簽核；**前置閘門未清償前不得啟動 T1**
**上位文件**：`SPEC_MVP_CAUSAL_FEEDBACK.md` (v4)、`PLAN_MVP_CAUSAL_FEEDBACK.md` (v4)
**工程約束**：`CLAUDE.md`、`CROSS_CUTTING_CONSTRAINTS.md`

> **v3 修訂摘要（相對 v2）**
> 1. **T0 的既成事實誠實標記**：v2 把 T0 列為待執行的 Commit 01，但 `cd69d93` 已在三份文件仍為「待簽核」時將附錄提交 —— T0 自己滿足了 G5，閘門空轉。v3 標記為「已於簽核前執行，待追認」並改寫查核方式。
> 2. **守門測試改端到端**並移出 `test/architecture/`。
> 3. **`tweakItinerary` 示範碼修正**：v2 的範例會保留上一輪焦點，正踩了它自己宣告要擋的坑。
> 4. **撞車檔案清單補齊**（v2 漏列 6 支，其中 `review_settlement_widget_test.dart` 與本案 T6 直接衝突）。
> 5. T1 擴至 14 條 reasonCode；新增 T6 的結算數字修正。

---

## 0. 前置閘門與全程紅線

### 0.1 施工前置（逐項查核，未過不得啟動 T1）

| # | 條件 | 查核方式 |
|---|---|---|
| G1 | `SPEC_MVP_CAUSAL_FEEDBACK.md` v4 經使用者簽核 | 文件狀態列改為「已覆核」 |
| G2 | `PLAN_MVP_CAUSAL_FEEDBACK.md` v4 經使用者簽核 | 同上 |
| G3 | 本執行計劃 v3 經使用者簽核 | 同上 |
| G4 | `SPEC_MVP_AMENDMENT_01.md` 的數值修訂已完成 | `EXECUTION_PLAN_MVP_AMENDMENT_01.md` 的最末 Commit 已提交且全套測試綠燈 |
| G5 | T0 文件增修完成並經追認 | **已清償**：`cd69d93` 經使用者追認（2026-09-12）；其缺口已於 `7790b30` 補齊 |

> **T0 的既成事實（已追認）**
> commit `cd69d93` 於 G1~G3 全部未清償時，將附錄寫進 `SPEC_MVP_TIMELINE_UI.md` 與 `SPEC_MVP_CORE_LOOP.md` 並提交，違反 `CLAUDE.md` §1「每一關都必須等使用者明確點頭」。當時的自我豁免理由是「A 節屬事實更正，與待審規格無關」—— 該理由已收回：**判定某段修改是不是純事實更正，本身就是該被覆核的判斷**。
> **使用者已於 2026-09-12 明確追認該 commit**，不回退。其內容缺口（正文未改寫、A.1 分節錯誤、遺漏的事實更正項）已於 `7790b30` 補齊。G5 清償。
> 紀律留存：此後任何對**已簽核文件**的修改，一律先經覆核與簽核，不得以「事實更正」自行豁免。

> **撞車禁令**：本案與 `feature/mvp-amendment-01` 觸及以下共同檔案，**嚴禁並行施工**：
>
> | 檔案 | AMENDMENT 任務 | 本案任務 |
> |---|---|---|
> | `lib/domain/core_loop/models/timeline_itinerary.dart` | 多個 | T1 |
> | `lib/domain/core_loop/models/review_outcome.dart` | T13 | T1（`ReviewOutcome` 分桶地基） |
> | `lib/domain/core_loop/review/client_review_engine.dart` | 多個 | T1（唯讀） |
> | `lib/domain/core_loop/run/curator_run_state.dart` | 多個 | T3 |
> | `lib/state/core_loop/curator_run_providers.dart` | T13 | T3 |
> | `lib/state/core_loop/curator_run_controller.dart` | 已完成 | T3 |
> | `lib/ui/core_loop/review_settlement_modal.dart` | T13 | T6 |
> | `lib/ui/core_loop/curator_studio_modal.dart` | 已完成 | T5 |
> | `lib/ui/core_loop/components/live_preview_hud.dart` | 多個 | T4 |
> | `lib/ui/core_loop/components/compact_slot_card.dart` | 已完成 | T4 |
> | `lib/ui/core_loop/field/attraction_detail_card.dart` | 已完成 | T2 |
> | `test/ui/core_loop/curator_studio_modal_test.dart` | T13 | T5/T7 |
> | `test/ui/core_loop/review_settlement_widget_test.dart` | T13 | T6 |
> | `test/ui/core_loop/timeline_rail_widget_test.dart` | 已完成 | T4 |
> | `test/ui/core_loop/attraction_gathering_ui_test.dart` | 已完成 | T2 |
>
> **特別注意**：AMENDMENT 的 T13「Review 只呈現 domain 報告」會重構 `review_outcome.dart` 與整支結算彈窗，正是本案 T1（`ReviewOutcome` 分桶）與 T6（歸因）的地基。**T13 必須先落地。**

### 0.2 全程紅線

- **`lib/domain/` 零污染**：不得 import `package:flutter`、`dart:ui`、`package:flame`。
- **零具名城市**：`lib/domain/`、`lib/state/` 不得出現 `taiwan`/`kyoto`（含註解與字面值），Codex 詞條一併適用。
- **UI 零業務邏輯**：不得裸寫 `riskLevel >= 3`，一律 `material.hasFatigueRisk`；階梯一律讀 `CausalFact.intensity`。
- **不改計分規則**：本計劃只投影既有計算。任何係數調整都屬 `SPEC_MVP_AMENDMENT_01` 範疇，發現需要調整就停下來回報。
- **數字揭露邊界**：編排期清退 Theme／Hype 計分結果、`+20% Combo`、`🎯themeValue`、絕景乘數；**保留** `🔥hypeValue`、相機倍率膠囊、成本／預算。
  > `🎯` 必須拿掉的理由：它是未經哲學係數換算的 base 值（實際 40%/90%/92%/**−70%**，`travel_philosophy.dart:62,72,78,84`），保留一個會誤導的數字比不給更糟。`🔥` 的 base 值確實會進 `slotEffectiveHypes`，是誠實的比較基準，故保留。
- **因果符號只從 facts 渲染**：編排期元件不得自行讀 `itineraryStatsProvider` 判斷因果（牌面屬性、成本、相機倍率除外）。不守這條，T7 的端到端守門永遠轉不綠。
- **結算面板禁止硬編碼分母與係數**：一律取自 `report.subscores` 與 `ClientSpec`。
- **決定性（CC-3）**：策略提示取樣支援注入 `Random?`。
- **值相等**：`CausalFact` / `ItineraryCausalReport` 手寫 `operator ==` / `hashCode`，`facts` 逐項比對（`domain/` 不可用 `listEquals`）。

### 0.3 每個 Task 的固定流程

1. **RED**：先寫測試，跑 focused 測試確認紅燈。
2. **GREEN**：最小實作轉綠。
3. **品質門禁**：
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   flutter analyze          # 0 errors / 0 warnings
   flutter test             # 全套
   ```
   > `dart test` 在本倉庫不可用（無 `package:test` 直接相依，會出 "Could not find package test"）。單跑檔案用 `flutter test <path>`，單跑 AC 用 `flutter test --plain-name 'AC-CF-1.1'`。
4. **COMMIT**：單一 Conventional Commit，英文，正文說明為什麼與所滿足的 AC。

---

## 1. Task 0 — 前置文件增修（**部分已執行，待追認**）

**對應**：SPEC v4 §6
**目標**：解除新舊 SPEC 的正面衝突。**不動任何程式碼。**

### 已執行部分（commit `cd69d93`，簽核前提交，待使用者追認或回退）

- `SPEC_MVP_TIMELINE_UI.md` 檔尾附錄：§2.3 數字對照表、AC-UI-2.2 等三條的作廢宣告。
- `SPEC_MVP_CORE_LOOP.md` 檔尾：`ClientSpec.personaName` 增修註記。

### 尚未執行部分（覆核指出的缺口）

1. **直接改寫 `SPEC_MVP_TIMELINE_UI.md` §2.3 正文**。目前只在檔尾另立對照表，`:104-111` 的舊數字原封不動 —— 同一份文件兩套矛盾數字並存，只讀正文的人會拿到錯的那套。
2. **附錄重新分節**。原 A.1 宣告 `AC-UI-3.2`／`AC-UI-3.3`「整條前提不成立」並指定新測試作法 —— 作廢已簽核 AC 是規格變更，應歸 B 節（待簽核後生效），不是 A 節（即刻生效）。
3. **`AC-UI-3.3` 的判定過頭，須更正**。實測現行引擎在 `finalTheme = 50` 時仍為 **67 分 / Near Miss**，與原文結論一致：

   | finalTheme | satisfaction | outcome |
   |---|---|---|
   | 40 | 62 | nearMiss |
   | **50** | **67** | **nearMiss** |
   | 60 | 72 | pass |

   失效的是**推導路徑**（×0.50 → ×0.70 階梯），不是結論。
4. **補上同樣符合「事實更正」判準卻被遺漏的項目**：
   - `AC-UI-1.4` / `AC-UI-2.5`「四槽才可提交」已被 `AC-A1-3.7/3.8` 取代（`SPEC_MVP_AMENDMENT_01.md:187,360`），現況 `live_preview_hud.dart:171-172` 已是「至少 3 個時段」與「素材需連續排列」。附錄隻字未提，B 節的「維持有效」清單也沒排除它們，讀者會誤以為仍然有效。
   - §1.2 的「16ms / 120Hz」宣稱 —— PLAN v4 已自承 widget test 量不到幀率而刪除同款宣稱，本體卻留著。
5. **指定 `AC-UI-3.2` / `AC-UI-3.3` 的承接者**。兩條被宣告失效，但 `SPEC_MVP_AMENDMENT_01` 只承接了 `AC-UI-1.4` 與 `AC-UI-2.5`，這兩條目前**無主** —— 被宣告失效卻沒有任何 SPEC 負責重寫。
6. **§2.2B 卡面 `🎯35` 數值丸**作廢（改定性階梯），§2.3 結算頁客群頁籤**明載維持有效**。

### COMMIT

```text
docs(spec): rewrite the timeline UI settlement section in place

The appendix left the body untouched, so the document carried two contradictory
sets of numbers and anyone reading only the body got the wrong one. Restate the
body from the current engine and keep the appendix as the change record.

Move the retirement of the two settlement acceptance criteria out of the
immediate section: declaring a signed criterion void is a spec change, not a
factual correction, and deciding which one a given edit is cannot be settled by
the author alone. Name who inherits them, and retire the four slot submission
clause and the frame rate claim that meet the same bar and were missed.
```

---

## 2. Task 1 (Commit 02) — Domain 因果模型與導出流水線

**對應 AC**：`AC-CF-1.1 ~ 1.13`（13 條）

### Files
- Create: `lib/domain/core_loop/causal/causal_fact.dart`
- Create: `lib/domain/core_loop/causal/causal_report_builder.dart`
- Modify: `lib/domain/core_loop/models/travel_material.dart`
- Modify: `lib/domain/core_loop/models/timeline_itinerary.dart`（補齊 `ItineraryStats.operator ==` 漏掉的五個擊穿欄位）
- Create: `test/domain/core_loop/causal_feedback_test.dart`

### Interface Signatures
```dart
// causal_fact.dart
enum ImpactDirection { positive, negative }
enum ImpactIntensity { minor, major }
enum CausalDomain { adjacency, philosophySynergy, budgetConstraint, spotlight, boredom, ambient }
enum ClientImpression { ecstatic, pleased, neutral, stressed, furious, idle }

class CausalFact {
  final CausalDomain domain;
  final ImpactDirection direction;
  final ImpactIntensity intensity;
  final int? slotIndex;
  final (int, int)? pairIndices;
  final String sourceSignifier;
  final String reasonCode;

  const CausalFact({
    required this.domain,
    required this.direction,
    this.intensity = ImpactIntensity.minor,
    this.slotIndex,
    this.pairIndices,
    required this.sourceSignifier,
    required this.reasonCode,
  });

  @override bool operator ==(Object other);
  @override int get hashCode;
}

class ItineraryCausalReport {
  final List<CausalFact> facts;
  final ClientImpression clientImpression;
  final bool hasFatigue;
  final bool isOverBudget;
  final int? primaryCulpritSlot;

  const ItineraryCausalReport({...});

  @override bool operator ==(Object other); // facts 逐項比對
  @override int get hashCode;               // Object.hashAll(facts)
}

// causal_report_builder.dart
class CausalReportBuilder {
  static ItineraryCausalReport build({
    required TimelineItinerary itinerary,
    required ItineraryStats stats,
    required TravelPhilosophy philosophy,
    required ClientSpec client,
  });
}
```

```dart
// travel_material.dart 類別內新增
bool get hasFatigueRisk => riskLevel >= 3;
```

### 導出對照（實作時逐條核對，禁止發明規則）

| reasonCode | 來源 |
|---|---|
| `fatigue_spike` | `stats.fatiguePairs`（Theme −10／對，所有哲學與客戶皆適用） |
| `fatigue_hype_penalty` | `client.type == hypeInfluencer` 且 `!philosophy.turnsAdjacentHighRiskIntoHypeCombo`（`client_review_engine.dart:118`） |
| `chaotic_combo` | `client.type == hypeInfluencer` 且 `philosophy.turnsAdjacentHighRiskIntoHypeCombo`（`:116`） |
| `rhythm_complement` | `stats.rhythmActivePairs`（Theme +10／對）。與 `fatigue_spike` 同軸反面，同一對槽位互斥 |
| `philosophy_repelled` | 命中 `repelledTags`（`travel_philosophy.dart:58` 短路，與 matched 互斥） |
| `philosophy_matched_major` | 命中 `preferredTags` ≥ 2（係數 90~92%） |
| `philosophy_matched_minor` | 命中 `preferredTags` == 1（係數 40%） |
| `budget_overrun_minor` / `_major` | `(stats.totalCost - client.targetBudget) / client.targetBudget` 以 0.15 分界 |
| `spotlight_shortfall` | `client.type == hypeInfluencer` 且 `stats.spotlightCount < 4`；`<= 1` 為 major |
| `spotlight_full` | `client.type == hypeInfluencer` 且 `stats.spotlightCount >= 4` |
| `boredom_risk` | `client.type == budgetWorker` 且 `stats.totalHype < client.boredomThreshold`（168） |
| `tag_synergy` | `stats.comboActiveSlots`（intensity **major**） |
| `ambient_slot_affinity` | `stats.slotThemeBonuses` 的每一個 key（涵蓋 Slot 0/1/3） |

**`facts` 排序鍵**：`domain → slotIndex（null 排最後）→ reasonCode`。不得依賴 `Set`／`Map` 的插入序 —— 目前雖然是決定性的，但那是撿到的，`AC-CF-1.8/1.9` 不該隱性依賴實作細節。

`clientImpression`：
```dart
final report = ClientReviewEngine
    .evaluate(client: client, stats: stats, philosophy: philosophy);
// canSubmit == false → idle（第六態，不可沿用 neutral）
// 否則依 report.outcome：perfect→ecstatic / pass→pleased / nearMiss→neutral
//   rejected → report.satisfaction >= 30 ? stressed : furious
```
> 以 `outcome` 而非 `satisfaction` 分桶是硬性要求：社畜退件門檻 60、網紅 50（`client_review_engine.dart:58,138`），統一門檻會讓社畜 50~59 分顯示 Near Miss 表情而實際被退件 —— 那正是本 SPEC 要消滅的「畫面說謊」。

### Steps
1. **RED**：`causal_feedback_test.dart` 覆蓋 AC-CF-1.1~1.13，測試名即 AC 編號。
2. **GREEN**：實作三支檔案。
3. **VERIFY**：`flutter test test/domain/core_loop/causal_feedback_test.dart`
4. **COMMIT**：
   ```text
   feat(core-loop): derive causal report from existing scoring rules

   Add immutable CausalFact and ItineraryCausalReport with hand written value
   equality, since domain cannot import listEquals and identity equality would
   defeat rebuild suppression. Derive every fact from an existing calculation in
   calculateStats or ClientReviewEngine so the visuals can never disagree with
   the score, and map client impression from the real satisfaction value rather
   than a second threshold table. Satisfies AC-CF-1.1 through AC-CF-1.13.
   ```

---

## 3. Task 2 (Commit 03) — Codex 詞庫與白天取材語意貫通

**對應 AC**：`AC-CF-2.2`

### Files
- Create: `lib/domain/core_loop/causal/curator_codex.dart`
- Create: `test/domain/core_loop/curator_codex_test.dart`
- Modify: `lib/domain/core_loop/review/client_spec.dart`（新增 `personaName`）
- Modify: `lib/ui/core_loop/field/attraction_detail_card.dart`
- Modify: `lib/ui/core_loop/field/gathering_replace_bottom_sheet.dart`
- Modify: `test/ui/core_loop/attraction_gathering_ui_test.dart`

### Interface Signatures
```dart
class CodexEntry {
  final String title;
  final String jargon;
  final String explanation;
  final String guideNote;
  const CodexEntry({required this.title, required this.jargon,
                    required this.explanation, required this.guideNote});
}

class CuratorCodex {
  static const Map<String, CodexEntry> entries = {
    'fatigue_spike': CodexEntry(
      title: '拉車疲勞',
      jargon: '遊覽車睡死',
      explanation: '連續安排高耗能行程，旅客體力透支、怨聲載道。',
      guideNote: '阿導筆記：兩段硬行程中間，墊一張悠閒的。',
    ),
    // 其餘 10 條
  };

  static CodexEntry? lookup(String reasonCode) => entries[reasonCode];
}
```

### Steps
1. **RED**：`curator_codex_test.dart` 驗 11 個 reasonCode 皆有非空 `title`/`explanation`，且全文不含 `taiwan`/`kyoto`。
2. **GREEN**：建 `curator_codex.dart`。
3. **具名**：`ClientSpec` 新增 `final String personaName`（`budgetWorker` → `小林`、`hypeInfluencer` → `安娜`）。`operator ==` 只比對 `type`，不必更動；`ClientSpec` 為手寫純類別，不需 codegen。`curator_briefing_modal.dart:258` 改為「小林（極限窮遊社畜）」形式。
4. **UI WIRING**：兩支 field UI 於 `material.hasFatigueRisk` 時渲染 `[💀 拉車隱患]`。
5. **VERIFY**：`flutter test test/domain/core_loop/curator_codex_test.dart test/ui/core_loop/attraction_gathering_ui_test.dart test/ui/core_loop/curator_briefing_modal_test.dart`
6. **COMMIT**：
   ```text
   feat(core-loop): name the causal rules and the clients

   Name every causal rule in world jargon so the concept exists before it costs
   the player points, and mark fatigue hazard on gathering cards during the day
   to close the gap between collecting a card and being punished at night. Give
   each client a persona name, which the timeline UI spec has used in prose
   since it was written while the code only ever had a job title.
   ```

---

## 4. Task 3 (Commit 04) — State 焦點光暈生命週期與報告 Provider

**對應**：SPEC §2.4、§3.2.2

### Files
- Modify: `lib/domain/core_loop/run/curator_run_state.dart`
- Modify: `lib/state/core_loop/curator_run_providers.dart`
- Modify: `lib/state/core_loop/curator_run_controller.dart`
- Create: `test/state/core_loop/curator_run_causal_test.dart`

### Key Implementations
```dart
// curator_run_state.dart
final int? focusedCulpritSlot;

CuratorRunState copyWith({
  ...,
  int? focusedCulpritSlot,
  bool clearFocusedCulpritSlot = false,   // 必要：現有 copyWith 全為 x ?? this.x，
}) => CuratorRunState(                    // 直接傳 null 設不掉（selectedPhilosophy 已踩過）
  ...,
  focusedCulpritSlot: clearFocusedCulpritSlot
      ? null
      : (focusedCulpritSlot ?? this.focusedCulpritSlot),
);
// 同步納入 operator == 與 hashCode

// curator_run_controller.dart
void tweakItinerary({int? culpritSlot}) {
  state = state.tweakItinerary().copyWith(
    focusedCulpritSlot: culpritSlot,
    // 必要：culpritSlot 為 null 時，`x ?? this.x` 會保留上一輪的舊焦點，
    // 玩家會看到一個與本輪無關的琥珀光暈。
    clearFocusedCulpritSlot: culpritSlot == null,
  );
}
// placeMaterialInSlot / removeMaterialFromSlot / swapSlots 內：
//   若 state.focusedCulpritSlot != null → copyWith(clearFocusedCulpritSlot: true)

// curator_run_providers.dart
final itineraryCausalReportProvider = Provider<ItineraryCausalReport>((ref) {
  final s = ref.watch(curatorRunControllerProvider);
  // 複用既有 memoized provider；s.currentStats 是 getter，每次重跑 calculateStats
  final stats = ref.watch(itineraryStatsProvider);
  return CausalReportBuilder.build(
    itinerary: s.itinerary, stats: stats,
    philosophy: s.philosophy, client: s.client,
  );
});
```

> **不得**把 `causalReport` 存進 `CuratorRunState`：它是純導出值，存了就是第二份真相。

### Steps
1. **RED**：`curator_run_causal_test.dart` 驗證 —— 微調帶入焦點槽位；換卡／移除／互換後焦點回到 `null`（此測試在沒有 `clearFocusedCulpritSlot` 時必紅）。
2. **GREEN**：實作。
3. **VERIFY**：`flutter test test/state/core_loop/curator_run_causal_test.dart`
4. **COMMIT**：
   ```text
   feat(state): carry culprit slot focus across the tweak round trip

   Add focusedCulpritSlot with an explicit clear flag, because copyWith uses the
   null coalescing idiom throughout and would otherwise silently refuse to reset
   it. Derive the causal report through a provider instead of storing it on the
   run state so there is only one source of truth.
   ```

---

## 5. Task 4 (Commit 05) — 編排期符號光軌、環境微光與清退計分數字

**對應 AC**：`AC-CF-3.2`

### Files
- Create: `lib/ui/core_loop/components/causal_badge.dart`
- Modify: `lib/ui/core_loop/components/timeline_rail.dart`
- Modify: `lib/ui/core_loop/components/compact_slot_card.dart`
- Modify: `lib/ui/core_loop/components/live_preview_hud.dart`
- Modify: `test/ui/core_loop/timeline_rail_widget_test.dart`
- Modify: `test/ui/core_loop/live_preview_and_drawer_test.dart`

### Key Implementations

**硬約束（先寫這條，否則 T7 永遠轉不綠）**：編排期所有因果符號一律只從 `itineraryCausalReportProvider` 的 `facts` 渲染。`timeline_rail.dart:15` 與 `compact_slot_card.dart` 目前都是 `ref.watch(itineraryStatsProvider)` 驅動，符號是從 stats 現場算出來的 —— 只要保留這條路徑，T7 注入任何報告都不會讓符號出現。牌面屬性、成本、相機倍率不在此限。

- `CausalBadge`：承載 `reasonCode`、`sourceSignifier`、`intensity`；可點擊（T5 接 Tooltip）。
- `TimelineRail`：
  - 相鄰軸三態**同軌同階**：`💀 拉車疲勞`（負）／`🎵 節奏互補`（正）／`⚡ 驚險連段`（正，網紅 × 混亂冒險）。同尺寸、同層級，僅色彩與符號不同。
  - **移除** `'$i-$next +20% Combo'`（`:98`），改渲染 `[共鳴]`。保留既有 `Key('combo_indicator_...')` / `Key('fatigue_warning_...')` 以免既有測試大面積失效。
- `CompactSlotCard`：
  - 階梯徽章 `★` / `★★` / `💢` / `⚠️` / `🚨`；`[時段契合]` 金色微光（**Slot 0/1/3 三槽皆需**）。
  - `focusedCulpritSlot == slotIndex` 時外圍 `Key('highlight_culprit_slot')` 琥珀呼吸光暈。
  - **移除** `🎯${material.themeValue}`（`:191`），改以哲學定性階梯取代。
  - **保留** `🔥${material.hypeValue}`（`:183`）與 `📷 x` 膠囊（`:104`）。
- `LivePreviewHUD`：
  - **刪除** `🎯 ${stats.finalTheme} / 100`（`:133`）與 `🔥 ${stats.totalHype}`（`:111`）。
  - **刪除** 客群視角切換器（`_buildClientTab`，`:60,:65,:187`）。
  - **`targetBudget` 改由 run state 取得**：`ref.watch(curatorRunControllerProvider.select((s) => s.client.targetBudget))`。原本 `:30-33` 的 `targetBudget` 完全由 `_selectedClientView` 決定，刪掉切換器後會沒有來源。該元件是 `ConsumerStatefulWidget`（`:8`），拿得到 `ref`。
  - **新增** 絕景 4 格 pip（`spotlight_shortfall` / `spotlight_full`，不顯示乘數）與社畜 `boredom_risk` 定性警示。
  - **保留** 成本／預算上限與超支紅字、提交鈕。

### Steps
1. **RED**：斷言計分數字與 `+20% Combo` 已消失、階梯徽章與光暈 Key 存在。
2. **GREEN**：重構四支檔案。
3. **VERIFY**：`flutter test test/ui/core_loop/`
4. **COMMIT**：
   ```text
   feat(ui): replace editing phase readouts with ordinal causal symbols

   A fully numbered tradeoff is arithmetic rather than a painful choice, so the
   rail now states direction and source instead of magnitude. Card face stats and
   the camera multiplier stay because they are card information, not the running
   score. Satisfies AC-CF-3.2 under the amended timeline UI spec.
   ```

---

## 6. Task 5 (Commit 06) — 客戶表情與 Codex 直通 Tooltip

**對應 AC**：`AC-CF-3.1`, `AC-CF-3.3`

### Files
- Create: `lib/ui/core_loop/components/client_expression_tile.dart`
- Create: `lib/ui/core_loop/components/codex_tooltip.dart`
- Modify: `lib/ui/core_loop/curator_studio_modal.dart`
- Create: `test/ui/core_loop/causal_studio_ui_test.dart`

### Key Implementations
- `ClientExpressionTile`：
  - `Key('client_expression')`，**只有一位客戶**（`state.client`）。
  - `ref.watch(itineraryCausalReportProvider.select((r) => r.clientImpression))`。
  - 五態靜態圖示切換（不引入動畫套件）；點擊出定性氣泡，文案以 `ClientSpec.displayName` 稱呼。
  - 內置 build 計數器測試點：換一張不改變心態的卡 → build 次數不增加。
- `CodexTooltip`：點擊 `CausalBadge` → 依 `reasonCode` 查 `CuratorCodex` → 彈出 `title` / `explanation` / `guideNote`；點擊空白關閉。

### Steps
1. **RED**：`causal_studio_ui_test.dart` 驗證單一表情元件存在且**畫面上不存在第二個** `client_expression*` 元件；表情隨狀態翻轉；點徽章出詞條。
2. **GREEN**：實作並裝配。
3. **VERIFY**：`flutter test test/ui/core_loop/causal_studio_ui_test.dart`
4. **COMMIT**：
   ```text
   feat(ui): show the assigned client reacting live and open the codex on tap

   Only the pinned client is shown, because a run has exactly one commission and
   a second face would react to a score nobody is paying for. Expression comes
   from the real satisfaction value, so the face can never contradict the verdict.
   ```

---

## 7. Task 6 (Commit 07) — 結算面板：修正說謊數字、局域歸因與微調繼承

**對應 AC**：`AC-CF-4.1 ~ 4.4`

### Files
- Modify: `lib/ui/core_loop/review_settlement_modal.dart`
- Create: `test/ui/core_loop/review_attribution_widget_test.dart`
- **Modify: `test/ui/core_loop/review_settlement_widget_test.dart`**（`AC-UI-3.1~3.5` 全掛在這支，改結算彈窗必動它）

### Key Implementations

**1. 四處硬編碼改由資料取值**（本案立案原則是「畫面不得與計分分歧」，這是現役畫面上最直接的反例）：

| 行 | 現行畫面 | 應改為 |
|---|---|---|
| `:525` | `'$budgetScore / 70'` | `/ ${100 - client.themeWeight}` → **44** |
| `:526` | `'$themeScore / 30'` | `/ ${client.themeWeight}` → **56** |
| `:529` | `'反無聊懲罰 (Hype<30)'` | `反無聊懲罰 (Hype<${client.boredomThreshold})` → **168** |
| `:553` | `'絕景打折提醒　無絕景打五折'` | 依 `spotlightCount` 呈現階梯與缺口張數 |

`:553` 尤其嚴重：`hasNoSpotlight = spotlightMultiplier < 1.0`（`:551`）在持有 1~3 張絕景時同樣成立，所以它會在**有**絕景時說「無絕景」，而且係數是 `×0.70` 不是五折。這條同時是網紅端最大的槓桿（mean |Δ| 17.44）。

**2. 局域歸因**：超支元兇槽位與金額、疲勞時段對、絕景缺口張數。

**3. 歸因限定指派客戶**：客群頁籤（`:154,:162`）**保留** —— 它會以 `ClientReviewEngine` 真的重算另一位客戶（`:83-98`），是免費的教學面，佣金發放受 `curator_run_state.dart:358` 守衛保護。但歸因與 `primaryCulpritSlot` 恆以指派客戶計算（超支判定用 `client.targetBudget`，兩位客戶差 4 倍）。切至非指派頁籤時隱藏歸因或標示「此為另一位客戶的試算」。

**4. 策略提示庫**：依主要失分項取樣，接受注入 `Random?`（CC-3）。

**5. 微調焦點**：`controller.tweakItinerary(culpritSlot: report.primaryCulpritSlot)`。

### Steps
1. **RED**：驗四處分母取自資料、歸因內容、頁籤切換時歸因行為、微調傳參。
2. **GREEN**：修改結算彈窗。
3. **VERIFY**：`flutter test test/ui/core_loop/`
4. **COMMIT**：
   ```text
   feat(ui): stop the settlement panel from misreporting its own math

   Four labels were hardcoded against a scoring model that no longer exists: the
   budget and theme denominators, the boredom threshold, and a spotlight notice
   that fires while the player holds one to three spotlights and calls a 0.70
   multiplier a half price cut. That last one covers the largest single lever in
   the influencer review.

   Attribution names the slot that cost the points and hands it back to the
   studio. The client tabs stay, since recomputing the other client is free
   teaching, but attribution follows the assigned client only, or the verdict
   and the culprit would come from two different people.
   ```

---

## 8. Task 7 (Commit 08) — 端到端接線守門與全系統驗收

**對應 AC**：`AC-CF-2.1`、`AC-CF-2.3` + 全套 24 條

### Files
- Create: `test/ui/core_loop/causal_wiring_test.dart`

> **不放 `test/architecture/`**：該目錄現有五條全是 `dart:io` 靜態掃描（`:27,42,63,79,113`），放 `testWidgets` 是類別不一致。採端到端寫法後它本質上就是整合測試。

### Key Implementation

```dart
// 端到端：真實行程 → calculateStats → CausalReportBuilder → Widget
// 禁止用人工建構的報告當唯一證據：那只證明「UI 會畫交到它手上的事實」，
// 不證明 builder 會從 stats 產出該事實。漏產 rhythm_complement 時照樣綠燈 ——
// 與 rhythmActivePairs 當年的病灶同型，而消滅它正是本案的立案理由。
testWidgets('AC-CF-2.1: 每個因果代碼都必須由真實行程走到畫面上', (tester) async {
  for (final scenario in _wiringScenarios) {   // 14 個，每個含 itinerary/philosophy/client
    final container = ProviderContainer(overrides: [
      curatorRunControllerProvider.overrideWith((_) => _stateOf(scenario)),
    ]);
    addTearDown(container.dispose);

    // 先證明 builder 真的產出了這條事實（鏈條中段）
    final report = container.read(itineraryCausalReportProvider);
    expect(
      report.facts.map((f) => f.reasonCode),
      contains(scenario.reasonCode),
      reason: '${scenario.reasonCode}：builder 沒從 stats 產出這條事實',
    );

    // 再證明它抵達畫面（鏈條末段）
    await tester.pumpWidget(_studioWith(container));
    expect(
      find.textContaining(scenario.signifier),
      findsWidgets,
      reason: '${scenario.reasonCode} 在工作台零可見 —— 這就是死碼',
    );
  }
});
```

五個擊穿欄位的覆蓋（`AC-CF-2.3`）：

| 欄位 | 由哪個情境證明 |
|---|---|
| `fatiguePairs` | `fatigue_spike` |
| `rhythmActivePairs` | `rhythm_complement` |
| `comboActiveSlots` | `tag_synergy` |
| `slotThemeBonuses` | `ambient_slot_affinity`（Slot 0/1/3 各一） |
| `spotlightCount` | `spotlight_shortfall` 與 `spotlight_full` |

### Steps
1. `flutter test test/ui/core_loop/causal_wiring_test.dart`
2. `flutter test test/architecture/layer_boundaries_test.dart`（五條全綠）
3. `flutter test`（全套；基線為 **462 passed**）
4. `flutter analyze`（0 errors / 0 warnings）
5. **COMMIT**：
   ```text
   test(ui): prove each causal code travels from the rules to the screen

   Drive every reason code from a real itinerary through calculateStats and the
   report builder into the widget tree, asserting both that the builder emits it
   and that its signifier is visible. Handing the widget a report built by the
   test would pass while the builder silently stopped emitting, which is how
   rhythmActivePairs stayed invisible from the day it was written.
   ```

---

## 9. 驗收清單（DoD）

- [ ] **前置閘門 G1~G5 全數清償**（G5 已於 2026-09-12 經追認清償）
- [ ] **24 條 AC 全綠**
  - [ ] AC-CF-1.1~1.4　疲勞三態分離、動態預算階梯
  - [ ] AC-CF-1.5　表情由 `ReviewOutcome` 導出，含社畜 50~59 分案例
  - [ ] AC-CF-1.6　未達門檻為 `idle` 且不等於 `neutral`
  - [ ] AC-CF-1.7　`ambient_slot_affinity` 涵蓋 Slot 0/1/3
  - [ ] AC-CF-1.8　`primaryCulpritSlot` 五款優先序 + 平手取索引較小者
  - [ ] AC-CF-1.9　報告值相等成立（`facts` 逐項）
  - [ ] AC-CF-1.10　`rhythm_complement` 與 `fatigue_spike` 互斥
  - [ ] AC-CF-1.11　絕景階梯三檔，社畜不產出
  - [ ] AC-CF-1.12　`boredom_risk` 社畜限定
  - [ ] AC-CF-1.13　排斥與契合互斥
  - [ ] AC-CF-2.1　14 個代碼**端到端**皆可見
  - [ ] AC-CF-2.2　Codex 詞條完整
  - [ ] AC-CF-2.3　五個擊穿欄位各有端到端案例
  - [ ] AC-CF-2.4　白天 `[💀 拉車隱患]`
  - [ ] AC-CF-3.1　單一客戶表情
  - [ ] AC-CF-3.2　編排期無計分結果數字（含 `🎯` 與絕景乘數）
  - [ ] AC-CF-3.3　徽章點擊出 Codex
  - [ ] AC-CF-3.4　相鄰軸三態同軌同階
  - [ ] AC-CF-4.1　歸因標明時段對、元兇槽位、絕景缺口
  - [ ] AC-CF-4.2　光暈繼承與消褪
  - [ ] AC-CF-4.3　結算分母取自資料，四處說謊數字修正
  - [ ] AC-CF-4.4　歸因限定指派客戶
- [ ] `flutter analyze` 0 errors / 0 warnings
- [ ] `lib/domain/` 零 Flutter/Flame 相依
- [ ] 未新增任何套件（CLAUDE.md §6）
- [ ] 未修改任何計分係數（T6 改的是顯示分母，不動引擎）

---

## 10. 未納入本計劃（回報後由使用者裁決）

1. **網紅端 `budget_overrun_*` 近乎死碼**：實測觸發率 0.0%（n=20000）。依 Rule 35 建議兩級併一級。屬卡表數值範疇。
2. **Rule 11 只在社畜端成立**：加第 4 張卡對網紅從不變差（0.0%）。屬 `SPEC_MVP_AMENDMENT_01`。
3. **網紅端表情只用到三態**（`furious` 0.0%、`stressed` 1.9%）。要五態均衡須動評等門檻。
4. **`CLAUDE.md` §0 過期**：`dart test` 不可用；「316 passed」實測 **462 passed**。

---

## 11. 已裁決（2026-09-12）

1. **`purity_bonus` 保留規則、不做任何表現**。保留的理由是 `AC-A1-3.4/3.5` 需要該狀態存在 —— **不是** v2 宣稱的「刪除會使 AC-A1-3.2 失去機制」，那點已被窮舉反證（`purityBonus = 0` 時仍有 4792 個見證組，`AC-A1-3.6` 五哲學結果一字不變）。
2. **客戶具名採用**：`ClientSpec.personaName` = `小林` / `安娜`，於 T2 實作。
3. **Codex 置於 `domain/core_loop/causal/`**。
4. **結算頁客群頁籤保留，歸因限定指派客戶**（T6）。
