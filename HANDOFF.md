# HANDOFF — 交接紀錄

**最後更新**：2026-09-12 上午
**分支**：`feature/mvp-amendment-01`
**上一份交接**：停在 2026-09-07 任務 C 階段，已整份汰換。

---

## 0. 三十秒版

本次會話做了四件事：

1. **解除一條擋住所有動畫的規格禁令** —— `SPEC_MVP_CAUSAL_FEEDBACK.md` §5.3 原本禁止骨骼／粒子動畫，已撤銷（v6）。
2. **寫出 M5 快門微動作 SPEC**，經**兩輪雙軌覆核**（企劃＋工程），v1 → v2，目前 **v2 待改為 v3**。
3. **跑了全母體搜尋**取得三態幅度的實證數據，推翻了 v2 的初始幅度（差一個數量級）。
4. **確立勳章系統構想**，排在 M5 之後，尚未寫成文件。

**下一步**：出 M5 SPEC v3（材料齊備，見 §3），然後寫勳章提案文件（見 §5）。

---

## 1. 版控狀態

```
456f6b2 test(ui): prove each causal code travels from the rules to the screen
239724e docs(spec): rewrite micro-action spec after dual-track review     ← M5 SPEC v2
188fc38 feat(ui): stop the settlement panel from misreporting its own math
ed29238 feat(ui): show the assigned client reacting live and open the codex on tap
66f0629 docs(spec): add micro-action shutter QTE spec for milestone M5    ← M5 SPEC v1
3bc8fb8 feat(ui): replace editing phase readouts with ordinal causal symbols
2495b9d feat(state): carry culprit slot focus across the tweak round trip
128400b docs: judge build status from git log, not document headers
9c2bd50 docs(spec): mark amendment 01 completed and permit engine-native animations
```

**未進版控**：

```
?? test/analysis/micro_action_amplitude_search_test.dart   ← 幅度搜尋腳本，見 §4
?? assets/images/guide_*_generated.png (18 張，仍在增加)    ← 角色素材，見 §6
?? lib/domain/core_loop/models/tour_time_of_day.dart       ← 並行 agent 的時段光照
?? lib/game/components/time_of_day_lighting_component.dart
```

**注意**：本次會話期間有**另一個 agent 並行施工**，上列 `feat(ui)` / `feat(state)` commit 由它產出。它先做因果可視化（`lib/ui/core_loop/`、`lib/state/core_loop/`），交接當下已轉向**時段光照**（未進版控的 `lib/domain/core_loop/models/tour_time_of_day.dart`、`lib/game/components/time_of_day_lighting_component.dart` 與其測試），並同時在產出角色素材（見 §6）。**動 `lib/` 之前先確認它是否仍在跑。**

---

## 2. 已完成且已 commit

### 2.1 動畫禁令解除（commit `9c2bd50`）

`SPEC_MVP_CAUSAL_FEEDBACK.md` v5 §5 第 3 款原文：

> **禁止骨骼／粒子動畫**：表情以靜態圖示切換呈現，不引入新套件（CLAUDE.md §6）。

該款以「不引入新套件」為由，連帶禁止了**不需要任何新套件**的表現手法（Flutter `AnimationController`/`Tween`、Flame `Effect`/`ParticleSystemComponent`），是整個專案視覺靜態化的制度來源。已撤銷並改為明確區分：新增相依套件仍禁止，引擎內建動畫能力開放。骨骼動畫（Spine／Rive）因確實需要新套件，仍不在範圍。

同時修正兩處過期檔頭：`SPEC_MVP_AMENDMENT_01.md`（「v7 草案待覆核」→ 實為已驗收）、`SPEC_MVP_CAUSAL_FEEDBACK.md`（「待 G4 清償後實作」→ 實作中）。

### 2.2 `CLAUDE.md` 新增「文件檔頭視為可能過期」（commit `128400b`）

