# Core Loop Balance Amendment 01 Implementation Plan

> **For agentic workers:** REQUIRED SUBSKILL: Use `superpowers:executing-plans` to execute this plan task-by-task. Before code changes, use `superpowers:using-git-worktrees`; for every behavior change, use `superpowers:test-driven-development`; before each completion claim, use `superpowers:verification-before-completion`.

**狀態**：v1 草案，待覆核；未授權施工

**Goal**：修復 Theme 恆為 100、客戶結果不可能失敗、京都虛擬移動無法完成一局三個核心迴圈缺陷，完整落實 `SPEC_MVP_AMENDMENT_01.md` v7 與 `PLAN_MVP_AMENDMENT_01.md` v3。

**Architecture**：數值與資格規則留在純 Dart domain；Riverpod state 只組裝輸入與轉交結果；Widget 只呈現 domain/state 結果；京都資料透過既有 `OverworldMapManifest` 與 `PoiMaterialResolver` 注入，不改通用引擎與 GPS 公尺契約。

**Tech Stack**：Dart、Flutter、Riverpod、Flame、`flutter_test`、既有 build_runner；不新增套件。

**Spec**：`SPEC_MVP_AMENDMENT_01.md` v7；施工順序與回退規則以 `PLAN_MVP_AMENDMENT_01.md` v3 為準。

---

## 0. 全程硬限制

- 不修改或刪除 GPS 管線、台灣真實圖資、`PoiMarker`、`OverworldMapManifest` 契約、`metersPerPixelAt()`、`findPoiProximityConflicts()`、`manifest_geometry_check.dart`。
- 不重新命名 `EquipmentType.sneakers/camera/waistBag`；舊事件日誌依名稱重播。
- 不做 Runner、Snapshot、軌跡錄製／重播、遙測、遠端 DLC 或新抽象。
- `lib/domain/` 不得 import Flutter／Flame；domain 測試仍用 `flutter test`。
- T0 必須是第一個行為 commit；T0b 可建立 resolver，但不得提前切 production provider。
- D4、D5、D6 必須聯立；D10 是外層候選。所有 D10 候選皆無 D4~D6 可行點時，停止施工、複驗搜尋完整性、回報並退回 SPEC。
- 最終可達池找不到解時，嚴格依 PLAN §3 D12 的四步回退，不放寬 AC、不新增哲學特例。
- T7 與 T9b 都修改 `attraction_detail_card.dart`，不得並行。
- 每個 commit 單一意圖、全綠；提交訊息 Conventional Commits，英文正文寫原因與 AC 授權。

### 每個行為 commit 的固定 TDD 流程

