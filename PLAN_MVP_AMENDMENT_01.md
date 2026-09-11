# PLAN — SPEC MVP 增修草案 01 施工計劃

**狀態**：v2 草案，待覆核
**對應 SPEC**：`SPEC_MVP_AMENDMENT_01.md` v6
**前提**：SPEC v6 覆核通過後才動工。本文件不含實作碼。

**v2 相對 v1 的變動**（企劃 + 工程師雙軌覆核後）：AC-A1-6.8 拆為 6.8a/6.8b 後斷開 T10↔T13 的環；D4/D5/D6 由依序決定改為**聯立求解**（原本漏了 AC-A1-6.8 這條夾具）；卡表加稅提前為 D0/T0（改一張卡的成本會讓所有窮舉失效）；T17 由階段三任務降為貫穿全程的紀律（否則測試從階段一中段紅到最後）；新增 T0b 京都素材解析器（原計劃完全缺席，而兜底規則會讓整個標籤 AC 家族空轉）；修正 `dart test` 指令、T11/T12/§7 的三方衝突、§1 分層自相矛盾。

---

## 0. 這份計劃要解決什麼

SPEC v6 有 14 條 REQ、約 45 條 AC，只約束行為邊界，不指定任何數字。主要風險不是寫不出來，而是：

- **數字彼此夾擠**：多條 AC 同時夾住同一個參數，順序錯了會反覆推翻。
- **接線盲區**：現行 `TaiwanPoiMaterialResolver` 有一條通配兜底規則，任何 poiId 都能合成出一張卡。它一旦留著，標籤詞彙表相關的 AC 量到的全是合成卡，不是那 32 張策劃過的卡 —— 元件全綠而需求空轉。
- **既有 383 條測試**中一批期望值會改變，須逐條分辨「該更新」與「被削弱」。

因此本計劃的核心是**決定順序與驗收歸屬**，而非任務清單。

---

## 1. 分層落點

| SPEC 條目 | 落點 | 理由 |
|---|---|---|
| REQ-A1-00 標籤詞彙表 | `domain/core_loop/models/travel_philosophy.dart`（標籤）+ `domain/core_loop/` 新增稽核純函式 + `data/core_loop/kyoto_night_catalog.dart`（卡表） | 規則與內容分離，見 §5 |
| REQ-A1-01 契合度分級 / 正規化 | `domain/core_loop/models/timeline_itinerary.dart`、`travel_philosophy.dart` | 純數值規則 |
| REQ-A1-01b 主題傳導 | `domain/core_loop/review/client_review_engine.dart`、`client_spec.dart` | 同上 |
| REQ-A1-02 內容不變式 | 測試清單（見 §5），不落程式 | SPEC 已降為回歸護欄 |
| REQ-A1-03/04 超支與反無聊 | `client_review_engine.dart`、`client_spec.dart` | 同上 |
| REQ-A1-05 3 槽提交 | `domain/.../timeline_itinerary.dart`（規則）+ `ui/core_loop/`（呈現） | 規則在 domain |
| REQ-A1-06/07 取材尺度 | `domain/core_loop/`（資格規則，自 state 搬入）+ `game/map_module/manifests/`（圖資）+ `state/`（**僅組裝**） | 見 T11 |
| REQ-A1-08/09 裝備與體力 | `domain/core_loop/models/meta_equipment.dart`、`run/curator_run_state.dart` | 純數值規則 |
| REQ-A1-10~13 評分失衡 | `client_review_engine.dart`、`kyoto_night_catalog.dart` | 同上 |
| REQ-A1-14 混亂冒險例外 | `domain/core_loop/models/travel_philosophy.dart`（具名旗標）+ `client_review_engine.dart`（唯一讀取點） | 見 §2 |

`domain/` 不得 import `package:flutter` / `package:flame` 的既有約束不變。

---

## 2. 抽象邊界：本次不新增抽象

依 CLAUDE.md §3，新抽象要能回答「擋住哪一條已知會變的軸」。