放在 §7 之後。核心：**判斷施工狀態一律以 `git log` 與驗收報告為準，文件自述的狀態行不算證據。** 判讀順序 `git log -- <spec>` → `*_VERIFICATION.md` 結論節 → 程式碼 → 最後才是檔頭。附帶「規格沒寫 ≠ 沒規劃」。

### 2.3 M5 SPEC v1 → v2（commit `66f0629` → `239724e`）

`SPEC_MVP_MICRO_ACTION.md`。目前檔案內容是 **v2**，狀態 `Draft v2 — 待覆核`。

---

## 3. M5 SPEC：v3 要做什麼（主要待辦）

### 3.1 已定案的設計裁決（v1/v2 使用者逐題裁決，不要重開）

| 議題 | 裁決 |
|---|---|
| 三態影響哪一側 | **產出側**（素材品質），成本固定 |
| 更好的卡怎麼來 | **每張卡手寫三版本**（`name` 三版相同，只有 `description` 不同） |
| Runner 與 Snapshot | 本里程碑**只做快門**，Runner 延後 |
| 快門玩法 | **收縮準心**；絕景加構圖，**單一手勢**（按住取景、放開快門） |
| 跳過與重試 | **皆不可**，無障礙由難度承接 |
| 難度 | 三檔 `tourist` 觀光客／`photographer` 攝影師／`decisiveMoment` 決定性瞬間 |
| 難度是否影響局內 | **是**（(a) 案）—— 難度放大三態幅度 |
| 事件範圍 | **縮小**，不建單局事件溯源管線 |
| 台灣卡表 | **descope**，只做京都 32 張 → 96 張、64 段新文案 |

### 3.2 v3 要寫進去的三個新裁決（本次會話已定，尚未寫入檔案）

**① 中斷改「判 `normal` + 每局一次配額」，不做凍結。**
v2 寫的是凍結續跑。改掉的理由有二：企劃指出凍結會造成必輸局面（`decisiveMoment` 在 760 ms 被打斷，回前景只剩 40 ms，低於人類反應時間）；工程指出現有 `lib/core/time/` 的 `Clock.elapsed` 是 `Stopwatch`、**沒有暫停能力**，凍結要嘛做不到、要嘛得擴張未核准的抽象。
判 `normal` 同時解掉兩邊：它劣於 `perfect` 故無刷取誘因，優於 `failed` 故真實來電不受罰，**每局一次配額**（第二次起判 `failed`）擋住濫用。附帶好處是**消滅了工程 P0-1 的暫停時長扣除問題**。
須補 AC：**任何中斷序列都不得提高三態結果的期望值。**

**② 節奏預算重寫。**
v2 引的「野外段基準 240 秒」是**誤引** —— `AC-A1-4.1` 是可達性測試（240 秒內能採到 6 個 POI），不是時間預算。
改為兩條可驗的東西：單次 QTE 儀式上限 = 動畫全長 + 1200 ms（轉場與浮字）；以 Lv1 體力上界 **16 次**（`gatheringHpCost = riskLevel × 6`，100 HP ÷ 6）計，總邏輯時間 ≤ **60 秒**。
並把 `tourist` 動畫全長從 2600 ms 壓到 **2000 ms**（`t_吻合` 1400 / `W_p` 800）。壓縮後 `(2.0 + 1.2) × 16 = 51.2 s`，守得住；順帶讓 `tourist` 的 `normal` 態真的存在（原本 `W_p` 佔全長 40%，normal 幾乎不可能出現）。

**③ 幅度依搜尋數據定案**（見 §4）：

| 難度 | 一般卡 | 絕景 | 動畫全長 | `t_吻合` | `W_p` | `W_n` |
|---|---|---|---|---|---|---|
| `tourist` | ±2 | ±3 | 2000 ms | 1400 ms | 800 ms | 不設上限 |
| `photographer` | ±3 | ±5 | 1600 ms | 1100 ms | 240 ms | 720 ms |
| `decisiveMoment` | ±4 | ±7 | 1200 ms | 800 ms | 120 ms | 300 ms |