1. 先新增或強化測試，跑 focused command，將預期失敗輸出存到 `/tmp/share-tour-a1-<task>-red.log`。
2. 寫最小實作。首次跑全套時，不同步修改既有期望值；把完整紅燈清單存到 `/tmp/share-tour-a1-<task>-suite-red.log`。
3. 逐條處理既有期望值。commit body 記錄 `old -> new -> REQ/AC`；禁止放寬 matcher、擴大 `closeTo`、自算期望、刪 `expect`、加 `skip`。
4. 修改前、修改後各用 `rg -F -c 'expect(' <changed-test-files>` 保存逐檔計數；淨減少須有承接測試與理由。
5. 依序跑：

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   <task focused tests>
   flutter analyze
   flutter test
   git diff --check
   ```

6. 全綠才提交。生成檔不進版控。

### 開工前基線（不提交）

- 用 `superpowers:using-git-worktrees` 建立隔離工作樹，確認原工作區與新工作樹皆無未辨識變更。
- 以 `git rev-parse HEAD | tee /tmp/share-tour-a1-base-sha` 固定施工基準；後續凍結檔稽核一律與此 SHA 比，不使用 `HEAD~N`。
- 跑 codegen、`flutter analyze`、`flutter test`，確認基線 383 passed、0 skipped、analyze 0/0；結果留在 `/tmp/share-tour-a1-baseline.log`。
- 保存所有預計修改測試檔的 `rg -F -c 'expect('` 基線，供每個 commit 比對。

### 窮舉共同測試工具

新增 `test/support/core_loop/itinerary_enumeration.dart`，只放測試用排列、合法行程、最大值與全平手聚合；不進 production。工具先自證：

- 4 張不同合成卡產生 `2P(4,3) + P(4,4) = 72` 個合法 3／4 槽行程。
- 6 張不同合成卡產生 `2P(6,3) + P(6,4) = 600` 個合法行程。
- 每份行程素材 ID 唯一；3 槽只可能 `[0,1,2]` 或 `[1,2,3]`。
- `bestBySatisfaction` 保留全部平手；`maxByTotalHype` 是另一個聚合，不能互代。
- AC-A1-5.1 的最高基礎 Hype 素材取自整手 6 張；任一最佳平手未把最高 Hype 卡放黃昏，即不算固定答案。

新增 `tool/search_mvp_balance.dart` 作可重跑選值工具。搜尋工具可使用自己的候選參數 record，但不得新增 production 設定服務。工具輸出：卡表 fingerprint、每個候選域與步距、母體筆數、每條 AC 的見證或反例、所有可行點；不得只輸出一個勝者。

搜尋的數值表示與選值規則固定如下：

- Theme／Hype／純度／HP／價格用整數；倍率用百分點整數，套用時除以 100，避免浮點步距漏點。
- D1 固定採「已填槽位的契合貢獻算術平均」；空槽不進分母。這使 3 槽不因少一張天然降 Theme，刪除代價仍由少一張素材的 Hype／Story 承擔。
- D2 候選：一標籤係數 40..55、二標籤係數 85..90、三個以上係數 91..93、排斥係數 70..100，步距均 1 百分點，且命中階梯嚴格遞增。排斥優先；單卡貢獻為 `round(themeValue * coefficient / 100)`，排斥取負；契合度基準為 `50 + round(sum(cardContribution) / filledCount)`。只保留 AC-A1-1.1~1.6 全通過者，且合成測試分別覆蓋 2 命中與 3 命中，防止 `themeValue=45` 時超過 92。依「一標籤係數最小、二標籤最接近 90、三標籤最接近 92、排斥係數最小」排序取第一個。
- D3 候選：社畜 Theme 權重 50..60、網紅 Theme factor 下限 40..80 百分點，步距 1。社畜先算 `themeScore = round(themeWeight * finalTheme / 100)`，未超支時 `budgetScore = 100 - themeWeight`；網紅用 `themeFactor = (floor + (100 - floor) * finalTheme / 100) / 100`。只保留 AC-A1-1.7/1.8 全通過者；先取兩客戶 Theme 90 參考分最接近 90，再取 Theme 30 降幅最接近 25，再依 `(themeWeight,floor)` 排序。
- D4 候選：每對 Hype 疲勞為 `targetHype` 的 14..100%，步距 1%；混亂冒險 Hype 側使用同量級反向加成；Theme 側固定每對 -10，不進搜尋。
- D5 候選：0 張固定 70%、4 張固定 100%；1/2/3 張從 75/80/85/90/95% 選三個嚴格遞增值，相鄰差不得超過 15 百分點。候選是一整條五階梯，不只搜尋 0→1；這是 production 的 5 百分點離散刻度，不把刻度外連續值視為候選。
- D6 候選：純度 Theme 獎勵 1..2、步距 1；獎勵僅在全部已填素材都是契合卡時成立。上界由 AC-A1-1.6 推得：契合度基準至少 88、恰一組高風險疲勞必伴至少一組高低風險節奏 +10，故要讓疲勞前 Theme 留在 90..100，正純度獎勵只能落在 1..2；0 不構成「獎勵」，不列候選。
- D7 候選：每超支一整份 `targetBudget` 扣 50..100 分、步距 1；`budgetScore = clamp((100 - themeWeight) - round(overspendRatio * penaltyPoints), 0, 100-themeWeight)`。反無聊門檻為 `client.targetHype` 的 100..1000%、步距 5%；懲罰保留 25 分。只保留 AC-A1-2.1~2.4 與 3.2/3.3 全通過者；先取 penaltyPoints 最大，再取全卡表觸發率最接近 25%，最後取門檻比例最小。
- D10 外層候選：相機 Lv.1 100..150 百分點、步距 5；Lv.2/Lv.3 不在本次 AC 搜尋域，保持既有遞增關係。對每個 D10 候選，完整保留其所有 D4+D5+D6 可行點。
- D8 固定線性共用式 `baseHp + riskLevel * riskSlope`；`baseHp` 0..15、`riskSlope` 1..16，步距 1。先以 AC-A1-5.2a/5.2b/5.3/5.6 篩選；依 SPEC 固定排序的美食前六張與混亂前五張計算，先最大化美食採完後剩餘 HP，再最小化混亂第五張的名目累計成本超過 100 的量，最後依 `(baseHp,riskSlope)` 字典序。AC-A1-6.2 於 T11 以真實 POI 續局收口。
- D9 價格候選保持三裝備同價：Lv.1→2 與 Lv.2→3 各為 50..10000、步距 50，後者不得低於前者。只保留 AC-A1-5.4 的 6..10 局；先取最接近 8 局，再取價比最接近既有 1:4，再取總價最低。
- D11 Rejected 故事收入係數 1..30%，步距 1；保留 AC-A1-6.4 通過者後取最高係數，保住最大失敗安慰獎。
- 多組 D1~D11 全通過時，先最大化五哲學最佳滿意度中的最低值，再最小化最高／最低差，最後以 `(D2,D3,D7,D10,D4,D5 ladder,D6,D8,D9,D11)` 字典序取第一個。不得手挑較好看的數字。

### 聯立搜尋的精確降維

禁止把所有參數點乘上 4,612,800 行程裸跑。`tool/search_mvp_balance.dart` 依下列順序求解，且每一步保持精確：

1. 先用合成 AC 過濾 D2、D3、D4、D5、D6、D7、D8 的必要條件；失敗點不進卡表枚舉。
2. 對每個 D10，只枚舉全卡表合法行程一次，快取不依 D4~D6 改變的原始特徵：槽位 Hype、相鄰風險對、Theme baseline/slot/rhythm、spotlight count、純度、成本、故事與素材 ID 順序。
3. 對以最佳滿意度驗收的 3.6、6.8a 建立支配前緣；只有在一列對所有剩餘 D4~D6 都不可能勝過另一列時才剪除，滿意度平手列全部保留。6.7 不走滿意度前緣：先按 `totalHype` 保留全部最高平手四槽行程，再逐筆驗 outcome ≥ Pass。6.9 也不走前緣，直接對一次完整母體驗 Theme 恆等式。
4. 用 4 張與 6 張合成小池同時跑「未剪枝 oracle」與「快取／前緣 solver」，逐候選比較可行點、最大值、完整平手 ID 集完全相等。
5. 先跑 1 個 D10 的完整 benchmark。若估算全域超過 30 分鐘，先改善等價快取／支配證明；不得抽樣、縮母體、丟平手或以 timeout 宣告空域。

離散域仍空時，先複驗未剪枝小池等值、候選邊界、母體與所有剪枝證明；確認後才依 PLAN 回報 SPEC，不臨時插值手選。

搜尋腳本是選值器，不是驗收 oracle。production 套用勝者後，獨立 `flutter_test` 必須用正式 domain API 重跑全部 AC。

---

## 1. Commit 00 — T0 八坂之塔加稅

**Files**

- Modify: `test/data/core_loop/kyoto_night_catalog_test.dart`
- Modify: `lib/data/core_loop/kyoto_night_catalog.dart`

**Steps**

- [ ] RED：新增 `AC-A1-6.5 content tax keeps at most one free low-risk spotlight`，精確驗八坂之塔 `cost == 500`、`riskLevel == 2`，以及全卡表 `cost == 0 && riskLevel <= 2` 的絕景 ≤1。
- [ ] 跑：

  ```bash
  flutter test test/data/core_loop/kyoto_night_catalog_test.dart --plain-name 'AC-A1-6.5'
  ```

- [ ] GREEN：只把 `kyoto_yasaka_pagoda` 的 `cost` 由 0 改為 500；不改 risk、標籤或其他卡。
- [ ] 跑固定全綠閘門。
- [ ] Commit：`fix(core-loop): add cost to Yasaka Pagoda spotlight`

Commit body 說明：免費低風險絕景從 2 張降至 1 張；本 commit 只完成 AC-A1-6.5 第一個 conjunct，第二個 conjunct 留 T1。

---

## 2. Commit 01 — T0b 京都 resolver，只建立不接線

**Files**

- Create: `lib/data/core_loop/kyoto_poi_material_resolver.dart`
- Create: `test/data/core_loop/kyoto_poi_material_resolver_test.dart`
- Test: `lib/domain/core_loop/models/poi_material_resolver.dart`

**Interface**

```dart
class KyotoPoiMaterialResolver implements PoiMaterialResolver {
  const KyotoPoiMaterialResolver();

