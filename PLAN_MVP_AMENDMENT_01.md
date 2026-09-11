# PLAN — SPEC MVP 增修草案 01 施工計劃

**狀態**：v3 草案，待覆核
**對應 SPEC**：`SPEC_MVP_AMENDMENT_01.md` v7（2026-09-11 已覆核）
**前提**：本計劃覆核通過後才動工。本文件不含實作碼。

**v3 相對 v2 的變動**（SPEC v7 最終覆核後同步）：全部窮舉改用 v7 的完整合法素材域與平手規則；Theme 疲勞固定為每對 −10，D4 只搜尋 Hype 側；絕景階梯補齊 4 張；美食補償固定採共用低風險體力公式；移除修改 GPS 公尺幾何護欄的錯誤指示；京都採集只新增 `DistrictAttraction.triggerRadiusPixels`，台灣公尺路徑原樣保留；resolver 與 manifest 改為完成後原子切換；新增最終可達池聯合收口，承接 AC-A1-5.1/5.4/6.2/6.4；其餘新增 state/UI 接線改與對應 domain 任務一併收口。

**v2 相對 v1 的變動**（企劃 + 工程師雙軌覆核後）：AC-A1-6.8 拆為 6.8a/6.8b 後斷開 T10↔T13 的環；D4/D5/D6 由依序決定改為**聯立求解**（原本漏了 AC-A1-6.8 這條夾具）；卡表加稅提前為 D0/T0（改一張卡的成本會讓所有窮舉失效）；T17 由階段三任務降為貫穿全程的紀律（否則測試從階段一中段紅到最後）；新增 T0b 京都素材解析器（原計劃完全缺席，而兜底規則會讓整個標籤 AC 家族空轉）；修正 `dart test` 指令、T11/T12/§7 的三方衝突、§1 分層自相矛盾。

---

## 0. 這份計劃要解決什麼

SPEC v7 只約束行為邊界，不指定待調係數的具體數字。主要風險不是寫不出來，而是：

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
| REQ-A1-06/07 取材尺度 | `domain/core_loop/`（資格規則，自 state 搬入）+ `domain/location/models/district_attraction.dart`（新增京都像素欄位）+ `game/map_module/manifests/`（圖資）+ `state/`（**僅組裝**） | 見 T9a/T9b/T10 |
| REQ-A1-08/09/09b 裝備與體力 | `domain/core_loop/models/meta_equipment.dart`、`run/curator_run_state.dart` + `ui/core_loop/field/`（提示接線） | 規則在 domain，UI 只呈現同一結果 |
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
| **D4** | Hype 側拉車疲勞佔 `targetHype` 的比例；Theme 側依 SPEC 固定為每對 −10，不得搜尋 |
| **D5** | 絕景係數階梯 0/1/2/3/4 張 |
| **D6** | 純度獎勵量級 |

**為什麼必須聯立**：

- D4 被三條夾，不是兩條 —— AC-A1-6.3a/6.3b（下界）、AC-A1-3.6（上界），以及 **AC-A1-6.8a**。SPEC 附錄 A.4 寫明混亂冒險多出的熱度須由其他哲學省下的 Hype 疲勞與 Theme 優勢抵銷；Hype 側疲勞量級須從 6.8a **反推**。
- D5 也夾 6.8a：改標籤後，午夜探索、美食朝聖、反觀光的**契合卡集**各含 1 張絕景，混亂冒險與慢旅行各含 2 張；這只描述內容傾向，不限制合法選卡。0/1/2 的係數仍直接影響五家最佳解的落差，須由完整合法域確認。
- D6 與 D4 互夾：AC-A1-3.2/3.3/3.6 比較 3 槽與 4 槽，兩邊都含純度與疲勞。先解任一個等於解含未知數的不等式。

**做法**：先固定符合 AC-A1-1.1~1.8 的 D1~D3。D10 相機倍率作為外層離散候選；對每個 D10 候選，各自以三維窮舉找 D4~D6 可行域。每個候選同時驗 AC-A1-3.2/3.3/3.6、6.1、6.3a/6.3b、6.6、6.7、6.8a、6.9，只保留「D10 值 + 非空三維可行域」。候選範圍與步距須寫入可重跑腳本，且平手依 SPEC §0.1 全部保留。若全部 D10 候選的三維可行域皆為空，先證明腳本、範圍與母體完整，再回報並退回 SPEC；不得硬選。

