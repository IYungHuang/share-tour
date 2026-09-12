# SPEC — Share Tour 角色動作與動畫系統

狀態：**Draft v4 — 待第四輪覆核**
流程位置：`spec → 覆核 → plan → 覆核 → 執行計劃 → 覆核`
上位文件：`CLAUDE.md`、`CROSS_CUTTING_CONSTRAINTS.md`
相關現況：`lib/game/components/player_component.dart`、`lib/game/universal_overworld_game.dart`

> v4 修訂：依第三輪 peer review 補上 Game pre-load 命令時機、相容 constructor 依賴規則、special priority 單一來源、loop 邊界 AC、無 padding 透明例外、`expression` assetKind，並移除 spec 對固定 package path 與實作算法的綁定。

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
| Activity | `none`、`eat`、`drink`、`sleep` |
| HeldItem | `none`、`oneHand`、`twoHands` |
| Special | 角色專屬、命名空間限定，例如 `guide.point` |

預設狀態為：`idle + standing + none`。未指定通道不得產生隱含的外部副作用。

合法組合例：

- `sit + drink`
- `supine + sleep`
- `walk + oneHand`
- `run + special`

動作模型相等性必須包含所有通道值。相同模型不得因建立時間或物件實例不同而被視為不同動作。

### 3.2 Canonical action key

每個 action 使用固定欄位順序產生 canonical key：

```text
locomotion=<value>|posture=<value>|activity=<value>|heldItem=<value>|special=<value>
```

缺省值固定為 `idle`、`standing`、`none`、`none`、`none`；不得省略欄位、交換順序或使用大小寫差異。`special` 值使用角色命名空間，例如 `guide.point`。

短名稱只是輸入別名，合併前必須轉成 canonical key：

- `sit` → `posture=sitting`
- `drink` → `activity=drink`
- `sit + drink` → `locomotion=idle|posture=sitting|activity=drink|heldItem=none|special=none`
- `walk + oneHand` → `locomotion=walk|posture=standing|activity=none|heldItem=oneHand|special=none`
- `run + guide.point` → `locomotion=run|posture=standing|activity=none|heldItem=none|special=guide.point`

同一通道出現兩個不同值時，命令無效，不得以後者覆蓋前者。不同通道可組合；未提供通道使用缺省值。

### 3.3 動作描述

每個可解析動作必須提供以下視覺播放契約：

- 是否循環 `loop`
- 播放時長或等價的 FPS 與 frame 數
- 優先級 `priority`
- 是否可被新命令中斷 `canInterrupt`
- 不可用時的明確 `fallbackAction`
- 動畫資產鍵 `animationKey`

播放契約只描述視覺行為，不得包含物品扣除、數值變化、任務完成或其他 domain 命令。
每個 canonical action key 對應一個完整 descriptor；組合 action 不使用局部通道 precedence。`run + guide.point` 若要播放，必須註冊完整 canonical key 與自己的 priority、loop、canInterrupt、fallback、animationKey；未註冊組合直接按 unsupported action fallback，不得自動拆成 `run` 或 `guide.point`。組合 descriptor 不繼承或平均各通道 descriptor 欄位。

### 3.4 特殊動作

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
- `update(dt)`：控制器唯一推進播放 elapsed、frame index 與一次性動作完成狀態的入口。

控制器不得讀取 GPS、位置、速度、背包、時間或事件 provider。
控制器是播放時鐘唯一擁有者。Flame 元件不得再以 `SpriteAnimationTicker` 或其他自有時鐘推進 frame；Flame 只依控制器輸出的 frame index render。

### 4.2 切換規則

1. 相同 action 且方向未變時，`play` 不得重設目前 frame 或播放時間。
2. action 或方向改變時，才切換 resolved animation。
3. 方向改變會切換到新方向動畫，但保留目前 action 的 normalized playback progress。loop action 在每個完整 duration 後回到第一 frame；非 loop action 到達 duration 後停在最後 frame。新方向以相同 normalized progress 映射；一次性 action 的完成狀態不因轉向重置。
4. 新 action 若被目前 action 阻擋，控制器維持目前播放，不偷偷改成 walk 或 idle。
5. 先解析能力與 manifest candidate，再做中斷判定。若目前 action `canInterrupt == true`，candidate 可切換；否則只有 `candidate.priority > current.priority` 可切換。高優先級可繞過目前 action 的 `canInterrupt`；同優先級不可繞過。
6. `stop()` 不會改變角色位置，也不會改變外部 domain 狀態。
7. 不支援 action 時，控制器必須使用該 action 的 `fallbackAction`；fallback 仍無法解析時，使用 idle。
8. fallback 解析不得無限循環；循環或缺失 fallback 視為無效，直接落到 idle。