**v2 寫的 ±12 / ±20 差了一個數量級，必須改。**

### 3.3 兩軌覆核的待修清單

第二輪雙軌覆核（企劃 8 條 P0、工程 4 條 P0）。**除 §3.2 已裁決的三條外**，剩下這些要在 v3 處理：

**工程軌 P0**

- **時基錨定**：`t_吻合` 是幀累加時間軸、`t_按下` 若取 `PointerEvent.timeStamp` 是自由奔跑時戳，**兩者相減沒有定義**。須明訂單一權威時間軸與換算式。（裁決①拿掉凍結後，暫停扣除的部分自動消失，只剩錨定要寫。）
- **難度持久化的載體被 v2 自己封死**：v2 寫「不為 `CuratorSaveData` 加欄位」，但它是重播的唯一投影 —— 不加欄位就沒有東西承載「上次選的難度」，AC-M5-5.3 成立不了。正解是**新增 `difficultySelected` 事件型別 `並` 在 `CuratorSaveData` 加 `lastDifficulty` 投影欄位**；`saveVersion` 不動（它不參與序列化）。往沒有 `toJson` 的投影型別加欄位不是 schema 變更。
- **§5.2 的前置 bugfix 寫錯層且漏洞更嚴重**（見 §7）。

**工程軌 P1**（逐條都要改）

- `AC-M5-1.8` 是空測（參數表根本不會有那兩個參數）→ 改靜態檢查：判定模組原始碼不出現 `riskLevel` / `cameraLevel`。
- `AC-M5-5.5` 無完美率模型，算不出來 → SPEC 須定義**參考玩家模型**：按下誤差 $\sim N(0, \sigma)$，$\sigma$ 取三檔固定值（建議 120 / 200 / 300 ms），AC 對三個 $\sigma$ 皆須成立。此模型同時讓經濟 AC 與支配性 AC 可自動化。
- `AC-M5-9.2` 母體未定義，最壞規模跑不完 → 須寫死：**16-POI 子集**（`reachablePool.take(16)`）、每手 6 張、3 槽、**全域齊一態**。用完整 32 張池是 $\binom{32}{6}=906{,}192$，約 113 倍、跑 8 小時。
- **三態值掛在哪個型別上仍未定**（v1 唯一沒關乾淨的老洞）→ SPEC 不需給設計，但要給**契約約束**：「三態值不得改變 `TravelMaterial` 的相等語意」「不得改動 `MaterialInventory` 與 `TimelineItinerary` 的元素型別」。
- `AC-M5-9.1` 只在相機 Lv3 成立（倍率 1.5 / 1.8 / 2.2；`12×1.5−12 = 6 < 12` 必紅）→ 明寫 `cameraLevel = 3`，或改門檻為「差值 > 0 且隨等級單調遞增」。
- `AC-M5-12.2` 分母未定，**SPEC 自己的範例三連過不了其中一種讀法**（實測 normal 28 / perfect 41 / failed 39 字，短版分母 46.4% > 40%）→ 明訂 `max/min ≤ 1.4`。
- `REQ-M5-03.4` 規定了機制而非性質（`CLAUDE.md` §1 禁止 spec 寫演算法）→ 改為性質陳述：「構圖偏差的判定不得受玩家縮放狀態影響；QTE 結束後相機狀態須與進入前一致」。另注意 `CameraFollow` **沒有存／還原 API**，`recenter()` 會清掉 `_frozenCenter` 等狀態。
- **快門時戳須取自原始指標事件，不得取自手勢識別器的 details** —— `TapUpDetails` 與 `DragEndDetails` **都沒有時戳**，只有 `DragUpdateDetails.sourceTimeStamp` 與 `PointerEvent.timeStamp` 帶得到。走 `onPanEnd` / Flame `DragCallbacks` 會在框架邊界弄丟時戳。可測性成立：`TestGesture.up(timeStamp:)` 可指定，走 `Listener.onPointerUp` 能寫決定性測試。
- **§5 須增列「擷取 32 張 `normal` golden fixture」為第 1 條**，早於一切卡表改動 —— 否則文案回填後基線就髒了。

