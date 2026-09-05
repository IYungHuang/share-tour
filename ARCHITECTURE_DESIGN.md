# Share Tour — 系統架構設計規劃書 v1.0

> 對應任務書 `ARCHITECTURE_BRIEF.md` 任務 A / B / C。
> 本文件為**設計規格**，不含實作碼；程式片段僅為介面契約 (contract sketch)。

---

## 0. 先決事項 (Blocking Prerequisites)

現況 `lib/main.dart` **沒有 `ProviderScope`**，Riverpod 目前完全未接線。三個子系統全部依賴全域狀態，因此下列為所有任務的前置步驟：

1. `runApp(const ProviderScope(child: ShareTourApp()))`。
2. Flame 與 Riverpod 的橋接策略（見 §0.1）——這是本專案最關鍵的架構決策。
3. `UniversalOverworldGame` 目前直接呼叫 `TaiwanGeoCalibrator.snapToRoad`，硬編碼了台灣校準器，違反 Map Manifest 解耦哲學。應把 `snapToRoad` 上移為 `OverworldMapManifest` 的介面方法（`Vector2 snapToRoad(Vector2 raw)`），由各 Manifest 自行決定吸附策略（京都可能用格狀街廓、台灣用公路節點）。

### 0.1 Flame ↔ Riverpod 橋接（單向資料流）

**原則：Riverpod 是唯一真實來源 (Single Source of Truth)，Flame 只是渲染層與輸入層。**

```
[GPS / 手勢 / Mini-game 結果]
        ↓ (事件)
   Riverpod Notifiers  ←—— 唯一寫入點
        ↓ (listen / stream)
   Flame Components (只讀，做視覺插值)
        ↓
   Flutter Overlay HUD (ConsumerWidget，只讀)
```

實作手法：`UniversalOverworldGame` 建構時注入 `Ref`（或 `ProviderContainer`），在 `onLoad` 內用 `ref.listen` 訂閱需要的 provider；**禁止** Flame Component 直接持有 mutable 遊戲數值。

```dart
class UniversalOverworldGame extends FlameGame with ScaleDetector {
  final OverworldMapManifest manifest;
  final Ref ref;                       // ← 新增
  final List<ProviderSubscription> _subs = [];

  @override
  void onRemove() { for (final s in _subs) { s.close(); } super.onRemove(); }
}
```

> 注意：`GameWidget.controlled` 每次 hot reload 會重建 game，訂閱必須在 `onRemove` 全部 close，否則會洩漏並產生重複的遭遇觸發。

### 0.2 目標目錄分層

```
lib/
├── main.dart
├── app/
│   ├── share_tour_app.dart          # MaterialApp + ProviderScope + 路由表
│   └── router/encounter_router.dart # 遭遇 → 場景 的路由解析
├── core/
│   ├── constants/                   # 調值常數（不寫在邏輯裡）
│   ├── result/                      # Result<T,E> / Failure 型別
│   └── retro/                       # 8-Bit 共用 UI 元件 (RetroPanel, RetroButton, PixelFont)
├── domain/                          # 純 Dart，零 Flutter/Flame import ← 可單元測試
│   ├── stats/                       # HP / YEN / SAN 模型與規則
│   ├── inventory/                   # 格子、形狀、相鄰加成演算法
│   ├── encounter/                   # 狀態機、遭遇定義、結算規則
│   └── meta/                        # 局外天賦、圖鑑、御朱印
├── data/
│   ├── persistence/                 # shared_preferences 封裝 + schema 版本遷移
│   └── catalog/                     # 物品/遭遇 靜態資料表 (JSON 載入)
├── services/
│   ├── gps/                         # GpsTrackingService + 虛擬 GPS 來源
│   └── audio/                       # 8-Bit 音效 facade
├── state/                           # Riverpod providers（唯一寫入層）
│   ├── run_state_provider.dart
│   ├── stats_provider.dart
│   ├── inventory_provider.dart
│   ├── encounter_provider.dart
│   └── location_provider.dart
├── game/                            # Flame 渲染層（既有 map_module 保留）
│   ├── map_module/
│   ├── universal_overworld_game.dart
│   ├── components/                  # PlayerComponent, PoiMarkerComponent
│   └── transitions/                 # 像素過場 (百葉窗 / 淡入)
└── ui/
    ├── hud/                         # RetroHUD overlay
    ├── encounter/                   # 各 Mini-game 畫面
    └── inventory/                   # 行李箱格子 UI
```