### 4.3 一次性動作

1. `loop == false` 的 action 播放至最後一 frame 後視為完成。
2. 控制器只保留一個 `resumeState`，用於第一個一次性 action 進入前的 loop action。`resumeState` 包含 action、direction 與 normalized playback progress。
3. 一次性 action 被更高優先級的一次性 action 中斷時，不建立第二層 stack；原有 `resumeState` 保留，新一次性 action 完成後直接恢復該單一 snapshot。
4. `resumeState` 無效時，回到目前完成 action 的 `fallbackAction`；仍無效時回到 idle。
5. 完成一次性 action 不得重播同一 action，也不得重設已完成 action 的 frame。
6. loop action 不得因 `update(dt)` 自動完成或回到 idle。

### 4.4 首版優先級最低契約

下表固定首版最小行為，後續角色可擴充但不得改變既有語意：

| Action | Priority | Loop | canInterrupt |
|---|---:|---:|---:|
| `idle` | 0 | 是 | 是 |
| `walk` | 10 | 是 | 是 |
| `run` | 20 | 是 | 是 |
| `eat` | 40 | 否 | 是 |
| `drink` | 40 | 否 | 是 |
| `sleep` | 50 | 是 | 否 |
| `dash` | 60 | 否 | 否 |
| `jump` | 70 | 否 | 否 |
| `special` | registry 必須明確指定 | registry 必須明確指定 | registry 必須明確指定 |

首版所有表列 action 的 fallback 均為 `idle`。特殊 action 必須在 registry 明確提供 priority、loop、canInterrupt 與 fallback；未提供者不可播放。
`80` 僅可作為個別 special descriptor 的明確值，不是全域 default；special priority 不得同時由共用表與 registry 推導。

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
- anchor（純資料 normalized `(x,y)`，每軸範圍 `0.0..1.0`）
- logical render width / height（Flame world units）
- current frame index（由 controller 輸出，不由 Flame 自行推進）

可觀察播放契約：播放開始顯示第一 frame；loop action 到達一個完整 duration 後重新顯示第一 frame；非 loop action 到達 duration 後顯示最後 frame 並完成。相同 normalized progress 在方向切換後對應新方向相同位置；具體 frame 計算留給 plan。

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
| `assetKind` | `overworld` / `dialogue` / `halfbody` / `portrait` / `expression`；本系統只接受 `overworld` |
| `assetPath` | 相對於 `assets/images/` 的路徑，例如 `guide_male/walk.png` |
| `frameWidth` | 正整數，單 frame 寬度 |
| `frameHeight` | 正整數，單 frame 高度 |
| `frameCount` | 正整數；每一 direction 的 frame 數，不是整張 sheet 總 frame 數 |
| `fps` | 正有限數值 |
| `loop` | 是否循環 |
| `anchor` | normalized `(x,y)`，每軸 `0.0..1.0` |
| `renderWidth` / `renderHeight` | 正數；角色在 Flame world 的邏輯尺寸，不由 source pixel 自動決定 |
| `directionAxis` | `row` 或 `column` |
| `sourceOrigin` | 此 action region 外框左上角的 pixel `(x,y)`，包含 region padding，非負整數 |
| `padding` | action region 四邊 pixel padding `{left, top, right, bottom}`，各值非負整數 |
| `spacing` | 相鄰 frame 間距 `{horizontal, vertical}`，各值非負整數 |
| `animationKey` | action canonical key + direction 的唯一鍵 |

### 6.2 Sprite sheet 契約

