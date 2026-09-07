# 任務 C：SPEC 修訂 v6 — 實作計劃（增量）

狀態：**待覆核**
流程位置：`spec → 覆核 → plan → 覆核 → 執行計劃 → 覆核`（目前在 **plan**）
規格：`SPEC_C_GPS_TRACKING.md`（v6）。本計劃只涵蓋 v6 相對 v5.1 的**增量**——`PLAN_C_GPS_TRACKING.md`（T1~T20）已在真機驗證中執行完畢，`lib/domain/location/`、`lib/data/location/`、`lib/state/location/` 均已存在對應實作，不重寫。
上位約束：`CROSS_CUTTING_CONSTRAINTS.md`（v3）。
工作規範：`CLAUDE.md`。

---

## 範圍

`SPEC_C_GPS_TRACKING.md` v6 §6.1.2 列出的變更中，屬本計劃範圍（有程式碼動作）的有：

| 任務 | 對應修訂 | 檔案 |
|---|---|---|
| T21 | 修訂二：REQ-C-13 規則 16、17（品質標記） | `pipeline/location_pipeline.dart`、`pipeline/quality_gate.dart`、`models/location_status.dart` |
| T22 | 修訂四：刪除道路吸附 + 接線分類遮罩 | `projection/map_manifest.dart`、`pipeline/projection_stage.dart`、`test/fakes/fake_map_manifest.dart`、`game/map_module/manifests/taiwan_map_manifest.dart`、`game/map_module/utils/taiwan_geo_calibrator.dart`（刪除）、`state/location/location_controller.dart`、`assets/maps/taiwan/mask.png`（接線） |
| T23 | 修訂五：REQ-C-03 規則 5 簡化 | `pipeline/quality_gate.dart` |
| T24 | 修訂一：REQ-C-16 裝置喚醒 | 新檔 `domain/location/keep_awake.dart`；新檔 `data/location/wakelock_control.dart` |
| T25 | 修訂三：REQ-C-18 觸發品質契約 | `pipeline/manifest_geometry_check.dart`（改寫）；新檔 `domain/location/trigger_suitability.dart` |
| T26 | REQ-C-02 規則 5：Android 平台更新間隔 | `data/location/geolocator_location_source.dart` |
| T27 | 修訂六：REQ-C-07 規則 6，不連續事件供畫面層 | `state/location/location_controller.dart` |
| T28 | 修訂八：AC-3.9 測試標題修正 | `test/domain/location/pipeline/significance_gate_test.dart` |
| T29 | DoD 7a/7b：真機驗收程序更新 | 無程式碼；更新驗收腳本／checklist |

**明確排除**（不屬任務 C）：探索網格 id 的產生與持久化（CC-5 新規則 3，屬任務 A／B 的 SPEC 與 plan）；里程角色框定（純文件，SPEC 已記載，無程式碼變更）。

---

## 任務相依圖

```
T23（獨立） T26（獨立） T28（獨立）── 可先做，風險低、無相依

T21 品質標記 ──┬──> T22 刪除吸附+遮罩 ──> T25 REQ-C-18 契約
               └──> T27 不連續供畫面層

T24 裝置喚醒（管線邏輯獨立，可併行寫）
    └─ 但與 T21 共享一次 LocationDiagnostics（@freezed）編輯視窗，見下方註記

T21+T22+T24+T25+T26+T27 全部完成 ──> T29 真機驗收
```

**關鍵路徑**：T21 → T22 → T25 → T29。
**T21 在前的理由**：T22 移除吸附後，`ProjectionStage` 的行為改變（範圍外仍投影、無吸附修正），而 T25 的幾何驗證要用 `positionErrorBound` 取代 `snapLimitMeters`；T27 的「不消耗不連續標記」規則直接讀 T21 產生的品質旗標。三者若反過來做，會在品質旗標語意未定時就要決定基準凍結行為，需要事後回改。

**T21／T24 的「併行」需要修正字面意思（雙方覆核都抓到）**：T21 步驟 3 與 T24 步驟 4 都要在 `LocationDiagnostics`（`models/location_status.dart:77-91`）新增欄位——這是**同一個 `@freezed` 類別**，兩者的純邏輯部分（品質標記判定 / `shouldKeepAwake` 純述詞）可以真的併行寫，但**對 `LocationDiagnostics` 的欄位新增必須序列化**：先完成的一方只加自己的欄位並跑一次 `build_runner`；後完成的一方在此基礎上加第二個欄位、再跑一次。不得兩邊同時修改再各自 regen，會在 `.freezed.dart`／`.g.dart` 上衝突。

