# Share Tour — 專案工作規範

以旅行為世界觀的 Luggage Roguelite 手機遊戲。Flutter + Flame + Riverpod + geolocator。

---

## 0. 常用指令

```bash
dart run build_runner build --delete-conflicting-outputs   # 先跑，否則 analyze/test 必失敗
flutter analyze                                            # 須 0 errors / 0 warnings
flutter test                                               # 全套（目前 316 passed, 0 skipped）
flutter test test/domain/core_loop/timeline_itinerary_test.dart   # 單檔
flutter test --plain-name 'AC-ML-4.4'                      # 單條 AC（AC 編號即測試名，最常用）
dart test test/domain/                                     # 純 domain，不需模擬器
bash tool/simulate_walk.sh                                 # 灌模擬座標進連線裝置
python3 tool/build_and_verify.py                           # 重生底圖/遮罩/路網（改圖資才跑）
```

架構大圖見 §9。

---

## 1. 開發流程（不可跳級）

```
spec → 覆核 → plan → 覆核 → 執行計劃 → 覆核
```

**每一關都必須等使用者明確點頭，才進下一關。**

各階段的產出邊界要嚴格區分：

| 階段 | 該寫什麼 | **不該**寫什麼 |
|---|---|---|
| **spec** | 需求、行為契約、可自動化測試的驗收條件（AC）、待決問題 | 目錄結構、套件選型、演算法、類別設計 |
| **plan** | 分層、抽象邊界、任務拆解、相依順序、選型理由 | 實作碼 |
| **執行計劃** | 依 plan 施工 | 超出 plan 的範圍 |

設計文件 ≠ spec。若把兩者混在一起，退回重寫。

**SPEC 逐個子系統過關，不一次寫完。** 任務 C（GPS 追蹤）已落地並通過真機驗證；其後改走 MVP 核心迴圈路線，順序 M1（純領域迴圈）→ M2（時間線 UI）→ M3（POI 取材）→ M4（行前委託／黑市裝備／存檔）。原先規劃的 A（遭遇系統）、B（行李箱背包）由核心迴圈的素材與腰包機制吸收。

---

## 2. TDD（施工階段強制）

`RED → GREEN → REFACTOR`。先寫失敗的測試，再寫實作。

由此推導出的**硬性架構約束**：

- **`domain/` 不得 import `package:flutter` 或 `package:flame`。** Flame 元件與 GPS 硬體不可測；邏輯留在裡面就做不了 TDD。
- 所有數值規則、格子演算法、狀態機轉移、座標投影都放 `domain/`，用 `dart test` 跑，不需模擬器。

分層測試策略：

| 層 | 測試方式 | 覆蓋率要求 |
|---|---|---|
| `domain/` | 純 `dart test` | 高 |
| `state/`（Riverpod Notifier） | `ProviderContainer` + fake repository | 高 |
| `data/location` | 注入虛擬定位來源，不碰真機 | 中 |
| `game/`, `ui/` | 煙霧測試 | 不追求 |

**spec 的每條需求都必須附可測的 AC**，否則寫不出測試。

---

## 3. Clean Code 與 SOLID —— 務實，不過度工程

**抽象只在「擋住已知會變的軸」時才做。其餘一律不預先抽象。**

目前**核准的抽象只有三條**：

| 抽象 | 擋住的變動軸 |
|---|---|
| `LocationSource` | 真實 GPS 不可測，需可替換為虛擬來源 |
| `PersistenceRepository` | 存檔後端將來會從本機換成遠端 |
| `OverworldMapManifest` | 城市圖資模組化注入 |

提出新抽象前，先回答「它擋住哪一條已知會變的軸」。答不出來就不要做。

**明確延後、不要主動提**：軌跡錄製/重播、A* 路網尋路、條件式物品效果系統、多段 GPS 功率模式（只做 active/suspended 兩段）、自訂 `Result<T,E>` 型別。

---

## 4. 圖資模組化注入

**通用引擎不得含任何特定城市的演算法。** 「城市即實體 DLC」。

`OverworldMapManifest` 需提供：投影（經緯度→像素）、反投影（像素→經緯度）、有效地理範圍（分類遮罩查詢）。道路吸附已於 SPEC C v6 刪除，勿重新加入。

**解耦驗收標準**：能用一個**純數學、不含圖檔與真實地理資料**的 `FakeMapManifest` 跑完整套 domain 測試。做得到才算解耦成立。

### 已知違反（待修）

（目前無）

### 已解除（勿再依此判斷）

以下各條已清償，程式碼與本節原本的記載不符：

