# 執行計劃 — MVP 玩法因果可視化與架構接線

> **For agentic workers:** REQUIRED SUBSKILL: 以 `superpowers:executing-plans` 逐任務執行。動碼前用 `superpowers:using-git-worktrees`；每個行為變更用 `superpowers:test-driven-development`；每次宣告完成前用 `superpowers:verification-before-completion`。

**狀態**：v2 待簽核；**前置閘門未清償前不得啟動 T1**
**上位文件**：`SPEC_MVP_CAUSAL_FEEDBACK.md` (v3)、`PLAN_MVP_CAUSAL_FEEDBACK.md` (v3)
**工程約束**：`CLAUDE.md`、`CROSS_CUTTING_CONSTRAINTS.md`

> **v2 修訂摘要（相對 v1）**
> 1. 前置閘門改為可查核的事實（v1 宣稱「等 `feature/mvp-amendment-01` 合入」，但撰寫當下 HEAD 就在該分支上，等於自我違反）。
> 2. `dart test` 全部改 `flutter test` —— 本倉庫**無** `package:test` 直接相依，該指令必失敗。
> 3. 新增 T0（TIMELINE_UI 增修），否則 T4 一動就撞已簽核的 AC-UI-2.2 與 §2.2C。
> 4. 雙客戶 → 單客戶；心態矩陣 → `ClientReviewEngine` 分桶；字串掃描 → 執行期斷言。
> 5. `copyWith` 清空旗標、手寫 List 值相等 —— 兩者都是不寫就靜默失效的坑。

---

## 0. 前置閘門與全程紅線

### 0.1 施工前置（逐項查核，未過不得啟動）

| # | 條件 | 查核方式 |
|---|---|---|
| G1 | `SPEC_MVP_CAUSAL_FEEDBACK.md` v3 經使用者簽核 | 文件狀態列改為「已覆核」 |
| G2 | `PLAN_MVP_CAUSAL_FEEDBACK.md` v3 經使用者簽核 | 同上 |
| G3 | 本執行計劃經使用者簽核 | 同上 |
| G4 | `SPEC_MVP_AMENDMENT_01.md` 的數值修訂已完成並合入 `main` | `git log main --oneline` 可見其收尾提交；`git status` 乾淨 |
| G5 | T0（`SPEC_MVP_TIMELINE_UI` 增修）完成並簽核 | 該檔含增修段，明載作廢條款 |

> **撞車禁令**：本計劃與 `feature/mvp-amendment-01` 觸及同一批檔案（`timeline_itinerary.dart`、`curator_run_state.dart`、`client_review_engine.dart`、`live_preview_hud.dart`）。**兩者嚴禁並行施工。** 啟動前先確認該分支已合入且無其他 session 正在讀寫（CLAUDE.md §8）。

### 0.2 全程紅線

- **`lib/domain/` 零污染**：不得 import `package:flutter`、`dart:ui`、`package:flame`。
- **零具名城市**：`lib/domain/`、`lib/state/` 不得出現 `taiwan`/`kyoto`（含註解與字面值），Codex 詞條一併適用。
- **UI 零業務邏輯**：不得裸寫 `riskLevel >= 3`，一律 `material.hasFatigueRisk`；階梯一律讀 `CausalFact.intensity`。
- **不改計分規則**：本計劃只投影既有計算。任何係數調整都屬 `SPEC_MVP_AMENDMENT_01` 範疇，發現需要調整就停下來回報。
- **數字揭露邊界**：編排期清退 Theme／Hype 計分結果與 `+20% Combo`；**保留**牌面 `🔥hypeValue`／`🎯themeValue` 與相機倍率膠囊。
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

## 1. Task 0 (Commit 01) — `SPEC_MVP_TIMELINE_UI` 增修（純文件）

**對應**：SPEC v3 §6.1
**目標**：解除新舊 SPEC 的正面衝突。**不動任何程式碼。**

### Files
- Modify: `SPEC_MVP_TIMELINE_UI.md`

