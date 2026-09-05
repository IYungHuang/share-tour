# Share Tour — 專案目標、當前進度與系統架構規劃任務書

## 1. 專案目標與定位 (Project Vision & Goal)

本專案為 **「以旅行為世界觀的 Luggage Roguelite 手機遊戲」**，深度整合行動端原生硬體特徵（GPS LBS 定位、相機打卡、離線快取、社群分享）。

### 核心技術棧
- **遊戲核心引擎**：`Flutter + Flame`（GameLoop、CameraComponent、向量手繪世界渲染、8-Bit 像素化無抗鋸齒）
- **狀態管理**：`flutter_riverpod`（管理 HP/YEN/SAN 三大生存數值、行李箱 Inventory 與全域事件）
- **LBS 與地理定位**：`geolocator`（高精度 WGS84 GPS 座標獲取、距離計算、背景位置監聽）
- **音效引擎**：`flame_audio`（8-Bit Chiptune 晶片音效與 BGM）
- **持久化儲存**：`shared_preferences`（局外天賦、圖鑑、御朱印）

### 核心架構哲學
- **Map Manifest 解耦模式**：「城市即實體 DLC」，底圖、POI、道路拓撲與 GPS 校準演算法透過外部注入（如 `TaiwanMapManifest`, `KyotoMapManifest`），不硬編碼地圖業務。
- **IDW 座標投影與道路吸附**：手繪地圖經過非線性誇張處理，透過控制錨點網格的反距離加權插值（Inverse Distance Weighting, IDW）映射像素座標，並疊加公路網節點吸附（Road Snapping）。

---

## 2. 當前已完成工程落地 (Current Progress)

專案已在 `/Users/appgongyong/share_tour` 建立並通過 `flutter analyze`（0 errors / 0 warnings）與演算法單元測試：

### 核心代碼結構
- `lib/game/map_module/models/geo_anchor.dart`：地理校準錨點模型
- `lib/game/map_module/models/overworld_poi_node.dart`：POI 節點與 `EncounterType` 列舉（sightseeing, rest, shop, challenge, boss）
- `lib/game/map_module/overworld_map_manifest.dart`：地圖資產包抽象介面 (Map Manifest Contract)
- `lib/game/map_module/utils/taiwan_geo_calibrator.dart`：IDW 插值演算法與公路網吸附實作
- `lib/game/map_module/manifests/taiwan_map_manifest.dart`：台灣手繪地圖 Manifest 實例（含基隆、台北101、台中歌劇院等 8 個控制點與 4 個 POI 節點）
- `lib/game/universal_overworld_game.dart`：Flame 遊戲主畫布、相機平移手勢、邊界限制與小人座標更新
- `lib/main.dart`：Flutter 應用程式入口與 8-Bit 木紋 RetroHUD 疊層
- `assets/images/taiwan_overworld.png`：2048×1152 基礎像素地圖資產
- `ios/Runner/Info.plist` & `android/app/src/main/AndroidManifest.xml`：已配置 GPS 權限說明
- `test/taiwan_geo_calibrator_test.dart`：演算法單元測試（台北 101 座標投影與道路吸附）已通過

---

## 3. 本階段委派任務：系統架構規劃 (Architecture Planning)

請針對以下三個核心子系統進行架構設計與規格規劃，產出具體的技術設計與目錄分層方案：

### 任務 A：POI 遭遇戰 (Encounter) Mini-Game 系統架構
1. **遭遇狀態機**：
   - 針對 5 大類型（`sightseeing`, `rest`, `shop`, `challenge`, `boss`）設計統一的 Encounter State Machine。
   - 遭遇生命週期：`Approached`（進入範圍） $\rightarrow$ `Prompted`（提示確認） $\rightarrow$ `Started`（進入 Mini-game） $\rightarrow$ `Resolved`（結算結果） $\rightarrow$ `Cooldown/Completed`。
2. **過場與場景切換路由**：
   - 評估並制定「大地圖（Flame Game） $\rightarrow$ Mini-Game 戰鬥/互動場景」的路由最佳實踐：
     - 是透過 Flame Component 換景？還是透過 Flutter Navigator 路由 / Overlay 彈窗？
     - 如何設計平滑的 Retro 像素過場（如黑屏淡入、百葉窗切換）？
3. **結算與數值回寫機制**：
   - 遭遇成功/失敗對三大生存數值（HP 生命值 / YEN 金錢 / SAN 理智值）的影響如何與 Riverpod 全域狀態對接？

### 任務 B：行李箱背包 (Luggage Roguelite Inventory) 系統架構
1. **背包空間與格子佈局 (Backpack Grid)**：
   - 類似《生化危機》或《背包英雄》的網格排列（寬度 × 高度）與旋轉（Rotate）。
   - 物品形狀、類別、重量限制與超載懲罰機制。
2. **物品資料結構與效果系統**：
   - 消耗品（食物、飲料、藥物）、裝備品（相機、雨傘、球鞋）、紀念品（御朱印、明信片）。
   - 物品相鄰加成（Adjacency Synergies）架構設計。
3. **單局 Run 與局外持久化 (Meta-Progression)**：
   - 單局背包資料 vs 局外永久行李箱升級與天賦解鎖的儲存架構。

### 任務 C：即時 LBS GPS 追蹤與平滑位移設計
1. **Geolocator 服務封裝 (`GpsTrackingService`)**：
   - 權限動態檢查與請求。
   - GPS 串流訂閱（`getPositionStream`）的節流（throttle）、省電與離線快取機制。
2. **小人移動平滑插值 (Movement Interpolation)**：
   - 避免 GPS 每次更新時小人產生「瞬移感」：設計 Lerp 平滑過渡或 Flame `MoveEffect` / 路徑導航動畫。
   - 開發/除錯模式下的「虛擬 GPS 控制器 / 點擊尋路」相容設計。

---

請先產出架構設計規劃（可編寫為規劃文檔或直接梳理規格回饋），供團隊後續分工實作！