- 通用引擎已不呼叫 `TaiwanGeoCalibrator`；該類別與其測試已於 SPEC C v6 修訂四隨道路吸附整項刪除（PRE-3，2026-09-06 確認吸附死碼，2026-09-07 執行刪除）。
- 圖資已由 `main.dart` 的 `ProviderScope.overrides` 注入（PRE-5）。
- `ProviderScope` 已存在於 `main.dart`，Riverpod 已接線（PRE-1）。
- **PRE-8｜圖資資料**（原「5 個道路節點中 4 個與 POI 座標完全相同」的吸附誤觸風險）：SPEC C v6 修訂四刪除道路吸附整項能力，`containsGeo` 改為查詢 `assets/maps/taiwan/mask.png` 的分類遮罩（`TaiwanMapManifest.load()`，2026-09-07）。原本要修的洞（矩形框把台灣海峽、太平洋含在範圍內）已隨遮罩接線一併解除；問題成因（道路節點）已不存在，不需要再補路網資料。

契約本體位於 `lib/domain/location/projection/map_manifest.dart`，`lib/game/map_module/overworld_map_manifest.dart` 僅為轉出。介面不含 `dart:ui` 型別（海洋色為 `int oceanColorArgb`），且已提供反投影、有效範圍（分類遮罩查詢）、降落點、公尺/像素比例、方向鍵速度、POI 節點列舉。**解耦驗收成立**：`FakeMapManifest` 跑得完整套 domain 測試。

---

## 5. 跨系統約束

詳見 `CROSS_CUTTING_CONSTRAINTS.md`。摘要：

- 第一版**純本機運作**，但後端服務是**既定終點**，設計不得排除它。
- 第一版**禁止實作**：帳號、雲端同步、排行榜、好友、遠端 DLC、伺服器驗證、遙測。**且不得提前埋鉤子。**
- 實體識別一律 **UUID**，禁用本機自增序號。
- 時戳一律 **UTC**；「經過了多久」的判定**必須**用**單調時鐘**（否則跨時區失效，且玩家調系統時間就能跳過冷卻）。
- 存檔採 **append-only 事件日誌**，最終狀態由重播得出。**重播必須是決定性的** —— 事件處理器不得依賴當下時間、亂數（除非種子存於事件內）或外部狀態。
- **原始 GPS 座標永不離開裝置**（產品承諾）。僅允許持久化：已投影的像素座標、POI 打卡結果、不含原始座標的事件欄位。

---

## 6. 技術選型（已定案）

- `freezed` + `json_serializable`：**導入**。資料模型多且需 JSON 序列化。
- `riverpod_generator`：**不導入**。Provider 手寫。
- 不要提議引入其他新套件，除非缺了它需求無法實作。

---

## 7. 文件地圖

| 檔案 | 用途 |
|---|---|
| `ARCHITECTURE_BRIEF.md` | 使用者提供的專案目標與任務書 |
| `CROSS_CUTTING_CONSTRAINTS.md` | 拘束 A/B/C 全部子系統的決策（**優先於各子系統 SPEC**），目前 v3 |
| `SPEC_C_GPS_TRACKING.md` | 任務 C 規格，目前 v6（已併入下列增修草案全部內容） |
| `SPEC_C_AMENDMENT_01.md` | 任務 C 實地測試後的增修草案。**已併入 `SPEC_C_GPS_TRACKING.md` v6，狀態為歷史紀錄**，僅供查閱實測證據（F1~F9）與三方覆核的收斂過程，不再是待審文件 |
| `PLAN_C_GPS_TRACKING.md` | 任務 C 的原始施工計劃（T1~T20），**已於真機驗證中執行完畢** |
| `PLAN_C_AMENDMENT_01.md` | SPEC v6 相對 v5.1 增量的實作計劃（T21~T29），目前的待執行清單 |
| `SPEC_MVP_CORE_LOOP.md` / `PLAN_MVP_CORE_LOOP.md` | M1 純領域核心迴圈（3+1 資源、5 種旅行哲學、素材契約），SPEC v3 正式通過，已實作 |
| `SPEC_MVP_TIMELINE_UI.md` / `PLAN_MVP_TIMELINE_UI.md` | M2 4 槽位時間線編輯器、雙客戶 Review 彈窗、狀態接線，SPEC v2，已實作 |
| `SPEC_MVP_POI_GATHERING.md` / `PLAN_MVP_POI_GATHERING.md` | M3 大世界 POI 踩線取材、野外 HUD、體力透支返程，SPEC v2 簽核，已實作 |
| `SPEC_MVP_META_PROGRESSION.md` / `PLAN_MVP_META_PROGRESSION.md` | M4 行前委託、黑市裝備升級、`PersistenceRepository` 本機存檔。SPEC v2 / PLAN v1，**未提交版控、待覆核** |
| `SPEC_MVP_MICRO_ACTION.md` | M5 快門微動作與雙層結算。**v9，八輪雙軌覆核通過（兩軌一致判定「可進 plan」），待使用者點頭進入 plan 階段**（v1~v9 累計八輪雙軌覆核、實機原型驗證，詳見文件內 §8 裁決紀錄；分支 `proto/m5-shutter-feel`） |
| `HANDOFF.md` | 交接紀錄，跨對話的進度快照，會隨每次交接改寫。**接手時先讀這份** |
| `TASK_D_LOCAL_TIER_PROPOSAL.md` | 任務 D（地方層地圖）提案 |
| `ARCHITECTURE_DESIGN.md` | 早期設計文件，**參考素材，非權威** |