### Steps
1. 追加「增修 01：因果可視化對齊」段落，明載：
   - **作廢 `AC-UI-2.2`**（光軌須含 `+20% Combo` 文本）→ 改為渲染定性符號 `[共鳴]`，不含百分比。
   - **改寫 §2.2C 即時試算指標** → 僅保留「總開銷 / 預算上限」與超支警示；刪除「預估熱度」與「主題滿意」兩項。
   - **刪除 §2.2C 客群視角切換器** → 客戶已於行前委託指派（`curator_studio_modal.dart:117` 以 `runState.client.type` 提交），切換器造成認知混淆。
   - **明載 `AC-UI-2.3`（疲勞警示 Key）與 `AC-UI-2.4`（相機倍率）維持有效**。
2. 標註增修理由與上游文件（SPEC_MVP_CAUSAL_FEEDBACK v3 §3.1.3、AC-CF-3.2）。
3. **COMMIT**：
   ```text
   docs(spec): amend timeline UI spec for causal feedback alignment

   AC-CF-3.2 forbids exact score readouts during the editing phase, which
   directly contradicts AC-UI-2.2 and the live preview HUD clause. Retire the
   combo percentage text and the Theme/Hype readouts, drop the client
   perspective switcher now that the client is pinned at briefing time, and
   record that the camera multiplier and fatigue warning clauses stay in force.
   ```

---

## 2. Task 1 (Commit 02) — Domain 因果模型與導出流水線

**對應 AC**：`AC-CF-1.1 ~ 1.9`（9 條）

### Files
- Create: `lib/domain/core_loop/causal/causal_fact.dart`
- Create: `lib/domain/core_loop/causal/causal_report_builder.dart`
- Modify: `lib/domain/core_loop/models/travel_material.dart`
- Create: `test/domain/core_loop/causal_feedback_test.dart`

### Interface Signatures
```dart
// causal_fact.dart
enum ImpactDirection { positive, negative }
enum ImpactIntensity { minor, major }
enum CausalDomain { fatigueAdjacency, philosophySynergy, budgetConstraint, ambient }
enum ClientImpression { ecstatic, pleased, neutral, stressed, furious }

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
| `fatigue_hype_penalty` | `client.type == hypeInfluencer` 且 `!philosophy.turnsAdjacentHighRiskIntoHypeCombo` |
| `chaotic_combo` | `client.type == hypeInfluencer` 且 `philosophy.turnsAdjacentHighRiskIntoHypeCombo` |
| `philosophy_repelled` | `philosophy.evaluateMaterial(m).isAligned == false` 且命中 `repelledTags` |
| `philosophy_matched_major` | 命中 `preferredTags` ≥ 2（係數 90~92%） |
| `philosophy_matched_minor` | 命中 `preferredTags` == 1（係數 40%） |
| `budget_overrun_minor` / `_major` | `(stats.totalCost - client.targetBudget) / client.targetBudget` 以 0.15 分界 |
| `tag_synergy` | `stats.comboActiveSlots` |
| `ambient_slot_affinity` | `stats.slotThemeBonuses` 的每一個 key（涵蓋 Slot 0/1/3） |
| `ambient_rhythm_flow` | `stats.rhythmActivePairs` |

`clientImpression`：
```dart
final satisfaction = ClientReviewEngine
    .evaluate(client: client, stats: stats, philosophy: philosophy)
    .satisfaction;
// canSubmit == false → neutral；否則 >=90 ecstatic / >=70 pleased / >=50 neutral / >=30 stressed / else furious
```

### Steps
1. **RED**：`causal_feedback_test.dart` 覆蓋 AC-CF-1.1~1.9，測試名即 AC 編號。
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
   than a second threshold table. Satisfies AC-CF-1.1 through AC-CF-1.9.
   ```

---

## 3. Task 2 (Commit 03) — Codex 詞庫與白天取材語意貫通

**對應 AC**：`AC-CF-2.2`