**分層鐵則**：`domain/` 不得 import `package:flutter` 或 `package:flame`。所有數值規則、格子演算法、狀態機轉移都在此，才能用 `dart test` 快速跑（不需 `flutter_test` 開模擬器）。既有 `test/taiwan_geo_calibrator_test.dart` 的模式沿用。

---

## 任務 A：POI 遭遇戰 (Encounter) 系統架構

### A.1 遭遇狀態機

#### 狀態定義

```dart
sealed class EncounterState {}
class EncounterIdle       extends EncounterState {}                       // 無遭遇
class EncounterApproached extends EncounterState { poiId; distance; }     // 進入 triggerRadius
class EncounterPrompted   extends EncounterState { poiId; prompt; }       // 已顯示確認卡
class EncounterStarted    extends EncounterState { poiId; sessionId; }    // Mini-game 執行中
class EncounterResolved   extends EncounterState { poiId; outcome; }      // 有結果待結算/展示
class EncounterCooldown   extends EncounterState { poiId; until; }        // 冷卻中，不重觸發
class EncounterCompleted  extends EncounterState { poiId; }               // 本 Run 已完成，永不重觸發
```

#### 轉移表（唯一合法路徑）

| From | Event | To | 備註 |
|---|---|---|---|
| Idle | `PlayerEnteredRadius(poi)` | Approached | 由 Flame 每 tick 距離檢查發出 |
| Approached | `PromptShown` | Prompted | 冷卻/完成中的 POI 直接被守衛擋掉 |
| Approached | `PlayerLeftRadius` | Idle | 含 hysteresis，見 A.1.3 |
| Prompted | `PlayerAccepted` | Started | |
| Prompted | `PlayerDeclined` | Cooldown | 短冷卻（如 60s），避免反覆彈窗 |
| Prompted | `PlayerLeftRadius` | Idle | |
| Started | `MiniGameFinished(outcome)` | Resolved | |
| Started | `MiniGameAborted` | Cooldown | app 被殺、來電中斷 → 視同放棄 |
| Resolved | `RewardsApplied` | Completed / Cooldown | 依 POI 的 `repeatPolicy` 決定 |
| Cooldown | `CooldownExpired` | Idle | |

**守衛條件 (guards)**：從 `Idle → Approached` 必須同時滿足 (a) POI 不在 cooldown、(b) POI 不在 completed set、(c) 目前無其他遭遇進行中（全域互斥鎖，同時只允許一場遭遇）。

#### A.1.3 觸發抖動防護（重要）

GPS 精度 ±10~30m，玩家站在 `triggerRadius` 邊界時會**反覆進出**，造成彈窗轟炸。必須設計：

- **遲滯 (Hysteresis)**：進入用 `triggerRadius`，離開用 `triggerRadius * 1.4`。
- **停留確認 (Dwell time)**：連續 N 秒（建議 3s）在半徑內才發 `PlayerEnteredRadius`。
- **精度閘門**：`position.accuracy > 50m` 時不觸發任何遭遇，HUD 顯示「訊號微弱」。

#### 資料模型擴充

`OverworldPoiNode` 目前只有 `encounterType`，不足以驅動遭遇。建議**不改 Manifest 模型**（保持圖資純粹），另建 `EncounterDefinition` 由 `data/catalog/` 依 `poiId` 查表：

```dart
class EncounterDefinition {
  final String poiId;
  final EncounterType type;
  final String miniGameId;          // 決定路由到哪個 Mini-game
  final RepeatPolicy repeatPolicy;  // onceEver / oncePerRun / cooldown(Duration)
  final Map<String, dynamic> params;// 難度、敵人表、商品表…（交給 Mini-game 自解）
  final EncounterCostSpec cost;     // 進入門檻：YEN 不足不能進商店等
}
```

好處：城市 DLC 只提供地理資料，遭遇內容可獨立熱更新 / A-B 調參。

#### 5 大類型的職責對應