**企劃軌 P0**

- **§1.2.4 設計意圖已被自己的修改證偽** → `riskLevel` 解耦後，任一非絕景卡的期望熱度是 $H + (p_p - p_f)\Delta$，一個**與路線無關的常數加項**，不改變任何兩條路線的排序。必須改寫或刪除（把已證偽的斷言留在「不得順手改掉」清單裡最糟）。
- **快門獎金改為封頂「提交行程中的 `perfect` 張數」（≤ 4）**，而非採集次數。v2 的算法獎勵「跑滿 32 個 POI、全採便宜卡」—— 行程品質最差的路線。單價與倍率建議 **40 金 × (0.5 / 1.0 / 1.5)**，並補 AC：**加入獎金後 `AC-A1-5.4` 仍須落在 6~10 局**。退件局比照故事折現打 30%。
- **節奏的 POI 數 16 → 32**（見 §8 的錯誤紀錄），並改以體力上界推導次數；`AC-M5-10.2` 改驗**最壞情況**，不要綁 `AC-A1-4.1` 的 6 次基準路徑（那是最友善案例，會在真實破綻存在時亮綠燈）。
- **新增 AC：以三態混合池為母體重跑 Amendment 01 的分佈 AC**（`AC-A1-5.1` 黃金槽 ≤ 30%、`6.3a/b`、`6.4`、`6.8a/b`）。目前三態變體不進扁平卡表（`AC-M5-2.7` 刻意保護），代價是那些 AC **全部只驗 `normal` 版**，玩家實際經歷的混合牌組從未被檢查。
  **特別注意 `AC-A1-5.1`**：`perfect` 嚴格優於其他版本 × 黃昏槽有倍率 = **強支配解**，而該 AC 正是要把強支配解壓在 30% 以下。v2 §1.2.1 把這件事當價值賣點，**兩份文件對同一件事結論相反**。須降級為「失手卡的損害控制」。

**企劃軌 P1**

- **§7 已知限制 1 的推論無效**（見 §8），須用 §4 的實測數據改寫。
- `AC-M5-9.1` / `AC-M5-9.3` **都是恆真式**。9.1：$0.5(H+12) > 12 \iff H > 12$，卡表最低 20 → 恆真。9.3：`AC-A1-6.8a` 比各哲學最佳解，最佳解一律全 `perfect`，五家同加同一量 → 極差不變。兩條都要重寫。
- **絕景單一手勢的三個手感破口**：(i) 取景框跟隨手指 → 判定瞬間手指正好蓋住要盯的環，**結構性遮擋**，須把環改成不繞標的（例如取景框邊框發光）；(ii) lift-off 座標會漂移數 px，`d_c` 須取**放開前約 50 ms** 的取樣或最後 N 筆中位數；(iii) 「取兩項較差者」使絕景失手率是一般卡的 7.8 倍 → 改為**構圖最多降一階**（構圖 `failed` + 時機 `perfect` → `normal`）。
- **快門獎金缺持久化與呈現規格**：必須折進 `runSettled` 的 `earnedCoins`（`curator_event_replay.dart` 只累加該欄位），並補 AC 驗證重播後金幣總額相符；另須在結算面板獨立成行 —— 它是社畜局玩家**唯一**感知得到的技巧回饋通道，呈現是承重的不是裝飾。

**P2 選要的**：`AppLifecycleState.inactive` 的涵蓋要與定位層策略區隔（`main.dart:182` 對 `inactive` 刻意 `break`）；`AC-M5-3.7` 應寫 `tester.binding.handleAppLifecycleStateChanged`（實例方法）；`AC-M5-3.5` 須明寫「以 `LocationSource` 注入新座標」（QTE 期間引擎暫停，方向鍵不會動）；`AC-M5-1.7` 禁 `dart:math` 過度（連 `min`/`max` 一起擋），改行為 AC；三態 UI 徽章的規格（腰包抽屜／4 槽卡面／結算歸因三處）完全沒寫。

