# PLAN — SPEC MVP 增修草案 01 施工計劃

**狀態**：v1 草案，待覆核
**對應 SPEC**：`SPEC_MVP_AMENDMENT_01.md` v5
**前提**：SPEC v5 覆核通過後才動工。本文件不含實作碼。

---

## 0. 這份計劃要解決什麼

SPEC v5 有 14 條 REQ、約 40 條 AC，但**只約束行為邊界，沒有指定任何數字**。施工的主要風險不是寫不出來，而是：

- 數字彼此夾擠 —— 多條 AC 同時夾住同一個參數（最嚴重的是拉車疲勞：被 AC-A1-6.3 從下、AC-A1-3.6 從上夾住）。順序錯了會反覆推翻。
- 既有 383 條測試中有一批的期望值會改變，必須逐條分辨「該更新期望值」與「斷言被削弱」。
- §4 的京都街區圖資是一整塊新資產，與數值工作相依但可並行。

因此本計劃的核心是**決定順序**，而非任務清單。

---

## 1. 分層落點

| SPEC 條目 | 落點 | 理由 |
|---|---|---|
| REQ-A1-00 標籤詞彙表 | `domain/core_loop/models/travel_philosophy.dart` + `data/core_loop/kyoto_night_catalog.dart` | 哲學標籤是純資料；卡表屬城市 DLC |
| REQ-A1-01 契合度分級 / 正規化 | `domain/core_loop/models/timeline_itinerary.dart`、`travel_philosophy.dart` | 純數值規則 |
| REQ-A1-01b 主題傳導 | `domain/core_loop/review/client_review_engine.dart`、`client_spec.dart` | 同上 |
| REQ-A1-03/04 超支與反無聊 | `client_review_engine.dart`、`client_spec.dart` | 同上 |
| REQ-A1-05 3 槽提交 | `domain/.../timeline_itinerary.dart`（規則）+ `ui/core_loop/`（呈現） | 規則在 domain，UI 只呈現 |
| REQ-A1-06/07 取材尺度 | `game/map_module/manifests/`（新京都 manifest）+ `state/core_loop/curator_run_providers.dart` | 圖資是 DLC；資格判定見 T2 |
| REQ-A1-08/09 裝備與體力 | `domain/core_loop/models/meta_equipment.dart`、`run/curator_run_state.dart` | 純數值規則 |
| REQ-A1-10~13 評分失衡 | `client_review_engine.dart`、`kyoto_night_catalog.dart` | 同上 |
| REQ-A1-14 混亂冒險例外 | `domain/core_loop/models/travel_philosophy.dart`（旗標）+ 兩處消費端 | 見 §2 |

**`domain/` 不得 import `package:flutter` / `package:flame`** 的既有約束不變，本次全部數值工作都落在可用 `dart test` 跑的範圍。

---

## 2. 抽象邊界：本次不新增抽象

依 CLAUDE.md §3，提出新抽象前要能回答「它擋住哪一條已知會變的軸」。逐條檢視：

- **REQ-A1-14 的哲學例外**：看似需要「規則修飾器」之類的機制，**但不要做**。它是 MVP 階段的唯一具名例外（SPEC §7 已釘死），未知的變動軸不存在。做法是在 `TravelPhilosophy` 上加一個具名旗標（語意為「相鄰高風險在 Hype 側視為連段」），由 `client_review_engine` 讀取。一個 enum 欄位，不是一層抽象。
  - 若日後真的擴散到三家以上，屆時再抽 —— 那時才會知道要擋的軸長什麼樣。
- **契合度分級**：是 `TravelPhilosophy` 既有 `evaluateMaterial` 的內部改寫，不新增型別。
- **3 槽提交**：`TimelineItinerary.canSubmit` 的條件放寬 + 連續性檢查，不新增型別。
- **京都街區圖資**：走既有的 `OverworldMapManifest`。**這正是該抽象的第一次真正兌現** —— 換一份 manifest 而引擎不動，若過程中被迫改引擎，表示解耦沒有成立，須回報。