---

## T21 — 品質標記（REQ-C-13 規則 16、17）

**目的**：目前 `LocationPipeline.ingest()` 對「通過品質閘門」的 Fix 一視同仁地拿去比較顯著性、更新基準、消耗不連續標記。v6 要求精度不合格（> 30 m）的 Fix 仍走管線，但**不得**成為任何基準、不消耗不連續標記、不推進 `motion`——同時**仍要**更新顯示點與 `coverage`。

**現狀**（`lib/domain/location/pipeline/location_pipeline.dart:120-187`）：品質閘門（REQ-C-03，精度上限 100 m）與品質標記（REQ-C-13，精度上限 30 m）目前是同一件事——閘門本身就丟棄 > 100 m 的 Fix，通過閘門的一律進顯著性判定。v6 之後這是兩層獨立判定：閘門「值不值得進管線」，標記「值不值得當作精確測量」。

**裁決（2026-09-07，依工程師與架構師覆核共識，取代原「待裁決點」）**：品質旗標**不進 `GeoFix`**——`GeoFix` 是「感測器讀到什麼」的值物件（REQ-C-02），`qualityAcceptable` 是管線判定結果，語意不同層。延續 `quality_gate.dart` 既有的 `GateResult`／`Accepted`／`Rejected` 風格，落地為管線輸出的一部分，而非新增獨立包裝型別（避免又一層轉換）。

**設計要點（供實作參考，非最終程式碼）**：

1. `QualityGate.evaluate()` 通過（`Accepted`）的 Fix，緊接著在 `ingest()` 內求 `qualityAcceptable = fix.accuracyMeters <= 30`（虛擬 Fix：`fix.sourceMode == SourceMode.virtual` 時一律 `true`，對應規則 17，且此判定必須在原本「虛擬 Fix 整段跳過品質閘門」的分支**之後**、而不是跳過品質標記本身——AC-0.4 要求虛擬 Fix 仍進入第 6 步）。
2. **分支插入點（比原稿更明確）**：現行 `ingest()` 的順序是「品質閘門 → `_motion.onAcceptedFix()` → 檢查 `_pendingDiscontinuity`（非空即進 `_ingestDiscontinuous` 並消耗）→ 顯著性閘門」。品質標記判定必須插在「`_motion.onAcceptedFix()`」與「`_pendingDiscontinuity` 檢查」之間，且**不合格的 Fix 必須完全繞開 `_pendingDiscontinuity` 檢查與 `_ingestDiscontinuous`**——不是"讓它走到那條路徑但不消耗"，而是走第三條獨立路徑：只投影＋更新顯示點／`coverage`，不動基準、不動待處理標記、不發任何事件。這是三向判斷（合格且顯著／合格且不顯著／不合格）與既有二向判斷（有無 pending discontinuity）的交叉重排，寫程式碼前先把這三條路徑的真值表列出來再動手，避免漏掉「不合格 + 有 pending discontinuity」這個最容易錯的組合（AC-13.17 就是專門測這格）。
3. `PipelineOutput`（`location_pipeline.dart:16-26`）新增一個欄位（例如 `bool qualityGated`），明確標記「這次 `targetPixel` 非空是因為品質不合格但仍要顯示」——不要讓 controller 靠「`events` 是否為空」這種隱式訊號反推，否則 AC-14.11 的 `accuracyGatedFixCount` 计数會和 `_acceptedFixCount` 混在一起判斷不出來。
4. `MotionTracker.onSignificantMove()` 只在合格且顯著時呼叫；`onAcceptedFix()`（REQ-C-14 規則 4 的 acquisition 追蹤）維持對所有通過閘門的 Fix 呼叫，不受品質標記影響——`acquisition` 的語意是「有沒有收到夠新的訊號」，與是否精確是兩件事。

**AC 對應**：AC-13.14~13.18（`SPEC_C_GPS_TRACKING.md` REQ-C-13）、AC-0.4（虛擬 Fix 進入品質標記步驟一律合格）、AC-14.11（`accuracyGatedFixCount` 遞增）。