- **REQ-A1-14 的哲學例外**：用 `TravelPhilosophy` 上一個**按效果命名**的旗標（語意為「相鄰高風險在 Hype 側視為連段」），**不得按身分命名**（`isChaosAdventure` 只是把 `if (philosophy == chaos)` 換個地方寫）。由 `client_review_engine` 在**唯一一處**讀取。這是資料不是抽象：沒有新介面、沒有註冊機制、相依方向不變、外部塞不進新規則。
  - **可強制而非自律**：加一條測試 `TravelPhilosophy.values.where((p) => p.<旗標>).length == 1`。SPEC §7 說它是 MVP 唯一具名例外，這條測試讓那句話有牙齒。
  - 出現第二處讀取點，即視為它已變成抽象，須回頭重新論證。
- **契合度分級**：`evaluateMaterial` 的內部改寫，不新增型別。
- **3 槽提交**：`canSubmit` 條件放寬 + 連續性檢查，不新增型別。
- **標籤稽核**：新增純函式 `audit(素材池, 哲學清單) -> 違規清單`，吃任意素材池。這不是抽象，是把規則從內容裡拆出來，且天生城市無關。

三條核准抽象維持不變，不新增第四條。

---

## 3. 數字決定順序

### D0　卡表加稅（最先，無需窮舉）

八坂之塔 `cost 0 → 500`，`riskLevel` 維持 2。依 SPEC 的「負擔得起 = `cost ≤ 社畜預算 × 25%`」與「`cost==0 && risk<=2` 者 ≤1 張」，這是唯一乾淨解（改 risk 會讓它自帶疲勞）。

**必須排在所有調參之前**：改一張卡的成本會讓 D1~D11 的所有窮舉結果失效。它是內容事實，不是調參結果。

### D1~D3　主題鏈（依序）

| # | 決定什麼 | 夾住它的 AC |
|---|---|---|
| **D1** | 主題正規化手段（按槽位數平均 vs 總貢獻軟上限） | AC-A1-1.1/1.2 |
| **D2** | 契合度階梯：命中 1/2/3 個偏好標籤的係數、`themeValue` 如何進入 | AC-A1-1.1/1.2/1.3 |
| **D3** | `minTheme` 映射與 `themeFactor` 係數 | AC-A1-1.7/1.8 |

D1 決定 3 槽的主題是否天然高於 4 槽，左右後續全部。

### D4+D5+D6　**聯立求解**（不可分開決定）

| # | 決定什麼 |
|---|---|
| **D4** | 拉車疲勞量級（Theme 側 −N、Hype 側佔 `targetHype` 的比例） |
| **D5** | 絕景係數階梯 0/1/2/3 張 |
| **D6** | 純度獎勵量級 |

**為什麼必須聯立**：

- D4 被三條夾，不是兩條 —— AC-A1-6.3（下界）、AC-A1-3.6（上界），以及 **AC-A1-6.8a**。SPEC 附錄 A.4 自己寫明「混亂冒險多出的 55 點熱度須由午夜探索省下的三組疲勞抵銷，AC-A1-6.8 是這件事的驗收閘門」—— Hype 側疲勞的量級是從 6.8a **反推**出來的。
- D5 也夾 6.8a：改標籤後午夜探索、美食朝聖、反觀光各只剩 1 張絕景，混亂冒險與慢旅行各 2 張。0/1/2 的係數階梯直接決定「1 張陣營」與「2 張陣營」的落差，是五家極差的主要成分。
- D6 與 D4 互夾：AC-A1-3.6 比較的是「3 槽最佳」與「4 槽最佳」，**兩邊都含純度獎勵與疲勞**。先解 D4 等於解一個含未知數的不等式。

**做法**：以三維窮舉找可行域，目標函數同時滿足 AC-A1-3.6、6.3、6.7、6.8a、6.9。**若可行域為空，回報而非硬選** —— 那表示 SPEC 的 AC 互斥，須退回 SPEC。

### D7~D11　其餘

| # | 決定什麼 | 相依 |
|---|---|---|
| **D7** | 超支曲線：Perfect 上界、Rejected 下界（跨度 ≥30%） | D3 |
| **D8** | 體力公式（AC-A1-5.3 要求 risk5 ≥ risk1 的 2 倍，現況 1.67 倍） | **可先行試算，最終值須回聯立步驟複驗** |
| **D8b** | **美食朝聖補償路徑的選定** | 見下 |
| **D9** | 升級價梯或佣金係數（AC-A1-5.4） | D7 |
| **D10** | 相機 Lv.1 倍率（AC-A1-5.1） | **同 D8，須回聯立複驗** |
| **D11** | Rejected 收入係數（AC-A1-6.4） | D9 |