  @override
  TravelMaterial? resolveMaterialFor(String poiId);
}
```

POI ID 直接等於 `kyotoNightMaterials` 的素材 ID；未知 ID 回 `null`，不得合成兜底卡。

**Steps**

- [ ] RED：已知 ID 精確回原卡；未知 ID 回 null；重複查詢決定性一致。
- [ ] 跑 `flutter test test/data/core_loop/kyoto_poi_material_resolver_test.dart`。
- [ ] GREEN：以既有京都 catalog 查表實作 resolver。
- [ ] 確認 `main.dart`、`poiMaterialResolverProvider` 尚未變動。
- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): add strict Kyoto POI material resolver`

---

## 3. Commit 02 — T1 標籤詞彙表與內容稽核

**Files**

- Create: `lib/domain/core_loop/material_catalog_audit.dart`
- Create: `test/domain/core_loop/material_catalog_audit_test.dart`
- Modify: `lib/domain/core_loop/models/travel_philosophy.dart`
- Modify: `test/domain/core_loop/travel_philosophy_test.dart`
- Modify: `test/data/core_loop/kyoto_night_catalog_test.dart`

**Interface**

```dart
typedef MaterialCatalogViolation = ({
  String code,
  String? philosophy,
  String? tag,
  int actual,
  int required,
});

List<MaterialCatalogViolation> auditMaterialCatalog({
  required Iterable<TravelMaterial> materials,
  required Iterable<TravelPhilosophy> philosophies,
});
```

`code` 使用固定值 `preferredTagCoverage`、`repelledTagDeclaration`、`repelledTagUnionCoverage`、`philosophyTagCoverage`、`unusedOnlyCardRatio`；不做 registry 或策略介面。

**Steps**

- [ ] RED：用合成小池逐一釘住 AC-A1-0.1 偏好標籤剛好 2 張、AC-A1-0.2 排斥聯集剛好 4 張、AC-A1-0.3 哲學標籤 100% 覆蓋、AC-A1-0.4 僅帶未使用標籤卡片剛好 1/3 的邊界與越界。
- [ ] RED：以 T0 後全卡表驗內容不變式與 AC-A1-6.5「五哲學各至少 1 張 cost≤500 的契合絕景」。
- [ ] 依 SPEC 附錄 A.1 更新五哲學：午夜 `#深夜 #小酌 / #拉車`；慢旅 `#散步 #古蹟 / #高風險`；美食 `#美食 #銅板美食 #早餐 / #高風險`；反觀光 `#巷弄秘境 #怪談 / #大眾名店`；混亂 `#高風險 #拉車 / #散步`。
- [ ] GREEN：完成城市無關 audit；domain test 不 import data。
- [ ] 跑：

  ```bash
  flutter test test/domain/core_loop/material_catalog_audit_test.dart test/domain/core_loop/travel_philosophy_test.dart test/data/core_loop/kyoto_night_catalog_test.dart
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): align philosophy tag vocabulary`

---

## 4. Commit 03 — T2 Theme 契合度分級與正規化

**Files**

- Modify: `lib/domain/core_loop/models/travel_philosophy.dart`
- Modify: `lib/domain/core_loop/models/timeline_itinerary.dart`
- Modify: `test/domain/core_loop/travel_philosophy_test.dart`
- Modify: `test/domain/core_loop/timeline_itinerary_test.dart`
- Create: `test/support/core_loop/itinerary_enumeration.dart`
- Create: `test/support/core_loop/itinerary_enumeration_test.dart`
- Create: `tool/search_mvp_balance.dart`

**Production result fields**

`ItineraryStats` 增加 `themeBaseline`、`themeBeforeFatigue`、`spotlightCount`、`purityActive`；`hasSpotlight` 由 `spotlightCount > 0` 衍生。所有新增呈現欄位必須納入 `==`／`hashCode`，避免 Riverpod selector 漏更新。

**Steps**

- [ ] RED：先驗窮舉 helper 的 72／600 筆、ID 唯一、合法端點空槽、全平手保留。
- [ ] RED：AC-A1-1.1、AC-A1-1.2、AC-A1-1.3、AC-A1-1.4、AC-A1-1.5、AC-A1-1.6。合成素材隔離時段／節奏／純度；五哲學各自驗排斥與 Theme 疲勞，強 Build 不得被 clamp 吃掉 -10。
- [ ] 在搜尋工具加入 D1/D2 域；跑工具並保留全部 AC-A1-1.1~1.6 可行點。沒有可行點即停止、回報 SPEC，不進下一 commit。
- [ ] GREEN：以確定性規則選出的 D1/D2 實作 `evaluateMaterial` 與 `calculateStats` 兩階段 Theme；中性貢獻 0，空槽不進平均，時段／節奏／純度在 baseline 後，疲勞最後扣再 clamp。
- [ ] 第一輪全套紅燈後，僅依 AC-A1-1.x 更新授權的舊精確期望。
- [ ] 跑：

  ```bash
  dart run tool/search_mvp_balance.dart
  flutter test test/support/core_loop/itinerary_enumeration_test.dart test/domain/core_loop/travel_philosophy_test.dart test/domain/core_loop/timeline_itinerary_test.dart
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): normalize graded theme alignment`

---

## 5. Commit 04 — T3 Theme 傳導到兩位客戶

**Files**

- Modify: `lib/domain/core_loop/review/client_review_engine.dart`
- Modify: `lib/domain/core_loop/review/client_spec.dart`
- Modify: `test/domain/core_loop/client_review_engine_test.dart`
- Modify: `tool/search_mvp_balance.dart`

**Steps**

- [ ] RED：AC-A1-1.7 對兩客戶各用一份固定參考輸入，Theme 90 得分 85~95；只降到 30 時少至少 20。
- [ ] RED：AC-A1-1.8 用同一素材、同一客戶，只換哲學，跨越至少一級 outcome。
- [ ] 搜 D3；完整保留 1.7/1.8 可行點，依 §0 規則選值。空域即停。
- [ ] GREEN：修改兩客戶 Theme 映射；不提前改超支、反無聊、疲勞、絕景或收入。
- [ ] 跑：

  ```bash
  dart run tool/search_mvp_balance.dart
  flutter test test/domain/core_loop/client_review_engine_test.dart --plain-name 'AC-A1-1.'
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): propagate theme into client satisfaction`