- [ ] **步驟 1（RED）**：在 `test/domain/location/pipeline/location_pipeline_test.dart`（若無則新建）按 AC-13.14~13.17 逐條寫失敗測試。**AC-13.17（不合格 Fix 不消耗不連續標記）優先寫**——這是三向分支裡最容易錯的組合。
- [ ] **步驟 2**：畫出三向路徑（合格且顯著／合格且不顯著／不合格）× 二向（有無 pending discontinuity）的真值表，再實作品質標記判定與管線分支、`PipelineOutput.qualityGated` 欄位。
- [ ] **步驟 3**：`LocationController` 新增 `accuracyGatedFixCount` 欄位；`LocationDiagnostics` 新增同名欄位（`models/location_status.dart:77-91`）。**本步驟與 T24 步驟 4 動同一個 `@freezed` 類別，兩者不得真的併行執行——由後完成的一方一次補齊兩個欄位**，見下方任務相依圖的更新。改欄位後先跑 `dart run build_runner build --delete-conflicting-outputs`，再 `flutter analyze`（CLAUDE.md §8 強制順序）。
- [ ] **步驟 4**：`flutter test test/domain/location/pipeline/` 全綠，`flutter analyze` 0 issue。

---

## T22 — 刪除道路吸附 + 接線分類遮罩（REQ-C-04 修訂四，§2.2 規則 4）

**目的**：整項刪除 `snapToRoad`、`snapLimitMeters`、`roadNodes`；**並把 `TaiwanMapManifest.containsGeo` 從矩形框改為真正查詢分類遮罩**（2026-09-07 使用者裁決：現在就接線，不留給任務 D）。

> `SPEC_C_AMENDMENT_01.md` §3.4 的排序禁令——「不得在遮罩接上之前刪除吸附，否則會留下一段完全沒有邊界守衛的期間」——本任務把兩件事合併在同一個任務內完成，不存在中間的無守衛狀態。

**現狀盤點**（含工程師覆核補上的兩項，原稿遺漏會導致 `flutter test` 直接編譯失敗）：
- `lib/domain/location/projection/map_manifest.dart:47-56`：介面含 `snapLimitMeters`、`roadNodes`、`snapToRoad`。
- `lib/domain/location/pipeline/projection_stage.dart:32`：`Projected(manifest.snapToRoad(manifest.projectToPixel(lat, lng)))`。
- `test/fakes/fake_map_manifest.dart:90-95,129-139`：`snapLimitMeters`、`roadNodes`、`snapToRoad` 三個成員與其邏輯、`snapCallCount`。
- `lib/game/map_module/manifests/taiwan_map_manifest.dart:186-187`：`containsGeo` 目前是矩形框（`lat ∈ [21.4, 25.7]`、`lng ∈ [119.7, 122.3]`），台灣海峽、太平洋全在框內；`:197-201` 另有 `snapToRoad` 的對應實作。
- `lib/state/location/location_controller.dart:124-126`：`switchLayer()` 換層重新定位時呼叫 `next.snapToRoad(next.projectToPixel(...))`。
- **（新增）`test/taiwan_map_manifest_test.dart:78-115`**：直接引用 `manifest.roadNodes`、`manifest.snapLimitMeters`、`findSnapTriggerConflicts(...)`——刪除介面成員後**此檔案會編譯失敗**，必須同步處理，不能只在步驟 9 才發現。其中 86~102 行「POI 之間距離大於觸發半徑總和」的測試與 T25 的 AC-18.3 邏輯重疊，於 T25 一併決定去留、避免兩份幾何檢查並存。
- **（新增）`lib/game/map_module/utils/taiwan_geo_calibrator.dart` 與 `test/taiwan_geo_calibrator_test.dart`**：`TaiwanGeoCalibrator.snapToRoad` 是 `TaiwanMapManifest.snapToRoad` 目前**唯一**呼叫者；刪除吸附後這個類別在 `lib/` 沒有任何呼叫端，屬死碼，須連同測試一併刪除（不要只刪呼叫、留下無人呼叫的類別）。
- **（新增）`assets/maps/taiwan/mask.png`**：已存在於倉庫（另一 agent 先前的地圖美術提交產出），但目前沒有任何程式碼讀取它。本任務要把它接進 `containsGeo`。

