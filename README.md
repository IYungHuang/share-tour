# Share Tour

以旅行為世界觀的 **Luggage Roguelite** 手機遊戲。玩家在真實世界走動，GPS 位移映射到一張手繪的 8-bit 大地圖上；抵達 POI 觸發遭遇，戰利品塞進一只格子有限的行李箱。

> 開發中。目前只有 GPS 追蹤子系統（任務 C）落地並通過真機驗證，遭遇系統與背包系統尚未實作。

---

## 技術棧

| 用途 | 選型 |
|---|---|
| 遊戲迴圈與渲染 | `flame` |
| 狀態管理 | `flutter_riverpod`（Provider 手寫，不用 codegen） |
| 定位 | `geolocator` |
| 音效 | `flame_audio` |
| 持久化 | `shared_preferences` |
| 資料模型 | `freezed` + `json_serializable` |

需求：Flutter 3.41+ / Dart SDK `^3.11.0`。

---

## 快速開始

生成檔（`*.freezed.dart`、`*.g.dart`）**不進版控**，clone 後必須先跑 codegen，否則分析與建置都會失敗：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze   # 應為 0 issues
flutter test      # 應為 192 passed, 1 skipped
flutter run
```

那個 skip 是刻意的 —— 見下方「已知問題」。

### 不用真機測 GPS

專案內建虛擬定位來源與一份實地步行軌跡夾具（`test/fixtures/trace_taichung_20260906.json`，142 筆、38.4 分鐘）。該夾具已平移至合成原點 (24.0, 121.0)：保留精度分布與時間結構，不含任何真實地理位置。

`tool/simulate_walk.sh` 可對連線中的裝置灌入模擬座標。

---

## 架構

### 分層

```
lib/
  domain/     純 Dart 邏輯。不得 import flutter 或 flame。
  data/       外部世界的實作（GPS 硬體、權限閘門）。
  state/      Riverpod Notifier。
  game/       Flame 元件與圖資模組。
  core/       時鐘、建置旗標。
```

**`domain/` 的 Flutter/Flame 禁令是硬性約束**，不是風格偏好。GPS 硬體與 Flame 元件不可測；所有數值規則、格子演算法、狀態機轉移與座標投影都留在 `domain/`，用純 `dart test` 驗證，不需模擬器。

### 圖資模組化注入 —— 「城市即實體 DLC」

通用引擎不含任何特定城市的演算法。底圖、POI、道路拓撲與 GPS 校準全部透過 `OverworldMapManifest` 外部注入（`TaiwanMapManifest`、將來的 `KyotoMapManifest`⋯），由 `main.dart` 的 `ProviderScope.overrides` 接上。

Manifest 契約提供：投影（經緯度→像素）、反投影、道路吸附、有效地理範圍、降落點、公尺/像素比例、POI 與道路節點列舉。介面不含 `dart:ui` 型別。

投影用**控制錨點網格的反距離加權插值（IDW）**，因為手繪地圖經過非線性誇張處理，無法用單一線性變換對應。

**解耦驗收標準**：能用一個純數學、不含圖檔與真實地理資料的 `FakeMapManifest` 跑完整套 domain 測試。目前成立。

### 只有三條抽象

抽象只在擋住「已知會變的軸」時才做：

| 抽象 | 擋住的變動軸 |
|---|---|
| `LocationSource` | 真實 GPS 不可測，需可替換為虛擬來源 |
| `PersistenceRepository` | 存檔後端將來從本機換成遠端 |
| `OverworldMapManifest` | 城市圖資模組化注入 |

其餘一律不預先抽象。

### GPS 管線

原始定位讀數經過一串閘門才成為位移：

```
LocationSource → 權限解析 → 品質閘（精度門檻）
              → 節流 → 重定位偵測 → 顯著性閘 → 投影 → 平滑 → 里程累計
```

每一段都在 `lib/domain/location/pipeline/` 內獨立可測。

---

## 跨系統約束

第一版**純本機運作**，但後端服務是既定終點，設計不得排除它。

- **原始 GPS 座標永不離開裝置**（產品承諾）。僅允許持久化：已投影的像素座標、POI 打卡結果、不含原始座標的事件欄位。
- 實體識別一律 UUID，禁用本機自增序號。
- 時戳一律 UTC；「經過了多久」的判定必須用**單調時鐘** —— 否則跨時區失效，且玩家調系統時間就能跳過冷卻。
- 存檔採 **append-only 事件日誌**，最終狀態由重播得出。重播必須是決定性的：事件處理器不得依賴當下時間、亂數（除非種子存於事件內）或外部狀態。
- 第一版禁止實作且**不得提前埋鉤子**：帳號、雲端同步、排行榜、好友、遠端 DLC、伺服器驗證、遙測。

完整條文見 `CROSS_CUTTING_CONSTRAINTS.md`。子系統 SPEC 若與之牴觸，以該檔為準。

---

## 開發流程

```
spec → 覆核 → plan → 覆核 → 執行計劃 → 覆核
```

不可跳級。施工階段強制 TDD（`RED → GREEN → REFACTOR`）。spec 的每條需求都必須附可自動化測試的驗收條件（AC），否則寫不出測試。

各層測試策略：

| 層 | 方式 | 覆蓋率 |
|---|---|---|
| `domain/` | 純 `dart test` | 高 |
| `state/` | `ProviderContainer` + fake repository | 高 |
| `data/location` | 注入虛擬定位來源，不碰真機 | 中 |
| `game/`, `ui/` | 煙霧測試 | 不追求 |

提交訊息用 Conventional Commits，正文說明**為什麼**。

---

## 已知問題

**PRE-8｜台灣圖資的道路節點與 POI 重疊。** `TaiwanMapManifest` 的 5 個道路節點中有 4 個與 POI 座標完全相同（實測間距 0.000 px）。吸附上限 50 公尺，玩家走近景點會被吸到節點上，而節點就是 POI —— 等於自動打卡。遭遇系統一接上就會誤觸發。

規則本身的測試是綠的；紅的只有台灣資料組，因此 `test/taiwan_map_manifest_test.dart` 掛 `skip`（理由寫在 skip 訊息裡）。修法是補上真正的路網節點，屬任務 D。

---

## 文件地圖

| 檔案 | 用途 |
|---|---|
| `CLAUDE.md` | 工作規範（流程、TDD、架構約束） |
| `CROSS_CUTTING_CONSTRAINTS.md` | 拘束全子系統的決策，**優先於各子系統 SPEC** |
| `ARCHITECTURE_BRIEF.md` | 專案目標與任務書 |
| `SPEC_C_GPS_TRACKING.md` / `SPEC_C_AMENDMENT_01.md` | 任務 C 規格與增修 |
| `PLAN_C_GPS_TRACKING.md` | 任務 C 施工計劃 |
| `TASK_D_LOCAL_TIER_PROPOSAL.md` | 任務 D 提案 |
| `HANDOFF.md` | 當前交接狀態 |
| `ARCHITECTURE_DESIGN.md` | 早期設計文件，**參考素材，非權威** |

---

## 授權

尚未指定授權條款，預設保留全部權利。