- 每張 `overworld` sheet 的方向順序固定為 `front / left / back / right`。
- `frameCount` 是每一 direction 的 frame 數。`directionAxis=row` 時，四個 direction 佔四列、每列 frame 由左至右；`directionAxis=column` 時，四個 direction 佔四欄、每欄 frame 由上至下。
- `sourceOrigin`、`padding` 與 `spacing` 必須納入切分公式，不得依程式猜測 rect。action region 外框尺寸為：`regionWidth = padding.left + frameCount * frameWidth + (frameCount - 1) * spacing.horizontal + padding.right`、`regionHeight = padding.top + 4 * frameHeight + 3 * spacing.vertical + padding.bottom`。第一個 frame 起點為 `sourceOrigin + (padding.left, padding.top)`。`directionAxis=row` 時，四個 direction 佔四列、每列 frame 由左至右；`directionAxis=column` 時，四個 direction 佔四欄、每欄 frame 由上至下。完整 region 必須位於 sheet 邊界內。
- 每筆 direction record 可指向同一 sheet；同一 `actionId` 的四筆 record 必須共用 asset path、layout、sourceOrigin、frameCount、frame 尺寸與 render size。
- 角色 sprite 必須是 RGBA，透明背景不可用 RGB 假透明替代。
- sheet 尺寸、每格尺寸、每方向 frame 數必須在同一角色資產集合內一致；男女角色可有不同契約，但各自必須自洽。
- `run`、`dash` 必須有不同 `actionId`；缺少其中一者時不得靜默共用另一者資產。
- `dialogue`、`halfbody`、表情變體與 overworld sprite 必須使用不同 `assetKind`，不得互相 fallback。

### 6.3 Manifest 驗證

載入期驗證與播放期 fallback 分開處理。

載入期驗證針對 manifest 結構與已宣告資產；失敗必須明確報錯，不得繼續載入該角色。每個角色的 `idle` 必須具備四方向有效 record。已宣告的 action 也必須具備四方向完整 record；未宣告的可選 action 不算載入錯誤，播放時走 fallback。

載入期至少拒絕：

- RGB 或其他非 RGBA 角色圖。
- 任一尺寸、frameCount、render size、padding 或 spacing 不合法。
- FPS 非正、非有限值。
- anchor 超出 `0.0..1.0`。
- asset path 不存在或圖片無法解碼。
- 圖片尺寸無法由 manifest layout、frame 尺寸、padding、spacing 與 frameCount 合法切分。
- `idle` 或已宣告 action 缺少四方向資料。
- 重複 action/direction 鍵。
- 重複 `animationKey`。
- `run` 與 `dash` 使用同一 action identity。
- 非 `overworld` assetKind 被角色動畫 manifest 宣告。
- fallback 指向不存在 action，或 fallback 形成循環。
- `sourceOrigin` 加 region 尺寸超出圖片邊界。
- declared padding 存在但 padding 像素非透明。

RGBA 是必要格式；無 padding 且 frame 內容填滿畫布時，允許 frame 全部不透明。`expression`、`dialogue`、`halfbody`、`portrait` 均不可作為 overworld action fallback。

播放期只處理合法 manifest 中「未宣告的 action」或「能力 registry 拒絕的特殊 action」：依 fallback chain 解析，無有效結果時使用該角色四方向 idle。不得把 dialogue、halfbody 或其他語意不同的 asset 當 fallback。合法 manifest 不允許已宣告 action 只缺單一方向；這類資料在載入期拒絕。

資產存在性測試同時檢查 manifest `assetPath` 對應 `assets/images/<assetPath>` 的檔案，並檢查 Flutter asset bundle 可載入該相對路徑。`loadSprite` 與 `loadSpriteAnimation` 均不得再加第二次 `assets/images/` 前綴。

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
- 呼叫 controller 的單一 `update(dt)`，再依 controller 輸出的 frame index render；不得另持有會自行推進的 animation ticker。
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

- 保留現有 `PlayerComponent({required position})` 的建構入口；新增 manifest/asset decoder 依賴必須 optional 且有既有行為相容的 default，或透過不改舊入口的 factory/setter 提供。建構子不得同步解碼圖片。
- `PlayerComponent` 建構時同步建立 controller；`onLoad` 只負責 async asset load 與 render adapter 初始化。`onLoad` 前收到的 `play`／`setDirection` 直接更新 controller，載入完成後 render controller 當前狀態，不丟失命令。
- PlayerComponent 是 world position owner；內部 CharacterComponent 使用 local zero position，不另存第二份 world position。`syncTo` 只改 façade position。
- `syncTo(Vector2 renderedPixel)` 繼續可用。
- `syncTo` 只複製位置值，不取得或保存位置來源的可變引用。
- 提供玩家專用的 `play(action)` 與 `setDirection(direction)` façade，兩者只轉送至共用播放核心。
- 初始 action 固定為 `idle + standing + none`，初始 direction 固定為 `front`。
- 玩家元件仍可被 `UniversalOverworldGame` 以目前方式加入 world。
- 對既有位置同步與 camera follow 的行為不得產生回歸。