三條核准抽象維持不變，不新增第四條。

---

## 3. 數字決定順序（相依，不可換序）

先決定的會夾住後面的。每一步都要能跑窮舉驗證，不靠手算。

| # | 決定什麼 | 夾住它的 AC | 為何排在這裡 |
|---|---|---|---|
| **D1** | 主題正規化手段（按槽位數平均 vs 總貢獻軟上限） | AC-A1-1.1/1.2 | 決定 3 槽的主題是否天然高於 4 槽，左右 D6 與整個 §3 |
| **D2** | 契合度階梯：命中 1/2/3 個偏好標籤的係數、`themeValue` 如何進入 | AC-A1-1.1/1.2/1.3 | 依賴 D1 的正規化形式 |
| **D3** | `minTheme` 映射與 `themeFactor` 係數 | AC-A1-1.7/1.8 | 依賴 D2 的主題分佈 |
| **D4** | 拉車疲勞量級（Theme 側 −N、Hype 側佔 `targetHype` 的比例） | AC-A1-6.3（下界）× AC-A1-3.6（上界） | **全案最被夾的數字**，兩條必須一起解 |
| **D5** | 絕景係數階梯 0/1/2/3 張 | AC-A1-6.1 | 依賴 D3 的滿意度尺度 |
| **D6** | 純度獎勵量級 | AC-A1-3.2/3.3 | 依賴 D1、D3 |
| **D7** | 超支曲線：Perfect 上界、Rejected 下界 | AC-A1-2.3/2.5 | 依賴 D3（主題佔分改變後預算的相對權重才確定） |
| **D8** | 體力公式 | AC-A1-5.2a/5.2b/5.3 | 與評分模型無相依，可並行於 D1~D7 |
| **D9** | 升級價梯或佣金係數 | AC-A1-5.4 | 依賴 D7（佣金依結果等級） |
| **D10** | 相機 Lv.1 倍率 | AC-A1-5.1 | 依賴 D4（疲勞改變排列最優解） |
| **D11** | Rejected 收入係數 | AC-A1-6.4 | 依賴 D9 |
| **D12** | 八坂之塔加稅值、當局可達 POI 選卡 | AC-A1-6.5、AC-A1-4.4/4.5/4.6 | 依賴 D1~D11 全部（選卡要驗 AC-A1-6.8 的極差） |

**D4 的解法**：先以 D3 定出的滿意度尺度，把 AC-A1-6.3 的下界（一張最低熱度素材 hype 20 的貢獻）與 AC-A1-3.6 的上界（3 槽不得優於 4 槽）換算成同一單位，取交集。若交集為空，回報而非硬選 —— 那表示 SPEC 的兩條 AC 仍然互斥，須退回 SPEC。

---

## 4. 任務拆解

### 階段一：純領域數值（不碰圖資與 UI）

- **T1　標籤詞彙表對齊**　依 SPEC 附錄 A.1 改寫 `travel_philosophy.dart` 的五組偏好／排斥標籤。附 AC-A1-0.1~0.4 的測試（以卡表為輸入的資料驅動測試）。
- **T2　契合度分級與正規化**　D1、D2。改寫 `evaluateMaterial` 與 `timeline_itinerary` 的主題累加。AC-A1-1.1~1.6。
- **T3　主題傳導**　D3。改 `client_review_engine` 的 `themeRatio` 封頂與 `themeFactor`。AC-A1-1.7/1.8。
- **T4　疲勞與連段**　D4 + REQ-A1-14。`TravelPhilosophy` 加具名旗標；Hype 側疲勞對混亂冒險反轉，Theme 側照扣。AC-A1-6.3/6.6/6.7/6.9。
- **T5　3 槽提交**　REQ-A1-05。`canSubmit` 放寬 + 連續性檢查 + 純度獎勵（D6）。AC-A1-3.0~3.6。
- **T6　超支與反無聊**　D7。AC-A1-2.1~2.5。
- **T7　絕景係數**　D5。AC-A1-6.1/6.2。
- **T8　體力與裝備階梯**　D8、D9、D10。AC-A1-5.1~5.4。
- **T9　退件收入**　D11。AC-A1-6.4。
- **T10　功率平衡驗收**　AC-A1-6.8。以全卡表窮舉五家最佳組合，驗極差 ≤15 分。**這是階段一的收口**，不過不得進階段二。