---

## 6. Commit 05 — T4 D4+D5+D6 聯立、D10 外層與混亂冒險

**Files**

- Modify: `lib/domain/core_loop/models/travel_philosophy.dart`
- Modify: `lib/domain/core_loop/models/timeline_itinerary.dart`
- Modify: `lib/domain/core_loop/review/client_review_engine.dart`
- Modify: `lib/state/core_loop/curator_run_controller.dart`
- Modify: `lib/ui/core_loop/review_settlement_modal.dart`
- Modify: `test/domain/core_loop/travel_philosophy_test.dart`
- Modify: `test/domain/core_loop/timeline_itinerary_test.dart`
- Modify: `test/domain/core_loop/client_review_engine_test.dart`
- Create: `test/data/core_loop/amendment_balance_test.dart`
- Modify: `tool/search_mvp_balance.dart`

**Signature change**

```dart
static ReviewReport evaluate({
  required ClientSpec client,
  required ItineraryStats stats,
  required TravelPhilosophy philosophy,
})
```

`TravelPhilosophy` 新增按效果命名的布林資料 `turnsAdjacentHighRiskIntoHypeCombo`。只有混亂冒險為 true；production 只有 `ClientReviewEngine` 一處讀取。

**Steps**

- [ ] RED：旗標唯一性；AC-A1-6.1、AC-A1-6.3a、AC-A1-6.3b、AC-A1-6.6；Theme 側對五哲學固定每對 -10。
- [ ] RED：用全卡表加入 AC-A1-6.7、AC-A1-6.9；6.7 驗全部最高 `totalHype` 平手四槽解，不得換成 satisfaction 最佳解。
- [ ] 在工具中依 §0「精確降維」以 D10 外層、D4+D5+D6 三維內層求完整可行域；候選須同時通過 AC-A1-1.6、AC-A1-3.2/3.3/3.6、AC-A1-6.1、AC-A1-6.3a/6.3b、AC-A1-6.6、AC-A1-6.7、AC-A1-6.8a、AC-A1-6.9。
- [ ] 若所有 D10 的三維域皆空：先驗卡表 32 張、每哲學合法母體 922,560、總母體 4,612,800、平手集合與搜尋邊界；仍空即停止並退回 SPEC。
- [ ] GREEN：套用確定性勝者。spotlight 由張數走 0..4 階梯；非混亂哲學扣 Hype 疲勞，混亂哲學同量級加 Hype；Theme 一律扣。
- [ ] 同 commit 更新四個正式評分入口：controller 一處；Review Modal `_switchClient`、`_assignedReport`、`_resolveReport` 三處。全部傳本局同一 philosophy，避免頁籤／備援報告分裂。
- [ ] 此時只讓搜尋與 stats 評估合法 3 槽；正式 `canSubmit` 尚不放寬。
- [ ] 跑：

  ```bash
  dart run tool/search_mvp_balance.dart
  flutter test test/domain/core_loop/travel_philosophy_test.dart test/domain/core_loop/timeline_itinerary_test.dart
  flutter test test/domain/core_loop/client_review_engine_test.dart --plain-name 'AC-A1-6.'
  flutter test test/data/core_loop/amendment_balance_test.dart --plain-name 'AC-A1-6.'
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): jointly balance fatigue spotlight and purity`

---

## 7. Commit 06 — T5 合法 3 槽垂直切片

**Files**

- Modify: `lib/domain/core_loop/models/timeline_itinerary.dart`
- Modify: `lib/state/core_loop/curator_run_controller.dart`
- Modify: `lib/ui/core_loop/components/live_preview_hud.dart`
- Modify: `lib/ui/core_loop/components/compact_slot_card.dart`
- Modify: `lib/ui/core_loop/curator_studio_modal.dart`
- Modify: `test/domain/core_loop/timeline_itinerary_test.dart`
- Modify: `test/state/core_loop/curator_run_controller_test.dart`
- Modify: `test/ui/core_loop/live_preview_and_drawer_test.dart`
- Modify: `test/ui/core_loop/timeline_rail_widget_test.dart`
- Modify: `test/ui/core_loop/curator_studio_modal_test.dart`

**Steps**

- [ ] RED domain：AC-A1-3.0、AC-A1-3.1、AC-A1-3.2、AC-A1-3.3、AC-A1-3.4、AC-A1-3.6。`[0,1,2]` 與 `[1,2,3]` 可交；2 槽及任何中間缺口不可；空槽無加成；純度在中性／排斥混入時消失。
- [ ] RED state：AC-A1-3.7 直接經 controller 放牌、移牌、提交；拒絕時 phase/report 不變。
- [ ] RED UI：AC-A1-3.8 驗合法 3 槽按鈕可用、兩端空槽顯示「刻意留白」、2 槽與中間缺口顯示可區分原因；四個槽位容器仍存在。
- [ ] RED integration：從 `CuratorStudioModal` 真按鈕提交兩種合法 3 槽，進 `clientReview` 並開 Review Modal；不能只注入 fake callback。
- [ ] GREEN：新增 `ItinerarySubmissionIssue { tooFewSlots, nonContiguous }` 與 `TimelineItinerary.submissionIssue`；`canSubmit == submissionIssue == null`。run state 保持 `=> itinerary.canSubmit`，state/UI 不重寫槽位規則。
- [ ] UI 對 `tooFewSlots` 顯示「至少安排 3 個時段」，對 `nonContiguous` 顯示「素材需連續排列」；只有 `canSubmit` 且端點為空時顯示「刻意留白」。
- [ ] 更新 controller 固定「4 槽未滿」錯誤字串與 HUD 的四時段提示。
- [ ] 跑：

  ```bash
  flutter test test/domain/core_loop/timeline_itinerary_test.dart test/state/core_loop/curator_run_controller_test.dart
  flutter test test/ui/core_loop/live_preview_and_drawer_test.dart test/ui/core_loop/timeline_rail_widget_test.dart test/ui/core_loop/curator_studio_modal_test.dart
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): allow contiguous three-slot submissions`

---

## 8. Commit 07 — T6 比例超支與可觸及反無聊

**Files**