AC-A1-6.2 另依賴 D8 與最終 POI 佈局，於 D12 聯合收口；D5 在該條通過前只算候選值。若 6.2 迫使改 D5，須回到本三維可行域內換點，重驗本段全部 AC。

### D7~D11　其餘

| # | 決定什麼 | 相依 |
|---|---|---|
| **D7** | 超支曲線：Perfect 上界、Rejected 下界（跨度 ≥30%） | D3 |
| **D8** | 全哲學共用體力公式；同時滿足 AC-A1-5.2a/5.2b/5.3/5.6 | **可先行試算；AC-A1-6.2 於 D12 用實際 POI 續局收口** |
| **D9** | 升級價梯（AC-A1-5.4） | 最終可達池的 Pass 收入中位數 |
| **D10** | 相機 Lv.1 倍率（AC-A1-5.1） | **先產生候選；須與 6.8a 及最終可達池一起複驗** |
| **D11** | Rejected 收入係數（AC-A1-6.4） | 最終可達池與 D9 |

**美食補償已裁決，不再選方向**：D8 使用所有哲學共用的低風險體力效率，依 SPEC 固定排序驗 AC-A1-5.6；不得改走飲食故事收入或美食專屬規則。

**D8 / D10 不是獨立的**：AC-A1-6.2 已移到採集階段（同時夾 D5 與 D8）；相機倍率縮放黃昏槽熱度，直接進網紅端滿意度，也就直接進 6.8a。

### D12　當局可達 POI 選卡（階段二）

在 D0~D8 與 D10 的候選參數下，搜尋最終可達子集及 POI 佈局。聯合約束包含 AC-A1-0.1~0.4、2.5、4.4~4.6、5.1、6.8b，並要求 AC-A1-5.4 的 Pass 集合、AC-A1-6.4 的兩客戶 Near Miss／Rejected 集合皆非空。選定後才由真實分佈決定 D9、D11，並驗 AC-A1-5.4、6.2、6.4。

這不是單向 DAG。收口順序固定：

1. 先嘗試同一組參數下的下一個可達子集／POI 佈局。
2. 若 AC-A1-5.1 或 6.8b 無子集可解，只能在已通過 D4~D6 可行域內更換 D4~D6／D10 候選，回跑 AC-A1-6.8a 後重搜。
3. 若 AC-A1-6.2 無佈局可解，在既有可行域內聯動 D5/D8，回跑所有受影響 AC 後重搜。
4. 候選與子集均耗盡才依 §6 回報；不得放寬 AC 或新增哲學特例。

---

## 4. 任務拆解

### 階段零：內容前置

- **T0　卡表加稅**　D0。只改八坂之塔 `cost 0 → 500`，先驗 AC-A1-6.5 的第一個內容條件（`cost == 0 && riskLevel <= 2` 者 ≤1）；不得提前修改哲學或其他數值。每哲學可負擔絕景須等 T1 標籤到位後完成。
- **T0b　京都素材解析器（只建立，不接正式入口）**　新增 `KyotoPoiMaterialResolver`，**查表未命中即回 null**，並附測試釘住這件事。
  - 現況 `taiwan_attraction_materials.dart:116-118` 有通配兜底規則，任何 poiId 都會被合成出一張卡。這條規則若留著，AC-A1-0.1~0.4、4.4~4.6 量到的全是合成卡，**整個標籤 AC 家族空轉**。
  - 本任務不得先切 `poiMaterialResolverProvider`。正式 manifest 與 resolver 必須於 T10 同一 commit 原子切換，避免中間版本的 POI／素材 ID 不相容。

### 階段一：數值與必要接線