| Type | Mini-game 骨架 | 主要影響數值 | 典型 repeatPolicy |
|---|---|---|---|
| `sightseeing` | 相機打卡（對準構圖 + 快門時機） | SAN ↑, 紀念品獲得 | onceEver（圖鑑收集感） |
| `rest` | 選擇住宿等級（資源分配） | HP ↑, YEN ↓, SAN 小↑ | cooldown(長) |
| `shop` | 網格背包購物 / 議價 | YEN ↓, 物品 ↑ | cooldown |
| `challenge` | QTE 節奏 / 敏捷檢定 | 成功 YEN↑；失敗 HP↓ SAN↓ | oncePerRun |
| `boss` | 回合制對決 | 大幅全數值變動 | onceEver |

五者共用同一狀態機，差異只在 `miniGameId` 與結算表 — 這是把 5 種玩法收斂成單一生命週期的關鍵。

---

### A.2 過場與場景路由 — 架構決策

**結論：採用 Flutter Navigator 全螢幕路由（`Navigator.push`）作為 Mini-game 主要載體，而非 Flame Component 換景，也不用 Overlay 承載完整玩法。**

三方案評比：

| 方案 | 優點 | 缺點 | 判定 |
|---|---|---|---|
| **Flame Component 換景**（同一 GameLoop 內 remove/add World） | 純 Canvas，過場動畫可控性最高 | Mini-game 要重寫全部 UI（按鈕、清單、文字排版）於 Canvas，開發成本極高；無障礙/輸入法全失 | ❌ 僅用於「Boss 對決」等真的需要精靈動畫者 |
| **Overlay 彈窗** | 輕、大地圖仍在背景運行 | 大地圖 GameLoop 持續 tick，白吃 CPU/電；GPS 仍在觸發距離檢查造成狀態污染 | ✅ 僅用於 `Prompted` 確認卡、小結算面板 |
| **Navigator 全螢幕路由** | Mini-game 是普通 Flutter Widget 樹，Riverpod 直通，開發最快；大地圖可 `pauseEngine()` 省電 | 過場需自訂 transition | ✅ **主方案** |

#### 混合策略（最終設計）

```
Approached  →  Flame 內：POI marker 發光 + 靠近音效           (Flame 層)
Prompted    →  Flutter Overlay 木紋確認卡「進入 台北101？」    (Overlay 層)
Started     →  Navigator.push(PixelTransitionRoute(...))       (Route 層)
               ↳ 進場時 game.pauseEngine() + GPS 降頻
Resolved    →  Mini-game 內結算畫面 → pop 回傳 EncounterOutcome
Completed   →  Navigator.pop 後 game.resumeEngine()，HUD 播數值變化動畫
```

`boss` 型別的 Mini-game 內部**自己再開一個 `GameWidget`**（獨立的 `BossBattleGame`），與大地圖 game 互不共用實例。這樣既得到 Flame 的動畫能力，又不必在同一 GameLoop 內做場景管理。

#### 像素過場實作規格

自訂 `PageRouteBuilder` 子類 `PixelTransitionRoute`，`transitionsBuilder` 用 `AnimatedBuilder + CustomPainter` 繪製：

- **百葉窗 (Venetian)**：把畫面切成 N 條水平帶（N=12），每條依 index 錯開 delay，用 `ClipPath` 由左右交替掃入。
- **黑屏淡入**：`ColorFiltered` 兩段式 — 前 50% 淡入純黑，後 50% 淡出到新畫面（避免兩畫面同時可見的交叉溶解，那不是 8-Bit 味）。
- **像素化溶解 (Dissolve)**：以 8×8 為單位的偽隨機遮罩逐格填黑，最貼近 8-Bit 觀感。

**硬規則**：所有過場 Painter 一律 `FilterQuality.none` + `isAntiAlias = false`，與既有 `mapComponent` 的 paint 設定一致。過場時長固定 `400ms` 進 / `300ms` 出；長於此會讓 LBS 遊戲的節奏拖沓。

- 提供 `TransitionStyle` enum 由 `EncounterType` 決定：boss → dissolve、shop → venetian、其餘 → fade。

---

### A.3 結算與數值回寫機制

#### 結算資料契約

Mini-game **不直接改數值**，只回傳一個純資料的 outcome，由單一結算器套用。這是防止數值來源分散的關鍵。