**D8b**：SPEC 附錄 A.2 明文「補償路徑目前不存在，施工計劃必須建立其中一條」。候選 (a) 體力公式改乘法（即 D8）／(b) 提高飲食卡 `storyValue` 折現（即 D9/D11）／(c) 給美食朝聖規則改寫 —— **(c) 與 §7「唯一具名例外」牴觸，不得就地開特例**；若窮舉後只有 (c) 可行，退回 SPEC 修訂 §7。

**D8 / D10 不是獨立的**：AC-A1-6.2 已移到採集階段（同時夾 D5 與 D8）；相機倍率縮放黃昏槽熱度，直接進網紅端滿意度，也就直接進 6.8a。

### D12　當局可達 POI 選卡（階段二）

在 D0~D11 定死的參數下，**帶約束搜尋**滿足 AC-A1-4.4/4.5/4.6 **且 AC-A1-6.8b** 的可達子集。單向承接，不回頭改參數 —— 除非搜不到可行子集，才依 §6 風險 2 的順序回退。

---

## 4. 任務拆解

### 階段零：內容前置

- **T0　卡表加稅**　D0。改 `kyoto_night_catalog.dart` 一張卡。AC-A1-6.5。
- **T0b　京都素材解析器**　新增 `KyotoPoiMaterialResolver`，**查表未命中即回 null**，並附測試釘住這件事。
  - 現況 `taiwan_attraction_materials.dart:116-118` 有通配兜底規則，任何 poiId 都會被合成出一張卡。這條規則若留著，AC-A1-0.1~0.4、4.4~4.6 量到的全是合成卡，**整個標籤 AC 家族空轉**。
  - 同時更新 `main.dart` 的兩個 DLC 注入點（`mapManifestProvider` 於 T12、`poiMaterialResolverProvider` 於此），並同步更新 `3a08fcc` 新增的 main.dart 接線測試。

### 階段一：純領域數值

- **T1　標籤詞彙表對齊**　依 SPEC 附錄 A.1 改五組標籤；新增稽核純函式。AC-A1-0.1~0.4。
- **T2　契合度分級與正規化**　D1、D2。AC-A1-1.1~1.6。
- **T3　主題傳導**　D3。AC-A1-1.7/1.8。
- **T4　疲勞、連段、絕景、純度（聯立）**　D4+D5+D6 + REQ-A1-14。`TravelPhilosophy` 加具名旗標；Hype 側對混亂冒險反轉，**Theme 側照扣且須有獨立斷言**。AC-A1-6.1/6.2/6.3/6.6/6.7/6.9。
- **T5　3 槽提交**　REQ-A1-05。`canSubmit` 放寬 + 連續性檢查 + 純度獎勵。AC-A1-3.0~3.6。**AC-A1-3.5（文案可區分）的文案產出歸 domain**，T16 只負責呈現。
- **T6　超支與反無聊**　D7。AC-A1-2.1~2.4。（**AC-A1-2.5 不在此** —— 它的窮舉域是可達子集，歸 T13。）
- **T7　體力與裝備階梯**　D8、D8b、D9、D10、D11。AC-A1-5.1~5.4、6.4。
- **T8　平衡收斂（全卡表）**　AC-A1-6.8a。以加稅後的卡表窮舉五家最佳組合。**這是階段一的收口**，不過不得進階段二。

相依：T0 → T1 → T2 → T3 → T4 → {T5, T6} → T8；T7 可在 T3 後並行，但最終值須回 T4 的聯立複驗。

### 階段二：京都街區圖資

- **T9a　像素觸發判定**　REQ-A1-06。`PoiMarker` / `DistrictAttraction` **新增** `triggerRadiusPixels`；公尺欄位保留不動並標註「僅供已凍結的台灣圖資使用」。**不得移除 `metersPerPixelAt`** —— `position_smoother.dart:79` 的 GPS 平滑在用它。一次採集只結算最近的 POI（需把 `Provider.family` 改為單一 provider 或另立 `nearestGatherableProvider`，因為 family 的形狀表達不了「我是不是全場最近的」）。AC-A1-4.2/4.3。
  - 連帶：`manifest_geometry_check.dart:29` 現行禁止觸發窗重疊，與 SPEC 新規牴觸，於本任務修訂或移除。
  - 連帶：`attraction_detail_card.dart:291` 寫死的 `'太遠 (需<50m)'` 文案。
  - 連帶：`district_attraction.dart:28` 的 `triggerRadiusMeters = 50.0` 預設值，改單位後會默默給京都景點錯的值。