### 7.3 UniversalOverworldGame 接線

遊戲層負責：

- 建立角色元件。
- 將 domain 已算出的 rendered pixel 傳給 `syncTo`。
- 提供 `playPlayerAction(action)` 與 `setPlayerDirection(direction)`，轉送 action/direction 命令給 `PlayerComponent`；不得另存第二份播放狀態。
- 上述 Game 命令只保證在 `onLoad` 完成後可呼叫；`onLoad` 前所需狀態必須由建構參數 `initialAction`／`initialDirection` 提供，預設為 idle/front。Game 不得在 `playerComponent` 尚未建立時直接解參考。
- 推進角色元件生命週期。
- 保持目前相機跟隨、縮放、地圖切換與位置同步流程。

遊戲層不得以位置差、速度或每幀距離變化自動猜測 walk/run/dash。

動畫命令與位置同步必須是兩條獨立資料流：位置更新不代表 action 更新，action 更新不代表位置更新。

既有 `switchMap`、camera follow、zoom 與 world lifecycle 是外部既有前置 gate 與回歸檢查項，不是本 SPEC 新增的地圖功能；本系統不得改變其既有語意。若實作基線尚未包含 `switchMap`，plan 必須先標記該 gate 未滿足，不得把 map switch 併入本系統實作。

`CharacterActionModel`、方向、播放狀態、controller 與 resolver 必須位於 domain 的純 Dart 邊界；Flame adapter、manifest asset decoding 與 `CharacterComponent` 留在 game/data 層。controller 的 `update(dt)` 只能由 CharacterComponent 的單一 update 路徑呼叫一次。

本 SPEC 固定外部行為契約，不固定 Dart 檔名、package path、Flame class hierarchy、public method 實作位置或 ticker API。純 Dart domain boundary 是必要架構約束；具體檔案拆分、公開 API 落點與 Flame adapter 選型由後續 plan 決定。

## 8. 分階段交付

### Phase 0：資產契約

不接 Flame。

交付：

- action ID、direction、frame 尺寸、FPS、loop、anchor、fallback 的固定規則。
- canonical action key、同通道衝突規則與 shorthand 正規化。
- 角色 sprite RGBA 驗證。
- 男女角色 sheet layout、padding、spacing、每方向 frameCount 與 logical render size 契約。
- manifest 欄位與驗證規則。

通過條件：所有首版要接線的角色資產均能由 manifest 通過驗證，且 `run`、`dash` identity 分離。

### Phase 1：純 Dart 播放核心

交付動作模型、canonical key、方向、播放狀態、控制器與解析行為。此階段不得 import Flutter 或 Flame；controller 擁有唯一 playback clock，測試不得依賴 Flame ticker。

至少驗證：

- idle → walk
- walk → run
- jump → idle
- sleep 不被 walk 覆蓋
- 一次性特殊動作完成後回 fallback
- 相同 action 不重設 frame
- 不支援 action → 明確 fallback
- 方向切換 → 切換對應方向動畫且保留 normalized progress
- fallback 循環 → idle
- walk → dash → jump → 恢復 walk 的單層 resumeState

### Phase 2：Flame 接線

先接：`idle`、`walk`、`dash`。

再接：`run`、`jump`。

驗證位置同步、相機跟隨、縮放、地圖切換、anchor、logical render size、像素濾鏡、asset 相對路徑與元件移除生命週期。

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

動作模型、方向、播放狀態、控制器與解析器位於 domain 的純 Dart boundary，可在無 Flutter、Flame、GPS、Riverpod 的測試環境執行。架構測試確認該 boundary 不出現 framework import。

### AC-CA-02 組合動作

同一角色可表達 `sit + drink`、`supine + sleep`、`walk + oneHand`、`run + special` 四種組合；每組合產生固定欄位順序的 canonical key；同通道衝突命令被拒絕；模型不需要新增一個代表完整組合的大型 enum。

### AC-CA-03 不重設相同 action

播放 action 後記錄目前 frame，重複呼叫相同 action 並推進相同 dt；播放 frame 必須接續，不得回到第一 frame。

### AC-CA-04 action 或方向切換

action 或 direction 任一改變時，resolved animation key 必須改變；方向切換保留 normalized playback progress，不得重播一次性 action。

### AC-CA-05 中斷與優先級