- Modify: `lib/domain/core_loop/review/client_review_engine.dart`
- Modify: `lib/domain/core_loop/review/client_spec.dart`
- Modify: `test/domain/core_loop/client_review_engine_test.dart`
- Modify: `tool/search_mvp_balance.dart`

**Steps**

- [ ] RED：AC-A1-2.1/AC-A1-2.2 的 Rejected／Perfect 存在性；AC-A1-2.3 用預算比例驗 Perfect 上界、Rejected 下界差至少 30%，逐百分點驗 satisfaction 單調不增；AC-A1-2.4 驗低於預算仍因無聊受罰。
- [ ] 在工具加入 D7。超支輸入只使用 `max(0,totalCost-targetBudget)/targetBudget` 的線性比例；反無聊門檻只使用 `client.targetHype` 的比例，不留 `30` 字面值。
- [ ] GREEN：套用通過 D3 與 2.1~2.4 的確定性候選；不在此宣告 2.5。
- [ ] 改 D7 後重跑 AC-A1-3.2/3.3 搜尋夾具。
- [ ] 跑：

  ```bash
  dart run tool/search_mvp_balance.dart
  flutter test test/domain/core_loop/client_review_engine_test.dart --plain-name 'AC-A1-2.'
  flutter test test/domain/core_loop/timeline_itinerary_test.dart --plain-name 'AC-A1-3.'
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): scale overspend and boredom penalties`

---

## 9. Commit 08 — T7 共用 HP、實扣浮字、相機候選

**Files**

- Modify: `lib/domain/core_loop/run/curator_run_state.dart`
- Modify: `lib/domain/core_loop/models/meta_equipment.dart`
- Modify: `lib/state/core_loop/curator_run_controller.dart`
- Modify: `lib/ui/core_loop/field/attraction_detail_card.dart`
- Modify: `lib/ui/core_loop/components/compact_slot_card.dart`
- Modify: `test/domain/core_loop/poi_gathering_domain_test.dart`
- Modify: `test/domain/core_loop/meta_equipment_test.dart`
- Modify: `test/state/core_loop/poi_gathering_controller_test.dart`
- Modify: `test/ui/core_loop/attraction_gathering_ui_test.dart`
- Modify: `test/ui/core_loop/gathering_floating_feedback_test.dart`
- Modify: `test/ui/core_loop/overworld_curator_integration_test.dart`
- Modify: `test/ui/core_loop/timeline_rail_widget_test.dart`
- Modify: `test/data/core_loop/kyoto_night_catalog_test.dart`
- Modify: `tool/search_mvp_balance.dart`

**Production seam**

```dart
int gatheringHpCost(TravelMaterial material);
```

一般採集與換牌的 controller 命令回傳 `({TravelMaterial material, int hpSpent})`；Widget 不再從 risk 重算。

**Steps**

- [ ] RED domain：AC-A1-5.2a/AC-A1-5.2b/AC-A1-5.3；一般採集與換牌都讀同一函式；最後一搏只扣剩餘 HP；赤字仍允許；拒絕路徑零副作用。
- [ ] RED content：依契合卡、Hype 降序、ID 平手的固定順序驗 AC-A1-5.6；美食第 6 張後 HP>0，混亂最遲第 5 張 HP=0、未滿包、轉 nightEditing。
- [ ] RED UI/state：AC-A1-5.5 兩入口都顯示名目成本；足額與只剩 5 HP 都驗回調實扣。換牌取消不扣資源、不出浮字；最後一搏真實串到 feedback overlay。
- [ ] RED camera snapshot：出發後局外裝備改變不影響本局黃昏顯示／評分；下一局才使用新倍率。
- [ ] 搜 D8，並用 T4 保留的 D10 候選回跑 D4~D6。套用勝者；若 D10 改變，重跑 6.8a 與 T8 全卡表閘門。
- [ ] GREEN：刪除 domain 兩份與 UI 三份 `10 + risk*2` 副本；預覽讀 domain 名目值，浮字使用 `beforeHp-afterHp`。
- [ ] 不決定 D9/D11 正式值，只讓工具產生候選。
- [ ] 跑：

  ```bash
  dart run tool/search_mvp_balance.dart
  flutter test test/domain/core_loop/poi_gathering_domain_test.dart test/domain/core_loop/meta_equipment_test.dart
  flutter test test/state/core_loop/poi_gathering_controller_test.dart test/ui/core_loop/attraction_gathering_ui_test.dart test/ui/core_loop/gathering_floating_feedback_test.dart test/ui/core_loop/overworld_curator_integration_test.dart test/ui/core_loop/timeline_rail_widget_test.dart
  flutter test test/data/core_loop/kyoto_night_catalog_test.dart --plain-name 'AC-A1-5.6'
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): unify stamina costs and actual debit feedback`

---

## 10. Commit 09 — T8 全卡表平衡閘門

**Files**

- Modify: `test/data/core_loop/amendment_balance_test.dart`
- Modify: `tool/search_mvp_balance.dart`
- Modify only if search requires a different already-feasible point: T4/T7 production numeric files

**Steps**

- [ ] RED／驗收：AC-A1-3.6 只用全卡表 `riskLevel>=3`；AC-A1-6.7 固定混亂、四槽、全部最高 Hype 平手；AC-A1-6.8 家族中，AC-A1-6.8a 用全 32 張×5 哲學完整合法域，AC-A1-6.8b 留 T11；AC-A1-6.9 用全 32 張且只過濾至少一組相鄰高風險對。
- [ ] 斷言母體：每哲學 922,560、6.8a 合計 4,612,800；不得依契合卡先過濾。
- [ ] 若失敗，只能在 T4/T7 已證明可行的候選內換點；每換點重跑 T4/T7 全部受影響 AC。
- [ ] GREEN：固定全卡表候選，保存工具完整輸出到 CI/log；測試用 production API 獨立通過。
- [ ] 跑：

  ```bash
  dart run tool/search_mvp_balance.dart
  flutter test test/data/core_loop/amendment_balance_test.dart
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`test(core-loop): lock full-catalog balance envelope`

---

## 11. Commit 10 — T9a 採集資格搬入 domain，零行為變更

**Files**

- Create: `lib/domain/core_loop/models/gathering_eligibility.dart`
- Create: `test/domain/core_loop/gathering_eligibility_test.dart`
- Modify: `lib/state/core_loop/curator_run_providers.dart`
- Modify: `lib/ui/core_loop/field/attraction_detail_card.dart`

**Interface**

```dart
GatheringEligibility evaluateAttractionEligibility({
  required DistrictAttraction attraction,
  required CuratorRunState run,
  required TravelMaterial? material,
  required Vector2 playerPixel,
  required OverworldMapManifest manifest,
});
```

**Steps**

- [ ] 先跑既有 state/UI 資格測試作重構前基線。
- [ ] 把六態 enum 與現有判定順序原樣搬入 domain；仍只走 `distPx * metersPerPixelAt` 與 `triggerRadiusMeters`。
- [ ] state provider 只收集 resolver/run/location/manifest，呼叫純函式。
- [ ] 不新增 phase 檢查，不改文字，不加入像素欄位。
- [ ] 跑：

  ```bash
  flutter test test/domain/core_loop/gathering_eligibility_test.dart test/state/core_loop/poi_gathering_controller_test.dart test/ui/core_loop/attraction_gathering_ui_test.dart
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`refactor(core-loop): move gathering eligibility into domain`

