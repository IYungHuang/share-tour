# SPEC — Share Tour 角色動作與動畫系統

狀態：**Draft v1 — 待覆核**
流程位置：`spec → 覆核 → plan → 覆核 → 執行計劃 → 覆核`
上位文件：`CLAUDE.md`、`CROSS_CUTTING_CONSTRAINTS.md`
相關現況：`lib/game/components/player_component.dart`、`lib/game/universal_overworld_game.dart`

## 1. 目的

把目前玩家的 `CircleComponent` 佔位圖標，逐步替換為可由動作命令驅動的角色動畫。

本系統只處理角色的**視覺狀態與動畫播放**。GPS、位置投影、背包、時間、事件、體力、任務、NPC 行為均不屬於本系統。

核心資料流：

```text
CharacterActionModel
        ↓
CharacterActionController
        ↓
CharacterAnimationResolver
        ↓
CharacterComponent / PlayerComponent
        ↓
Flame SpriteAnimation
```

## 2. 設計邊界

### 2.1 必須保留

- `UniversalOverworldGame` 繼續負責角色建立、位置同步、生命週期與相機跟隨。
- `PlayerComponent` 繼續提供玩家專用 façade。
- `PlayerComponent.syncTo(Vector2 renderedPixel)` 行為不變：複製座標值，不與來源 `Vector2` 共用可變實例。
- 位置來源仍由既有 domain/location 管線提供。
- 動畫渲染使用 Flame 內建 `SpriteAnimation`，不新增動畫套件。

### 2.2 明確不做

- 不由每幀位置、速度或 GPS 狀態猜測角色動作。
- 不把動作規則塞進 `PlayerComponent`。
- 不把角色動作接入背包、時間、事件日誌、體力、任務或 GPS domain。
- 不做多層 sprite 合成；首版每個 resolved action 只對應一個 Flame 動畫。
- 不把對話圖、半身圖或表情圖當作地圖角色 sprite。
- 不把 `run`、`dash` 視為同一動作。
- 不複製 `OceanWavesComponent` 的硬編 sprite rect 做角色資產解析。
- 不在首版建立完整 NPC 行為樹、尋路或 AI。
- 不做骨骼動畫。

## 3. 動作模型

### 3.1 動作通道

角色動作由可組合通道構成，不使用包含所有組合的大型 enum。

| 通道 | 首版值 |
|---|---|
| Locomotion | `idle`、`walk`、`run`、`dash`、`jump` |
| Posture | `standing`、`crouching`、`sitting`、`supine`、`prone` |
| Activity | `eat`、`drink`、`sleep` |
| HeldItem | `none`、`oneHand`、`twoHands` |
| Special | 角色專屬、命名空間限定，例如 `guide.point` |

預設狀態為：`idle + standing + none`。未指定通道不得產生隱含的外部副作用。

合法組合例：

- `sit + drink`
- `supine + sleep`
- `walk + oneHand`
- `run + special`

動作模型相等性必須包含所有通道值。相同模型不得因建立時間或物件實例不同而被視為不同動作。

### 3.2 動作描述

每個可解析動作必須提供以下視覺播放契約：

- 是否循環 `loop`
- 播放時長或等價的 FPS 與 frame 數
- 優先級 `priority`
- 是否可被新命令中斷 `canInterrupt`
- 不可用時的明確 `fallbackAction`
- 動畫資產鍵 `animationKey`

播放契約只描述視覺行為，不得包含物品扣除、數值變化、任務完成或其他 domain 命令。

### 3.3 特殊動作

特殊動作使用角色命名空間，不加入共用 locomotion、posture、activity 或 held-item 值。

首批命名例：

- `guide.point`
- `guide.waveFlag`
- `protagonist.inspectArtifact`
- `npc.openShop`
- `npc.greet`

角色能力由 capability registry 判斷。角色不具備某特殊動作時，命令不得播放該動作，必須走明確 fallback。

## 4. 播放控制契約

### 4.1 控制操作