### Files
- Create: `lib/domain/core_loop/causal/curator_codex.dart`
- Create: `test/domain/core_loop/curator_codex_test.dart`
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
3. **UI WIRING**：兩支 field UI 於 `material.hasFatigueRisk` 時渲染 `[💀 拉車隱患]`。
4. **VERIFY**：`flutter test test/domain/core_loop/curator_codex_test.dart test/ui/core_loop/attraction_gathering_ui_test.dart`
5. **COMMIT**：
   ```text
   feat(core-loop): add curator codex and overworld fatigue signifier

   Name every causal rule in world jargon so the concept exists before it costs
   the player points, and mark fatigue hazard on gathering cards during the day
   to close the gap between collecting a card and being punished at night.
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
  state = state.tweakItinerary().copyWith(focusedCulpritSlot: culpritSlot);
}
// placeMaterialInSlot / removeMaterialFromSlot / swapSlots 內：
//   若 state.focusedCulpritSlot != null → copyWith(clearFocusedCulpritSlot: true)

// curator_run_providers.dart
final itineraryCausalReportProvider = Provider<ItineraryCausalReport>((ref) {
  final s = ref.watch(curatorRunControllerProvider);
  return CausalReportBuilder.build(
    itinerary: s.itinerary, stats: s.currentStats,
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
- `CausalBadge`：承載 `reasonCode`、`sourceSignifier`、`intensity`；可點擊（T5 接 Tooltip）。
- `TimelineRail`：
  - `💀 拉車疲勞`；客戶為網紅且哲學反轉時並排 `⚡ 驚險連段`。
  - `[律動]` 淡藍流光（`ambient_rhythm_flow`）、`[共鳴]`（`tag_synergy`）。
  - **移除** `'$i-$next +20% Combo'` 字樣（`timeline_rail.dart:98`），改渲染 `[共鳴]`。保留既有 `Key('combo_indicator_...')` / `Key('fatigue_warning_...')` 不變，以免既有測試大面積失效。
- `CompactSlotCard`：
  - 階梯徽章 `★` / `★★` / `💢` / `⚠️` / `🚨`。
  - `[時段契合]` 金色微光（`ambient_slot_affinity`，**Slot 0/1/3 三槽皆需**）。
  - `focusedCulpritSlot == slotIndex` 時外圍 `Key('highlight_culprit_slot')` 琥珀呼吸光暈。
  - **保留** `🔥${material.hypeValue}`、`🎯${material.themeValue}`（`:183,:191`）與 `📷 x` 膠囊（`:104`）—— 牌面屬性與裝備資訊不是取捨算術。
- `LivePreviewHUD`：
  - **刪除** `🎯 ${stats.finalTheme} / 100`（`:133`）與 `🔥 ${stats.totalHype}`（`:111`）。
  - **刪除** 客群視角切換器（`_buildClientTab`，`:60,:65,:187`）。
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

## 7. Task 6 (Commit 07) — 結算局域歸因與微調焦點繼承

**對應 AC**：`AC-CF-4.1 ~ 4.3`

### Files
- Modify: `lib/ui/core_loop/review_settlement_modal.dart`
- Create: `test/ui/core_loop/review_attribution_widget_test.dart`

### Key Implementations
- 歸因清單：超支時標「超支元兇：Slot X（¥金額）」；疲勞時標「拉車疲勞路段：Slot A – Slot B」。
- 策略提示庫：依主要失分項取樣（超支→省錢、疲勞→節奏互補、低熱度→絕景），接受注入 `Random?`（CC-3）。
- 「返回微調」：`controller.tweakItinerary(culpritSlot: report.primaryCulpritSlot)`。
- **禁止**任何「把某卡換成某卡」的建議文案（AC-CF-4.3）。

### Steps
1. **RED**：`review_attribution_widget_test.dart` 驗歸因內容、微調傳參、無替換建議字樣。
2. **GREEN**：修改結算彈窗。
3. **VERIFY**：`flutter test test/ui/core_loop/review_attribution_widget_test.dart`
4. **COMMIT**：
   ```text
   feat(ui): attribute the loss to a specific slot and carry it back

   Name where the points went instead of only how many were lost, and hand the
   culprit slot to the studio so the player does not have to remember which card
   was wrong. No global best swap is offered; finding it is the game.
   ```

---

## 8. Task 7 (Commit 08) — 架構守門（執行期）與全系統驗收

**對應 AC**：`AC-CF-2.1`、`AC-CF-2.3` + 全套 18 條

### Files
- Create: `test/architecture/causal_wiring_test.dart`

### Key Implementation
```dart
// 執行期斷言：不掃原始碼。UI 消費的是 CausalFact 物件，
// 原始碼裡不會出現 reasonCode 字面值，掃描必得假綠燈 —— 那正是本案要修的病灶。
testWidgets('AC-CF-2.1: 每個因果代碼都必須在工作台上看得見', (tester) async {
  const allCodes = [
    'fatigue_spike', 'fatigue_hype_penalty', 'chaotic_combo',
    'philosophy_repelled', 'philosophy_matched_minor', 'philosophy_matched_major',
    'budget_overrun_minor', 'budget_overrun_major',
    'tag_synergy', 'ambient_slot_affinity', 'ambient_rhythm_flow',
  ];

  for (final code in allCodes) {
    final entry = CuratorCodex.lookup(code);
    expect(entry, isNotNull, reason: 'Codex 缺少 $code');

    final report = _reportWithSingleFact(code);   // 只含這一條事實
    await tester.pumpWidget(_studioWith(report));
    expect(
      find.text(_signifierOf(code)),
      findsWidgets,
      reason: '$code 的符號在工作台上零可見 —— 這就是 rhythmActivePairs 式死碼',
    );
  }
});
```

擊穿欄位 `rhythmActivePairs` / `comboActiveSlots` / `fatiguePairs` / `slotThemeBonuses` 分別由 `ambient_rhythm_flow` / `tag_synergy` / `fatigue_spike` / `ambient_slot_affinity` 覆蓋，隨上述迴圈一併驗收（AC-CF-2.3）。

### Steps
1. `flutter test test/architecture/causal_wiring_test.dart`
2. `flutter test test/architecture/layer_boundaries_test.dart`（五條全綠）
3. `flutter test`（全套）
4. `flutter analyze`（0 errors / 0 warnings）
5. **COMMIT**：
   ```text
   test(architecture): prove every causal code reaches the screen

   Assert at runtime that each reason code renders its signifier in the studio.
   A source scan would pass while the UI shows nothing, which is exactly how
   rhythmActivePairs stayed invisible since it was implemented.
   ```

---

## 9. 驗收清單（DoD）

- [ ] **前置閘門 G1~G5 全數清償**
- [ ] **18 條 AC 全綠**
  - [ ] AC-CF-1.1 相鄰高風險產出 Theme 側疲勞事實
  - [ ] AC-CF-1.2 網紅 × 混亂冒險：連段取代 Hype 側疲勞，Theme 側疲勞仍在
  - [ ] AC-CF-1.3 社畜不存在 Hype 側疲勞或連段
  - [ ] AC-CF-1.4 超支階梯依本局客戶預算動態判定
  - [ ] AC-CF-1.5 表情與 `ClientReviewEngine` 評等一致
  - [ ] AC-CF-1.6 未達提交門檻鎖 `neutral`
  - [ ] AC-CF-1.7 `ambient_slot_affinity` 涵蓋 Slot 0/1/3
  - [ ] AC-CF-1.8 `primaryCulpritSlot` 決定性
  - [ ] AC-CF-1.9 報告值相等成立（`facts` 逐項）
  - [ ] AC-CF-2.1 11 個代碼於 UI 執行期皆可見
  - [ ] AC-CF-2.2 Codex 詞條完整且零具名城市
  - [ ] AC-CF-2.3 四個擊穿欄位皆被消費
  - [ ] AC-CF-3.1 單一客戶表情，畫面無第二位客戶
  - [ ] AC-CF-3.2 編排期無計分結果數字
  - [ ] AC-CF-3.3 徽章點擊出 Codex
  - [ ] AC-CF-4.1 結算標明元兇槽位與疲勞時段
  - [ ] AC-CF-4.2 光暈繼承與操作後消褪
  - [ ] AC-CF-4.3 結算無替換建議
- [ ] `flutter analyze` 0 errors / 0 warnings
- [ ] `lib/domain/` 零 Flutter/Flame 相依；Codex 零具名城市
- [ ] 未新增任何套件（CLAUDE.md §6）
- [ ] 未修改任何計分係數

---

## 10. 未納入本計劃（回報後由使用者裁決）

1. **`purity_bonus` 存廢**：`timeline_itinerary.dart` 的 `purityBonus = 1`，實值 1 分，低於感知門檻。本計劃不為它做表現；依 Rule 35 建議檢討刪除該規則本身。
2. **客戶具名角色**：`ClientSpec` 目前只有 `極限窮遊社畜` / `IG 網紅`，無人名。若要在氣泡文案用具名角色，須先於 `ClientSpec` 補欄位（屬 core loop 規格變更）。
3. **`CLAUDE.md` §0 過期指令**：`dart test test/domain/` 一行不可用，建議另開 docs 提交修正。
