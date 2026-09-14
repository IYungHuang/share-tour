# 混合地圖方向討論紀錄

- 日期：2026-09-14
- 分支：`feature/mvp-amendment-01`
- 狀態：討論暫停；方向已初步確認，尚非完整規格，未授權實作

## 背景

目前產品以手繪 8-bit 地圖作為遊戲世界，將真實 GPS 經緯度投影到地圖像素。實機體驗顯示，風格與世界觀成立，但玩家較難理解自己所在位置、下一個 POI 的實際方向，以及手繪距離和真實距離的關係。

討論目標不是製作一次性 Demo，而是先驗證「真實空間資訊加入後，核心循環是否更可玩、更好玩」，再決定是否投入完整圖資、離線與動態店家能力。

## 已確認產品方向

採用混合模式：

- 宏觀層保留現有手繪京都地圖與 JRPG 世界觀。
- 玩家進入街區後，切換至真實地圖圖資。
- 真實地圖使用深色、低資訊密度樣式。
- 保留道路、水系、車站與街區名稱。
- 一般地圖資訊退居背景，角色、遊戲 POI 與事件維持視覺主體。
- GPS 與 D-pad 地位相同，玩家可自由切換。
- 首版只顯示既有策展 POI；不做即時店家搜尋。
- 未來希望接入動態店家資料，生成更多 POI 與素材。

## 首版技術選擇

以開發速度及玩法驗證為優先，首版採 Google Maps：

- 只驗證一個京都街區。
- 使用線上地圖，不做完整離線下載。
- 地圖載入失敗或無網路時，回退現有 Flame 手繪街區圖。
- 不做步行導航、路線規劃、Places 搜尋或高度客製地圖渲染。
- 驗證成功後，再評估 Mapbox 或 MapLibre 的離線與風格能力。

選擇 Google Maps 的理由：Flutter 整合成熟；基本地圖、樣式、marker、點擊與相機跟隨可較快落地；未來若採 Google Places，整合路徑也較直接。

## 已比較方案

### Google Maps

優點：最快完成線上垂直切片、玩家熟悉、未來 Places 整合直接。

限制：缺少由 App 管理完整離線區域下載的正式 Flutter 路徑；高度遊戲化樣式與供應商自由度較低。

### Mapbox

優點：Flutter SDK、自訂樣式、`OfflineManager` 與 `TileStore` 較完整，適合品牌化街區地圖。

限制：商業授權、access token、費用、attribution、telemetry 與供應商鎖定。

### MapLibre

優點：開源、可自選圖磚來源、支援 GeoJSON、樣式圖層、PMTiles 與離線區域，長期控制力最高。

限制：需自行決定 tile provider、快取、授權標示與營運方式；首版工程責任較重。

## 初步架構

採雙地圖表面，不讓 Google Maps 與 Flame 同時控制同一街區：

- 宏觀盆地：現有 `GameWidget`／Flame 手繪地圖。
- 真實街區：Flutter `GoogleMap` Widget。
- 共用層：HUD、D-pad、行動選單、景點卡、QTE 與策展狀態機。
- POI：街區層以 `DistrictAttraction.geo` 經緯度放置 marker。
- 角色：首版使用自訂地圖 marker；先不移植完整逐格 Flame 動畫。
- 定位：GPS 與 D-pad 都更新同一份玩家地理位置。
- 回退：Google 地圖載入失敗時切回既有 Flame 街區圖，遊戲狀態不中斷。
- 隔離：以 `StreetMapAdapter` 隔離地圖供應商，降低未來改用 Mapbox／MapLibre 的成本。

定位模型需保留經緯度作為真實街區層的真理源；像素位置只作 Flame 宏觀與回退地圖的衍生結果。既有定位品質閘門、核心狀態機、素材、QTE 與取材規則原則上不重寫。

## 隱私影響

Google 地圖會請求玩家附近圖磚，供應商可從請求區域推知大致位置。因此現有「原始 GPS 永不離開裝置」承諾需重新定義：

> 本 App 不儲存或主動傳送原始 GPS；第三方地圖供應商依其服務與隱私政策處理地圖請求。

此取捨已在討論中接受，但正式規格仍需定義揭露文字、API key 限制與法律／attribution 呈現。

## 首版成功判準

垂直切片只回答三個問題：

1. 玩家是否更快理解自己在哪裡？
2. 玩家是否知道下一個 POI 該往哪裡走？
3. 真實移動 → 點擊 POI → QTE → 取得素材的循環是否好玩？

若答案不佳，不先追加 Places、導航、離線或更複雜視覺。

## 尚未決定

- 首個驗證街區與確切地理邊界。
- Google Maps 深色樣式細節與資訊隱藏層級。
- D-pad 在經緯度空間中的移動速度與邊界規則。
- 角色 marker 的方向、動畫與相機跟隨細節。
- 地圖載入失敗判定、重試及回退提示。
- Google API key 管理、配額、預算警示與平台限制。
- 未來 Places 資料如何轉換成遊戲素材，以及內容審核規則。
- 何種驗證結果會觸發 Mapbox／MapLibre 遷移評估。

## 官方參考

- [Google Maps for Flutter](https://developers.google.com/maps/flutter-package/overview)
- [Google Maps Platform pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
- [Mapbox Maps SDK for Flutter](https://docs.mapbox.com/flutter/maps/guides/)
- [Mapbox Flutter offline map example](https://docs.mapbox.com/ja/flutter/maps/examples/offline/)
- [MapLibre Flutter advanced features](https://maplibre.org/flutter-maplibre-gl/advanced/)

## 下一步

恢復討論時，從「首個驗證街區與邊界」開始，接續完成資料流、錯誤處理、測試策略與驗收條件。完整設計經確認後，再轉成正式規格與實作計畫。