控制器提供四種行為：

- `play(action)`：請求播放動作。
- `setDirection(direction)`：設定 `front`、`left`、`back` 或 `right`。
- `stop()`：停止目前播放，回到可解析的 fallback，預設為 idle。
- `update(dt)`：只推進目前動畫時間與一次性動作完成狀態。

控制器不得讀取 GPS、位置、速度、背包、時間或事件 provider。

### 4.2 切換規則

1. 相同 action 且方向未變時，`play` 不得重設目前 frame 或播放時間。
2. action 或方向改變時，才切換 resolved animation。
3. 方向改變會切換到新方向動畫，播放從該動畫第一 frame 開始。
4. 新 action 若被目前 action 阻擋，控制器維持目前播放，不偷偷改成 walk 或 idle。
5. 新 action 可在目前 action `canInterrupt == true` 時中斷；高優先級命令可中斷低優先級命令。相同優先級不得繞過 `canInterrupt`。
6. `stop()` 不會改變角色位置，也不會改變外部 domain 狀態。
7. 不支援 action 時，控制器必須使用該 action 的 `fallbackAction`；fallback 仍無法解析時，使用 idle。
8. fallback 解析不得無限循環；循環或缺失 fallback 視為無效，直接落到 idle。

### 4.3 一次性動作

1. `loop == false` 的 action 播放至最後一 frame 後視為完成。
2. 完成後優先回到切換前仍有效、可恢復的 action。
3. 原 action 不再有效或不存在時，回到該 action 的 `fallbackAction`；仍無效時回到 idle。
4. 完成一次性 action 不得重播同一 action，也不得重設已完成 action 的 frame。
5. loop action 不得因 `update(dt)` 自動完成或回到 idle。

### 4.4 首版優先級最低契約

下表固定首版最小行為，後續角色可擴充但不得改變既有語意：

| Action | Loop | 可被 walk 覆蓋 | 完成後 fallback |
|---|---:|---:|---|
| `idle` | 是 | 是 | `idle` |
| `walk` | 是 | 是 | `idle` |
| `run` | 是 | 是 | `idle` |
| `dash` | 否 | 否 | `idle` |
| `jump` | 否 | 否 | `idle` |
| `eat` | 否 | 是 | `idle` |
| `drink` | 否 | 是 | `idle` |
| `sleep` | 是 | 否 | `idle` |

`dash` 可存在於 Flame 接線階段，但不得被當成 `run` 的別名或自動 fallback。

## 5. 動畫解析契約

### 5.1 單一 resolved animation

解析結果必須是單一動畫描述，包含：

- character identity
- action identity
- direction
- asset path
- frame width / height
- frame count
- FPS
- loop
- anchor

首版不把 locomotion、posture、activity、held item 分別渲染後再合成。若某組合沒有對應資產，依 action 契約 fallback。

### 5.2 解析決定性

相同 character、action、direction 與相同 manifest 輸入，必須得到相同解析結果。解析不得依賴：

- 當下時間
- GPS 座標
- 隨機數
- Flame 元件目前 frame
- 外部 mutable global state

解析器不得自行推導角色能力；特殊動作能力檢查由 capability registry 完成後，解析器只處理已授權 action。

## 6. 資產 manifest 契約

### 6.1 必要欄位

每筆動畫資產至少包含：

| 欄位 | 契約 |
|---|---|
| `characterId` | 穩定角色識別值 |
| `actionId` | 動作或動作組合識別值 |
| `direction` | `front` / `left` / `back` / `right` |
| `assetPath` | Flutter asset 路徑 |
| `frameWidth` | 正整數，單 frame 寬度 |
| `frameHeight` | 正整數，單 frame 高度 |
| `frameCount` | 正整數 |
| `fps` | 正數 |
| `loop` | 是否循環 |
| `anchor` | 角色基準錨點 |

### 6.2 Sprite sheet 契約

