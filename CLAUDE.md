# Share Tour — 專案工作規範

以旅行為世界觀的 Luggage Roguelite 手機遊戲。Flutter + Flame + Riverpod + geolocator。

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

**SPEC 逐個子系統過關，不一次寫完。** 目前順序：C（GPS 追蹤）→ A（遭遇系統）→ B（行李箱背包）。理由：C 是 A 的前置，範圍最小。

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
| `services/gps` | 注入虛擬定位來源，不碰真機 | 中 |
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

`OverworldMapManifest` 需提供：投影（經緯度→像素）、反投影（像素→經緯度）、道路吸附、有效地理範圍。

**解耦驗收標準**：能用一個**純數學、不含圖檔與真實地理資料**的 `FakeMapManifest` 跑完整套 domain 測試。做得到才算解耦成立。

### 已知違反（待修）

- **PRE-8｜圖資資料**：`TaiwanMapManifest` 的 5 個道路節點中，有 4 個與 POI 座標完全相同（實測間距 0.000 px）。吸附上限 50 公尺，玩家走近景點會被吸到節點上，而節點就是 POI —— 等於自動打卡，任務 A 的遭遇系統一接上就會誤觸發。
  規則本身的測試是綠的，紅的只有台灣資料組（`test/taiwan_map_manifest_test.dart` 掛 `skip`，理由寫在 skip 訊息裡）。屬**任務 D**，修法是補上真正的路網節點。

### 已解除（勿再依此判斷）

以下三條在 2026-09-06 確認皆已清償，程式碼與本節原本的記載不符：

- 通用引擎已不呼叫 `TaiwanGeoCalibrator`；吸附改由 `TaiwanMapManifest.snapToRoad` 轉呼叫（PRE-3）。
- 圖資已由 `main.dart` 的 `ProviderScope.overrides` 注入（PRE-5）。
- `ProviderScope` 已存在於 `main.dart`，Riverpod 已接線（PRE-1）。

契約本體位於 `lib/domain/location/projection/map_manifest.dart`，`lib/game/map_module/overworld_map_manifest.dart` 僅為轉出。介面不含 `dart:ui` 型別（海洋色為 `int oceanColorArgb`），且已提供反投影、有效範圍、降落點、公尺/像素比例、方向鍵速度、POI 與道路節點列舉。**解耦驗收成立**：`FakeMapManifest` 跑得完整套 domain 測試。

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
| `CROSS_CUTTING_CONSTRAINTS.md` | 拘束 A/B/C 全部子系統的決策（**優先於各子系統 SPEC**） |
| `SPEC_C_GPS_TRACKING.md` | 任務 C 規格 |
| `ARCHITECTURE_DESIGN.md` | 早期設計文件，**參考素材，非權威** |

子系統 SPEC 若與 `CROSS_CUTTING_CONSTRAINTS.md` 牴觸，以後者為準並回報。

---

## 8. 慣例

- 提交訊息：Conventional Commits，正文說明**為什麼**，英文撰寫。
- 生成檔（`*.freezed.dart`、`*.g.dart`）不進版控。clone 後、或修改任何標註類別後，先執行：
  `dart run build_runner build --delete-conflicting-outputs`
- **先跑 codegen，再** `flutter analyze`，必須維持 0 errors / 0 warnings。
  （乾淨 clone 上未跑 codegen 時分析必然失敗，這不是缺陷。）
- 自 `lib/` import 的套件一律要在 `pubspec.yaml` 宣告直接相依，否則觸發 `depend_on_referenced_packages`。
- 動檔前先確認該檔沒有其他 Agent 正在讀寫。