子系統 SPEC 若與 `CROSS_CUTTING_CONSTRAINTS.md` 牴觸，以後者為準並回報。

### 文件檔頭視為可能過期

**判斷「某項工作做到哪」一律以 `git log` 與驗收報告為準，文件自述的狀態行不算證據。**

規格檔頭的 `狀態：待覆核`／`流程位置：待 X 清償後實作` 是寫下當刻的快照，施工完成後常常沒人回頭改。已知踩過的坑：

- `SPEC_MVP_AMENDMENT_01.md` 檔頭長期寫「v7 草案，待覆核」，實際 T0~T14 共 16 個 commit 早已執行並驗收（`MVP_AMENDMENT_01_VERIFICATION.md` §6、commit `0b9a30a`）。照檔頭判讀會得出「閘門未開」的相反結論。
- §0 的「316 passed」實測為 462。

判讀順序：`git log --oneline -- <spec 檔>` → 對應的 `*_VERIFICATION.md` 結論節 → 實際程式碼 → 最後才是檔頭。

同理，**「規格沒寫」不等於「沒規劃」**：先查各 SPEC 的非目標／延後清單，被明文延後的項目（如微動作 Runner／Snapshot）是有規劃且附帶解閘條件的，不是遺漏。

這與 §9「接線本身必須有測試」同構：元件寫過不代表接線成立，文件寫過不代表它還成立。

---

## 8. 慣例

- 提交訊息：Conventional Commits，正文說明**為什麼**，英文撰寫。
- 生成檔（`*.freezed.dart`、`*.g.dart`）不進版控。clone 後、或修改任何標註類別後，先執行：
  `dart run build_runner build --delete-conflicting-outputs`
- **先跑 codegen，再** `flutter analyze`，必須維持 0 errors / 0 warnings。
  （乾淨 clone 上未跑 codegen 時分析必然失敗，這不是缺陷。）
- 自 `lib/` import 的套件一律要在 `pubspec.yaml` 宣告直接相依，否則觸發 `depend_on_referenced_packages`。
- 動檔前先確認該檔沒有其他 Agent 正在讀寫。

---

## 9. 架構大圖（讀多檔才看得出來的部分）

### 分層

```
lib/
  domain/   純 Dart 規則（location 管線、core_loop 數值與狀態機）。零框架相依。
  data/     外部世界實作（geolocator、權限閘門、wakelock、城市素材目錄）
  state/    手寫 Riverpod Notifier（無 codegen）
  game/     Flame 元件與城市圖資模組（map_module/）
  ui/       Widget，以 Flame overlay 疊在遊戲上
  core/     時鐘（含單調時鐘）、建置旗標
```

### 架構約束由測試強制，不靠自律

`test/architecture/layer_boundaries_test.dart` 三條，違反就紅：

1. `lib/domain` 不得 import `package:flutter/`、`dart:ui`、`package:flame/`、`package:geolocator/`、`vector_math_64.dart`。
2. **`lib/domain`、`lib/state`、`lib/game/universal_overworld_game.dart` 的原始碼不得出現字串 `taiwan`/`Taiwan`/`kyoto`/`Kyoto`** —— 註解與字面值都算，最容易誤觸。
3. location 層不得碰 `domain/stats/` 或 `SurvivalStats`（單一寫入點）。

### GPS 管線是一串獨立閘門

`lib/domain/location/pipeline/`：

```
LocationSource → 權限解析 → 品質閘（精度門檻）→ 節流
              → 重定位偵測 → 顯著性閘 → 投影 → 平滑 → 里程累計
```

**歷史教訓**：任務 C 真機驗證抓到的四個 bug 全是同一形狀 —— 元件本身正確且測過，但**接線沒人測**（`resetBaselines()` 零呼叫端、`FixThrottle` 在 `lib/` 內零引用）。故接線本身必須有測試，不能只測元件。

投影用**控制錨點的反距離加權插值（IDW）**（`domain/location/projection/control_mesh.dart`）：手繪地圖經非線性誇張，無單一線性變換可對應。

### DLC 注入點

`main.dart` 的 `ProviderScope.overrides` 三個：`mapManifestProvider`、`curatorMaterialPoolProvider`、`poiMaterialResolverProvider`。`TaiwanMapManifest.load()` 是非同步的（解碼 `assets/maps/taiwan/mask.png` 分類遮罩），`main()` 內 await 完才 `runApp`。

### 核心迴圈現況

M1~M3 已實作（`domain/core_loop/`、`state/core_loop/`、`ui/core_loop/`）：單局 5~10 分鐘，接委託 → 選哲學 → 大世界採集 → 夜間 4 槽位時間線 → 雙客戶 100 分制 Review → 局外升級。M4（存檔與黑市）尚未施工。