### 3.4 設計語言的轉向（**使用者已同意，v3 必須貫徹**）

搜尋數據證明這個機制**只有懲罰、沒有獎勵**（見 §4）。已同意把設計語言從「拍得好有獎勵」改成「拍壞了有懲罰」：

> `normal` 不是「普通」，是**這張素材原本的價值**；`perfect` 是少數情況下的額外收穫；`failed` 是你搞砸了。

配套：文案契約的重心反轉 —— **`failed` 版是主力**（最常看到、最需要變化），`perfect` 版是彩蛋。這會影響 §7 限制 3 的撰寫成本評估。

---

## 4. 幅度搜尋的實測數據（v3 的 AC-M5-9.2 依據）

腳本：`test/analysis/micro_action_amplitude_search_test.dart`（**未 commit**）。母體與 `AC-A1-5.1` 同基準：16-POI 子集、8,008 手 × 5 哲學 × 2 客戶 = 40,040 樣本、相機 Lv.1。排列以 `normal` 態的最佳解決定（排列選擇與幅度無關），再在同一排列上評估三態。**執行 28 秒。**

```
[社畜] ±2/±3   三態相異 0.0%  完全同分 73.3%  P=N 100.0%  F=N 73.4%  極差 mean 6.7  med 0  p95 25 max 25
[社畜] ±3/±5   三態相異 0.0%  完全同分 62.9%  P=N  99.8%  F=N 63.1%  極差 mean 9.3  med 0  p95 25 max 25
[社畜] ±4/±7   三態相異 0.0%  完全同分 53.3%  P=N  99.7%  F=N 53.6%  極差 mean 11.7 med 0  p95 25 max 25
[社畜] ±6/±10  三態相異 0.0%  完全同分 38.1%  P=N  99.2%  F=N 38.9%  極差 mean 15.5 med 25 p95 25 max 25
[社畜] ±8/±13  三態相異 0.0%  完全同分 27.9%  P=N  98.7%  F=N 29.2%  極差 mean 18.0 med 25 p95 25 max 25
[社畜] ±12/±20 三態相異 0.0%  完全同分 10.4%  P=N  97.2%  F=N 13.2%  極差 mean 22.4 med 25 p95 25 max 25
[社畜] ±20/±33 三態相異 0.0%  完全同分  0.1%  P=N  96.2%  F=N  3.8%  極差 mean 25.0 med 25 p95 25 max 25

[網紅] ±2/±3   三態相異 40.3%  完全同分 37.0%  P=N 59.7%  F=N 37.0%  極差 mean  3.4 med  3 p95  8 max  9
[網紅] ±3/±5   三態相異 40.3%  完全同分 25.4%  P=N 59.7%  F=N 25.4%  極差 mean  5.9 med  5 p95 13 max 15
[網紅] ±4/±7   三態相異 40.3%  完全同分 17.6%  P=N 59.7%  F=N 17.6%  極差 mean  8.5 med  8 p95 18 max 20
[網紅] ±6/±10  三態相異 40.3%  完全同分  8.6%  P=N 59.7%  F=N  8.6%  極差 mean 12.9 med 12 p95 24 max 28
[網紅] ±8/±13  三態相異 40.3%  完全同分  4.1%  P=N 59.7%  F=N  4.1%  極差 mean 17.3 med 17 p95 30 max 36
[網紅] ±12/±20 三態相異 40.3%  完全同分  1.2%  P=N 59.7%  F=N  1.2%  極差 mean 27.2 med 26 p95 42 max 54
[網紅] ±20/±33 三態相異 40.3%  完全同分  0.0%  P=N 59.7%  F=N  0.0%  極差 mean 45.5 med 44 p95 61 max 75
```

### 四個結論