- **T1　標籤詞彙表對齊**　依 SPEC 附錄 A.1 改五組標籤；新增稽核純函式，以合成池驗邊界、以全卡表驗內容有能力提供合格子集；並在加稅後卡表完成 AC-A1-6.5 的「每哲學至少 1 張可負擔絕景」。AC-A1-0.1~0.4 對「最終可達池」的正式驗收留到 T11。
- **T2　契合度分級與正規化**　D1、D2。AC-A1-1.1~1.6。
- **T3　主題傳導**　D3。AC-A1-1.7/1.8。
- **T4　疲勞、連段、絕景、純度（聯立）**　以 D10 為外層候選，聯立 D4+D5+D6 + REQ-A1-14。`TravelPhilosophy` 加具名旗標；Hype 側對混亂冒險反轉，Theme 側固定每對 −10 且須有獨立斷言。AC-A1-6.1、6.3a/6.3b、6.6/6.7/6.9；AC-A1-6.2 留到 T11。
- **T5　3 槽垂直切片**　REQ-A1-05。domain 完成 `canSubmit`、連續性與純度；controller 只轉交同一份結果；UI 同 commit 更新按鈕、端點留白與失敗原因。AC-A1-3.0~3.4、3.6~3.8。AC-A1-3.5 的結算文案留到 T13。
- **T6　超支與反無聊**　D7。AC-A1-2.1~2.4。（**AC-A1-2.5 不在此** —— 它的窮舉域是最終可達子集，歸 T11。）
- **T7　體力垂直切片、相機與收入候選**　D8、D10，並先建立 D9/D11 的候選計算。domain 體力公式與一般採集／滿包換牌的 UI 預覽、浮字、最後一搏實扣同一任務收口；完成 AC-A1-5.2a/5.2b/5.3/5.5/5.6。AC-A1-5.1/5.4、6.4 依賴最終可達池，留到 T11。美食補償不得另選路徑。
- **T8　平衡收斂（全卡表）**　以加稅後卡表驗 AC-A1-3.6、6.7、6.8a、6.9；各條嚴格使用 §5 所列專屬母體（3.6 只用 `riskLevel >= 3` 候選，其餘不得因此過濾）。這是進入圖資階段前的全卡表閘門，不代表最終可達池已收口。

相依：T0 → T1 → T2 → T3 → T4 → {T5, T6, T7} → T8。T7 的 D8/D10 候選若改變 T4/T8 輸入，須回跑聯立腳本與 T8。

### 階段二：京都街區圖資

- **T9a　資格規則搬進 domain**　先做純重構，不改行為，以既有測試全綠收口。`GatheringEligibility` enum 一併移入 domain，UI 改讀 domain 型別；不得混入像素新行為。
- **T9b　京都像素採集與最近 POI**　REQ-A1-06。只在 `DistrictAttraction` **新增**可選的 `triggerRadiusPixels`；有像素值時採集資格直接比較像素，無值時維持既有 `triggerRadiusMeters ÷ metersPerPixelAt()` 路徑。不得修改 `PoiMarker`、既有公尺欄位、`map_manifest.dart`、`findPoiProximityConflicts()` 或台灣 manifest。正式入口先解析全場最近可採 POI，等距依 `id` 字典序，再執行一次原子採集。AC-A1-4.2/4.3/4.3b。
  - GPS 公尺幾何三組既有測試必須原樣通過；另加 state／入口測試驗最近 POI 只扣一次 HP/Budget、只新增一張卡與一個 ID。
  - `attraction_detail_card.dart` 的距離提示須於同一任務改由資格結果產生，不得繼續假設所有圖層都是 `<50m`；以 Widget 測試覆蓋像素與公尺兩種模式。
- **T10　京都夜間街區 manifest 與原子注入**　新增小尺度手繪底圖與京都 manifest；台灣 manifest、GPS 管線原地保留。
  - 京都採集與畫面景點以 `districtAttractions` 為唯一權威通道；`poiNodes` 在京都 manifest 回傳空集合，不複製第二套採集資料。
  - 不改 `OverworldMapManifest`。手繪畫布以京都範圍的簡單有界仿射投影實作既有 `containsGeo/projectToPixel/unprojectToGeo/metersPerPixelAt`；本階段驗收只使用既有 virtual source，不新增或修改 GPS 行為。
  - 完成 T0b 的 POI ID 對照後，於同一 commit 同時切換 `mapManifestProvider` 與 `poiMaterialResolverProvider`。新增 production bootstrap 接線測試，測試必須讀正式組裝結果，不得自行重抄 override 清單。
- **T11　最終可達池聯合收口**　D12。搜尋並固定 POI 子集／佈局，驗 AC-A1-0.1~0.4、2.5、4.4~4.6、5.1、5.4、6.2、6.4、6.8b；決定 D9/D11 最終值。依 §3 的固定回退順序處理不可行候選，每次回調均重驗受影響的全卡表與子集 AC。
- **T12　採集節奏實測**　AC-A1-4.1。三件裝備 Lv.1，以 final 京都佈局及 domain 體力公式跑 4 分鐘邏輯時間。**tick 模擬器須住在 `test/`，不得進 `lib/`**；不做軌跡錄製／重播。