**步驟**：
- [ ] **步驟 1（RED）**：`test/domain/location/projection/map_manifest_test.dart`（或架構測試）新增 AC-4.7：比照 T1 的 `layer_boundaries_test.dart` 手法做原始碼靜態掃描，斷言 `map_manifest.dart` 原始碼不含 `snapToRoad`、`snapLimitMeters`、`roadNodes` 字串。先確認此測試在刪除前失敗。
- [ ] **步驟 2**：`map_manifest.dart` 移除三個成員。
- [ ] **步驟 3**：`projection_stage.dart` 改為 `Projected(manifest.projectToPixel(lat, lng))`（不再吸附），文件註解同步刪除「吸附」字樣。
- [ ] **步驟 4**：`fake_map_manifest.dart` 移除 `snapLimitMeters`、`roadNodes`、`snapToRoad`、`snapCallCount`；`resetCallCounts()` 只留 `projectCallCount`。
- [ ] **步驟 5（RED→GREEN）**：新增 AC-4.8：`FakeMapManifest` 既有的預設建構子本身就有邊界（`minLat/maxLat/minLng/maxLng`），不需另建 `linearAt`；斷言 `containsGeo` 為假時 `projectCallCount` 不遞增，且以相同座標分別驅動虛擬 Fix 與真實 Fix，兩者 `coverage` 判定相同。
- [ ] **步驟 6**：處理 `test/taiwan_map_manifest_test.dart`：刪除引用 `roadNodes`／`snapLimitMeters`／`findSnapTriggerConflicts` 的段落（78~115 行）；86~102 行的 POI 間距測試移到 T25 的 `manifest_geometry_check_test.dart` 或確認由其新版取代後刪除。
- [ ] **步驟 7**：刪除 `lib/game/map_module/utils/taiwan_geo_calibrator.dart` 與 `test/taiwan_geo_calibrator_test.dart`（確認無其他呼叫端後）。
- [ ] **步驟 8（RED）**：新增 `test/game/map_module/manifests/taiwan_map_manifest_mask_test.dart`：載入 `assets/maps/taiwan/mask.png`，斷言已知落在遮罩外的像素座標（例如台灣海峽中點對應的經緯度投影後的位置）`containsGeo` 為假，已知落在陸地內的座標（現有 POI 附近）為真。先確認在遮罩接線前此測試失敗（現行矩形框會讓海峽座標誤判為真）。
- [ ] **步驟 9**：實作遮罩查詢：讀取 `mask.png`（建議在建構子預先解碼並量化成 `Uint8List`/`bitset`，避免每次呼叫都解碼圖檔，滿足 NFR-4 常數時間要求），`containsGeo` 改為依經緯度投影到像素座標後查詢遮罩值。遮罩解析度、如何從連續經緯度映射到離散遮罩格的規則需在實作時明確記錄（供 §2.2 規則 4 的「解析度由模組宣告」）。
- [ ] **步驟 10**：`taiwan_map_manifest.dart` 移除 `snapToRoad`、`snapLimitMeters`、`roadNodes` 相關實作與資料。
- [ ] **步驟 11**：`location_controller.dart:124-126` 的 `switchLayer()` 改為 `next.projectToPixel(last.latitude, last.longitude)`（不再吸附）。
- [ ] **步驟 12**：更新 `CLAUDE.md` §4「已知違反（待修）」PRE-8 條目——現況已寫「SPEC v6 已宣告 PRE-8 作廢」但 `CLAUDE.md` 尚未同步，兩份文件目前矛盾；同時把矩形框改遮罩這件事的完成狀態記錄進去（原條目描述的正是矩形框洞，遮罩接線完成後應移入「已解除」）。
- [ ] **步驟 13**：全域搜尋 `snapToRoad|snapLimitMeters|roadNodes` 確認 `lib/`、`test/` 無殘留（`manifest_geometry_check.dart` 的 `roadNodes` 參數留給 T25 處理）。
- [ ] **步驟 14**：`flutter analyze` 0 issue；`flutter test` 全綠。

---

## T25 — 觸發品質契約（REQ-C-18）

**目的**：`manifest_geometry_check.dart` 目前驗證的是「道路節點與 POI 的幾何間距」（PRE-8）。v6 刪除道路吸附後，這個驗證失去對象；REQ-C-18 需要的是一個新驗證——「任兩個 POI 之間的幾何約束」，改用 `d(A, B) > r_A + r_B + positionErrorBound`。