```dart
class EncounterOutcome {
  final String poiId;
  final EncounterResult result;     // success / failure / fled / partial
  final StatsDelta delta;           // { hp: -10, yen: +300, san: +5 }
  final List<ItemGrant> items;      // 獲得物品（含形狀，需塞進背包）
  final List<String> unlockedMeta;  // 局外解鎖旗標（圖鑑、御朱印）
  final Map<String, dynamic> log;   // 給結算畫面顯示的敘事資料
}
```

#### 回寫管線（單向、可測試）

```
Mini-game → EncounterOutcome
              ↓
      EncounterResolver (domain, 純函式)
        ├─ 套用局外天賦修正（如「鐵胃」: 食物 HP 回復 +20%）
        ├─ 套用背包相鄰加成修正
        ├─ 套用超載懲罰（見任務 B）
        └─ clamp 至合法區間 → ResolvedOutcome
              ↓
      StatsNotifier.apply(ResolvedOutcome.delta)   ← 唯一寫入點
      InventoryNotifier.grant(items)               ← 可能失敗（背包滿）
      MetaProgressNotifier.unlock(flags)           ← 立即持久化
              ↓
      RunStateNotifier 檢查死亡條件
```

`EncounterResolver` 是純函式 `(outcome, modifiers) -> ResolvedOutcome`，可 100% 單元測試，這是數值平衡工作的核心測試面。

#### 三大數值的狀態設計

```dart
class SurvivalStats {
  final int hp;  final int maxHp;    // 0 → Run 結束（力竭）
  final int yen;                     // 可為 0，不可為負；不足即擋下消費
  final int san; final int maxSan;   // 0 → Run 結束（精神崩潰，不同結局）
}
```

- `StatsNotifier extends Notifier<SurvivalStats>`，**只暴露語意化方法**（`applyDelta`, `spend`, `heal`），不暴露 setter。
- `spend(yen)` 回傳 `bool`／`Result`，讓商店能正確拒絕交易——不要讓 UI 自行判斷餘額後再扣款（TOCTOU 競態）。
- SAN 的**被動衰減**（每移動 X 公里 / 每現實 Y 分鐘 -1）由 `RunTickProvider` 驅動，不要塞在 Flame `update()` 裡（app 進背景時 GameLoop 會停，數值會不一致）。
- 死亡判定放在 `RunStateNotifier` 對 stats 的 `listen`，集中一處，避免每個 Mini-game 各自檢查。

---

## 任務 B：行李箱背包 (Luggage Roguelite Inventory) 系統架構

### B.1 網格與形狀模型

```dart
class GridShape {                      // 物品佔位遮罩，(0,0) 為左上錨點
  final int width, height;
  final List<bool> cells;              // width*height 的 bitmap，true = 佔用
  GridShape rotated90();               // 回傳新實例（不可變）
}

class LuggageGrid {
  final int width, height;             // 局外升級可擴張（如 5x4 → 7x5）
  final List<PlacedItem> items;
  final Set<Point<int>> lockedCells;   // 未解鎖 / 破損格
}

class PlacedItem {
  final String instanceId;             // 同款物品多個並存，需要實例 ID
  final String itemDefId;              // 指向靜態表
  final Point<int> origin;             // 左上格座標
  final Rotation rotation;             // r0 / r90 / r180 / r270
}
```

放置驗證 `canPlace(grid, def, origin, rotation)`：邊界內 → 不撞 lockedCells → 不與既有 item 遮罩重疊。純函式，全部在 `domain/inventory/`，高度可測。

**旋轉的 UI 規格**：拖曳中長按或雙指旋轉皆不可靠（手機拖曳時另一手不便），建議**拖曳浮動預覽 + 固定「↻ ROTATE」實體按鈕**，且落點合法性以綠/紅像素外框即時回饋。

### B.2 重量與超載懲罰

重量與格子佔用是**兩個獨立維度**（大而輕的枕頭 vs 小而重的相機），這正是行李箱主題的樂趣來源：

```
totalWeight = Σ item.weight
capacity    = baseCapacity + Σ meta天賦加成
overload    = max(0, totalWeight - capacity)
```

超載懲罰採**分級而非硬鎖**（硬鎖會讓玩家卡死無法前進，Roguelite 大忌）：

| 超載比例 | 懲罰 |
|---|---|
| 0% | 無 |
| 1–25% | 移動 SAN 衰減速率 ×1.5 |
| 26–50% | 疊加：`challenge` 型遭遇成功率 −20% |
| >50% | 疊加：每次觸發遭遇 HP −1（腰痛） |