---

## 12. Commit 11 — T9b 京都像素資格與最近 POI 原子採集

**Files**

- Modify: `lib/domain/location/models/district_attraction.dart`
- Modify: `lib/domain/core_loop/models/gathering_eligibility.dart`
- Modify: `lib/state/core_loop/curator_run_providers.dart`
- Modify: `lib/state/core_loop/curator_run_controller.dart`
- Modify: `lib/ui/core_loop/field/attraction_detail_card.dart`
- Modify: `test/domain/core_loop/gathering_eligibility_test.dart`
- Modify: `test/domain/location/models/district_attraction_test.dart`
- Modify: `test/state/core_loop/poi_gathering_controller_test.dart`
- Modify: `test/ui/core_loop/attraction_gathering_ui_test.dart`

**Interfaces**

```dart
final double? triggerRadiusPixels;

({DistrictAttraction attraction, TravelMaterial material})?
nearestGatherablePoi({
  required Iterable<DistrictAttraction> attractions,
  required CuratorRunState run,
  required Vector2 playerPixel,
  required OverworldMapManifest manifest,
  required PoiMaterialResolver resolver,
});
```

正式 controller 命令接受當下 manifest/playerPixel；換牌另帶 `expectedPoiId` 防止底抽屜等待期間候選改變。命令重新求最近點，成功只轉移一次，回傳實際 poi/material/hpSpent。

**Steps**

- [ ] RED domain：像素半徑非 null 時直接比 pixel 且不呼叫 mpp；null 時公尺邊界與既有行為一致；最近點按距離，等距按 ID，重排輸入不變。
- [ ] RED state/入口：AC-A1-4.3 重疊窗口按一次只加 1 ID、1 卡，只扣 1 次 HP/Budget；等距 ID 穩定；換牌 expected ID 失配時零副作用。
- [ ] RED Widget：像素模式顯示 px 資格／距離提示；公尺模式保留 m/km 與既有門檻；按鈕與抽屜呈現實際最近素材。
- [ ] GREEN：只為 `DistrictAttraction` 新增 optional `triggerRadiusPixels`。保留 `triggerRadiusMeters` 預設與 `toPoiMarker()` 語意。
- [ ] UI 不再寫死 `需<50m`；文案由資格結果與 attraction 契約產生。
- [ ] 跑：

  ```bash
  flutter test test/domain/core_loop/gathering_eligibility_test.dart test/domain/location/models/district_attraction_test.dart
  flutter test test/state/core_loop/poi_gathering_controller_test.dart test/ui/core_loop/attraction_gathering_ui_test.dart
  flutter test test/domain/location/pipeline/manifest_geometry_check_test.dart test/domain/location/projection/map_manifest_contract_test.dart test/domain/location/smoothing/position_smoother_test.dart
  ```