**設計要點**：
1. 新檔 `lib/domain/location/trigger_suitability.dart`：
   - `triggerSuitabilityThreshold`、`gridEligibilityThreshold` 兩個具名常數（值 30，與 `QualityGate` 既有的品質標記門檻同值）；一條測試斷言三者（含 `mileageQualityThreshold`，即 T21 的品質標記門檻）相等，**不共用同一個常數宣告**，避免日後修改其中之一時誤以為連動改了全部。
   - `bool isTriggerSuitable(double accuracyMeters) => accuracyMeters <= triggerSuitabilityThreshold;`
2. 改寫 `manifest_geometry_check.dart`：
   - 函式簽章由 `findSnapTriggerConflicts({roadNodes, pois, snapLimitMeters, metersPerPixel})` 改為 `findPoiProximityConflicts({required List<PoiMarker> pois, required double positionErrorBound, required double metersPerPixel})`。
   - 邏輯改為兩兩 POI 互驗：`d(A,B) * metersPerPixel > A.triggerRadiusMeters + B.triggerRadiusMeters + positionErrorBound`。
   - 檔頭註解更新為 REQ-C-18 的推導（見 SPEC §3.3 規則 3）。
3. `positionErrorBound` 作為函式參數，**不在本檔案給預設值**——呼叫端（未來任務 A 的觸發半徑裁決流程）必須顯式提供，符合 SPEC「必填注入、無預設值」。Dart 的 `required` 具名參數在型別系統層級就不允許帶預設值，此設計不會被上游意外架空；任務 A 開工前，本函式只會被測試碼以顯式數值呼叫，不是死碼，也不擋整合測試。

**釘住一個解讀（架構師覆核提出，先定案避免日後爭議）**：REQ-C-18 規則 1「每筆位置對外提供觸發適用性標記」，本任務的實作是獨立純函式 `isTriggerSuitable(accuracyMeters)`，**不**把這個標記接進 `GeoFix` 或 `PipelineOutput` 成為隨附欄位（這點與 T21 的品質標記處理方式不對稱——後者確實接進管線內部狀態）。**裁決**：「對外提供」以「公開純函式 + 已公開的 `GeoFix.accuracyMeters` 欄位」滿足，呼叫端（任務 A）自行對每筆位置呼叫。若任務 A 開工後認為需要「每筆位置自帶已算好的旗標」，屬其 SPEC／plan 階段的新需求，不視為本任務未完成。

**步驟**：
- [ ] **步驟 1（RED）**：新增 `test/domain/location/trigger_suitability_test.dart`：三個門檻常數相等性斷言（AC 對應 REQ-C-18 規則 1 附註）、`isTriggerSuitable` 邊界測試（AC-18.1、AC-18.2）。
- [ ] **步驟 2（RED）**：改寫 `test/domain/location/pipeline/manifest_geometry_check_test.dart`：
  - 合法 `FakeMapManifest` 資料 → 綠燈。
  - 刻意違規資料（兩 POI 相距 0.2 像素、r 各 50 m、e = 52.5 m）→ 必須偵測到（AC-18.3 第二點）。
  - `TaiwanMapManifest` 資料 → 綠燈，測試名稱與註解註明「綠燈源自地圖尺度非佈點品質，地方層上線後須重驗」（AC-18.3 第三點）。
- [ ] **步驟 3**：實作 `trigger_suitability.dart` 與改寫 `manifest_geometry_check.dart`。
- [ ] **步驟 4**：搜尋 `findSnapTriggerConflicts` 呼叫端（若有整合測試或工具腳本引用舊函式名）一併更新。
- [ ] **步驟 5**：`flutter test` 全綠、`flutter analyze` 0 issue。

---

## T23 — REQ-C-03 規則 5 簡化（刪除裝置速度交叉檢查）

**現狀**：`lib/domain/location/pipeline/quality_gate.dart:77-89` 的 `_exceedsSpeedLimit` 取兩點差分與裝置回報速度的較小值。