`sleep` 播放期間收到 `walk`，sleep 維持播放；低優先級 action 被不可中斷 action 拒絕；高優先級 `jump` 可切換；同優先級 `special` 不得繞過 `canInterrupt`；可中斷 action 收到同優先級 `eat` 可切換；被拒絕命令不得改變目前狀態。

### AC-CA-06 一次性完成

`walk → dash → jump` 中，jump 完成後恢復 walk；dash 的一次性狀態不建立第二層 stack。無有效 `resumeState` 時回明確 fallback；不得停在不存在的 frame，也不得重播自身。

### AC-CA-07 fallback

載入期拒絕 malformed manifest；播放期遇到未宣告 action 或能力不允許特殊動作時，結果明確落到 idle 或契約指定的有效 fallback。已宣告 action 缺方向不得進入播放期，因為載入期已拒絕；不得拋出未處理例外，也不得選用相鄰但語意不同的資產。

### AC-CA-08 決定性解析

相同 manifest 與相同 character/action/direction 輸入重複解析，結果的 `assetKind`、asset path、frame geometry、FPS、loop、normalized anchor、logical render size、layout、sourceOrigin、animationKey 完全相同。current frame 由 AC-CA-14 驗證，不由 resolver 自行推進。

### AC-CA-09 manifest 驗證

測試拒絕 RGB、非法尺寸、非法 frameCount、非法 FPS、非 finite FPS、非法 anchor、非法 render size、非法 padding/spacing、無法切分的 sheet、缺方向、重複鍵、重複 animationKey、非 overworld assetKind、缺少 asset、無法解碼、run/dash identity 共用、fallback 循環、source region 越界與 declared padding 不透明；無 padding 的全不透明 frame 可通過；測試確認未宣告 optional action 走 runtime fallback。

### AC-CA-10 玩家位置相容

既有 `PlayerComponent` 測試繼續通過：`syncTo` 複製座標，來源向量後續變更不會改變元件位置。

同一 AC 同時驗證既有 `PlayerComponent({required position})` 建構入口仍可建立、`onLoad` 完成 async asset load 後不改變 façade world position；`onLoad` 前送入的 action/direction 在首次 render 可見。

### AC-CA-11 遊戲位置與動作解耦

位置同步多次發生但沒有 action 命令時，action 狀態不變；action 命令發生但沒有位置更新時，角色位置不變。

### AC-CA-12 Flame 像素渲染

接線煙霧測試確認角色使用 `FilterQuality.none`、normalized anchor 映射正確、logical render size 不依 source pixel 自動放大、asset path 只套用一次 `assets/images/` 前綴，且元件加入與移除不破壞現有 world、camera follow、zoom。若外部既有 `switchMap` gate 已存在，另確認 map switch 回歸；不得為本系統新增 map switch。

### AC-CA-13 首版範圍

測試與程式碼搜尋確認角色動作系統沒有新增 GPS、背包、時間、事件、體力、任務或 NPC 行為依賴。

### AC-CA-14 單一播放時鐘

controller 是唯一更新 elapsed、frame index 與完成狀態的元件；CharacterComponent 每次 `update(dt)` 只呼叫一次 controller。Flame ticker 不得再推進同一 animation。測試以固定 dt 驗證 frame 與完成時點只有一種結果。

### AC-CA-15 公開命令與狀態單一來源

外部呼叫 `UniversalOverworldGame.playPlayerAction(action)` 或 `setPlayerDirection(direction)` 後，命令只經 `PlayerComponent` façade 進入共用 controller；game、PlayerComponent、controller 不得各自保存互相矛盾的 action 狀態。未提供命令時，初始狀態為 `idle + standing + none + front`。

### AC-CA-16 播放邊界

固定 frameCount、FPS 與 dt 的 table-driven 測試必須驗證：播放起點顯示第一 frame；loop action 經過一個 duration 後回第一 frame，經過兩個 duration 後仍回第一 frame；非 loop action 在 duration 前顯示中間或最後有效 frame，恰好到達 duration 時顯示最後 frame 並只完成一次；方向切換不改變 normalized progress。

## 10. 完成定義

本 SPEC 通過後，才可進入 plan。plan 必須把 Phase 0–4 拆成可獨立測試的工作，並在 Flame 接線前先完成純 Dart 核心與 manifest 驗證。

Phase 2 以前不修改 `UniversalOverworldGame` 的位置同步語意；Phase 2 完成後，既有位置同步、相機跟隨、縮放與地圖切換測試必須維持通過。