- [ ] AC-A1-4.3b：檢查凍結檔 diff 為空，三組 GPS 公尺幾何測試原樣通過；跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): gather nearest Kyoto POI by pixel radius`

---

## 13. Commit 12 — T10 京都 manifest、底圖、production 原子注入

**Files**

- Create: `lib/data/core_loop/kyoto_night_layout.dart`
- Create: `lib/game/map_module/manifests/kyoto_night_map_manifest.dart`
- Create: `assets/images/kyoto_night_block.png`
- Create: `test/game/map_module/kyoto_night_map_manifest_test.dart`
- Create: `test/app_bootstrap_test.dart`
- Modify: `lib/main.dart`
- Test unchanged: `lib/game/universal_overworld_game.dart`
- Test unchanged: `lib/game/components/attraction_layer_component.dart`

**Manifest contract**

- `assetPath == 'kyoto_night_block.png'`；既有 `assets/images/` pubspec 宣告直接承接。
- `districtAttractions` 是唯一 POI／採集資料；每個 ID 等於 resolver 內素材 ID，顯式給 `triggerRadiusPixels`。
- `poiNodes == const []`，不複製第二套資料。
- 京都內部使用有界仿射 `containsGeo/projectToPixel/unprojectToGeo/metersPerPixelAt`；mpp 保留正值以滿足既有介面，不作京都採集資格。
- `dpadSpeedPixelsPerSecond` 與像素直徑共同滿足 AC-A1-4.2。

**Steps**

- [ ] RED manifest：投影往返、邊界、spawn、正 mpp、空 poiNodes、景點 ID 唯一、像素半徑與速度契約、asset 可解碼。
- [ ] RED bootstrap：pump 正式 `buildProductionApp(repository: repository, initialSave: initialSave)`，從 Consumer 讀出 production providers，驗 manifest 為 Kyoto、material pool 為 Kyoto catalog、每個 district attraction 都能由 strict resolver 精確解析。測試不得手抄 overrides。
- [ ] 產生 1024×1024 京都夜間街區 PNG；視覺工作執行時使用 `imagegen` skill。畫面不得含台灣輪廓或真實 GPS UI；道路與 POI 動線須可辨識。
- [ ] 實作京都 manifest/layout。Attraction Layer 已只讀 `districtAttractions`，不改 engine。
- [ ] 在 `main.dart` 抽出 `ProviderScope buildProductionApp({required PersistenceRepository repository, required CuratorSaveData initialSave})`；同一函式同時注入 Kyoto manifest、Kyoto resolver、Kyoto material pool。`main()` 改載 Kyoto manifest；存檔載入保持並行。
- [ ] 更新 `main.dart` 內 production 固定 Taiwan 標題；不動凍結地圖／GPS 檔。
- [ ] 跑：

  ```bash
  flutter test test/game/map_module/kyoto_night_map_manifest_test.dart test/app_bootstrap_test.dart test/game/universal_overworld_game_test.dart
  ```

- [ ] 檢查凍結檔 diff 為空；跑固定全綠閘門。
- [ ] Commit：`feat(map): add Kyoto night block as production DLC`

---

## 14. Commit 13 — T11 最終可達池、D9/D11、聯合收口

**Files**

- Modify: `lib/data/core_loop/kyoto_night_layout.dart`
- Modify: `lib/domain/core_loop/models/meta_equipment.dart`
- Modify: `lib/domain/core_loop/review/client_review_engine.dart`
- Create: `test/support/core_loop/gathering_continuations.dart`
- Create: `test/data/core_loop/kyoto_reachable_pool_test.dart`
- Create: `test/data/core_loop/kyoto_gathering_tradeoff_test.dart`
- Modify: `test/domain/core_loop/meta_equipment_test.dart`
- Modify: `test/domain/core_loop/client_review_engine_test.dart`
- Modify: `test/domain/core_loop/curator_event_log_test.dart`
- Modify: `test/data/core_loop/local_persistence_repository_test.dart`
- Modify: `test/state/core_loop/meta_progression_controller_test.dart`
- Modify: `tool/search_mvp_balance.dart`

**Steps**

- [ ] RED：由正式 Kyoto manifest `districtAttractions` 經正式 resolver 導出可達池；禁止測試另抄池。
- [ ] 完整驗 AC-A1-0.1/AC-A1-0.2/AC-A1-0.3/AC-A1-0.4、AC-A1-2.5、AC-A1-4.4/AC-A1-4.5/AC-A1-4.6、AC-A1-5.1、AC-A1-5.4、AC-A1-6.2、AC-A1-6.4、AC-A1-6.8b。2.5/6.8b 母體為 `5 × (2P(n,3)+P(n,4))`；5.1 對全部 `5 × C(n,6)` 手牌，每手 600 行程且保留全部最佳平手。
- [ ] AC-A1-6.2 用 `gathering_continuations.dart` 真正分叉「第二張絕景／非絕景」，再窮舉 HP／腰包限制下所有續局與最終合法行程；Budget 可赤字且不得成採集閘。另跑無 HP 限制控制組：使用相同兩張候選卡、相同剩餘池與行程域，等化兩分支可用 HP 後，第二張絕景分支不得仍嚴格較差；否則不能把差異歸因 HP。
- [ ] D12 子集域固定為 32 張 catalog 的全部 16..32 張子集。按張數由 32 遞減、同張數按排序後 ID 組合字典序遍歷；以剩餘卡仍不可能補足標籤／絕景／結果集合的必要條件作 lossless DFS 剪枝。每個保留子集均跑完整數值 AC；不得抽樣。
- [ ] 每個子集的 layout 由唯一模板產生，不搜尋連續像素平面：1024×1024 畫布上用 `(x,y)=(160+224*column,112+112*row)` 的 4×8 格；spawn `(128,112)`；`triggerRadiusPixels=20`；速度沿用 manifest 的 40 px/s。列出所有「6 張採後 HP>0」的六卡組合，以排序後 ID 序列取字典序第一組；按該序列放進蛇形路徑前六格，其餘卡按 ID 放後續格。直徑 40px ≥ 10px，且固定前六格路徑長 1040px、以 40px/s 為 26 秒，可先證 ≤240 秒；T12 再走正式管線。
- [ ] 先固定 T8 參數選下一個子集／其唯一 layout；無解才在已通過 D4~D6/D10 域換點；6.2 無解時聯動 D5/D8；上述有限候選耗盡才退回 SPEC。
- [ ] 用最終 Pass 集合中位數搜尋 D9；用兩客戶 Near Miss／Rejected 集合搜尋 D11。按 §0 確定性規則選值，重跑所有受影響 AC。
- [ ] 與第一次修改價格／收入同時新增寫死的舊 JSON fixture：三種舊 enum 名、舊 300/1200 cost、歷史 earnedCoins、UTC 時戳。不得用新版 `toJson` 生成 fixture。
- [ ] 舊日誌驗 `fromJson -> replay` 精確 coins/levels/completedRuns/seq/time；repository 重開不重寫舊日誌、不建立 corrupted backup；載入後新增一筆新價格／收入事件，再重播等於 live state。
- [ ] GREEN：固定最終 layout、價格階梯、Rejected 非零故事係數。不得改 enum 名。
- [ ] 跑：

  ```bash
  dart run tool/search_mvp_balance.dart
  flutter test test/data/core_loop/kyoto_reachable_pool_test.dart test/data/core_loop/kyoto_gathering_tradeoff_test.dart
  flutter test test/domain/core_loop/meta_equipment_test.dart test/domain/core_loop/client_review_engine_test.dart test/domain/core_loop/curator_event_log_test.dart
  flutter test test/data/core_loop/local_persistence_repository_test.dart test/state/core_loop/meta_progression_controller_test.dart
  flutter test test/data/core_loop/amendment_balance_test.dart
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`feat(core-loop): converge reachable pool and progression economy`

---

## 15. Commit 14 — T12 四分鐘邏輯步行採集實測

**Files**

- Create: `test/integration/kyoto_walk_gathering_test.dart`
- Create: `test/support/kyoto_walk_driver.dart`
- Reuse unchanged: `test/fakes/fake_clock.dart`
- Reuse unchanged: `lib/data/location/virtual_location_source.dart`
- Reuse unchanged: `lib/state/location/location_controller.dart`

**Steps**

- [ ] RED：用 production Kyoto bootstrap、真 virtual source、真 LocationNotifier、三裝備 Lv.1，自 spawn 開始。
- [ ] 每 tick 必須：`setDirection`；`FakeClock.advanceAsync(virtualSource.interval)`；讓串流／節流送達；呼叫 `LocationController.tick(dt)` 推進 `renderedPixel`；經 T9b 正式最近 POI 入口採集。
- [ ] 禁止 teleport、直接 `gatherPoi(id)`、用速度×時間直接代替 rendered position、修改 GPS／virtual source 來迎合測試。
- [ ] GREEN：存在一條只用方向鍵的固定路徑，在 ≤240 秒邏輯時間採集 6 個不同 ID；腰包 6 張、HP>0；scope dispose 後來源停止。
- [ ] 跑：

  ```bash
  flutter test test/integration/kyoto_walk_gathering_test.dart --plain-name 'AC-A1-4.1'
  flutter test test/data/location/virtual_location_source_test.dart test/state/location/location_wiring_test.dart
  ```