**步驟**：
- [ ] **步驟 1（RED）**：刪除 `test/domain/location/pipeline/quality_gate_test.dart` 的 `AC-3.10`、`AC-3.11` 兩條測試（`quality_gate_test.dart:111-124`）。確認刪除後既有其餘測試仍綠（尚未改動邏輯）。
- [ ] **步驟 2**：`quality_gate.dart` 的 `_exceedsSpeedLimit` 改為：
  ```
  final speed = meters / (delta.inMicroseconds / 1e6);
  return speed > maxSpeedMetersPerSecond;
  ```
  移除 `fix.hasSpeed`／`fix.speedAccuracy`／`fix.speedMetersPerSecond` 的取值邏輯（欄位本身在 `GeoFix` 保留，僅管線不再消費，符合 SPEC 修訂五）。
- [ ] **步驟 3**：函式頭註解補上 F4 的結論（都卜勒與位置解算共用衛星幾何，裝置回報速度非獨立證據源），避免日後被重新提議。
- [ ] **步驟 4**：`flutter test test/domain/location/pipeline/quality_gate_test.dart` 全綠。

---

## T26 — REQ-C-02 規則 5：Android 平台更新間隔

**現狀**：`lib/data/location/geolocator_location_source.dart` 尚未檢視此欄位是否已宣告；SPEC 新增「Android 另設平台層更新間隔 1 秒」。

**步驟**：
- [ ] **步驟 1**：確認 `geolocator` 套件的 `AndroidSettings`（或對應設定類別）是否有 `intervalDuration` 參數；若目前 `LocationSettings` 建構未指定，新增 `intervalDuration: const Duration(seconds: 1)`（僅 Android 分支；iOS 的 `AppleSettings` 無此參數，維持原樣）。
- [ ] **步驟 2**：因涉及平台 API，本檔案屬 `data/` 層，NFR-1 不要求無真機可測；改為在建構參數層寫一條單元測試斷言傳入 `LocationSettings` 的物件確實帶有該值（用可注入的 settings 建構函式或 fake 驗證参数，不必啟動真實定位）。
- [ ] **步驟 3**：`flutter analyze` 0 issue。真機驗收併入 T29。

---

## T24 — REQ-C-16 裝置喚醒抑制

**目的**：新增 `keepAwakeActive` 純述詞，並接上平台喚醒能力（plan 裁決部分）。

**選型裁決（2026-09-07，工程師與架構師覆核一致同意，定案）**：採用 `wakelock_plus`（`wakelock` 已停止維護），符合 CLAUDE.md §6「缺了它需求無法實作」的例外——喚醒鎖無 Flutter SDK 原生 API。**但兩位覆核者都特別提醒：不要包裝成正式抽象。** `LocationSource` 之所以被核准為抽象，是因為它擋住一條業務上真實存在的變動軸（真實 GPS ↔ 虛擬來源，兩者都是正式功能）；`wakelock_plus` 永遠只有開／關，沒有第二種正式生產行為需要切換，不構成「擋住已知會變的軸」。定位比照 `Clock`——純粹為了讓 NFR-5 可測而存在的縫，做**最小的具體類別**（兩個方法、建構參數可覆寫），不取名為 `xxxGateway`（容易被誤讀成第四條核准抽象），也不放進 CLAUDE.md §3 的核准清單。

**設計要點**：
1. 新檔 `lib/domain/location/keep_awake.dart`：純函式 `bool shouldKeepAwake({required SourceMode mode, required PermissionState permission, required bool isForeground, required bool featureEnabled})`，逐字對應 SPEC 規則 1 的合取式。**不含 `powerMode`**（依 SPEC 規範性註解）。
2. **`keepAwakeActive` 只做成衍生 getter，不進任何 `@freezed` 欄位**（工程師覆核意見，比照 `realDistanceMeters`／`virtualDistanceMeters` 目前的做法——`LocationControllerState.state` getter 現算，不落地存成欄位）。原稿寫「`LocationStatus` 或 `LocationControllerState` 新增欄位」是留了一個不該留的選擇：`LocationStatus` 是 REQ-C-14 規則 1 明訂的「五個獨立維度」，`keepAwakeActive` 是這五維度的函式而非第六維度，塞進去會讓讀者誤會多了一個獨立狀態維度。`LocationDiagnostics`（見下）才是它對外曝光的位置，同樣現算、不落地。
3. `LocationController` 新增 `featureEnabled`（預設 `true`，見 Q26：暫不跨進程持久化，重啟後預設開啟，待任務 B 持久化層決定是否升級）與對應的開關方法。
4. 新檔（`data/` 層）`wakelock_control.dart`（不叫 `Gateway`）：兩個方法 `enable()`/`disable()` 包一層 `wakelock_plus`；接線層訂閱 `keepAwakeActive` 的值變化並呼叫。
5. `NFR-5` 的 dispose 路徑須呼叫 `disable()`。