相依：T1 → T2 → T3 → {T4, T6, T7} → T5 → T10；T8、T9 可並行，T9 在 T6 之後。

### 階段二：京都街區圖資（可與階段一並行啟動，但驗收在後）

- **T11　觸發判定改像素**　REQ-A1-06。移除 `metersPerPixel` 換算路徑；採集資格改「只結算最近的一個 POI」。順帶把 `GatheringEligibility` 的規則自 `curator_run_providers.dart` 搬進 `domain/`（純函式，前一輪架構審查已指出它是純數值規則卻住在 Provider 裡）。
- **T12　京都夜間街區 manifest**　新增 manifest，台灣 manifest 原地保留不刪。驗證 `OverworldMapManifest` 抽象成立：引擎碼零改動。
- **T13　可達 POI 選卡**　D12。AC-A1-4.4~4.6。
- **T14　採集節奏實測**　AC-A1-4.1（4 分鐘內 6 次採集）。需模擬移動，非單元測試 —— 以邏輯 tick 驅動的 domain 層模擬完成，不進模擬器。

相依：T11 → T12 → T13 → T14；T13 依賴 T10 的平衡結果。

### 階段三：UI 接上

- **T15　時間線編輯器支援 3 槽**　空槽呈現、連續性限制的提示。
- **T16　Review 呈現純度獎勵與連段**　玩家要看得懂為什麼加分/扣分（Exit Criteria ③）。
- **T17　既有測試期望值更新**　逐條檢視 `test/domain/core_loop/`。**規則：只更新期望值，不得削弱斷言**；若某條測試在新規則下失去意義，刪除並在 commit 說明，不得改成恆真。

---

## 5. 測試策略

- 階段一全部走 `dart test test/domain/`，不需模擬器。
- **資料驅動測試**：AC-A1-0.x、6.5、6.8 的輸入是卡表本身。這些測試須直接讀 `kyoto_night_catalog.dart` 的資料，而非複製一份常數 —— 否則改卡表不會讓測試變紅（這正是本專案反覆踩到的接線盲區）。
- **窮舉測試**：AC-A1-2.5、5.1、6.8 需要窮舉組合。須控制在秒級；必要時以固定抽樣 + 種子。
- 架構測試維持現有五條，不因本次改動放寬。

---

## 6. 風險

1. **D4 無解**　AC-A1-6.3 與 AC-A1-3.6 若在 D3 定出的尺度下交集為空，須退回 SPEC。這是已知的最高風險點。
2. **AC-A1-6.8 不可達**　五家極差 ≤15 分是強約束。若窮舉後達不到，選項是放寬到 20 分或調整 D12 的選卡，**不是**再給某一家開規則特例（SPEC §7 已禁止）。
3. **圖資解耦不成立**　T12 若被迫改引擎碼，表示 `OverworldMapManifest` 沒擋住城市這條軸，須回報而非硬改。
4. **既有測試大量變紅**　預期 T2/T3 會讓 `client_review_engine_test.dart` 與 `timeline_itinerary_test.dart` 多條變紅。這是預期內的期望值更新，但須逐條分辨，T17 的規則不可妥協。

---

## 7. 不做的事

- 不新增抽象（見 §2）。
- 不做微動作（Runner / Snapshot）—— SPEC §7 已排除。
- 不碰台灣圖資與 GPS 管線 —— 凍結，留待 Reality Run 階段。
- 不做事件日誌壓縮 —— 已評估不需要。
- 不為混亂冒險以外的哲學開規則特例。