- [ ] 檢查 location production diff 為空；跑固定全綠閘門。
- [ ] Commit：`test(core-loop): prove four-minute Kyoto gathering route`

---

## 16. Commit 15 — T13 Review 只呈現 domain 報告

**Files**

- Modify: `lib/domain/core_loop/review/client_review_engine.dart`
- Modify: `lib/domain/core_loop/models/review_outcome.dart`
- Modify: `lib/state/core_loop/curator_run_providers.dart`
- Modify: `lib/ui/core_loop/review_settlement_modal.dart`
- Modify: `test/ui/core_loop/review_settlement_widget_test.dart`
- Modify: `test/ui/core_loop/curator_studio_modal_test.dart`

**State seam**

```dart
final comparisonReviewReportProvider =
    Provider.family<ReviewReport, ClientType>((ref, clientType) {
  final state = ref.watch(curatorRunControllerProvider);
  final latest = state.latestReport;
  if (latest != null && latest.clientType == clientType.name) return latest;
  final client = switch (clientType) {
    ClientType.budgetWorker => ClientSpec.budgetWorker,
    ClientType.hypeInfluencer => ClientSpec.hypeInfluencer,
  };
  return ClientReviewEngine.evaluate(
    client: client,
    stats: state.currentStats,
    philosophy: state.philosophy,
  );
});

final assignedReviewReportProvider = Provider<ReviewReport>((ref) {
  final assignedType = ref.watch(
    curatorRunControllerProvider.select((state) => state.client.type),
  );
  return ref.watch(comparisonReviewReportProvider(assignedType));
});
```

兩者輸入本局 stats、philosophy、指定或指派 client；clientType 等於 `latestReport.clientType` 時回傳已鎖定報告，否則由唯一 `ClientReviewEngine` 計算。Widget 不 import/reinvoke engine。

**Steps**

- [ ] RED presentation：AC-A1-3.5 用人工固定 report 驗純度成立／失效文案可區分；AC-A1-6.6 用混亂報告同時呈現 Hype 冒險連段收益與 Theme 疲勞，其他哲學呈現 Hype 疲勞損失。
- [ ] RED integration：真裝牌→controller submit→Review Modal，驗 UI 數字與 state report 完全一致；切換對照客戶不改指派客戶的 outcome、earnedCoins、操作區或持久化 payload。
- [ ] GREEN：把 Modal 三處 `ClientReviewEngine.evaluate` 移到 state 衍生入口；`ReviewReport.subscores` 承接 `purityBonus`、`hypeFatigue`／`adventureCombo`、`themeFatigue` 等已判定值。
- [ ] 更新舊字面提示 `Hype<30` 與「倍率<1就是無絕景打五折」；Widget 依 report key/value 呈現，不重算規則。
- [ ] 保留並加強 AC-FIX-5.1：頁籤只供比較，不能免費改籤領佣金。
- [ ] 跑：

  ```bash
  flutter test test/ui/core_loop/review_settlement_widget_test.dart test/ui/core_loop/curator_studio_modal_test.dart
  flutter test test/domain/core_loop/client_review_engine_test.dart test/state/core_loop/curator_run_controller_test.dart
  ```

- [ ] 跑固定全綠閘門。
- [ ] Commit：`refactor(core-loop): render review effects from domain reports`

---

## 17. Commit 16 — T14 追溯矩陣與最終驗證

**Files**

- Create: `MVP_AMENDMENT_01_VERIFICATION.md`
- Modify tests only if a previous task demonstrably omitted an approved AC; behavior fixes仍須回到責任 task，不塞進此 commit

**Steps**

- [ ] 建立逐條矩陣：`SPEC AC | exact test name | task | commit SHA | verification command | result`。涵蓋 AC-A1-0.1 至 6.9，含 3.7/3.8、4.3b、5.5、6.8a/6.8b。
- [ ] 記錄每個窮舉母體實際筆數、平手政策、最終搜尋參數與可重跑命令；所有統計從腳本輸出抄入，不手算。
- [ ] 逐檔核對凍結資產沒有 diff：

  ```bash
  git diff "$(cat /tmp/share-tour-a1-base-sha)" -- lib/domain/location/projection/map_manifest.dart lib/game/map_module/manifests/taiwan_map_manifest.dart lib/domain/location/pipeline lib/data/location lib/game/universal_overworld_game.dart
  ```

  `DistrictAttraction` 只允許 optional pixel 欄位；另核對 `metersPerPixelAt` 仍被 `position_smoother.dart` 使用。
- [ ] 核對 `EquipmentType` 三個名稱不變；舊事件 fixture 全綠。
- [ ] 搜索延後項目未偷做：

  ```bash
  rg -n "Runner|Snapshot|telemetry|analytics|track replay|route replay" lib
  ```

  新命中逐一與 baseline 比較；既有命中不擅刪。
- [ ] 最終命令：

  ```bash
  dart run build_runner build --delete-conflicting-outputs
  dart run tool/search_mvp_balance.dart
  flutter test test/domain/
  flutter analyze
  flutter test
  git diff --check
  git status --short
  ```

- [ ] 只有 codegen 0 非預期輸出、analyze 0/0、全套 0 failures/0 skipped、工作樹只含預期文件時，才填 verification 結果。
- [ ] Commit：`docs(core-loop): record amendment acceptance evidence`

---

## 18. 執行順序與停工點

嚴格順序：

```text
T0 → T0b → T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8
   → T9a → T9b → T10 → T11 → T12 → T13 → T14
```

只有下列情況允許回退：

1. T7 改 D8/D10：回跑 T4 聯立域與 T8。
2. T11 子集無解：依 PLAN §3 D12 固定四步回退。
3. 任一舊測試紅：先判定是否有 SPEC 授權；無授權即修實作，不改測試。
4. D4+D5+D6 可行域空、最終可達池候選耗盡、或 AC 互斥：停止，不硬選、不放寬，提交可重跑反例後退回 SPEC 關卡。

本文件覆核通過前，不執行 Commit 00，不修改任何 product code 或 asset。