**步驟**：
- [ ] **步驟 1（RED）**：`test/domain/location/keep_awake_test.dart`，逐條覆蓋 AC-16.1~16.7（純函式測試，無需平台）。
- [ ] **步驟 2**：實作 `keep_awake.dart`，接上 `LocationController` 的衍生 getter。
- [ ] **步驟 3**：`flutter pub add wakelock_plus`；實作 `wakelock_control.dart`，接線層（`main.dart` 或 providers）訂閱 `keepAwakeActive` 變化並呼叫。
- [ ] **步驟 4**：`LocationDiagnostics` 新增 `keepAwakeActive` 欄位（`models/location_status.dart:77-91`，衍生值，非持久狀態）。**本步驟與 T21 步驟 3 動同一個 `@freezed` 類別，不得真的併行——由後完成的一方一次補齊兩個欄位。** 改欄位後先跑 `dart run build_runner build --delete-conflicting-outputs`，再 `flutter analyze`。
- [ ] **步驟 5**：`NFR-5` 覆核：dispose 測試斷言 `wakelock_control` 呼叫過 `disable()`（用 fake 計數）。
- [ ] **步驟 6**：真機設定 UI（開關本功能）屬 `game/`／`ui/` 層，煙霧測試即可，不追求覆蓋率（依 CLAUDE.md §2 分層測試策略）。
- [ ] **步驟 7**：`flutter test` 全綠、`flutter analyze` 0 issue。

---

## T27 — 不連續事件供畫面層（REQ-C-07 規則 6）

**現狀**：`LocationController.events`（`state/location/location_controller.dart:98`）已是公開的唯讀清單，任何訂閱端（含未來的 HUD）皆可讀取全部事件，**結構上未限制只讓任務 A 消費**。HANDOFF 提到的「目前該事件只餵給任務 A」描述的是**尚未實作**的畫面層，不是 `LocationController` 本身的限制。

**判斷**：本任務在 `LocationController` 層**已滿足** REQ-C-07 規則 6 的資料可得性；缺的是 AC-7.8 要求的**可測性**——需要一條測試明確斷言 `discontinuity` 類事件可被獨立於任務 A 的訂閱端讀到，防止未來有人加了一個「只給任務 A」的過濾器而不自覺違反本規則。

**工程師覆核已實地確認（非計劃推測）**：`lib/state/location/location_providers.dart:193` 的 `onAppForeground()` 已經呼叫 `_controller.markDiscontinuity(RelocationNote.backgroundResume)`，接線並非空缺；`location_controller.dart:245-250` 的 `ingest()` 對 `out.events` 一律 `_log.addAll`，不分 `RelocationCause`／`RelocationNote`，證實無過濾。**因此本任務只需補測試，步驟 2 原本的「若紅燈…」備案分支用不到，已移除。**

**步驟**：
- [ ] **步驟 1（RED）**：`test/state/location/location_controller_test.dart` 新增 AC-7.8：模擬 `markDiscontinuity` 後產生的 `RelocationEvent`（`note` 為 `backgroundResume` 等），斷言可從 `controller.events` 篩出，且不依賴任何任務 A 專屬型別或介面。
- [ ] **步驟 2**：`flutter test` 全綠（預期本測試直接綠燈，因為接線已存在——寫這條測試的目的是把既有正確行為釘成回歸保護，不是修一個缺陷）。

---

## T28 — AC-3.9 測試標題修正

**現狀**：`test/domain/location/pipeline/significance_gate_test.dart:36-48` 的測試邏輯**已經是正確行為**（0-based 迴圈 `i=3` 對應第 4 筆 Fix，得到 36 m、觸發 1 次），只是**標題與內文用了「恰有第 3 筆」**，與 SPEC v6 改寫後的「恰有第 4 筆」不一致（純標籤問題，非邏輯錯誤——原 SPEC v5.1 的敘述本身有 off-by-one，程式碼從未依照錯誤敘述實作）。