- **T9b　資格規則搬進 domain**　**純重構，不得改行為**，以既有測試全綠為驗收。`GatheringEligibility` enum 本身也要搬（現宣告在 state 卻被 UI 消費，留在原地會觸發倒向相依規則），連帶改 `attraction_detail_card.dart` 的 import。
- **T10　京都夜間街區 manifest**　新增 manifest；台灣 manifest 原地保留不刪。
  - **須先裁決**：契約有兩條平行 POI 通道（`poiNodes` 與 `districtAttractions`），採集資格走後者。京都用哪一條、另一條怎麼辦，動工前決定。
  - **須預先說明投影退化方案**：契約強制每份 manifest 提供真實地理投影，但手繪街區沒有真實經緯度。這是抽象的真實漏洞 —— 它把「地理參照地圖」寫死進契約，而「城市即 DLC」的下一張圖就不是地理參照的。**這一點比單位問題更值得回報。**
- **T11　可達 POI 選卡**　D12。AC-A1-4.4~4.6、2.5、6.8b。
- **T12　採集節奏實測**　AC-A1-4.1。**tick 模擬器須住在 `test/`，不得進 `lib/`** —— 它離「軌跡錄製／重播」這個明確延後項只有一步，換個名字混進來就是違規。

相依：T0b → T9a → T9b → T10 → T11 → T12。**T11 依賴 T8 的參數**（單向）。**T12 依賴 T7 的體力公式** —— AC-A1-4.1 的「6 次採集」正是體力與腰包的咬合點。

### 階段三：UI

- **T13　時間線編輯器支援 3 槽**　空槽呈現、連續性提示。
- **T14　Review 呈現純度獎勵與連段**　玩家要看得懂為何加扣分（Exit Criteria ③）。
- **T15　測試總表覆查**　見 §5 的紀律。

### 檔案級衝突：不得同時在飛

- **T7（改體力）與 T9a（讀 `runState.resources.isExhausted`）** 會同時動到體力語意。
- T2/T3/T4 動 `timeline_itinerary` / `client_review_engine` / `travel_philosophy`，與 T10 動 `manifests/` 互不相干，可並行。

---

## 5. 測試策略

- 階段一全部走 **`flutter test test/domain/`**（純 Dart VM、headless、不需模擬器；實測 196 passed / 4 秒）。
  - **`dart test` 在本 repo 不可用** —— `test/domain/` 全部 import `package:flutter_test`，要讓 `dart test` 成真須新增 `package:test` dev_dependency，違反不引入新套件。CLAUDE.md §0 的該行亦已過期，待另案更正。
- **規則與內容分層測試**（避免 domain 測試相依 data 層）：
  - 規則：`audit()` 純函式，以**合成小池**在 `test/domain/` 測邊界（剛好 2 張、剛好 1 張、聯集剛好 4 張）。
  - 內容：`test/data/core_loop/kyoto_night_catalog_test.dart` 把真卡表餵進同一個 audit。改卡表會紅，**而且紅在正確的地方**。
  - REQ-A1-02 的內容不變式、AC-A1-6.5 一併放在這裡。
- **窮舉，不得抽樣**。窮舉域逐條寫明：

  | AC | 窮舉域 | 量級 |
  |---|---|---|
  | AC-A1-5.1 | 10 組代表性手牌的全部排列 | 240 |
  | AC-A1-6.8a | 每種哲學各自的可用卡（9~16 張） | 五家合計 < 12 萬 |
  | AC-A1-6.8b / 2.5 | 當局可達池（≥16 張） | 約 4.4 萬 |

  AC-A1-6.8 是**最大值**斷言、AC-A1-2.5 是**分佈**斷言 —— 抽樣求得的最大值不是最大值，抽樣得到的佔比不是佔比。**抽樣等於把斷言換成較弱的命題**，與下面的測試紀律自相矛盾。若仍嫌慢，用可證明不損失最優解的剪枝（評分可分解為「單槽貢獻 + 相鄰對耦合」時對槽位做 DP），不得抽樣。
- 架構測試維持現有五條，不因本次改動放寬。