相依：T0b → T9a → T9b → T10 → T11 → T12；T11 依賴 T8 的全卡表候選與 T10 的實際 POI，且可能依 §3 明訂邊界回調。T12 依賴 T7 的體力公式與 T11 的最終佈局。

### 階段三：結算回饋與總驗收

- **T13　Review 呈現純度與冒險連段**　只呈現 domain 產出的判定與文案，不在 Widget 重算。AC-A1-3.5；並以整合測試證明 AC-A1-6.6 的 Hype／Theme 雙側效果能被玩家區分。
- **T14　測試總表覆查**　逐條建立 SPEC AC → 測試名稱 → 任務 → commit 對照，執行 §5 全部護欄；不得以本任務延後前面漏掉的測試。

### 檔案級衝突：不得同時在飛

- **T7（改體力並更新 UI）與 T9b（採集資格／提示）** 不得同時在飛。
- T2/T3/T4 動 `timeline_itinerary` / `client_review_engine` / `travel_philosophy`，與 T10 動 `manifests/` 互不相干，可並行。

---

## 5. 測試策略

- 純數值規則走 **`flutter test test/domain/`**（純 Dart VM、headless、不需模擬器）；T5/T7 的 state／UI 接線另跑對應 controller 與 Widget 測試。
  - **`dart test` 在本 repo 不可用** —— `test/domain/` 全部 import `package:flutter_test`，要讓 `dart test` 成真須新增 `package:test` dev_dependency，違反不引入新套件。CLAUDE.md §0 的該行亦已過期，待另案更正。
- **規則與內容分層測試**（避免 domain 測試相依 data 層）：
  - 規則：`audit()` 純函式，以**合成小池**在 `test/domain/` 測邊界（剛好 2 張、剛好 1 張、聯集剛好 4 張）。
  - 內容：`test/data/core_loop/kyoto_night_catalog_test.dart` 把真卡表餵進同一個 audit。改卡表會紅，**而且紅在正確的地方**。
  - REQ-A1-02 的內容不變式、AC-A1-6.5 一併放在這裡。
- **窮舉，不得抽樣**。窮舉域逐條寫明：

  | AC | 窮舉域 | 量級／計算式 |
  |---|---|---|
  | AC-A1-2.5 / 6.8b | 最終可達池 n 張 × 5 哲學的全部合法 3／4 槽 | `5 × (2P(n,3) + P(n,4))`；n=16 時 252,000 |
  | AC-A1-3.6 | 全卡表中 m 張 `riskLevel >= 3` 素材 × 5 哲學的全部合法 3／4 槽 | `5 × (2P(m,3) + P(m,4))` |
  | AC-A1-5.1 | 最終可達池全部 6 張手牌 × 5 哲學；每手牌保留全部最佳解 | `5 × C(n,6)` 組，每組 600 行程；n=16 時 40,040 組／24,024,000 次評分 |
  | AC-A1-5.4 | `budgetWorker` × 最終可達池 × 5 哲學的全部合法行程 | 與 AC-A1-2.5 共用同一批 252,000 筆結果，不另抽樣 |
  | AC-A1-6.4 | 兩位客戶 × 最終可達池 × 5 哲學的全部合法行程 | n=16 時 504,000 筆；兩個評級集合皆須非空 |
  | AC-A1-6.8a | 全 32 張卡 × 5 哲學的全部合法 3／4 槽，不按哲學過濾 | 4,612,800 個 `(哲學, 行程)` 配對 |
  | AC-A1-6.9 | 全 32 張卡、混亂冒險、至少一組高風險相鄰對的全部合法行程 | 自每哲學 922,560 個合法行程過濾；不得只驗最高熱度解 |

  AC-A1-6.8 是**最大值**斷言、AC-A1-2.5 是**分佈**斷言、AC-A1-5.1 還要求保留全部平手。抽樣等於改弱命題。若執行時間過長，可快取同一行程統計，或使用能證明不改變母體／最佳解／平手集合的剪枝；不得抽樣。
- 架構測試維持現有五條，不因本次改動放寬。
- 每個行為改動強制 **RED → GREEN → REFACTOR**。每個 commit 前依序跑 codegen、受影響測試、`flutter analyze`、`flutter test`；任一項未綠不得提交。

### 既有測試的更新紀律（貫穿全程，非單一任務）

**每個任務自己收掉它弄紅的測試，每個 commit 必須全綠。** 不得把期望值更新推到最後 —— 否則測試套件會從階段一中段一路紅到結尾，中間所有任務都失去「跑全綠」這個收口訊號，而 TDD 的 RED→GREEN 正是靠它運作。