- 每張 sheet 的方向順序固定為 `front / left / back / right`。
- manifest 的 frame 尺寸必須能完整切分圖片，不得依程式猜測 rect。
- 角色 sprite 必須是 RGBA，透明背景不可用 RGB 假透明替代。
- sheet 尺寸、每格尺寸、每方向 frame 數必須在同一角色資產集合內一致；男女角色可有不同契約，但各自必須自洽。
- `run`、`dash` 必須有不同 `actionId`；缺少其中一者時不得靜默共用另一者資產。
- `dialogue`、`halfbody`、表情變體與 overworld sprite 必須使用不同資產類型識別，不得互相 fallback。

### 6.3 Manifest 驗證

驗證失敗必須在載入或測試階段明確報錯，不得以錯誤 frame 尺寸繼續渲染。至少拒絕：

- RGB 或其他非 RGBA 角色圖。
- 任一尺寸、frameCount 或 FPS 非正值。
- 圖片尺寸無法由 manifest frame 尺寸與 frameCount 合法切分。
- 缺少四方向資料。
- 重複 action/direction 鍵。
- `run` 與 `dash` 使用同一 action identity。
- fallback 指向不存在 action，或 fallback 形成循環。

目前已知資產阻塞：

- `guide_female_overworld_sheet_v3_generated.png` 目前是 RGB，不符合 RGBA 契約。
- 男女 sheet 的尺寸與格子契約尚未完全固定。
- 尚無正式 manifest。

因此 Phase 0 必須先完成資產契約與驗證，Phase 2 才能接 Flame 真實 sprite。

## 7. Flame 接線契約

### 7.1 CharacterComponent 職責

共用角色元件負責：

- 持有目前 resolved Flame sprite animation。
- 持有角色 anchor。
- 依 `update(dt)` 播放 frame。
- 使用 `FilterQuality.none` 維持像素硬邊。
- 將 resolved animation render 成角色圖像。

共用角色元件不得負責：

- GPS 或位置投影。
- 相機跟隨。
- 動作推斷。
- 背包、時間、事件、體力或任務規則。

### 7.2 PlayerComponent façade

`PlayerComponent` 改為玩家專用 façade，內部使用共用角色元件與播放核心。

相容要求：

- `syncTo(Vector2 renderedPixel)` 繼續可用。
- `syncTo` 只複製位置值，不取得或保存位置來源的可變引用。
- 玩家元件仍可被 `UniversalOverworldGame` 以目前方式加入 world。
- 對既有位置同步與 camera follow 的行為不得產生回歸。

### 7.3 UniversalOverworldGame 接線

遊戲層負責：

- 建立角色元件。
- 將 domain 已算出的 rendered pixel 傳給 `syncTo`。
- 傳入 action 與 direction 命令。
- 推進角色元件生命週期。
- 保持目前相機跟隨、縮放、地圖切換與位置同步流程。

遊戲層不得以位置差、速度或每幀距離變化自動猜測 walk/run/dash。

動畫命令與位置同步必須是兩條獨立資料流：位置更新不代表 action 更新，action 更新不代表位置更新。

## 8. 分階段交付

### Phase 0：資產契約

不接 Flame。

交付：

- action ID、direction、frame 尺寸、FPS、loop、anchor、fallback 的固定規則。
- 角色 sprite RGBA 驗證。
- 男女角色 sheet 格子契約。
- manifest 欄位與驗證規則。

通過條件：所有首版要接線的角色資產均能由 manifest 通過驗證，且 `run`、`dash` identity 分離。

### Phase 1：純 Dart 播放核心

交付動作模型、方向、播放狀態、控制器與解析行為。此階段不得 import Flutter 或 Flame。

至少驗證：

- idle → walk
- walk → run
- jump → idle
- sleep 不被 walk 覆蓋
- 一次性特殊動作完成後回 fallback
- 相同 action 不重設 frame
- 不支援 action → 明確 fallback
- 方向切換 → 切換對應方向動畫
- fallback 循環 → idle

### Phase 2：Flame 接線

先接：`idle`、`walk`、`dash`。