懲罰全部表達為 `StatModifier` 物件，統一餵進 §A.3 的 `EncounterResolver`，而不是散落在各系統做 if 判斷。

### B.3 物品定義與效果系統

```dart
sealed class ItemDefinition {
  String get id; GridShape get shape; int get weight; ItemRarity get rarity;
}
class ConsumableItem extends ItemDefinition { List<ItemEffect> onUse; int charges; }
class EquipmentItem  extends ItemDefinition { List<ItemEffect> passive; EquipSlot? slot; }
class SouvenirItem   extends ItemDefinition { String codexEntryId; }  // 通常無主動效果，但參與相鄰加成
```

**效果用資料描述，不用 Dart 回呼**：

```dart
class ItemEffect {
  final EffectTrigger trigger;   // onUse / passive / onEncounterStart / onEncounterResolve
  final EffectTarget target;     // hp / san / yen / encounterSuccessRate / weightCapacity
  final EffectOp op;             // add / multiply / setFloor
  final num value;
  final EffectCondition? when;   // 如 encounterType == rest
}
```

理由：可序列化 → 可從 JSON 載入 → 可在不改碼下調平衡、可存檔、可讓 Mini-game 通用地查詢「我現在的成功率修正是多少」。若用 closure，存檔與數值面板都會失能。

### B.4 相鄰加成 (Adjacency Synergies)

```dart
class AdjacencyRule {
  final String sourceItemId;
  final ItemMatcher neighborMatcher;   // byId / byTag（如 tag:"food"）
  final AdjacencyMode mode;            // orthogonal（四方） / anyTouching（含斜角）
  final List<ItemEffect> bonus;
}
```

計算 `computeSynergies(LuggageGrid) -> List<ActiveSynergy>`：對每個 item 展開其佔用格 → 收集邊界外一圈的鄰居格 → 查表匹配。**純函式且要 memoize**：只在背包變動（放置/移除/旋轉）時重算一次並快取進 `inventoryProvider` 的 state，**絕不可**在 Flame `update()` 或 build 中每幀重算。

範例：`保溫瓶` 正交相鄰 `tag:food` → 該食物回復量 ×1.3；`相機` 相鄰 `記憶卡` → sightseeing 遭遇 SAN 獲得 +2。

> 平衡陷阱：相鄰加成與旋轉組合的搜尋空間很大，容易出現「一個 dominant 擺法」。建議加入**同類加成遞減**（同一 sourceItem 最多吃 2 次同型加成）。

### B.5 單局 Run 與局外持久化 (Meta-Progression)

**兩條完全獨立的狀態線，絕不共用 Notifier：**

| | Run State（單局） | Meta State（局外永久） |
|---|---|---|
| 內容 | `LuggageGrid` 內容物、三數值、已完成 POI、當前遭遇 | 背包基礎尺寸、天賦樹、圖鑑、御朱印、總里程 |
| 生命週期 | Run 開始建立，Run 結束丟棄 | 跨 Run 累積，永不重置（除非玩家手動） |
| 寫入時機 | 記憶體為主，**checkpoint 式**落盤 | 每次解鎖立即落盤 |
| Provider | `runStateProvider` (autoDispose) | `metaProgressProvider` (keepAlive) |

#### 持久化策略

`shared_preferences` 存的是 String/基本型別，不適合高頻大物件寫入。設計：

- **一個 key 一個聚合根**：`run_snapshot_v1`（整個 Run 的 JSON）、`meta_progress_v1`、`codex_v1`。
- **Schema 版本號寫在 JSON 內**（`{"v":1,...}`），啟動時走 `MigrationRunner` 逐版遷移。這在 Roguelite 長期迭代中是必需品，第一版就要做，事後補極痛。
- **Run 快照落盤時機**：僅在「遭遇結算完成」與「app 進入 background (`AppLifecycleState.paused`)」時寫入。手機遊戲常被系統殺掉，沒有這個就會丟失整段旅程。**不要**每次 GPS 更新就寫。
- `shared_preferences` 單值不宜超過數百 KB。若日後圖鑑/相簿（含打卡照片）膨脹，照片走檔案系統 + 只存路徑；屆時可將存檔層換成 `sqflite` — 因此**所有存取必須經過 `PersistenceRepository` 介面**，不得在 domain 或 UI 直接呼叫 `SharedPreferences`。