可機械檢查的五條：

1. **授權來源**：每條期望值變更，commit body 須寫「舊值 → 新值 → 授權它的 REQ/AC 編號」。找不到 SPEC 條文授權的，不准改。
2. **禁止的具體變形**（可 grep）：`equals(x)` → `greaterThan`/`isNotNull`/`isA`；`closeTo` 容差變大；把硬編碼期望值換成由被測程式自己算出的值（自我實現斷言，最隱蔽）；`expect` 被刪但測試保留；`test(...)` 加 `skip:`。
3. **`expect` 淨數不得下降**：逐檔 `grep -c 'expect('` 比對，下降須說明。
4. **刪除測試的交接條款**：寫出「它原本保護哪個不變量」與「該不變量現在由哪條新測試承接」。承接不到就不能刪。
5. **既有期望值分兩步**：新增行為仍須先寫 RED 測試；開始改實作後，第一輪不得同步修改**既有測試的期望值**，先跑全套記下完整紅燈清單，再逐條依授權更新。**預期會紅卻沒紅的既有測試本身就可疑** —— 代表它沒在測它宣稱的東西。

---

## 6. 風險

1. **D4+D5+D6 聯立可行域為空**　最高風險點。先複驗搜尋腳本、候選範圍、完整合法域與平手集合；確認空域後回報並退回 SPEC，不得硬選。
2. **AC-A1-6.8a/6.8b 達不到**　處置順序（**不得跳步**）：
   1. 固定參數，調 T11 可達子集／POI 佈局；
   2. 回到 D4/D5/D6/D10 已通過全卡表閘門的候選集合換點，重跑 6.8a 後再選池；
   3. **調整 SPEC 附錄 A.1 的標籤** —— 實證上最有效的槓桿，v5 本身就是這麼修好的（午夜探索改排斥 `#拉車`，卡集重疊 0.33 → 0.11）；
   4. 最後才放寬門檻，且須說明放寬後如何保住 Rule 26。**放寬到 20 分等於允許「一家永遠 Perfect、另一家永遠 Pass」**（網紅分級 Perfect ≥90 / Pass ≥70），那正是這條 AC 要擋的東西。
   - **任何情況下都不得為混亂冒險以外的哲學開規則特例。**
3. **圖資解耦或 GPS 凍結失守**　以可判定護欄驗收：①`universal_overworld_game.dart`、`map_manifest.dart`、`PoiMarker`、`taiwan_map_manifest.dart` 與 GPS pipeline diff 為空；②`DistrictAttraction` 只允許新增京都採集用可選像素欄位，既有公尺欄位與 `toPoiMarker()` 語意不變；③`manifest_geometry_check.dart` 與三組 AC-18.3 測試不改弱；④京都特定資料只落在 manifest／data DLC；⑤production bootstrap 同時注入京都 manifest 與 resolver。
4. **存檔相容性**　`curator_event_replay.dart:33-45` 以**字串**比對裝備種類（`'sneakers'`/`'camera'`/`'waistBag'`），比不到即拋 `FormatException`。**`EquipmentType` 的 enum 名稱在本次凍結。** 價格與佣金係數的改動是安全的（歷史事件的 `cost`/`earnedCoins` 存在 payload，重播拿當時的值），但須補一條「舊格式日誌重播」的回歸測試。

---

## 7. 不做的事

- 不新增抽象（見 §2）。
- 不做微動作（Runner / Snapshot）。
- **不碰台灣圖資與 GPS 管線** —— 凍結。像素觸發只在 `DistrictAttraction` **新增可選欄位**；不修改 `PoiMarker`、既有公尺欄位、`map_manifest.dart`、`manifest_geometry_check.dart`、台灣 manifest 的 40 個字面值，不移除 `metersPerPixelAt`。
- 不做事件日誌壓縮。
- 不為混亂冒險以外的哲學開規則特例。
- 不引入新套件（含 `package:test`）。

---

## 8. 帶出本次範圍的待辦（記錄，不施工）

- **S5**：`lastPersistError` / `persistFailureCount` 在 `lib/` 內零讀者，存檔失敗對玩家仍是靜默的。提示形式是產品決策，但不宜無限期掛著 —— 玩家的金幣靜默消失，與沒修是一樣的體感。
- **CLAUDE.md §0 過期**：`dart test test/domain/` 不可用；「316 passed」實為 383。