再接：`run`、`jump`。

驗證位置同步、相機跟隨、縮放、地圖切換、anchor、像素濾鏡與元件移除生命週期。

### Phase 3：通用生活動作

加入純動畫命令。下列 shorthand 對應動作模型通道值：`crouch` 對應 `posture=crouching`，`sit` 對應 `posture=sitting`；`oneHand` 與 `twoHands` 對應 `heldItem`：

- `eat`
- `drink`
- `sleep`
- `crouch`
- `sit`
- `supine`
- `prone`
- `oneHand`
- `twoHands`

這些命令首版不連動物品、時間、體力或任務。

### Phase 4：NPC 與特殊動作

加入共用角色圖層、角色能力 registry 與特殊動作 registry。

主角與 NPC 共用播放核心；NPC 行為決策仍屬後續系統，不在本 SPEC 實作。

## 9. 驗收條件

### AC-CA-01 純模型邊界

動作模型、方向、播放狀態、控制器與解析器可在無 Flutter、Flame、GPS、Riverpod 的測試環境執行。架構測試確認 `domain/` 不出現 framework import。

### AC-CA-02 組合動作

同一角色可表達 `sit + drink`、`supine + sleep`、`walk + oneHand`、`run + special` 四種組合；模型不需要新增一個代表完整組合的大型 enum。

### AC-CA-03 不重設相同 action

播放 action 後記錄目前 frame，重複呼叫相同 action 並推進相同 dt；播放 frame 必須接續，不得回到第一 frame。

### AC-CA-04 action 或方向切換

action 或 direction 任一改變時，resolved animation key 必須改變；方向切換從新動畫第一 frame 開始。

### AC-CA-05 中斷與優先級

`sleep` 播放期間收到 `walk`，sleep 維持播放；可中斷 action 收到合法高優先級 action 時才切換；被拒絕命令不得改變目前狀態。

### AC-CA-06 一次性完成

`jump`、`dash` 或特殊一次性 action 播放完畢後，只回到有效前一狀態或明確 fallback；不得停在不存在的 frame，也不得重播自身。

### AC-CA-07 fallback

解析器遇到不存在 action、缺方向資產、能力不允許特殊動作、fallback 缺失或 fallback 循環時，結果明確落到 idle 或契約指定的有效 fallback；不得拋出未處理例外，也不得選用相鄰但語意不同的資產。

### AC-CA-08 決定性解析

相同 manifest 與相同 character/action/direction 輸入重複解析，結果的 asset path、frame geometry、FPS、loop、anchor 完全相同。

### AC-CA-09 manifest 驗證

測試拒絕 RGB、非法尺寸、非法 frameCount、非法 FPS、無法切分的 sheet、缺方向、重複鍵、run/dash identity 共用與 fallback 循環。

### AC-CA-10 玩家位置相容

既有 `PlayerComponent` 測試繼續通過：`syncTo` 複製座標，來源向量後續變更不會改變元件位置。

### AC-CA-11 遊戲位置與動作解耦

位置同步多次發生但沒有 action 命令時，action 狀態不變；action 命令發生但沒有位置更新時，角色位置不變。

### AC-CA-12 Flame 像素渲染

接線煙霧測試確認角色使用 `FilterQuality.none`、anchor 來自 manifest，且元件加入與移除不破壞現有 world、camera follow、zoom 與 map switch。

### AC-CA-13 首版範圍

測試與程式碼搜尋確認角色動作系統沒有新增 GPS、背包、時間、事件、體力、任務或 NPC 行為依賴。

## 10. 完成定義

本 SPEC 通過後，才可進入 plan。plan 必須把 Phase 0–4 拆成可獨立測試的工作，並在 Flame 接線前先完成純 Dart 核心與 manifest 驗證。

Phase 2 以前不修改 `UniversalOverworldGame` 的位置同步語意；Phase 2 完成後，既有位置同步、相機跟隨、縮放與地圖切換測試必須維持通過。