---

## 任務 C：即時 LBS GPS 追蹤與平滑位移

### C.1 `GpsTrackingService` 封裝

```dart
abstract class LocationSource {                    // ← 抽象，便於替換
  Stream<GeoFix> get stream;
  Future<PermissionOutcome> ensurePermission();
  Future<GeoFix?> lastKnown();
  void setPowerMode(GpsPowerMode mode);
}

class GeoFix {                                     // 不直接外洩 geolocator 的 Position
  final double lat, lng, accuracy, speed;
  final DateTime timestamp;
  final bool isMocked;
}
```

實作三種來源，靠介面抽換：`RealGpsSource`（geolocator）、`SimulatedGpsSource`（除錯用）、`ReplayGpsSource`（重播錄製軌跡，做自動化測試）。

#### 權限流程（順序不可顛倒）

1. `Geolocator.isLocationServiceEnabled()` — 系統定位總開關關閉時，先引導使用者開啟，不要直接請求權限（會靜默失敗）。
2. `checkPermission()`；若 `denied` 才 `requestPermission()`。
3. `deniedForever` → 顯示說明並提供 `Geolocator.openAppSettings()` 入口；**同時自動切換到「離線/虛擬模式」讓遊戲仍可玩**，不要卡死在權限牆。
4. 背景追蹤（Android `foregroundService` / iOS `allowBackgroundLocationUpdates`）屬第二階段，第一版只做前景追蹤，避免 App Store 審核與電池爭議。

> 隱私注意：GPS 軌跡屬敏感個資。原始經緯度只保留在裝置本地，存檔只落地「已投影的像素座標與 POI 打卡紀錄」，不要把完整原始軌跡序列化進存檔或送往任何外部服務。日後若做社群分享功能，分享的應是遊戲畫面而非座標。

#### 串流節流與省電

```dart
LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 10,        // 平台原生節流：移動 10m 才推一次（省電關鍵）
)
```

四段功率模式，依遊戲狀態切換（由 `encounterProvider`/`AppLifecycle` 驅動）：

| 模式 | 觸發時機 | 設定 |
|---|---|---|
| `active` | 大地圖前景探索 | high, distanceFilter 10 |
| `nearPoi` | 已 Approached，需精確判定 | best, distanceFilter 3 |
| `lowPower` | Mini-game 進行中（`Started`） | reduced, distanceFilter 50 |
| `suspended` | app background / 權限缺失 | 取消訂閱 |

再加一層應用層節流：`.throttleTime(1s)` 級的合併 + **精度過濾**（丟棄 `accuracy > 100m` 的 fix）+ **速度合理性檢查**（兩點推算速度 > 200 km/h 視為漂移，丟棄）。GPS 城市峽谷跳點是本專案最會被玩家抱怨的問題，這層過濾必做。

#### 離線快取

- `lastKnownPosition` 作為冷啟動的即時起點（避免開場空白 3 秒）。
- 斷訊時進入 **Dead Reckoning 寬限期**：保持小人在最後位置 + HUD 顯示「SIGNAL LOST」閃爍，60s 後暫停 SAN 衰減與遭遇判定（不懲罰在隧道/室內的玩家）。
- 打卡等有價值的事件在離線時寫入 `pendingEventQueue`，恢復後重放。

### C.2 移動平滑插值

**核心觀念：GPS 座標是「目標」，畫面小人是「追隨者」。** 現有 `updatePlayerGps` 直接 `playerComponent.position = snappedPixel` 會瞬移，必須改為雙變數模型。

```dart
class PlayerComponent extends PositionComponent {
  Vector2 _target = Vector2.zero();     // 由 GPS 投影+吸附後寫入
  static const double _smoothing = 4.0; // 每秒收斂率

  void setGpsTarget(Vector2 p) => _target.setFrom(p);

  @override
  void update(double dt) {
    // 幀率無關的指數平滑（不可用固定 lerp 係數，會隨 FPS 變速）
    final t = 1 - math.exp(-_smoothing * dt);
    position.lerp(_target, t);
    // 朝向：位移量足夠大時才更新面向，避免原地抖動亂轉
  }
}
```