1. **幅度落點在 ±3/±5**。網紅端極差 p95 = 13、max = 15，剛好壓在哲學軸（`AC-A1-6.8a` 的五哲學極差 ≤ 15 分）之內。`±4` 的 p95 18 就超了。**v2 的 ±12 是哲學軸的 1.8~2.8 倍，會讓手速蓋過所有編排與哲學。**

2. **社畜端「三態相異」恆為 0.0%**，所有幅度皆然。熱度只透過 `totalHype < boredomThreshold(168)` 的二元門檻進入，**永遠是 0 或 25，從不漸進**。幅度只改變遇到斷崖的頻率。

3. **網紅端 `P=N` 恆為 59.7%**，所有幅度皆然 —— 那是 `.clamp(0, 100)`，**六成手牌在 `normal` 態已經滿分**，`perfect` 不可能有作用。

4. 合起來：**「完美」在 59.7% 的網紅局與約 99% 的社畜局什麼都不做。這個機制只有懲罰，沒有獎勵。** 這不是調參問題，在「只動素材、不動引擎」的前提下無解（`hypeValue` 撞天花板、`storyValue` 規模不夠 —— 範圍 1~5、`×5` 換金幣，四張卡全動 ±1 只值 ±20 金，對照 `baseCommission` 1000/1500 是雜訊、`themeValue` 已裁決凍結）。

**這個第 4 點就是勳章構想的起因。**

---

## 5. 勳章系統（構想已定，文件未寫）

**使用者裁決**：勳章第一版**只做收集**；「給局外資源（金幣、解鎖）」與「解鎖內容（新哲學、新裝備、新城市）」**都可以加在後面**。

**排程**：不塞進 M5。理由是 M5 已兩輪覆核未過、桌上還有十幾條 P0，再加子系統會讓「快門手感成不成立」與「勳章設計對不對」混在一起無法歸因；且**勳章等 M5 落地會設計得更好** —— `perfect` 的實際達成率要等實機調完難度參數才知道，那個數字直接決定「一局全完美」該是家常便飯還是稀有成就。

```
M5  快門微動作 → M6 勳章系統 → M7 Runner 衝刺
```

**三條會框住設計的既有約束**：

| 約束 | 影響 |
|---|---|
| 第一版禁止排行榜／好友／雲端／**遙測**，且不得提前埋鉤子（`CROSS_CUTTING_CONSTRAINTS.md`） | 勳章只能是**單機、給自己看的**。不能有「全球 3% 玩家擁有」這類東西 |
| **單局事件溯源管線不存在** | 「單局過程中」的條件無法重播 |
| 重播必須決定性（CC-3） | 判定不得依賴當下時間或亂數 |

**條件的三個類別**（第二條約束推導出的鐵律：**條件必須能在結算那一刻算出來，或由結算數字累加得出**）：

- **① 單局成就 —— 可行**。結算當下 run state 有的：4 槽位（含三態）、哲學、難度、客戶、滿意度、評等、`gatheredPoiIds`。
  例：「以決定性瞬間難度通關」「4 槽全部完美」「五張絕景同一局全部完美」
- **② 累計成就 —— 可行**。只要結算事件 payload 帶出彙總數字，重播就能累加終身計數（`CuratorSaveData` 現在就是這樣累積金幣與通關數）。
  例：「累計 100 張完美快門」「五種哲學各通關一次」「京都 32 個 POI 全部踩過」
- **③ 單局過程中的序列條件 —— 不可行**。例：「連續 10 次完美不失手」。需要記住採集順序，而單局狀態全在記憶體。除非在結算時壓成一個數字（如「本局最長連續完美數」）帶進 payload —— 那就退化成 ②。

**框架的抽象邊界**（`CLAUDE.md` §3）：會變的軸是**條目本身**（未來一定會加），不是判定機制。所以框架該薄到只擋住那條軸：**一個條件表、一個發放事件、一個持有清單**。不做外掛式的成就引擎。