**步驟**：
- [ ] 將測試標題改為 `'AC-3.9 基準凍結：恰有第 4 筆顯著，累計 36m'`，內文註解同步改為「12 否、24 否、36 是（基準移到 36）、48 距新基準 12 否、60 距 24 否」對應「第 2、3 筆未達門檻，第 4 筆顯著，第 5 筆未達新門檻」的敘述。
- [ ] `flutter test test/domain/location/pipeline/significance_gate_test.dart` 確認仍綠（純文字變更，行為不變）。

---

## T29 — DoD 7a/7b 真機驗收（流程，無程式碼）

**前置**：T21（`accuracyGatedFixCount`）、T24（`keepAwakeActive`）、T26（Android 更新間隔）需先完成，DoD 7a 第 4 項才有資料可記。

**步驟**：
- [ ] 依 `SPEC_C_GPS_TRACKING.md` §7 DoD 7a：三趟不同時段測試（含至少一趟清除 GNSS 快取），記錄假顯著位移事件筆數、品質標記通過率、`accuracyGatedFixCount`、`acceptedFixCount`、精度分佈。
- [ ] 7a 第 5 項（探索網格 ≤ 1 格誤差）**依賴任務 A／B 的網格計算模組**，若該模組尚未實作，本項**暫緩**、於文件中明確標註「候補」，不得以里程比值替代判定（v6 已明確捨棄該替代方案）。
- [ ] 依 §7 DoD 7b：手機收於口袋、允許鎖屏、步行 500 公尺，確認未產生假里程且中斷區間對玩家可見（畫面層若尚未實作 HUD 呈現，本項驗證 `LocationController.events` 層級的可得性即可，UI 呈現屬另一任務）。
- [ ] 全部結果寫回新的 `FIELD_TEST_LOG_02.md` 或併入下一輪 HANDOFF，供 Q19、Q21、Q22、Q25 累積資料。

---

## 執行順序建議

1. T23、T26、T28（獨立、低風險）→ 可任意順序或併行先做完。
2. T21（品質標記）與 T24（裝置喚醒的純邏輯部分）可併行寫，**但 `LocationDiagnostics` 的欄位新增序列化**（見上方任務相依圖註記）——建議約定由 T21 先加 `accuracyGatedFixCount` 並 regen，T24 收尾時再加 `keepAwakeActive` 並 regen 一次。
3. T22（刪除吸附 + 接線分類遮罩）→ T25（REQ-C-18 契約）。
4. T27（不連續供畫面層，多半只是補測試）。
5. T29（真機驗收，收尾）——含更新 `PLAN_C_GPS_TRACKING.md` 標頭與 `CLAUDE.md` §7 文件地圖（見下方文件治理）。

---

## 已裁決事項（原「待 plan 覆核時確認的裁決點」，2026-09-07 依工程師與架構師覆核共識 + 使用者裁決定案）

1. **T24 採用 `wakelock_plus` 依賴**，包裝為最小具體類別（`wakelock_control.dart`），不做成正式抽象、不放進 CLAUDE.md §3 核准清單。
2. **T21 的品質旗標不放 `GeoFix`**，落地為 `PipelineOutput` 的新欄位（`qualityGated`），延續 `GateResult`／`Accepted`／`Rejected` 的既有風格。
3. **T22 範圍納入分類遮罩接線**：`TaiwanMapManifest.containsGeo` 現在就從矩形框改為查詢 `assets/maps/taiwan/mask.png`，不留待任務 D（使用者裁決：圖資已存在，現在接線）。

---

## 文件治理（架構師覆核提出，非阻擋項，建議併入 T29 收尾）

1. `PLAN_C_GPS_TRACKING.md` 標頭仍寫「規格：`SPEC_C_GPS_TRACKING.md`（v5.1）」，且無指向本文件的連結。收尾時加一行：「T1~T20 已於真機驗證中執行完畢；v6 相對 v5.1 的增量見 `PLAN_C_AMENDMENT_01.md`（T21~T29）」。
2. `CLAUDE.md` §7「文件地圖」表格未列 `SPEC_C_AMENDMENT_01.md`、`PLAN_C_GPS_TRACKING.md`、`PLAN_C_AMENDMENT_01.md`、`HANDOFF.md`、`TASK_D_LOCAL_TIER_PROPOSAL.md`，補齊並註明 `SPEC_C_AMENDMENT_01.md` 現狀為「已併入 SPEC，僅供實測證據與收斂過程查閱」。
