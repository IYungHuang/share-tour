# 交接 — 2026-09-06 實地 GPS 測試

## 一句話

任務 C（GPS 追蹤）程式碼全部完成、161 條測試通過，但**真實 GPS 從未被驗證過**：
切到 GPS 模式後 `REAL` 里程始終是 0，原因未明。今天要用實地行走找出來。

---

## 出門前

```bash
cd ~/share_tour
dart run build_runner build --delete-conflicting-outputs
flutter test                       # 應為 161 passed, 1 skipped
flutter run -d EMD6VSPZV8MFBMDI    # CPH2783，Android 16
```

> 生成檔不進版控，clone 或改模型後必須先跑 codegen。
> 磁碟曾經被 `build/`（1.9 GB）與模擬器快照塞爆導致測試假性卡死。空間不足時先 `rm -rf build`。

---

## 測試步驟

### 1. 靜止 3 分鐘（先做這個）

放著不動，記錄 HUD：

```
FIX ok:__ rej:__      REAL:__ m      MOTION:__      ACC:__ m
```

**預期**：`REAL` 為 0、`MOTION` 變 `still`、`ok` 緩慢增加或不增加。

**若 `REAL` 持續增加** → 顯著位移閘門門檻太鬆，GPS 抖動被當成移動。
係數在 `SPEC_C_GPS_TRACKING.md` §5 的「位移顯著性係數 0.75」。

### 2. 按 `USE GPS`（右下角）

**預期**：跳系統權限對話框，有「精確」與「大概」兩個選項。

先選 **精確 + 允許**。按鈕變綠 `GPS ON`、`MODE: GPS`。

### 3. 步行 500 公尺

**看 HUD 數字，不要看小人** —— 500 公尺在大地圖上只有 1.35 像素，肉眼看不出來。

**預期**：`REAL` 增加到 **400~600 公尺**（DoD 第 7 條，±20%）。

### 4. 回來後讀日誌

```bash
~/Library/Android/sdk/platform-tools/adb logcat -d | grep TRACK | tail -50
```

每一筆長這樣：

```
[TRACK] lat=.. lng=.. acc=.. hasAcc=.. mocked=.. mode=.. rej=.. target=.. events=.. cov=..
```

---

## 怎麼判讀

| 現象 | 意義 | 下一步 |
|---|---|---|
| `REAL` 增加 400~600 m | ✅ 全部正常 | 移除追蹤日誌，任務 C 收工 |
| 完全沒有 `mode=gps` 的 TRACK | 真實來源沒送出任何 Fix | 查 `GeolocatorLocationSource.start()` 與 `LocationSubscriptionManager` 的訂閱 |
| 有 `mode=gps` 但 `rej=` 有值 | 品質閘門在丟 | 看是哪個原因；`unmeasuredAccuracy` 表示裝置沒回報精度 |
| 有 `mode=gps`、`rej=null`、但 `target=null` | 顯著位移閘門判定為未移動 | 比對連續兩筆的 lat 差與 `acc`——門檻是 `0.75 × (acc前+acc後)` |
| `cov=false` | 落在圖資範圍外 | 檢查 `TaiwanMapManifest.containsGeo` 的邊界 |
| `mode=virtual` 但你在 GPS 模式 | `isMocked` 歸屬或模式綁定有誤 | 看 `mocked=` 欄位 |

**重點**：`FIX ok` 這個計數曾經誤導過我兩次。虛擬來源原地空轉時會灌爆它（已修），
而它只說「有幾筆進來」，不說「為什麼沒動」。**以 TRACK 逐筆日誌為準。**

---

## 順便驗（可選）

**Android 12+ 概略位置** —— 規格 REQ-C-01 有這條需求，但目前只有單元測試、沒有真機證據。

到系統設定把定位權限改成「大概」，回 app 重按 `USE GPS`：

- 預期：顯示 `請開啟「精確位置」`，自動退回方向鍵模式
- 若顯示 `GPS ON` 卻不動、`REAL` 不增加 → 那條需求失效，正是它要防的症狀

---

## 已知紅燈（刻意保留，不是遺漏）

| 測試 | 原因 |
|---|---|
| `layer_boundaries_test` 已解除 | PRE-3 已清償 |
| `manifest_geometry_check_test` 台灣資料組 | **PRE-8**：5 個道路節點中 4 個與 POI 同座標（實測間距 0.000 px）。吸附會把玩家從數公里外瞬移到 POI 上並誤觸發遭遇 |

PRE-8 屬圖資資料，會在任務 D 一併處理。

---

## 待決

| # | 問題 | 卡住誰 |
|---|---|---|
| Q15 | **地方層地圖的尺度**——真實移動要以什麼比例映射到地圖 | 任務 D 的核心決策。**今天的實地體感就是裁決依據** |
| Q16 | POI 觸發半徑的公尺數 | 任務 A。需要 Q15 先定 |
| — | 方向鍵的「慣性」是否該調短 | 桌面即可測，10 分鐘 |
| — | 手繪圖的控制點密度 | 8 點是分片線性，非線性誇張下三角形邊界會有折角 |

---

## 今天之後的路線

```
實地測 GPS → 修（若有問題）→ 移除追蹤日誌
    ↓
任務 D：地方層地圖（spec → 覆核 → plan → 覆核 → 執行）
    ↓                     順帶解決 PRE-8 路網、裁決 Q15/Q16
任務 A：遭遇系統
    ↓
任務 B：行李箱背包
```

---

## 昨天學到的（避免重蹈）

1. **推測前先取資料。** 我對 `REAL=0` 推測了三次原因（平台阻擋、模式沒開、Fused 不轉發），三次都錯。解決問題的是那行逐筆日誌。
2. **自己做的診斷會誤導自己。** `FIX ok:222` 被虛擬來源空轉灌爆，讓「一筆都沒收到」看起來像「收了 222 筆卻不動」。
3. **測試替身只能驗證假設自洽，不能驗證假設正確。** 權限語意讀錯（`denied` 是「去請求」不是「被拒絕」），147 條測試全綠，真機一按就現形。
4. **測試綠燈不等於功能存在。** 真實 GPS 來源整個沒做，而所有測試都通過——因為沒有任何測試需要它。