**待辦**：開 `SPEC_MVP_BADGES_PROPOSAL.md`（提案，不是 SPEC，比照 `TASK_D_LOCAL_TIER_PROPOSAL.md` 的格式），把上述記下來。另在 M5 v3 的 §7 已知限制加**一句話**註明「`perfect` 的長期回報預期由勳章系統承接」——**不加任何欄位、不改任何介面**。

---

## 6. 角色素材（本次會話期間出現，未進版控）

素材缺口原本是 M6 Runner 的硬阻塞（`PlayerComponent` 是 17 行的 `CircleComponent` 紅圓，沒有任何角色 sprite）。現在 `assets/images/` 下已有：

```
共 18 張，分三類（阿導與女性版各一套）：

  大世界行走表                                   2 張  例 1448x1086
  動作表                                      2 張  例 1246x1262
  對話立繪（含 8bit、半身、怒／笑／哀等表情變體）               14 張  例 1024x1536
```

**數量仍在增加中**（交接當下 8 → 18 張），清單以 `ls assets/images/guide_*` 為準。

**尚未做的事**：

1. **切圖與 sheet 契約**。這些是大圖，不是可直接播放的 sprite sheet。現有前例是 `ocean_wave_sheet.png` = **48×16**（3 frame × 16×16），播放器範本是 `ocean_waves_component.dart`（149 行，含 `update(dt)` + frame 輪播 + 相位錯開）。
2. **尺寸決策**。現行小人是 `CircleComponent(radius: 8)` = 直徑 16 px；`TASK_D_LOCAL_TIER_PROPOSAL.md:236` 的分析假設角色為 **24 螢幕像素**。
3. `pubspec.yaml` **不用改** —— 宣告的是目錄 `assets/images/`，丟檔進去就能用。
4. M5 **不需要**角色 sprite（快門 QTE 是取景框與準心，幾何 UI）。這是 M6/M7 的前置。

---

## 7. 一條獨立於 M5 的資料遺失 bug（**建議優先修，獨立 commit**）

重播遇未知事件型別會滅掉玩家存檔。目前未觸發（4 種事件從沒變過），但 M5 要新增 `difficultySelected` 會**首次踩到**。

**兩段路徑，第二段比第一段嚴重**：

1. `lib/domain/core_loop/events/curator_event.dart:89` —— `CuratorEvent.fromJson` 對未知 `type` 直接 `throw FormatException`。而 `LocalPersistenceRepository.loadEvents` 接到解析失敗會把**整份日誌搬去 `.bak` 並回傳空**，`loadSave` 於是重建全新身分 → **金幣與裝備歸零**。
   （注意：拋出點在**解析**不在重播；`replayCuratorEvents` 的 `switch` 是 enum 窮舉，未知型別根本無法被表示。M5 SPEC v2 的 §5.2 寫「重播對未知事件型別採忽略」是**寫錯層**，照字面做會改錯檔案。）

2. **更嚴重**：即使把解析改成「跳過未知事件」，`_doAppend`（`local_persistence_repository.dart:69-80`）的追加是「`loadEvents()` 讀出 → 合併 → **整份寫回**」：

   ```dart
   final existing = await loadEvents();
   var nextSeq = existing.isEmpty ? 0 : existing.last.seq;
   final sealed = [for (final draft in drafts) draft.seal(++nextSeq)];
   final merged = [...existing, ...sealed];
   await prefs.setString(eventLogKey, jsonEncode(merged.map((e) => e.toJson()).toList()));
   ```

   被跳過的未知事件**不在 `existing` 裡，於是在下一次追加時被永久抹掉**；且 `nextSeq` 會與被抹掉那些事件的 seq **撞號**。

**正解**：解析層對未知型別採**原文保留**（unknown-event 佔位，保留 `seq` 與原 JSON），重播忽略之，追加時原樣寫回。這是 append-only 日誌前向相容的標準解法。只改第一段等於修一半，滅檔換個形式再來。