要點：
- **用 `1 - exp(-k*dt)` 而非 `lerp(a, b, 0.1)`**：後者在 120Hz 與 30Hz 裝置上速度不同。
- **距離分級**：`target` 與 `position` 距離 > 200px（如玩家搭高鐵/傳送）時，不平滑，改播過場並瞬移，否則小人會慢慢「飄」過整張地圖看起來很怪。
- **道路吸附放在 target 端**：先投影 → 吸附 → 才餵給 `_target`，插值永遠對吸附後的點做，小人自然沿路走。
- 若要更進階「沿公路網走」，把 `snapToRoad` 升級為在路網上做 A*，把 `_target` 換成 `List<Vector2>` 路徑點佇列，`update` 逐點消耗 — 建議列為第二階段，第一版指數平滑已足夠。
- 相機跟隨改用 `camera.follow(playerComponent)` 並保留「手勢平移中暫時解除跟隨、3 秒無操作後 `camera.moveTo` 平滑回歸」的行為；目前的 `onScaleUpdate` 直接寫 viewfinder.position，與跟隨會打架，需一併處理。

### C.3 除錯 / 虛擬 GPS 控制器

同一個 `LocationSource` 介面，除錯模式注入 `SimulatedGpsSource`：

- **點擊尋路**：`TapCallbacks` 取得地圖像素座標 → **反投影**回經緯度（需要 `Manifest.unprojectPixelToGps()`，目前 Manifest 只有單向 `projectGpsToPixel`，**需補上反向介面**）→ 餵入模擬串流。這樣除錯路徑與正式路徑完全共用，不會出現「模擬能跑、真機不能跑」。
- **虛擬搖桿**：以固定步進速度（如 5 km/h 步行 / 60 km/h 車行）沿方向產生連續 fix，用來驗證平滑與節流。
- **軌跡錄製/重播**：真機錄一段 `List<GeoFix>` 存成 JSON，`ReplayGpsSource` 重播，可寫成整合測試（含刻意注入跳點、精度惡化、斷訊）驗證 §C.1 的過濾邏輯。
- 切換入口放在 debug-only 面板（`kDebugMode` 守衛），不要進 release build。
- `GeoFix.isMocked` 保留欄位：正式版需決定是否對外掛式定位偽造做處理（至少記錄，避免圖鑑/排行榜被污染）。

---

## 交付優先序（建議分工）

| # | 項目 | 依賴 | 說明 |
|---|---|---|---|
| P0 | `ProviderScope` + Flame/Riverpod 橋接 + 目錄分層 | — | 一切的前提 |
| P0 | `LocationSource` 抽象 + `SimulatedGpsSource` | P0 橋接 | 先有模擬源，後續全部可在桌面開發 |
| P0 | `Manifest.unprojectPixelToGps()` + `snapToRoad` 上移介面 | — | 補既有解耦缺口 |
| P1 | `PlayerComponent` 平滑插值 + 相機跟隨 | LocationSource | 立即可見的手感提升 |
| P1 | Encounter 狀態機（domain 純邏輯 + 測試） | 橋接 | 不含任何 Mini-game 內容 |
| P1 | `StatsNotifier` + `EncounterResolver` | 狀態機 | 數值單一寫入點 |
| P2 | `PixelTransitionRoute` 過場 + Prompted Overlay | 狀態機 | |
| P2 | `LuggageGrid` 放置/旋轉/相鄰加成（純函式 + 測試） | — | 可與遭遇並行開發 |
| P2 | `PersistenceRepository` + schema 版本遷移 | Run/Meta 模型 | 越早做越省事 |
| P3 | 各 Mini-game 實作（先做 sightseeing + rest 兩種驗證管線） | P1+P2 | |
| P3 | `RealGpsSource` 真機調校、省電模式、離線佇列 | P1 | 需實地測試 |

## 建議補充的依賴

- `riverpod_annotation` + `riverpod_generator`：Notifier 樣板多，codegen 可觀省事。
- `freezed` + `json_serializable`：`EncounterOutcome`/`GridShape`/存檔模型皆為不可變資料類 + JSON，手寫 `copyWith`/`fromJson` 成本高且易錯。
- `rxdart` 或自寫 throttle：GPS 串流節流。
- `flame_riverpod`：可評估，但本文的手動 `ref.listen` 橋接已足夠且更可控。