### 既有測試的更新紀律（貫穿全程，非單一任務）

**每個任務自己收掉它弄紅的測試，每個 commit 必須全綠。** 不得把期望值更新推到最後 —— 否則測試套件會從階段一中段一路紅到結尾，中間所有任務都失去「跑全綠」這個收口訊號，而 TDD 的 RED→GREEN 正是靠它運作。

可機械檢查的五條：

1. **授權來源**：每條期望值變更，commit body 須寫「舊值 → 新值 → 授權它的 REQ/AC 編號」。找不到 SPEC 條文授權的，不准改。
2. **禁止的具體變形**（可 grep）：`equals(x)` → `greaterThan`/`isNotNull`/`isA`；`closeTo` 容差變大；把硬編碼期望值換成由被測程式自己算出的值（自我實現斷言，最隱蔽）；`expect` 被刪但測試保留；`test(...)` 加 `skip:`。
3. **`expect` 淨數不得下降**：逐檔 `grep -c 'expect('` 比對，下降須說明。
4. **刪除測試的交接條款**：寫出「它原本保護哪個不變量」與「該不變量現在由哪條新測試承接」。承接不到就不能刪。
5. **分兩步**：先只改實作不碰測試，跑一次全套，記下完整紅燈清單；再逐條處理。**預期會紅卻沒紅的測試本身就可疑** —— 代表它沒在測它宣稱的東西。

---

## 6. 風險

1. **D4+D5+D6 聯立可行域為空**　最高風險點。回報而非硬選，退回 SPEC。
2. **AC-A1-6.8a/6.8b 達不到**　處置順序（**不得跳步**）：
   1. 調 T11 選卡 —— 免費，不動規則，6.8b 本來就該是選卡的目標函數之一；
   2. 回到 D4/D5/D6 可行域裡換一個點 —— 本來就是在區間內找解，不算讓步；
   3. **調整 SPEC 附錄 A.1 的標籤** —— 實證上最有效的槓桿，v5 本身就是這麼修好的（午夜探索改排斥 `#拉車`，卡集重疊 0.33 → 0.11）；
   4. 最後才放寬門檻，且須說明放寬後如何保住 Rule 26。**放寬到 20 分等於允許「一家永遠 Perfect、另一家永遠 Pass」**（網紅分級 Perfect ≥90 / Pass ≥70），那正是這條 AC 要擋的東西。
   - **任何情況下都不得為混亂冒險以外的哲學開規則特例。**
3. **圖資解耦不成立**　T10 的驗收改為可判定三條：①`universal_overworld_game.dart` diff 為空；②`lib/domain/location/` diff 為空；③新增檔案只落在 `lib/game/map_module/manifests/` 與 `lib/data/core_loop/`。
   - **T9a 對 `map_manifest.dart` 的像素欄位擴充是事前授權的契約變更，不計入判定** —— 否則必然得到假陰性，然後回報一個假問題。
4. **存檔相容性**　`curator_event_replay.dart:33-45` 以**字串**比對裝備種類（`'sneakers'`/`'camera'`/`'waistBag'`），比不到即拋 `FormatException`。**`EquipmentType` 的 enum 名稱在本次凍結。** 價格與佣金係數的改動是安全的（歷史事件的 `cost`/`earnedCoins` 存在 payload，重播拿當時的值），但須補一條「舊格式日誌重播」的回歸測試。

---

## 7. 不做的事

- 不新增抽象（見 §2）。
- 不做微動作（Runner / Snapshot）。
- **不碰台灣圖資與 GPS 管線** —— 凍結。像素觸發以**新增欄位**達成，不修改既有公尺欄位、不動台灣 manifest 的 40 個字面值、不移除 `metersPerPixelAt`。
- 不做事件日誌壓縮。
- 不為混亂冒險以外的哲學開規則特例。
- 不引入新套件（含 `package:test`）。

---

## 8. 帶出本次範圍的待辦（記錄，不施工）

- **S5**：`lastPersistError` / `persistFailureCount` 在 `lib/` 內零讀者，存檔失敗對玩家仍是靜默的。提示形式是產品決策，但不宜無限期掛著 —— 玩家的金幣靜默消失，與沒修是一樣的體感。
- **CLAUDE.md §0 過期**：`dart test test/domain/` 不可用；「316 passed」實為 383。