另一條同類的既有缺陷（M5 §5.6 已列為前置條件，同樣建議獨立 commit）：`curator_run_controller.gatherPoi()` 會用 `nearestGatherablePoi()` **重算並覆蓋傳入的 `poiId`**，且沒有 `replaceGatheredPoi()` 那樣的 `expectedPoiId` 防護。插入 QTE 後，「按下取材」與「實際呼叫 domain」之間多了 1.2~2.0 秒，期間位置持續更新 → 玩家對 A 景點做的 QTE 會套用到 B 景點的素材上。

---

## 8. 本次會話的錯誤紀錄（同一形狀重複四次，接手者請引以為戒）

`CLAUDE.md` 新增的那條規則就是為此而寫。四次都是**讀到一個數字／狀態就拿來用，沒確認它是什麼語意**：

| # | 錯誤 | 真相 |
|---|---|---|
| 1 | 讀 `SPEC_MVP_AMENDMENT_01.md` 檔頭「v7 草案，待覆核」，據此判斷微動作的閘門未開 | 檔頭過期。T0~T14 共 16 個 commit 早已執行並驗收（`MVP_AMENDMENT_01_VERIFICATION.md` §6、commit `0b9a30a`） |
| 2 | SPEC v1 三處寫 `ΔHP = 10 + riskLevel × 2`，抄自 `SPEC_MVP_POI_GATHERING.md` | 該公式已被 Amendment 01 D8 廢除。現行是 `gatheringHpCost() = riskLevel × 6`（`curator_run_state.dart:17`）。照字面實作的 AC 會當場紅 |
| 3 | 用 `grep -c "isSpotlight: true"` 得到京都絕景 6 張 | 第 12 行是**註解**提到該字串。實為 **5 張** |
| 4 | 把 `AC-A1-4.4` 的 `>= 16` 當成可達 POI 的實際值 | 那是**產品下限**。同一條測試緊接著 `expect(reachablePool.length, 32)`。真正把 QTE 次數壓在 16 附近的是 **HP**（100 ÷ 6），不是 POI 數 |

另有一次**推論**錯誤（性質不同但同樣承重）：SPEC v2 §7 限制 1 寫「反無聊觸發率 24.70%，**故**約四分之三的社畜局三態一分不動」。那個「故」不成立 —— 24.70% 是 `totalHype < 168` 的行程比例，而三態改變社畜結果的條件是 `normal` 態的 `totalHype` 落在門檻 ±Δ 的帶內。§4 的實測顯示在 ±3 幅度下**完全同分只有 62.9%**（不是 75%），且在 ±12 下只剩 10.4% —— 方向與我寫的相反。**未經驗算的推論不要放進論證鏈的承重位置。**

---

## 9. 覆核流程的操作筆記

雙軌覆核（企劃軌＋工程軌並行，各自獨立不互通）在本次會話**兩輪都有效**：

- 第一輪：兩軌**各自獨立**算出同一個致命問題（三態對結算不可見）。這種收斂度是強訊號。
- 第二輪：工程軌 4 條 P0、企劃軌 8 條，重疊 2 條，分工乾淨（工程抓架構與可測性，企劃抓數值與體驗）。

**紀律**：agent 報告一律**逐項複驗再採信**。本次會話複驗了十餘條承重主張，**全部屬實** —— 但正因為每條都查過，才敢把「絕景 5 張」「可達 POI 32」這兩條反過來推翻我自己先前報給使用者的數字。

**給覆核 agent 的 prompt 要點**（本次有效的寫法）：明確給出要驗證的前一輪問題清單、要求「標示哪些已關閉／哪些沒關乾淨／哪些是新引入」、要求「實際讀程式碼驗證，不要憑印象」、要求算式要算出數字、並明確禁止改檔案。

---

## 10. 接手第一步

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze            # 須 0 errors / 0 warnings
flutter test               # 註：CLAUDE.md §0 的「316 passed」已過期，實測 462+
```

然後讀 `SPEC_MVP_MICRO_ACTION.md`（v2），對照本文 §3 出 v3。§4 的數據直接用，不必重跑；要重跑的話腳本在 `test/analysis/`，28 秒。
