# 任務 C：GPS 追蹤與平滑位移 — 實作計劃

> **狀態（2026-09-07）：T1~T20 已於真機驗證中執行完畢。** SPEC 修訂到 v6 後的
> 增量（品質標記、裝置喚醒、刪除道路吸附＋接線分類遮罩、觸發品質契約等）
> 見 `PLAN_C_AMENDMENT_01.md`（T21~T29），本檔以下內容為 v5.1 的原始施工紀錄，
> 保留供查閱，不再是待執行清單。

> **給執行者：** 本計劃以 TDD 逐任務執行。每個步驟都是勾選項（`- [ ]`），一次做一步。
> 每個任務結束時必須：`flutter analyze` 無 issue、該任務的測試全綠、提交一次。

**目標：** 把裝置 GPS 轉成地圖上穩定可信的小人位置，並在權限缺失、精度劣化、服務關閉或圖資未涵蓋時仍可遊玩。

**架構：** 單向資料流。`domain/` 為零框架相依的純函式管線，是 TDD 的主戰場；`data/` 提供可替換的定位來源；`state/` 以 Riverpod 聚合並作為唯一寫入點；`game/` 只負責渲染與輸入，不持有遊戲數值。

**技術棧：** Flutter 3.41 / Dart 3.11、Flame 1.38、flutter_riverpod 2.6、geolocator 14.0.3、freezed 3.2 + json_serializable 6.14、vector_math 2.2。

**規格：** `SPEC_C_GPS_TRACKING.md`（v5.1）。本計劃的每個任務都標註其實作的需求與 AC 編號；執行者應同時閱讀規格。
**上位約束：** `CROSS_CUTTING_CONSTRAINTS.md`（v2）。**牴觸時以上位文件為準並回報。**
**工作規範：** `CLAUDE.md`。

---

## 全域約束

每個任務的驗收都隱含以下條件：

- **TDD**：`RED → GREEN → REFACTOR`。先寫失敗的測試，執行確認失敗，再寫最小實作。
- **`lib/domain/` 不得 import `package:flutter`、`dart:ui`、`package:flame`。** 由 Task 1 的架構測試強制。
- **時間**：任何「經過了多久」一律用注入的單調時鐘，禁止 `DateTime.now()`。持久化時戳一律 UTC。
- **識別碼**：所有持久化實體用 UUID，禁止本機自增序號。
- **隱私**：原始經緯度**永不**寫入存檔、事件或日誌。
- **向量**：只用 `package:vector_math/vector_math.dart`（**不是** `vector_math_64.dart`）。經緯度用 `double`，禁止裝入 `Vector2`。
- **抽象紀律**：核准的抽象只有 `LocationSource`、`OverworldMapManifest`、`Clock`。新增抽象前須能說出它擋住哪一條已知會變的軸。

### 本計劃新增的抽象與其正當性

| 抽象 | 擋住的變動軸 | 任務 |
|---|---|---|
| `Clock` | 牆鐘與單調時間的取得方式，且 `DateTime.now()`／`Stopwatch` 不可注入，逾時與時鐘異常規則無法在無真實等待下測試 | T2 |
| `LocationPermissionGateway` | geolocator 的權限與精度 API 全是靜態方法，不注入就無法在無真機的條件下驗證 AC-1.1~1.8（NFR-1 明文要求） | T15 |

**排程**併入 `Clock`，不另立抽象：`FixThrottle` 的 trailing 需要延後觸發，`Clock` 因此加一個 `Future<void> delay(Duration)`。多一個方法比多一條抽象便宜，且它與時間屬同一個變動軸。
- **靜態分析**：**先執行 codegen，再** `flutter analyze`，必須 0 errors / 0 warnings。
  （生成檔不進版控，乾淨 clone 上未跑 codegen 時分析必然失敗，這不是缺陷。）
- **直接相依宣告**：任何自 `lib/` import 的套件都必須在 `pubspec.yaml` 宣告，否則觸發 `depend_on_referenced_packages`。本計劃需新增兩個：`vector_math`（T1）與 `uuid`（T3）——兩者目前都只是傳遞相依。

### 生成檔的 git 慣例（本計劃裁定）

`*.freezed.dart` 與 `*.g.dart` **加入 `.gitignore`，不進版控**。
理由：生成檔的 diff 噪音大且極易產生合併衝突，而重新生成的成本只是一道指令。
代價：clone 之後、或修改任何標註類別之後，必須先執行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

此指令會寫進 `CLAUDE.md` 的慣例章節（Task 1）。

---

## 檔案結構

```
lib/
├── main.dart                                       修改：包上 ProviderScope
├── core/
│   ├── time/clock.dart                             Clock 抽象（牆鐘 + 單調）
│   ├── time/system_clock.dart                      正式實作
│   └── build_flags.dart                            可注入的建置旗標
├── domain/location/                                ← 零框架相依，TDD 主戰場
│   ├── models/
│   │   ├── geo_fix.dart                            一筆定位讀數（含已量測旗標）
│   │   ├── location_status.dart                    五維度狀態
│   │   ├── location_diagnostics.dart               診斷快照
│   │   ├── movement_event.dart                     三類持久化事件（sealed）
│   │   └── rejection_reason.dart                   丟棄原因列舉
│   ├── projection/map_manifest.dart                圖資契約（介面）
│   ├── pipeline/
│   │   ├── quality_gate.dart                       品質閘門
│   │   ├── significance_gate.dart                  顯著位移閘門（基準凍結）
│   │   ├── motion_tracker.dart                     motion 逾時判定
│   │   ├── projection_stage.dart                   範圍檢查 → 投影 → 吸附
│   │   ├── relocation_detector.dart                大跨距偵測
│   │   ├── distance_buckets.dart                   分桶距離
│   │   └── location_pipeline.dart                  §3.0 全序編排
│   ├── smoothing/position_smoother.dart            平滑位移 + 公尺換算
│   └── camera/camera_follow.dart                   相機跟隨狀態機（P1）
├── data/location/
│   ├── location_source.dart                        來源抽象
│   ├── geolocator_location_source.dart             真實 GPS
│   ├── virtual_location_source.dart                方向鍵 + 除錯
│   └── location_permission_gateway.dart            權限/服務/精度查詢抽象
├── state/location/
│   ├── location_providers.dart                     Riverpod 接線
│   └── location_controller.dart                    唯一寫入點
└── game/
    ├── map_module/                                 既有，逐步重構
    ├── components/player_component.dart            顯示點渲染
    └── universal_overworld_game.dart               修改：移除硬編碼與台灣相依

test/
├── architecture/layer_boundaries_test.dart         強制分層（AC-4.5、AC-7.7）
├── domain/location/…                               對應 domain 各檔
├── data/location/…
└── fakes/
    ├── fake_map_manifest.dart                      純數學圖資（解耦驗收核心）
    ├── fake_clock.dart
    └── fake_location_source.dart
```

---

## 任務相依圖

```
Phase 0  T1 地基 ──> T2 時鐘與旗標
                        │
Phase 1                 ├──> T3  GeoFix ────────┐
                        ├──> T4a 契約 + Fake ───┤
                        └──> T5  五維度狀態 ────┤
                                                 │
Phase 2   T3+T5 ──> T6 品質閘門 ──> T7 顯著位移  │
          T2+T5 ──> T8 motion                    │
          T4a ──┬─> T9  投影階段 ─────┐          │
                ├─> T13 平滑          │          │
          T2 ──┬──> T10 大跨距 ───────┤          │
          T3+T5 ─> T11 分桶與事件 ────┼──> T12 管線編排
                                                 │
Phase 2b  T4b 台灣 manifest 遷移（不阻擋 T6~T13，但阻擋 T18）
Phase 3   T4a+T2 ──> T14 虛擬來源
                     T15 權限（獨立）
          T14+T15 ─> T16 串流與省電
Phase 4   T12+T16 ──> T17 控制器聚合 ──> T18 Flame 橋接（需 T4b）
Phase 5   T19 相機（P1，僅需 T2）      T20 換層（P1，需 T17）
```

**可並行**：T6/T8/T9/T10/T11/T13 六者互不相干，全部是純函式。
**關鍵路徑**：T1 → T2 → T4a → T9/T13 → T12 → T17 → T18。
**T4a 與 T4b 分開的理由**：T4a 純新增，不動既有碼，完成後六個純函式任務即可開工；T4b 要改台灣 manifest 並修既有測試，是關鍵路徑外的獨立工作。

---

## Phase 0 — 地基

### Task 1：分層邊界與依賴地基

**實作：** PRE-1、PRE-9、AC-4.5、AC-7.7、生成檔慣例

**檔案：**
- 修改：`pubspec.yaml`（新增 `vector_math` 直接相依）
- 修改：`.gitignore`（忽略生成檔）
- 修改：`lib/main.dart:8-12`（包上 `ProviderScope`）
- 修改：`CLAUDE.md`（新增 codegen 指令與生成檔慣例）
- 建立：`test/architecture/layer_boundaries_test.dart`

**介面：**
- 產出：一組會在 `lib/domain/` 出現禁用 import 時失敗的測試。後續每個任務都依賴它守住邊界。

- [ ] **步驟 1：先寫失敗的架構測試**

建立 `test/architecture/layer_boundaries_test.dart`：

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// domain 層必須零框架相依，否則 TDD 迴圈需要模擬器，會慢到不可用。
/// 這條規則靠人自律守不住，所以用測試強制。
void main() {
  const forbiddenInDomain = [
    'package:flutter/',
    'dart:ui',
    'package:flame/',
    'package:geolocator/',
    'package:vector_math/vector_math_64.dart',
  ];

  List<File> dartFilesUnder(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .toList();
  }

  test('domain 層不得相依框架型別', () {
    final violations = <String>[];
    for (final file in dartFilesUnder('lib/domain')) {
      final source = file.readAsStringSync();
      for (final banned in forbiddenInDomain) {
        if (source.contains("import '$banned") ||
            source.contains('import "$banned')) {
          violations.add('${file.path} → $banned');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'domain 層出現框架相依：\n${violations.join('\n')}');
  });

  test('通用引擎不得引用具名城市模組', () {
    final violations = <String>[];
    final generic = [
      ...dartFilesUnder('lib/domain'),
      ...dartFilesUnder('lib/state'),
      File('lib/game/universal_overworld_game.dart'),
    ].where((f) => f.existsSync());

    for (final file in generic) {
      final source = file.readAsStringSync();
      if (source.contains('taiwan') || source.contains('Taiwan')) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty,
        reason: '通用引擎硬編碼了特定城市：\n${violations.join('\n')}');
  });

  test('domain 與 state 層不得引用遊戲數值模組', () {
    final violations = <String>[];
    for (final file in [
      ...dartFilesUnder('lib/domain/location'),
      ...dartFilesUnder('lib/data/location'),
    ]) {
      final source = file.readAsStringSync();
      if (source.contains("import 'package:share_tour/domain/stats/") ||
          source.contains('SurvivalStats')) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty,
        reason: '任務 C 直接碰觸遊戲數值，違反單一寫入點：\n${violations.join('\n')}');
  });
}
```

> **關於本任務的 TDD**：架構守衛測試不走典型的 RED→GREEN。第一條在 `lib/domain/` 尚不存在時掃到空集合而恆綠，第二條會紅並隨即被 skip。這是守衛測試的本質——它們的價值在於**未來**某次改動讓它們變紅。計劃誠實標註此事，不宣稱它是 TDD 迴圈。

- [ ] **步驟 2：執行，確認第二條測試失敗**

```bash
flutter test test/architecture/layer_boundaries_test.dart
```

預期：「通用引擎不得引用具名城市模組」FAIL —— `lib/game/universal_overworld_game.dart` 目前 import 了 `taiwan_geo_calibrator.dart`。這正是 PRE-3，Task 18 才會清償。

- [ ] **步驟 3：暫時將該條標記為已知失敗**

在該 test 加上：

```dart
    }, skip: 'PRE-3：universal_overworld_game 仍直呼台灣校準器，Task 18 清償');
```

> 用 `skip` 而非刪除，理由：紅燈誠實可見。Task 18 會把它拿掉。

- [ ] **步驟 4：新增 vector_math 直接相依**

```bash
flutter pub add vector_math
```

理由：`lints 6.1.0` 的 `depend_on_referenced_packages` 規則會在 `lib/` 直接 import 未宣告的套件時告警，違反 0 warnings 要求。目前它只是 flame 的傳遞相依。

- [ ] **步驟 5：忽略生成檔**

在 `.gitignore` 末尾加入：

```
# Code generation output (run: dart run build_runner build --delete-conflicting-outputs)
*.freezed.dart
*.g.dart
```

- [ ] **步驟 6：接上 Riverpod 作用域**

`lib/main.dart` 的 `main()` 改為：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverworldScaffold(),
    ),
  ));
}
```

並加上 `import 'package:flutter_riverpod/flutter_riverpod.dart';`。

- [ ] **步驟 7：記錄慣例**

在 `CLAUDE.md` 的「慣例」章節加入：

```markdown
- 生成檔（`*.freezed.dart`、`*.g.dart`）不進版控。clone 後或修改標註類別後執行：
  `dart run build_runner build --delete-conflicting-outputs`
```

- [ ] **步驟 8：驗證並提交**

```bash
flutter analyze && flutter test
git add -A
git commit -m "chore: enforce layer boundaries and wire ProviderScope

The domain layer must stay free of Flutter, Flame and geolocator types,
or its tests need a simulator and the TDD loop becomes unusable. That
rule does not survive on discipline alone, so a test now reads the
sources and fails on a forbidden import.

One boundary test is skipped rather than deleted: the overworld game
still calls the Taiwan calibrator directly, which is PRE-3 and gets paid
off later. A skipped test keeps that visible.

Also declares vector_math directly, since importing a transitively
available package trips depend_on_referenced_packages, and ignores
generated sources, which merge badly and cost one command to rebuild."
```

---

### Task 2：時鐘與建置旗標

**實作：** NFR-3、AC-10.4、AC-12.2 的前置

**檔案：**
- 建立：`lib/core/time/clock.dart`
- 建立：`lib/core/time/system_clock.dart`
- 建立：`lib/core/build_flags.dart`
- 建立：`test/fakes/fake_clock.dart`
- 測試：`test/core/time/clock_test.dart`

**介面：**
- 產出：
  - `abstract class Clock { DateTime nowUtc(); Duration get elapsed; }`
  - `class SystemClock implements Clock`
  - `class FakeClock implements Clock { void advance(Duration d); void setWallClock(DateTime t); }`
  - `class BuildFlags { final bool isRelease; const BuildFlags({required this.isRelease}); }`

- [ ] **步驟 1：先寫失敗的測試**

建立 `test/core/time/clock_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/core/time/clock.dart';
import '../../fakes/fake_clock.dart';

void main() {
  test('單調時間不受牆鐘調整影響', () {
    final clock = FakeClock();
    final before = clock.elapsed;

    // 使用者把系統時間往回調一天
    clock.setWallClock(clock.nowUtc().subtract(const Duration(days: 1)));
    clock.advance(const Duration(seconds: 30));

    expect(clock.elapsed - before, const Duration(seconds: 30),
        reason: '調整牆鐘不得影響已經過的單調時間');
  });

  test('牆鐘一律為 UTC', () {
    final clock = FakeClock();
    expect(clock.nowUtc().isUtc, isTrue);
  });

  test('單調時間只增不減', () {
    final clock = FakeClock();
    final t0 = clock.elapsed;
    clock.advance(const Duration(milliseconds: 1));
    expect(clock.elapsed, greaterThan(t0));
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

```bash
flutter test test/core/time/clock_test.dart
```

預期：FAIL，`clock.dart` 不存在。

- [ ] **步驟 3：寫最小實作**

`lib/core/time/clock.dart`：

```dart
/// 時間來源抽象。
///
/// 分成兩種是因為它們會在不同時候壞掉：牆鐘會被使用者調整、被 NTP 校時回跳、
/// 跨時區改變；單調時間不會。任何「經過了多久」的判定都必須用後者，否則玩家
/// 調一下系統時間就能跳過冷卻，跨時區旅行還會產生負數時距——而跨時區旅行正是
/// 這款遊戲的核心情境。
abstract class Clock {
  /// 牆鐘時間，一律 UTC。用於持久化與顯示。
  DateTime nowUtc();

  /// 自某個未指定起點以來經過的時間。只增不減，不受時鐘調整影響。
  Duration get elapsed;
}
```

`lib/core/time/system_clock.dart`：

```dart
import 'clock.dart';

class SystemClock implements Clock {
  SystemClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Duration get elapsed => _stopwatch.elapsed;
}
```

`test/fakes/fake_clock.dart`：

```dart
import 'package:share_tour/core/time/clock.dart';

class FakeClock implements Clock {
  DateTime _wall = DateTime.utc(2026, 1, 1);
  Duration _elapsed = Duration.zero;

  void advance(Duration d) {
    _elapsed += d;
    _wall = _wall.add(d);
  }

  /// 只動牆鐘，不動單調時間——模擬使用者調整系統時間或 NTP 回跳。
  void setWallClock(DateTime t) => _wall = t.toUtc();

  @override
  DateTime nowUtc() => _wall;

  @override
  Duration get elapsed => _elapsed;
}
```

`lib/core/build_flags.dart`：

```dart
/// 建置旗標以值傳遞而非編譯期常數，這樣單一建置下就能測試兩側行為。
/// 若用 kReleaseMode，release 專屬的分支在測試裡永遠跑不到。
class BuildFlags {
  const BuildFlags({required this.isRelease});

  const BuildFlags.debug() : isRelease = false;
  const BuildFlags.release() : isRelease = true;

  final bool isRelease;
}
```

- [ ] **步驟 4：執行，確認通過**

```bash
flutter test test/core/time/clock_test.dart
```

預期：3 tests passed。

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add injectable clock and build flags

Wall clock and monotonic time are separated because they fail in
different ways: the wall clock moves when a user changes the system
time, when NTP corrects, and across time zones, while monotonic time
does not. Every elapsed-time decision uses the latter — otherwise
changing the device clock skips cooldowns, and crossing a time zone
yields negative intervals, which is the core scenario of this game.

Build flags are a value rather than a compile-time constant so a single
build can test both sides of a release-only branch."
```

---
## Phase 1 — 契約與型別

### Task 3：GeoFix 值型別

**實作：** REQ-C-02 規則 2（含已量測旗標）

**檔案：**
- 建立：`lib/domain/location/models/geo_fix.dart`
- 測試：`test/domain/location/models/geo_fix_test.dart`

**介面：**
- 產出：`GeoFix`，欄位 `latitude`、`longitude`（`double`）、`accuracyMeters`、`hasAccuracy`、`speedMetersPerSecond`、`hasSpeed`、`speedAccuracy`、`hasSpeedAccuracy`、`timestampUtc`、`isMocked`、`sourceMode`。
- 產出：`enum SourceMode { gps, virtual }`。

- [ ] **步驟 1：先寫失敗的測試**

`test/domain/location/models/geo_fix_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';

GeoFix fix({bool hasAccuracy = true, double accuracy = 20}) => GeoFix(
      latitude: 25.034,
      longitude: 121.564,
      accuracyMeters: accuracy,
      hasAccuracy: hasAccuracy,
      speedMetersPerSecond: 1.4,
      hasSpeed: true,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 1),
      isMocked: false,
      sourceMode: SourceMode.gps,
    );

void main() {
  test('時戳必須為 UTC', () {
    expect(fix().timestampUtc.isUtc, isTrue);
  });

  test('未量測精度時，旗標與值分開表達', () {
    // 平台在無法量測時回傳 0.0 佔位值。若不帶旗標，下游會把
    // 「未量測」當成「零誤差」，精度閘門與顯著性閘門會同時失效。
    final f = fix(hasAccuracy: false, accuracy: 0);
    expect(f.hasAccuracy, isFalse);
    expect(f.accuracyMeters, 0);
  });

  test('相同內容的兩個實例相等', () {
    expect(fix(), equals(fix()));
  });

  test('copyWith 不改動其他欄位', () {
    final f = fix().copyWith(accuracyMeters: 50);
    expect(f.accuracyMeters, 50);
    expect(f.latitude, 25.034);
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

```bash
flutter test test/domain/location/models/geo_fix_test.dart
```

預期：FAIL，`geo_fix.dart` 不存在。

- [ ] **步驟 3：寫實作**

`lib/domain/location/models/geo_fix.dart`：

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'geo_fix.freezed.dart';

/// 一筆位移的產生方式。不可由下游竄改。
enum SourceMode { gps, virtual }

/// 一筆定位讀數。
///
/// 經緯度刻意用 double 而非向量型別：vector_math 的 Vector2 是 Float32 儲存，
/// 在台灣的經度量級量化間隔約 0.77 公尺，會吃掉判定所需的精度。
@freezed
abstract class GeoFix with _$GeoFix {
  const factory GeoFix({
    required double latitude,
    required double longitude,
    required double accuracyMeters,

    /// 平台是否確實量測了精度。為 false 時 accuracyMeters 是 0.0 佔位值，
    /// 不是「零誤差」。
    required bool hasAccuracy,
    required double speedMetersPerSecond,

    /// 為 false 時 speedMetersPerSecond 是 0.0 佔位值，而 0.0 同時也是
    /// 合法的靜止讀數，兩者無法從值本身分辨。
    required bool hasSpeed,
    required double speedAccuracy,
    required bool hasSpeedAccuracy,
    required DateTime timestampUtc,
    required bool isMocked,
    required SourceMode sourceMode,
  }) = _GeoFix;
}
```

- [ ] **步驟 4：生成並執行**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/domain/location/models/geo_fix_test.dart
```

預期：4 tests passed。

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add GeoFix value type with measured flags

The platform returns 0.0 as a placeholder when it cannot measure
accuracy or speed, and 0.0 is also a legitimate reading for both. A
consumer that filters on the value alone treats an unmeasured position
as perfectly accurate and an unmeasured speed as stationary, which
silently disables both the accuracy gate and the speed gate. The flags
keep the two cases distinguishable.

Latitude and longitude are doubles rather than a vector: the vector
library stores Float32, whose quantisation at Taiwan's longitudes is
about 0.77 metres."
```

---

### Task 4a：圖資契約與 FakeMapManifest（純新增，不動既有碼）

**實作：** §2.2 契約、AC-4.2、DoD-3

**檔案：**
- 建立：`lib/domain/location/projection/map_manifest.dart`
- 建立：`test/fakes/fake_map_manifest.dart`
- 測試：`test/domain/location/projection/map_manifest_contract_test.dart`

**介面（產出）：**

```dart
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class PoiMarker {
  const PoiMarker({required this.id, required this.pixel,
                   required this.triggerRadiusMeters});
  final String id;
  final Vector2 pixel;
  final double triggerRadiusMeters;
}

abstract class OverworldMapManifest {
  String get mapId;
  String get assetPath;
  Vector2 get mapDimensions;
  int get oceanColorArgb;
  Vector2 get defaultSpawnPixel;
  double get dpadSpeedPixelsPerSecond;
  double get snapLimitMeters;
  List<Vector2> get roadNodes;
  List<PoiMarker> get poiNodes;

  bool containsGeo(double lat, double lng);
  Vector2 projectToPixel(double lat, double lng);
  GeoPoint unprojectToGeo(Vector2 pixel);
  Vector2 snapToRoad(Vector2 pixel);
  double metersPerPixelAt(Vector2 pixel);
}
```

- [ ] **步驟 1：先寫失敗的契約測試**

`test/domain/location/projection/map_manifest_contract_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import '../../../fakes/fake_map_manifest.dart';

void main() {
  test('反投影是投影的逆運算，誤差小於 2 像素', () {
    final m = FakeMapManifest.linear();
    final pixel = Vector2(120, 240);
    final geo = m.unprojectToGeo(pixel);
    final back = m.projectToPixel(geo.latitude, geo.longitude);
    expect((back - pixel).length, lessThan(2.0));
  });

  test('範圍邊界含入', () {
    final m = FakeMapManifest.linear();
    expect(m.containsGeo(FakeMapManifest.minLat, FakeMapManifest.minLng), isTrue);
    expect(m.containsGeo(FakeMapManifest.maxLat, FakeMapManifest.maxLng), isTrue);
    expect(m.containsGeo(FakeMapManifest.maxLat + 1, FakeMapManifest.maxLng), isFalse);
  });

  test('換一個圖資模組，相同經緯度得到不同像素（AC-4.2）', () {
    final a = FakeMapManifest.linear();
    final b = FakeMapManifest.linear(originPixel: Vector2(500, 500));
    expect(a.projectToPixel(24.0, 121.0),
        isNot(equals(b.projectToPixel(24.0, 121.0))),
        reason: '若相同，代表投影被硬編碼在通用引擎裡而非委派模組');
  });

  test('公尺/像素比例可隨位置變化', () {
    final m = FakeMapManifest.nonLinear();
    expect(m.metersPerPixelAt(Vector2(0, 0)),
        isNot(equals(m.metersPerPixelAt(Vector2(1000, 1000)))));
  });

  test('投影呼叫計數可被觀察與重置', () {
    final m = FakeMapManifest.linear();
    m.projectToPixel(24.0, 121.0);
    expect(m.projectCallCount, 1);
    m.resetCallCounts();
    expect(m.projectCallCount, 0);
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

```bash
flutter test test/domain/location/projection/map_manifest_contract_test.dart
```

預期：FAIL，`fake_map_manifest.dart` 不存在。

- [ ] **步驟 3：建立契約檔**

`lib/domain/location/projection/map_manifest.dart` 依上方「介面」段落逐字建立，檔頭加上：

```dart
/// 圖資模組契約。「城市即實體 DLC」——底圖、投影、路網與範圍全部由外部注入，
/// 通用引擎不得含任何特定城市的演算法。
///
/// 刻意不做介面拆分：唯一需要隔離的框架型別是海洋顏色，改用 ARGB int 即可。
/// 為一個顏色欄位新增一整層繼承，擋不住任何已知會變的軸。
```

- [ ] **步驟 4：建立 FakeMapManifest**

`test/fakes/fake_map_manifest.dart`：

```dart
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';

/// 純數學圖資模組：不載入圖檔、不含真實地理資料。
///
/// 這是解耦驗收的核心（規格 §2.2、DoD-3）：若整條管線能只靠它測完，
/// 就代表沒有城市專屬邏輯洩漏進通用引擎。
class FakeMapManifest implements OverworldMapManifest {
  FakeMapManifest._({
    required Vector2 originPixel,
    required this.pixelsPerDegree,
    required this.varyScale,
  }) : _origin = originPixel;

  /// 等距線性投影，公尺/像素恆為 1.0。
  factory FakeMapManifest.linear({Vector2? originPixel}) => FakeMapManifest._(
        originPixel: originPixel ?? Vector2.zero(),
        pixelsPerDegree: 100.0,
        varyScale: false,
      );

  /// 公尺/像素隨 x 線性變化，用於驗證換算的求值契約（AC-6.8、AC-15.5）。
  factory FakeMapManifest.nonLinear() => FakeMapManifest._(
        originPixel: Vector2.zero(),
        pixelsPerDegree: 100.0,
        varyScale: true,
      );

  /// 固定但非 1.0 的比例，用於驗證公尺門檻的換算（AC-6.7）。
  factory FakeMapManifest.fixedScale(double metersPerPixel) => FakeMapManifest._(
        originPixel: Vector2.zero(),
        pixelsPerDegree: 100.0,
        varyScale: false,
        fixedMpp: metersPerPixel,
      );

  // 座標系：經緯度原點 (minLat, minLng) 對應 originPixel，
  // 每度 100 像素，緯度往北 → y 減少。
  static const double minLat = 23.0;
  static const double maxLat = 25.0;   // → 高 200 px
  static const double minLng = 120.0;
  static const double maxLng = 122.0;  // → 寬 200 px

  final Vector2 _origin;
  final double pixelsPerDegree;
  final bool varyScale;

  int projectCallCount = 0;
  int snapCallCount = 0;
  void resetCallCounts() {
    projectCallCount = 0;
    snapCallCount = 0;
  }

  @override
  String get mapId => 'fake';
  @override
  String get assetPath => 'fake.png';
  @override
  Vector2 get mapDimensions => Vector2(400, 400);
  @override
  int get oceanColorArgb => 0xFF000080;
  @override
  Vector2 get defaultSpawnPixel => Vector2(10, 10);
  @override
  double get dpadSpeedPixelsPerSecond => 40;
  @override
  double get snapLimitMeters => 50;

  /// 單一水平線段 y=100，x 由 0 到 200。
  @override
  List<Vector2> get roadNodes => [_origin + Vector2(0, 100), _origin + Vector2(200, 100)];

  /// 兩個 POI，間距 150 px，遠大於 triggerRadius(50m=50px) + snapLimit(50m=50px)。
  @override
  List<PoiMarker> get poiNodes => [
        PoiMarker(id: 'poi_a', pixel: _origin + Vector2(20, 20), triggerRadiusMeters: 50),
        PoiMarker(id: 'poi_b', pixel: _origin + Vector2(170, 20), triggerRadiusMeters: 50),
      ];

  @override
  bool containsGeo(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  @override
  Vector2 projectToPixel(double lat, double lng) {
    projectCallCount++;
    return _origin +
        Vector2((lng - minLng) * pixelsPerDegree, (maxLat - lat) * pixelsPerDegree);
  }

  @override
  GeoPoint unprojectToGeo(Vector2 pixel) {
    final local = pixel - _origin;
    return GeoPoint(maxLat - local.y / pixelsPerDegree,
        minLng + local.x / pixelsPerDegree);
  }

  /// 垂直投影到 y=100 的水平線段；超過上限則不吸附。
  @override
  Vector2 snapToRoad(Vector2 pixel) {
    snapCallCount++;
    final limitPixels = snapLimitMeters / metersPerPixelAt(pixel);
    final roadY = _origin.y + 100;
    final dy = (pixel.y - roadY).abs();
    final withinX = pixel.x >= _origin.x && pixel.x <= _origin.x + 200;
    if (!withinX || dy > limitPixels) return pixel;
    return Vector2(pixel.x, roadY);
  }

  @override
  double metersPerPixelAt(Vector2 pixel) =>
      varyScale ? 1.0 + pixel.x / 1000.0 : 1.0;
}
```

**已驗算的座標**（供後續任務的測試資料使用，勿再自行推算）：

| 經緯度 | `linear()` 投影像素 | 說明 |
|---|---|---|
| (24.0, 121.0) | (100, 100) | 在範圍內，**恰在路網上** |
| (24.9, 121.0) | (100, 10) | 在範圍內，距路網 90 px > 50 px 上限 → **不吸附** |
| (80.0, 0.0) | — | **範圍外**，不得投影 |
| (25.0, 120.0) | (0, 0) | 左上角 |
| 像素 (120, 240) | → (22.6, 121.2) | **超出 minLat**，反投影往返仍成立（往返不檢查範圍） |

- [ ] **步驟 5：執行，確認通過（5 tests passed）**

```bash
flutter test test/domain/location/projection/map_manifest_contract_test.dart
```

- [ ] **步驟 6：提交**

```bash
git add -A
git commit -m "feat: add map manifest contract and a maths-only fake

The contract gains what the tracking pipeline needs beyond projection:
unprojection for click-to-navigate, a bounds test, a spawn point, a
metres-per-pixel query and the d-pad speed. Colour is an ARGB int so the
contract stays free of Flutter types without splitting the interface to
isolate one field.

The fake is the decoupling requirement made executable. It draws nothing
and loads no image, so if the whole pipeline can be tested against it,
no city-specific logic has leaked into the engine. It counts projection
calls, which lets later tests assert that an out-of-range position was
never projected rather than trusting the ordering to a comment.

This task adds files only. Migrating the Taiwan manifest onto the
contract touches existing code and tests, and is separated so the pure
pipeline work can start without waiting for it."
```

---

### Task 4b：台灣 manifest 遷移與既有測試修正

**實作：** PRE-2、PRE-4、PRE-7、PRE-11

> **關鍵路徑外**：T6~T13 只需要 T4a。本任務阻擋的是 T18。

**檔案：**
- 修改：`lib/game/map_module/models/geo_anchor.dart`（import 改 vector_math）
- 修改：`lib/game/map_module/models/overworld_poi_node.dart`（同上）
- 修改：`lib/game/map_module/overworld_map_manifest.dart`（改為 `export` domain 契約）
- 修改：`lib/game/map_module/manifests/taiwan_map_manifest.dart`（實作新成員）
- 修改：`lib/game/universal_overworld_game.dart:23,100`
- 修改：`test/taiwan_map_manifest_test.dart`（14 處）
- 修改：`test/taiwan_geo_calibrator_test.dart:14`

**已知會編譯失敗的位置**（改名的必然後果，不是意外）：

| 檔案:行 | 現況 | 改為 |
|---|---|---|
| `universal_overworld_game.dart:23` | `manifest.oceanColor` | `Color(manifest.oceanColorArgb)` |
| `universal_overworld_game.dart:100` | `manifest.projectGpsToPixel(...)` | `manifest.projectToPixel(...)` |
| `taiwan_geo_calibrator_test.dart:14` | `projectGpsToPixel` | `projectToPixel` |
| `taiwan_map_manifest_test.dart:52,53,62,63,68,69,70` | `projectGpsToPixel` | `projectToPixel` |
| `taiwan_map_manifest_test.dart:79,80,88` | `poi.pixelPosition` | `poi.pixel` |
| `taiwan_map_manifest_test.dart:91` | `pois[i].triggerRadius`（像素） | 見下方步驟 3 |
| `taiwan_map_manifest_test.dart:92` | `pois[i].title` | `pois[i].id` |

- [ ] **步驟 1：先改測試，確認紅燈**

把上表的測試檔改成新名稱。此時 `lib/` 尚未改，測試**無法編譯** —— 這就是本任務的 RED。

- [ ] **步驟 2：實作台灣 manifest 的新成員**

```dart
@override
int get oceanColorArgb => 0xFF1E6F9F;

@override
Vector2 get defaultSpawnPixel => Vector2(1162, 148);   // 自通用引擎搬來（PRE-7）

@override
double get snapLimitMeters => 50;

@override
double get dpadSpeedPixelsPerSecond => 40;             // 暫定，Q15 由任務 D 裁決

/// 過渡底圖為等距投影，故為常數。最終手繪圖需改為逐點計算。
@override
double metersPerPixelAt(Vector2 pixel) => 370.4;

@override
bool containsGeo(double lat, double lng) =>
    lat >= 21.4 && lat <= 25.7 && lng >= 119.7 && lng <= 122.3;
```

- [ ] **步驟 3：修正 POI 觸發半徑測試的單位混用**

既有測試比較的是「像素距離 > 觸發半徑總和」，而 `triggerRadiusMeters` 現在是公尺。改為換算後比較：

```dart
test('POI 之間的距離大於觸發半徑總和，避免同時觸發兩個遭遇', () {
  final pois = manifest.poiNodes;
  final mpp = manifest.metersPerPixelAt(Vector2.zero());
  for (var i = 0; i < pois.length; i++) {
    for (var j = i + 1; j < pois.length; j++) {
      final metersApart = pois[i].pixel.distanceTo(pois[j].pixel) * mpp;
      expect(metersApart,
          greaterThan(pois[i].triggerRadiusMeters + pois[j].triggerRadiusMeters),
          reason: '${pois[i].id} 與 ${pois[j].id} 的觸發範圍重疊');
    }
  }
});
```

- [ ] **步驟 4：實作 `unprojectToGeo`**

**IDW 的像素→經緯度不是經緯度→像素的數學逆函數**（兩個方向都往錨點均值收縮），直接對稱套用達不到 AC-10.1 要求的 2 像素往返誤差。改用**迭代修正**：

```dart
/// 以牛頓式迭代求反投影：從錨點加權初猜出發，
/// 每輪用正向投影的誤差回推經緯度修正量。
@override
GeoPoint unprojectToGeo(Vector2 target) {
  // 初猜：取最近的三個錨點做像素距離加權平均
  var lat = ..., lng = ...;
  for (var i = 0; i < 12; i++) {
    final projected = projectToPixel(lat, lng);
    final error = target - projected;
    if (error.length < 0.5) break;
    // 用局部雅可比（以 0.001 度的差分估計）把像素誤差換回度數
    final dLat = (projectToPixel(lat + 0.001, lng) - projected) / 0.001;
    final dLng = (projectToPixel(lat, lng + 0.001) - projected) / 0.001;
    // 解 2x2 線性系統
    ...
  }
  return GeoPoint(lat, lng);
}
```

- [ ] **步驟 5：為往返一致性補測試**

```dart
test('台灣 manifest 的反投影往返誤差小於 2 像素（AC-10.1）', () {
  final m = TaiwanMapManifest();
  for (final p in [Vector2(1162, 148), Vector2(909, 408), Vector2(816, 871)]) {
    final geo = m.unprojectToGeo(p);
    final back = m.projectToPixel(geo.latitude, geo.longitude);
    expect((back - p).length, lessThan(2.0), reason: '$p 往返失敗');
  }
});
```

> 若迭代法在某些點無法收斂到 2 像素內，**回報而非放寬門檻**：AC-10.1 是除錯點擊尋路的正確性下限，放寬它等於讓除錯路徑與正式路徑產生偏差。

- [ ] **步驟 6：執行全部測試並提交**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
git add -A
git commit -m "refactor: migrate Taiwan manifest onto the domain contract

Projection, snapping, spawn point and geographic bounds now come from
the manifest rather than from the generic engine, which had the spawn
coordinate hardcoded and called the Taiwan calibrator directly.

Unprojection is solved iteratively rather than by mirroring the forward
pass. Inverse-distance weighting is not its own inverse — both
directions contract toward the anchor mean — so a mirrored
implementation would miss the two-pixel round-trip the click-to-navigate
debug path depends on.

The existing POI spacing test compared a pixel distance against what is
now a radius in metres. Converting one side keeps the assertion meaning
what it did before the units changed."
```

---

### Task 5：五維度狀態與診斷快照

**實作：** REQ-C-14 規則 1、5、6、初始值；AC-14.1~14.3、AC-14.6、AC-14.7、AC-14.10

**檔案：**
- 建立：`lib/domain/location/models/rejection_reason.dart`
- 建立：`lib/domain/location/models/location_status.dart`
- 建立：`lib/domain/location/models/location_diagnostics.dart`
- 測試：`test/domain/location/models/location_status_test.dart`

**介面：**
- 產出：`enum PermissionState { ready, serviceDisabled, denied, deniedForever, approximate, unavailable }`
- 產出：`enum CoverageState { inside, outside }`、`enum AcquisitionState { acquiring, acquired }`、`enum MotionState { still, moving }`、`enum PowerMode { active, suspended }`
- 產出：`enum RejectionReason { unmeasuredAccuracy, accuracy, timestamp, speed, insignificant }`
- 產出：`LocationStatus`（五維度）、`LocationStatus.initial()`、`HudPriority hudPriorityOf(LocationStatus)`
- 產出：`LocationDiagnostics`

- [ ] **步驟 1：先寫失敗的測試**

`test/domain/location/models/location_status_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';

void main() {
  test('初始狀態符合規格（AC-14.10）', () {
    const s = LocationStatus.initial;   // static const，非具名建構子
    expect(s.permission, PermissionState.unavailable);
    expect(s.mode, SourceMode.gps);
    expect(s.coverage, CoverageState.inside);
    expect(s.acquisition, AcquisitionState.acquiring);
    expect(s.motion, MotionState.still);
  });

  test('五個維度互相獨立（AC-14.1、AC-14.2）', () {
    const s = LocationStatus.initial();
    final t = s.copyWith(
      permission: PermissionState.ready,
      coverage: CoverageState.outside,
      mode: SourceMode.virtual,
    );
    // 三者同時成立，且改 mode 不影響 permission
    expect(t.permission, PermissionState.ready);
    expect(t.coverage, CoverageState.outside);
    expect(t.mode, SourceMode.virtual);
  });

  test('HUD 優先序唯一決定（AC-14.3）', () {
    const base = LocationStatus(
      permission: PermissionState.ready,
      mode: SourceMode.gps,
      coverage: CoverageState.inside,
      acquisition: AcquisitionState.acquired,
      motion: MotionState.moving,
    );
    expect(hudPriorityOf(base), HudPriority.normal);
    expect(hudPriorityOf(base.copyWith(acquisition: AcquisitionState.acquiring)),
        HudPriority.acquiring);
    expect(hudPriorityOf(base.copyWith(coverage: CoverageState.outside)),
        HudPriority.outsideCoverage);
    expect(hudPriorityOf(base.copyWith(mode: SourceMode.virtual)),
        HudPriority.virtualMode);
    // 權限異常壓過所有其他維度
    expect(
      hudPriorityOf(base.copyWith(
        permission: PermissionState.denied,
        mode: SourceMode.virtual,
        coverage: CoverageState.outside,
        acquisition: AcquisitionState.acquiring,
      )),
      HudPriority.permissionProblem,
    );
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

```bash
flutter test test/domain/location/models/location_status_test.dart
```

預期：FAIL，型別不存在。

- [ ] **步驟 3：寫實作**

`location_status.dart` 的核心是 freezed 值物件加一個純函式：

```dart
enum HudPriority { permissionProblem, virtualMode, outsideCoverage, acquiring, normal }

/// 同時成立時只顯示最高者。順序寫成函式而非散落在 UI，
/// 才能對「任一組合唯一決定」這件事寫測試。
HudPriority hudPriorityOf(LocationStatus s) {
  if (s.permission != PermissionState.ready) return HudPriority.permissionProblem;
  if (s.mode == SourceMode.virtual) return HudPriority.virtualMode;
  if (s.coverage == CoverageState.outside) return HudPriority.outsideCoverage;
  if (s.acquisition == AcquisitionState.acquiring) return HudPriority.acquiring;
  return HudPriority.normal;
}
```

`LocationStatus` 必須是**單一形狀**的 freezed 類別（非 union），因為 AC-14.1／14.3 都用到 `copyWith`：

```dart
@freezed
abstract class LocationStatus with _$LocationStatus {
  const factory LocationStatus({
    required PermissionState permission,
    required SourceMode mode,
    required CoverageState coverage,
    required AcquisitionState acquisition,
    required MotionState motion,
  }) = _LocationStatus;

  /// 用 static const 而非 `const factory LocationStatus.initial()`。
  /// 後者會讓 LocationStatus 變成 union，union 上沒有共用的 copyWith。
  static const LocationStatus initial = LocationStatus(
    permission: PermissionState.unavailable,
    mode: SourceMode.gps,
    coverage: CoverageState.inside,
    acquisition: AcquisitionState.acquiring,
    motion: MotionState.still,
  );
}
```

`location_diagnostics.dart` 依 REQ-C-14 規則 5 的欄位清單建立 freezed 值物件並加 `toJson`，**不含任何經緯度欄位**。補一條測試：

```dart
test('AC-14.7 診斷快照序列化不含座標鍵', () {
  final json = someDiagnostics.toJson();
  for (final k in ['lat', 'lng', 'latitude', 'longitude']) {
    expect(json.keys, isNot(contains(k)));
  }
});
```

- [ ] **步驟 4：執行，確認通過**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/domain/location/models/location_status_test.dart
```

預期：3 tests passed。

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: model location state as five independent dimensions

Permission, mode, coverage, acquisition and motion can all hold at once
— an authorised player can be outside the map's coverage while walking
in virtual mode — so collapsing them into one enum produces legitimate
states the type cannot express.

Display precedence is a function rather than scattered UI conditionals,
which makes 'any combination resolves to exactly one thing' testable.

The diagnostics snapshot carries no coordinates, per the privacy rule."
```

---
## Phase 2 — 純邏輯管線

> 本階段全部是純函式，不碰任何 IO。這是 TDD 的主戰場與測試密度最高處。
> T6~T13 之間除標註的相依外互不相干，可分給不同人並行。

### Task 6：品質閘門

**實作：** REQ-C-03 規則 1~6、9；AC-3.1~3.7、3.10、3.11

**檔案：**
- 建立：`lib/domain/location/pipeline/quality_gate.dart`
- 測試：`test/domain/location/pipeline/quality_gate_test.dart`

**介面：**
- 消費：`GeoFix`（Task 3）、`RejectionReason`（Task 5）
- 產出：

```dart
sealed class GateResult {}
class Accepted extends GateResult { final GeoFix fix; }
class Rejected extends GateResult { final RejectionReason reason; }

class QualityGate {
  QualityGate({required this.accuracyLimitMeters, required this.maxSpeedMetersPerSecond,
               required this.clockAnomalyThreshold, required this.consecutiveRejectLimit});
  GateResult evaluate(GeoFix fix);
  void resetBaseline();
}
```

- [ ] **步驟 1：先寫失敗的測試**

`test/domain/location/pipeline/quality_gate_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/rejection_reason.dart';
import 'package:share_tour/domain/location/pipeline/quality_gate.dart';

GeoFix f({
  double lat = 25.0,
  double lng = 121.0,
  double accuracy = 20,
  bool hasAccuracy = true,
  double speed = 1.4,
  bool hasSpeed = true,
  int secondsFromEpoch = 0,
}) =>
    GeoFix(
      latitude: lat,
      longitude: lng,
      accuracyMeters: accuracy,
      hasAccuracy: hasAccuracy,
      speedMetersPerSecond: speed,
      hasSpeed: hasSpeed,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 1).add(Duration(seconds: secondsFromEpoch)),
      isMocked: false,
      sourceMode: SourceMode.gps,
    );

QualityGate gate() => QualityGate(
      accuracyLimitMeters: 100,
      maxSpeedMetersPerSecond: 350 * 1000 / 3600, // 350 km/h
      clockAnomalyThreshold: const Duration(days: 1),
      consecutiveRejectLimit: 5,
    );

void main() {
  test('AC-3.1 精度門檻含入', () {
    expect(gate().evaluate(f(accuracy: 150)), isA<Rejected>());
    expect(gate().evaluate(f(accuracy: 20)), isA<Accepted>());
    expect(gate().evaluate(f(accuracy: 100)), isA<Accepted>(),
        reason: '門檻值本身視為合格');
  });

  test('AC-3.2 精度未量測一律丟棄', () {
    final r = gate().evaluate(f(hasAccuracy: false, accuracy: 0));
    expect(r, isA<Rejected>());
    expect((r as Rejected).reason, RejectionReason.unmeasuredAccuracy);
  });

  test('AC-3.3 速度不合理丟棄', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    // 約 1 公里外、間隔 1 秒 → 3600 km/h
    final r = g.evaluate(f(lat: 25.009, secondsFromEpoch: 1));
    expect((r as Rejected).reason, RejectionReason.speed);
  });

  test('AC-3.4 時戳回捲丟棄', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 10));
    final r = g.evaluate(f(secondsFromEpoch: 5));
    expect((r as Rejected).reason, RejectionReason.timestamp);
  });

  test('AC-3.5 連續丟棄 5 筆後，第 6 筆接受並重置基準', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    for (var i = 1; i <= 5; i++) {
      expect(g.evaluate(f(lat: 25.0 + i * 0.01, secondsFromEpoch: i)),
          isA<Rejected>());
    }
    expect(g.evaluate(f(lat: 25.06, secondsFromEpoch: 6)), isA<Accepted>());
  });

  test('AC-3.6 強制接受僅豁免速度規則，精度仍生效', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    for (var i = 1; i <= 5; i++) {
      g.evaluate(f(lat: 25.0 + i * 0.01, secondsFromEpoch: i));
    }
    final r = g.evaluate(f(lat: 25.06, accuracy: 200, secondsFromEpoch: 6));
    expect(r, isA<Rejected>());
    expect((r as Rejected).reason, RejectionReason.accuracy);
  });

  test('AC-3.7 時鐘異常重置基準而非丟棄', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    final r = g.evaluate(f(secondsFromEpoch: -2 * 86400)); // 早兩天
    expect(r, isA<Accepted>(), reason: '時鐘被調整時應重置基準，否則後續全被丟棄');
  });

  test('AC-3.10 裝置 speed 已量測時取較小值', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    // 兩點差分約 300 m/s，但裝置回報 2 m/s
    final r = g.evaluate(f(lat: 25.0027, speed: 2, secondsFromEpoch: 1));
    expect(r, isA<Accepted>());
  });

  test('AC-3.11 裝置 speed 未量測時只用兩點差分', () {
    final g = gate();
    g.evaluate(f(secondsFromEpoch: 0));
    final r = g.evaluate(
        f(lat: 25.009, speed: 0, hasSpeed: false, secondsFromEpoch: 1));
    expect(r, isA<Rejected>(),
        reason: '佔位 0.0 不得讓速度閘門失效');
  });

  test('AC-3.9(規則9) 首筆不受速度規則約束', () {
    expect(gate().evaluate(f()), isA<Accepted>());
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

```bash
flutter test test/domain/location/pipeline/quality_gate_test.dart
```

預期：FAIL，`quality_gate.dart` 不存在。

- [ ] **步驟 3：寫實作**

依下列順序實作 `evaluate`：

```
1. 已量測旗標（精度未量測 → 丟棄）
2. 精度門檻
3. 時間差判定（關鍵，順序不可顛倒）：
   3a. |Δt| > 1 天  → 時鐘異常：重置基準並【接受】，直接返回
   3b. Δt <= 0      → 時戳回捲：丟棄
4. 速度合理性（強制接受時跳過此步）
```

> **為什麼 3a 必須在 3b 之前**：一筆「早兩天」的 Fix 同時滿足兩條規則——它既早於前一筆（規則 3 → 丟棄），差距又超過一天（規則 4 → 接受）。若照字面把單調性排在前面，AC-3.7 必紅。時鐘異常是「基準本身不可信」，必須先於任何以基準為準的判定。
維護 `_baseline`（上一筆被接受的 fix）與 `_consecutiveRejects`。
強制接受的分支只跳過速度判定。

**注意**：兩點距離用 haversine，寫成同檔的私有函式；不要引入新套件。

- [ ] **步驟 4：執行，確認通過**

```bash
flutter test test/domain/location/pipeline/quality_gate_test.dart
```

預期：10 tests passed。

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add GPS quality gate

Four gates in a fixed order: whether the platform measured accuracy at
all, the accuracy limit, timestamp monotonicity, and a speed sanity
check. Speed uses the smaller of the two-point difference and the
device's own reading, but only when the device actually measured it —
the placeholder zero would otherwise pin the minimum at zero and
disable the gate entirely.

A clock that jumps backwards by more than a day resets the baseline
rather than rejecting, since a corrected system clock would otherwise
reject every subsequent fix with a symptom that is very hard to trace.

After five consecutive rejections the next fix is accepted regardless of
speed, so a wrong baseline cannot wedge tracking permanently. That
override does not extend to accuracy or monotonicity."
```

---

### Task 7：顯著位移閘門（基準凍結）

**實作：** REQ-C-03 規則 7、8；AC-3.8、AC-3.9

**檔案：**
- 建立：`lib/domain/location/pipeline/significance_gate.dart`
- 測試：`test/domain/location/pipeline/significance_gate_test.dart`

**介面：**
- 消費：`GeoFix`
- 產出：

```dart
class SignificanceGate {
  SignificanceGate({required this.coefficient}); // 0.75
  /// 回傳本次的顯著位移公尺數；未達門檻回傳 null 且不更新基準。
  double? evaluate(GeoFix fix);
}
```

- [ ] **步驟 1：先寫失敗的測試**

`test/domain/location/pipeline/significance_gate_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/pipeline/significance_gate.dart';

/// 以緯度位移構造精確的公尺距離：1 度緯度 ≈ 110574 公尺。
GeoFix atMeters(double metersNorth, {double accuracy = 20, int second = 0}) =>
    GeoFix(
      latitude: 25.0 + metersNorth / 110574.0,
      longitude: 121.0,
      accuracyMeters: accuracy,
      hasAccuracy: true,
      speedMetersPerSecond: 1.4,
      hasSpeed: true,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 1).add(Duration(seconds: second)),
      isMocked: false,
      sourceMode: SourceMode.gps,
    );

void main() {
  test('AC-3.8 精度 20m 兩筆相距 15m → 未顯著，不累計', () {
    final g = SignificanceGate(coefficient: 0.75);
    g.evaluate(atMeters(0));
    expect(g.evaluate(atMeters(15, second: 1)), isNull);
  });

  test('AC-3.8b 相距 60m → 顯著', () {
    final g = SignificanceGate(coefficient: 0.75);
    g.evaluate(atMeters(0));
    final d = g.evaluate(atMeters(60, second: 1));
    expect(d, isNotNull);
    expect(d!, closeTo(60, 1));
  });

  test('AC-3.9 基準凍結：5 筆每筆 12m，恰有第 3 筆顯著，累計 36m', () {
    final g = SignificanceGate(coefficient: 0.75);
    final significant = <double>[];
    for (var i = 0; i <= 5; i++) {
      final d = g.evaluate(atMeters(i * 12.0, second: i));
      if (d != null) significant.add(d);
    }
    // 門檻 0.75 * (20+20) = 30m。基準凍結在 0m：
    //   12m 否、24m 否、36m 是（基準移到 36m）、48m 距新基準 12m 否、60m 距 24m 否
    expect(significant.length, 1,
        reason: '基準前移的實作會得到 0 次；每筆都算的實作會得到 5 次');
    expect(significant.single, closeTo(36, 1));
  });

  test('AC-13.5 合成路徑：500m、每 10m 一筆、精度 20m → 累計約 480m', () {
    final g = SignificanceGate(coefficient: 0.75);
    var total = 0.0;
    for (var i = 1; i <= 50; i++) {
      total += g.evaluate(atMeters(i * 10.0, second: i)) ?? 0;
    }
    expect(total, inInclusiveRange(400, 550),
        reason: '基準前移的實作會得到 0，這條是里程「少算」的唯一防線');
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

```bash
flutter test test/domain/location/pipeline/significance_gate_test.dart
```

預期：FAIL，檔案不存在。

- [ ] **步驟 3：寫實作**

```dart
/// 顯著位移閘門。
///
/// 靜坐時 GPS 會在精度半徑內來回跳，每一筆都通過精度、速度與時戳三道閘門，
/// 於是小人原地繞圈並持續累積假里程。這道閘門用「位移相對於量測誤差是否夠大」
/// 來判定，門檻隨精度浮動。
///
/// 基準必須凍結：未達門檻時不更新基準。若基準隨每筆前移，都市步行每筆位移
/// 10~15 公尺全部小於 30 公尺門檻，里程會永遠是 0——散步、逛街、塞車全部歸零。
class SignificanceGate {
  ...
}
```

- [ ] **步驟 4：執行，確認通過**

```bash
flutter test test/domain/location/pipeline/significance_gate_test.dart
```

預期：4 tests passed，其中合成路徑測試得到約 480。

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add significance gate with frozen baseline

A seated player's GPS wanders inside its own accuracy radius, and every
one of those readings passes the accuracy, speed and timestamp gates —
so the character circles in place and accrues distance it never walked.
This gate asks whether the displacement is large relative to the
measurement error instead, so the threshold moves with accuracy.

The baseline is frozen on a non-significant reading rather than
advancing. Advancing it looks equivalent and is catastrophic: urban
walking arrives in 10-15 metre steps against a 30 metre threshold, so
every step falls short and recorded distance is permanently zero.

The five-fix test distinguishes the two: frozen yields 36 metres,
advancing yields nothing at all."
```

---

### Task 8：motion 逾時判定

**實作：** REQ-C-14 規則 2、4；AC-14.4、14.5、14.8、14.9

**檔案：**
- 建立：`lib/domain/location/pipeline/motion_tracker.dart`
- 測試：`test/domain/location/pipeline/motion_tracker_test.dart`

**介面：**
- 消費：`Clock`（Task 2）、`MotionState`/`AcquisitionState`（Task 5）
- 產出：

```dart
class MotionTracker {
  MotionTracker({required Clock clock, required Duration stillAfter,        // 30s
                 required Duration acquiringAfter});                        // 45s
  void onSignificantMove();
  void onAcceptedFix();
  MotionState get motion;
  AcquisitionState get acquisition;
}
```

- [ ] **步驟 1：先寫失敗的測試**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/pipeline/motion_tracker.dart';
import '../../../fakes/fake_clock.dart';

void main() {
  late FakeClock clock;
  late MotionTracker tracker;

  setUp(() {
    clock = FakeClock();
    tracker = MotionTracker(
      clock: clock,
      stillAfter: const Duration(seconds: 30),
      acquiringAfter: const Duration(seconds: 45),
    );
  });

  test('AC-14.4 完全不推送任何 Fix，30 秒後為 still', () {
    tracker.onSignificantMove();
    expect(tracker.motion, MotionState.moving);
    clock.advance(const Duration(seconds: 31));
    expect(tracker.motion, MotionState.still,
        reason: '平台在玩家靜止時根本不推 Fix，用 Fix 到達判定在真機永遠不會變 still');
  });

  test('AC-14.5 出現顯著位移即回到 moving', () {
    clock.advance(const Duration(seconds: 60));
    expect(tracker.motion, MotionState.still);
    tracker.onSignificantMove();
    expect(tracker.motion, MotionState.moving);
  });

  test('AC-14.8 取得首筆被接受的 Fix → acquired；45 秒無被接受的 Fix → acquiring', () {
    expect(tracker.acquisition, AcquisitionState.acquiring);
    tracker.onAcceptedFix();
    expect(tracker.acquisition, AcquisitionState.acquired);
    clock.advance(const Duration(seconds: 46));
    expect(tracker.acquisition, AcquisitionState.acquiring);
  });

  test('AC-14.9 Fix 全被丟棄達 45 秒 → acquiring（地下街情境）', () {
    tracker.onAcceptedFix();
    // 期間有推送但全被品質閘門丟棄，故不呼叫 onAcceptedFix
    clock.advance(const Duration(seconds: 46));
    expect(tracker.acquisition, AcquisitionState.acquiring);
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

```bash
flutter test test/domain/location/pipeline/motion_tracker_test.dart
```

- [ ] **步驟 3：寫實作**

以「上次事件的單調時間戳」與當前 `clock.elapsed` 相減判定，**不要**用計時器。
這樣狀態是查詢時計算出來的，測試只要推進假時鐘即可，不需要非同步等待。

- [ ] **步驟 4：執行，確認通過（4 tests passed）**

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: derive motion and acquisition from elapsed time

Both are computed from how long ago the last event happened rather than
from an arriving fix. The platform's distance filter means it stops
sending fixes precisely when the player stops moving, so a fix-driven
rule can never reach 'still' on a real device — while a unit test that
feeds fixes in would pass.

Acquisition is bidirectional for the same reason it exists: losing a
usable position and never having had one are the same thing to a player.
Underground, fixes still arrive but are discarded for poor accuracy, and
without this the HUD would read normal while the character stood still."
```

---
### Task 9：投影階段（範圍檢查 → 投影 → 吸附）

**實作：** REQ-C-04 全部、REQ-C-05 規則 1；AC-4.1、4.3、4.4、4.6、AC-5.1~5.4、AC-0.1

**檔案：**
- 建立：`lib/domain/location/pipeline/projection_stage.dart`
- 建立：`lib/domain/location/pipeline/manifest_geometry_check.dart`
- 測試：`test/domain/location/pipeline/projection_stage_test.dart`
- 測試：`test/domain/location/pipeline/manifest_geometry_check_test.dart`

**介面：**
- 消費：`OverworldMapManifest`（Task 4）
- 產出：

```dart
sealed class ProjectionResult {}
class Projected extends ProjectionResult { final Vector2 pixel; }
class OutsideCoverage extends ProjectionResult {}

class ProjectionStage {
  ProjectionStage(this.manifest);
  ProjectionResult project(double lat, double lng);
}

/// 幾何約束驗證，門檻由呼叫端注入（AC-4.6 參數化）。
List<String> findSnapTriggerConflicts({
  required List<Vector2> roadNodes,
  required List<PoiMarker> pois,
  required double snapLimitMeters,
  required double metersPerPixel,
});
```

- [ ] **步驟 1：先寫失敗的測試**

`test/domain/location/pipeline/projection_stage_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/pipeline/projection_stage.dart';
import '../../../fakes/fake_map_manifest.dart';

void main() {
  test('AC-4.1 目標點等於範圍檢查通過後投影再吸附的結果', () {
    final m = FakeMapManifest.linear();
    final r = ProjectionStage(m).project(24.0, 121.0) as Projected;
    final expected = m.snapToRoad(m.projectToPixel(24.0, 121.0));
    expect(r.pixel, expected);
  });

  test('AC-4.4 / AC-0.1 範圍外時不呼叫投影', () {
    final m = FakeMapManifest.linear()..resetCallCounts();
    final r = ProjectionStage(m).project(80.0, 0.0);
    expect(r, isA<OutsideCoverage>());
    expect(m.projectCallCount, 0,
        reason: 'IDW 對範圍外輸入不報錯，只回傳凸包內看似合理的錯點，'
            '所以範圍檢查必須在投影之前');
  });

  test('AC-4.3 距所有道路超過上限則不吸附', () {
    final m = FakeMapManifest.linear(); // 路網為 y=100 的水平線段
    final raw = m.projectToPixel(24.9, 121.0); // 刻意遠離路網
    final r = ProjectionStage(m).project(24.9, 121.0) as Projected;
    expect(r.pixel, raw);
  });
}
```

`test/domain/location/pipeline/manifest_geometry_check_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/domain/location/pipeline/manifest_geometry_check.dart';
import 'package:share_tour/game/map_module/manifests/taiwan_map_manifest.dart';

void main() {
  test('AC-4.6 規則本身正確：合法資料無衝突', () {
    final conflicts = findSnapTriggerConflicts(
      roadNodes: [Vector2(0, 0), Vector2(1000, 0)],
      pois: [PoiMarker(id: 'far', pixel: Vector2(500, 500), triggerRadiusMeters: 50)],
      snapLimitMeters: 50,
      metersPerPixel: 1.0,
    );
    expect(conflicts, isEmpty);
  });

  test('AC-4.6 規則本身正確：節點壓在 POI 上會被抓到', () {
    final conflicts = findSnapTriggerConflicts(
      roadNodes: [Vector2(500, 500)],
      pois: [PoiMarker(id: 'onTop', pixel: Vector2(500, 500), triggerRadiusMeters: 50)],
      snapLimitMeters: 50,
      metersPerPixel: 1.0,
    );
    expect(conflicts, contains(contains('onTop')));
  });

  test(
    'AC-4.6 台灣圖資的幾何約束',
    () {
      final m = TaiwanMapManifest();
      final conflicts = findSnapTriggerConflicts(
        roadNodes: m.roadNodes,
        pois: m.poiNodes,
        snapLimitMeters: m.snapLimitMeters,
        metersPerPixel: m.metersPerPixelAt(Vector2.zero()),
      );
      expect(conflicts, isEmpty);
    },
    skip: 'PRE-8：5 個道路節點中 4 個與 POI 同座標（實測間距 0.000 px），'
        '吸附會把玩家從數公里外瞬移到 POI 上並誤觸發遭遇。'
        '待路網升級為路段拓撲後解除。',
  );
}
```

> **為什麼用 `skip` 而不是刪掉**：把「規則寫得對不對」與「台灣資料合不合格」分開。前者現在就綠，後者的紅燈留著且有說明，不會被忘記，也不阻擋開工。

- [ ] **步驟 2：執行，確認前兩組失敗、第三組被跳過**

```bash
flutter test test/domain/location/pipeline/
```

- [ ] **步驟 3：寫實作**

`ProjectionStage.project` 嚴格照順序：`containsGeo` → 不通過就回 `OutsideCoverage` 並**直接返回**（不得呼叫投影）→ `projectToPixel` → `snapToRoad`。

`FakeMapManifest` 需要加上 `projectCallCount` 與 `resetCallCounts()`，這是為了讓「未被呼叫」成為可斷言的事實。

`findSnapTriggerConflicts` 對每個節點與每個 POI 計算像素距離，換算成公尺後比較 `triggerRadiusMeters + snapLimitMeters`，回傳衝突描述字串清單。

- [ ] **步驟 4：執行，確認通過**

```bash
flutter test test/domain/location/pipeline/
```

預期：投影 3 條、幾何 2 條通過，1 條 skip。

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add projection stage with coverage check first

The bounds check runs before projection, not after. Inverse-distance
weighting does not fail on an out-of-range input — it returns a point
inside the anchors' convex hull that looks entirely plausible and is
completely wrong, so a later check would be reading a fabricated
position. The fake counts calls so 'projection was not invoked' is an
assertion rather than a comment.

The geometry check is parameterised over the trigger radius and snap
limit, which splits two questions that were tangled: whether the rule
is right, and whether Taiwan's data satisfies it. The rule is verified
now against synthetic data; the Taiwan case is skipped with the measured
reason, since four of five road nodes sit exactly on POIs and snapping
would teleport a player onto one from kilometres away."
```

---

### Task 10：大跨距偵測

**實作：** REQ-C-07 全部；AC-7.1~7.5

**檔案：**
- 建立：`lib/domain/location/pipeline/relocation_detector.dart`
- 測試：`test/domain/location/pipeline/relocation_detector_test.dart`

**介面：**
- 消費：`Clock`
- 產出：

```dart
enum RelocationCause { continuousTracking, discontinuity }

/// 保證非空、列舉固定。供任務 A 日後區分用，本 SPEC 不依賴它做行為分歧。
enum RelocationNote { backgroundResume, serviceRecovered, modeSwitch, coverageRecovered, debugTeleport, realMovement }

class RelocationDecision {
  const RelocationDecision({
    required this.distanceMeters,
    required this.speedMetersPerSecond,
    required this.cause,
    required this.note,
  });
  final double distanceMeters;
  final double speedMetersPerSecond;
  final RelocationCause cause;
  final RelocationNote note;
}

class RelocationDetector {
  RelocationDetector({required this.jumpLimitMeters,           // 2000
                      required this.jumpSpeedLimitMps});       // 120 km/h
  /// 回傳 null 代表不構成大跨距。
  RelocationDecision? evaluate({
    required double previousLat, required double previousLng,
    required double currentLat, required double currentLng,
    required Duration interval,
    required bool subscriptionWasContinuous,
    required RelocationNote note,
  });
}
```

- [ ] **步驟 1：先寫失敗的測試**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/pipeline/relocation_detector.dart';

RelocationDetector detector() => RelocationDetector(
      jumpLimitMeters: 2000,
      jumpSpeedLimitMps: 120 * 1000 / 3600,
    );

void main() {
  test('AC-7.1 位移 5 公里構成大跨距', () {
    final d = detector().evaluate(
      previousLat: 25.0, previousLng: 121.0,
      currentLat: 25.045, currentLng: 121.0, // 約 5 km
      interval: const Duration(minutes: 10),
      subscriptionWasContinuous: true,
      note: RelocationNote.realMovement,
    );
    expect(d, isNotNull);
    expect(d!.distanceMeters, closeTo(5000, 200));
  });

  test('AC-7.2 位移 300 公尺、步行速度 → 不構成', () {
    final d = detector().evaluate(
      previousLat: 25.0, previousLng: 121.0,
      currentLat: 25.0027, currentLng: 121.0, // 約 300 m
      interval: const Duration(minutes: 4),
      subscriptionWasContinuous: true,
      note: RelocationNote.realMovement,
    );
    expect(d, isNull);
  });

  test('AC-7.4 背景恢復造成的跨距 → discontinuity，附註非空', () {
    final d = detector().evaluate(
      previousLat: 25.0, previousLng: 121.0,
      currentLat: 25.045, currentLng: 121.0,
      interval: const Duration(seconds: 30),
      subscriptionWasContinuous: false,
      note: RelocationNote.backgroundResume,
    )!;
    expect(d.cause, RelocationCause.discontinuity);
    expect(d.note, RelocationNote.backgroundResume);
  });

  test('AC-7.5 連續追蹤中以 200 km/h 移動 → continuousTracking', () {
    final d = detector().evaluate(
      previousLat: 25.0, previousLng: 121.0,
      currentLat: 25.03, currentLng: 121.0, // 約 3.3 km
      interval: const Duration(seconds: 60), // 約 200 km/h
      subscriptionWasContinuous: true,
      note: RelocationNote.realMovement,
    )!;
    expect(d.cause, RelocationCause.continuousTracking);
  });

  test('AC-7.3 酬載帶跨距與速度', () {
    final d = detector().evaluate(
      previousLat: 25.0, previousLng: 121.0,
      currentLat: 25.045, currentLng: 121.0,
      interval: const Duration(seconds: 60),
      subscriptionWasContinuous: true,
      note: RelocationNote.realMovement,
    )!;
    expect(d.distanceMeters, closeTo(5000, 200));
    expect(d.speedMetersPerSecond, closeTo(5000 / 60, 5));
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

- [ ] **步驟 3：寫實作**

`cause` 的判定只有一條：`subscriptionWasContinuous == true` → `continuousTracking`，否則 `discontinuity`。
`note` 由呼叫端提供且**保證非空**。

在檔頭加上這段說明：

```dart
/// 大跨距偵測。
///
/// 判準是地理位移與速度，不是像素——手繪地圖的尺度在不同區域可差數倍，
/// 同一個像素門檻在一處是幾公里、在另一處是幾十公里。
///
/// 本模組只發出事實，不建議任何遊戲後果。二元成因的兩側目前都不該被懲罰：
/// continuousTracking 是玩家真的在高速移動（搭高鐵是這款遊戲的核心體驗），
/// discontinuity 的每條路徑也都不是玩家的錯。後果由任務 A 依酬載決定。
```

- [ ] **步驟 4：執行，確認通過（5 tests passed）**

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: detect long-distance relocation in metres

Thresholds are geographic distance and speed rather than pixels: the
hand-drawn map's scale varies several-fold across regions, so one pixel
threshold means a few kilometres in one place and tens in another.

The cause is binary, decided solely by whether the subscription stayed
continuous. An earlier five-way split let three causes hold at once with
no precedence, and left cold start and coverage recovery with none at
all. The finer reason travels alongside as a guaranteed-present note, so
task A can distinguish cases later without a change here.

This module emits facts and proposes no consequence. Both sides of the
binary are innocent: continuous tracking at speed is a player on a
train, which is the point of the game, and every discontinuity path is
something the app did rather than the player."
```

---

### Task 11：分桶距離與事件酬載

**實作：** REQ-C-13 規則 6~10、13~15；AC-13.4、13.6~13.8、13.11~13.13
（規則 13~15 與 AC-13.12／13.13 於規格 v5.1 補回，落實上位文件 CC-3 規則 2、5 與 CC-5）

**檔案：**
- 建立：`lib/domain/location/models/movement_event.dart`
- 建立：`lib/domain/location/pipeline/distance_buckets.dart`
- 測試：`test/domain/location/pipeline/distance_buckets_test.dart`

**介面：**
- 消費：`Clock`、`SourceMode`、`CoverageState`
- 產出：

```dart
@freezed
sealed class MovementEvent with _$MovementEvent {
  const factory MovementEvent.displacement({
    required String eventId,            // UUID
    required DateTime timestampUtc,
    required int sequence,              // 單調序號
    required SourceMode sourceMode,
    required double distanceMeters,
    required CoverageState coverage,
  }) = DisplacementEvent;

  const factory MovementEvent.modeChanged({
    required String eventId,
    required DateTime timestampUtc,
    required int sequence,
    required SourceMode sourceMode,     // 切換後
    required SourceMode previousMode,
    required bool automatic,
    required String reason,
  }) = ModeChangedEvent;

  const factory MovementEvent.relocation({
    required String eventId,
    required DateTime timestampUtc,
    required int sequence,
    required SourceMode sourceMode,
    required double fromPixelX,          // 像素，不是經緯度（CC-5）
    required double fromPixelY,
    required double toPixelX,
    required double toPixelY,
    required double distanceMeters,
    required double distancePixels,
    required double speedMetersPerSecond,
    required RelocationCause cause,
    required RelocationNote note,
  }) = RelocationEvent;

  factory MovementEvent.fromJson(Map<String, dynamic> json) =>
      _$MovementEventFromJson(json);
}

class DistanceBuckets {
  /// 由事件序列重播得出，非獨立累加。
  static ({double real, double virtual}) replay(Iterable<MovementEvent> events);
}
```

- [ ] **步驟 1：先寫失敗的測試**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/models/movement_event.dart';
import 'package:share_tour/domain/location/pipeline/distance_buckets.dart';

MovementEvent disp(double m, SourceMode mode, {int seq = 0,
    CoverageState coverage = CoverageState.inside}) =>
    MovementEvent.displacement(
      eventId: 'e$seq',
      timestampUtc: DateTime.utc(2026, 1, 1),
      sequence: seq,
      sourceMode: mode,
      distanceMeters: m,
      coverage: coverage,
    );

void main() {
  test('AC-13.4 virtual 移動 1 公里 → 只進 virtual 桶', () {
    final r = DistanceBuckets.replay([disp(1000, SourceMode.virtual)]);
    expect(r.virtual, closeTo(1000, 1));
    expect(r.real, 0);
  });

  test('AC-13.7 範圍外的位移兩桶皆不變', () {
    final r = DistanceBuckets.replay(
        [disp(500, SourceMode.gps, coverage: CoverageState.outside)]);
    expect(r.real, 0);
    expect(r.virtual, 0);
  });

  test('AC-13.13 重播具決定性', () {
    final events = [
      disp(100, SourceMode.gps, seq: 0),
      disp(200, SourceMode.virtual, seq: 1),
      disp(300, SourceMode.gps, seq: 2),
    ];
    final a = DistanceBuckets.replay(events);
    final b = DistanceBuckets.replay(events);
    expect(a, equals(b));
    expect(a.real, closeTo(400, 1));
  });

  test('AC-13.11 位移事件帶齊 CC-3 要求的五個欄位', () {
    final e = disp(100, SourceMode.gps, seq: 7) as DisplacementEvent;
    expect(e.eventId, isNotEmpty);
    expect(e.timestampUtc.isUtc, isTrue);
    expect(e.sequence, 7);
    expect(e.sourceMode, SourceMode.gps);
  });

  test('AC-13.12 三類事件的序列化結果皆不含經緯度鍵', () {
    // 位移事件型別上就沒有座標欄位，所以真正的鑑別力在傳送事件——
    // 它是唯一帶起訖點的事件，也是唯一可能夾帶經緯度的地方。
    final events = <MovementEvent>[
      disp(100, SourceMode.gps),
      MovementEvent.modeChanged(
        eventId: 'm1', timestampUtc: DateTime.utc(2026), sequence: 1,
        sourceMode: SourceMode.virtual, previousMode: SourceMode.gps,
        automatic: true, reason: 'permissionDenied',
      ),
      MovementEvent.relocation(
        eventId: 'r1', timestampUtc: DateTime.utc(2026), sequence: 2,
        sourceMode: SourceMode.gps,
        fromPixelX: 10, fromPixelY: 20, toPixelX: 300, toPixelY: 400,
        distanceMeters: 5000, distancePixels: 13.5,
        speedMetersPerSecond: 83.3,
        cause: RelocationCause.continuousTracking,
        note: RelocationNote.realMovement,
      ),
    ];
    for (final e in events) {
      final keys = e.toJson().keys.map((k) => k.toLowerCase());
      for (final banned in ['lat', 'lng', 'latitude', 'longitude']) {
        expect(keys, isNot(contains(banned)), reason: '$e 夾帶了座標鍵 $banned');
      }
    }
  });

  test('AC-CC-1.1 事件 UUID 互不相同', () {
    final a = MovementEventFactory(uuid: const Uuid()).displacement(
        distanceMeters: 1, sourceMode: SourceMode.gps,
        coverage: CoverageState.inside, timestampUtc: DateTime.utc(2026), sequence: 0);
    final b = MovementEventFactory(uuid: const Uuid()).displacement(
        distanceMeters: 1, sourceMode: SourceMode.gps,
        coverage: CoverageState.inside, timestampUtc: DateTime.utc(2026), sequence: 1);
    expect(a.eventId, isNot(equals(b.eventId)));
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

- [ ] **步驟 3：寫實作**

`replay` 為 `static`、無狀態、只讀事件序列 —— 這是重播決定性的結構保證：它不可能依賴當下時間或外部狀態。

`MovementEvent` 需要 `part 'movement_event.g.dart'` 與 `fromJson`／`toJson`（AC-13.12 斷言的是序列化結果，不是 `toString`）。

事件建立集中在 `MovementEventFactory`，由它注入 `Uuid` 與單調序號來源，避免每個呼叫端各自產生識別碼：

```dart
class MovementEventFactory {
  MovementEventFactory({required Uuid uuid}) : _uuid = uuid;
  final Uuid _uuid;
  int _sequence = 0;
  DisplacementEvent displacement({...}) => MovementEvent.displacement(
      eventId: _uuid.v4(), sequence: _sequence++, ...) as DisplacementEvent;
}
```

**新增直接相依**：`flutter pub add uuid`。它目前只是傳遞相依（`pubspec.lock` 顯示 `transitive`），自 `lib/` 直接 import 會觸發 `depend_on_referenced_packages` —— 與 T1 處理 `vector_math` 是同一個問題。

在 `movement_event.dart` 檔頭寫上：

```dart
/// 本 SPEC 產生的持久化事件。
///
/// 每一類都帶 CC-3 要求的五個欄位（UUID、類型、UTC 時戳、單調序號、來源模式），
/// 且依 CC-5 不含任何原始座標——位移只記公尺數，不記起訖點。
///
/// 分桶距離是這些事件重播的衍生結果而非獨立累加，因為一旦有後端，
/// 客戶端自報的最終數字沒有任何可驗證的依據，而那是事後補不回來的。
```

- [ ] **步驟 4：生成、執行，確認通過（4 tests passed）**

- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: derive distance buckets by replaying movement events

Each event carries the five fields the cross-cutting constraints require
of every persisted event, and carries no coordinates — a displacement
records its length, never its endpoints.

The buckets are replayed from the event log rather than accumulated
independently. Once a backend exists it has no basis to trust a
client-reported total, and a bare final number cannot be audited after
the fact. Replay is a static function over the events so it cannot
depend on the current time or any outside state, which is what makes it
deterministic."
```

---
### Task 12：管線編排

**實作：** §3.0 全序；AC-0.1、0.2、0.3

**檔案：**
- 建立：`lib/domain/location/pipeline/location_pipeline.dart`
- 測試：`test/domain/location/pipeline/location_pipeline_test.dart`

**介面：**
- 消費：T6 `QualityGate`、T7 `SignificanceGate`、T8 `MotionTracker`、T9 `ProjectionStage`、T10 `RelocationDetector`、T11 事件型別
- 產出：

```dart
class PipelineOutput {
  const PipelineOutput({this.targetPixel, this.events = const [], this.rejection});
  final Vector2? targetPixel;          // null = 未更新
  final List<MovementEvent> events;
  final RejectionReason? rejection;
}

class LocationPipeline {
  LocationPipeline({
    required OverworldMapManifest manifest,
    required Clock clock,
    QualityGate? qualityGate,               // 省略時以規格參數建立
    SignificanceGate? significanceGate,
    MotionTracker? motionTracker,
    RelocationDetector? relocationDetector,
    MovementEventFactory? eventFactory,
  });

  PipelineOutput ingest(GeoFix fix);

  MotionState get motion;                   // 轉發自 MotionTracker
  AcquisitionState get acquisition;
  Map<RejectionReason, int> get rejectionsByReason;
}
```

> 子模組以**具預設值的具名參數**注入：正式路徑不必逐一組裝，測試又能替換任一段。
> 這不是新抽象——它們都是本計劃自己的具體類別，只是可替換。

- [ ] **步驟 1：先寫失敗的測試**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/pipeline/location_pipeline.dart';
import '../../../fakes/fake_clock.dart';
import '../../../fakes/fake_map_manifest.dart';

/// FakeMapManifest.linear() 的座標系：(24.0, 121.0) → (100, 100)，恰在路網上。
/// 以緯度位移構造精確公尺距離：1 度緯度 ≈ 110574 公尺。
GeoFix at({
  required double metersNorth,
  double accuracy = 20,
  int second = 0,
  SourceMode mode = SourceMode.gps,
  double baseLat = 24.0,
  double lng = 121.0,
}) =>
    GeoFix(
      latitude: baseLat + metersNorth / 110574.0,
      longitude: lng,
      accuracyMeters: accuracy,
      hasAccuracy: true,
      speedMetersPerSecond: 1.4,
      hasSpeed: true,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 1).add(Duration(seconds: second)),
      isMocked: false,
      sourceMode: mode,
    );

void main() {
  late FakeMapManifest manifest;
  late LocationPipeline pipeline;

  setUp(() {
    manifest = FakeMapManifest.linear();
    pipeline = LocationPipeline(manifest: manifest, clock: FakeClock());
  });

  test('AC-0.1 範圍外不進入投影', () {
    manifest.resetCallCounts();
    final out = pipeline.ingest(at(metersNorth: 0, baseLat: 80.0, lng: 0.0));
    expect(out.targetPixel, isNull);
    expect(manifest.projectCallCount, 0,
        reason: 'IDW 對範圍外輸入不報錯，只回傳凸包內看似合理的錯點');
  });

  test('AC-0.3 未顯著移動者不進入後續步驟', () {
    pipeline.ingest(at(metersNorth: 0));
    manifest.resetCallCounts();
    final out = pipeline.ingest(at(metersNorth: 15, second: 1)); // < 30m 門檻
    expect(out.targetPixel, isNull);
    expect(out.events, isEmpty);
    expect(manifest.projectCallCount, 0);
  });

  test('AC-0.4 virtual 的 Fix 跳過品質閘門', () {
    pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
    manifest.resetCallCounts();
    // 位移 5000 公尺、間隔 1 秒 → 18000 km/h，遠超速度門檻
    final out = pipeline.ingest(
        at(metersNorth: 5000, second: 1, mode: SourceMode.virtual));
    expect(out.rejection, isNull, reason: '合成資料沒有量測誤差，品質閘門不適用');
    expect(out.targetPixel, isNotNull);
    expect(manifest.projectCallCount, 1);
  });

  test('品質閘門丟棄者不進入其後任何步驟', () {
    manifest.resetCallCounts();
    final out = pipeline.ingest(at(metersNorth: 0, accuracy: 150)); // > 100m
    expect(out.rejection, isNotNull);
    expect(out.targetPixel, isNull);
    expect(out.events, isEmpty);
    expect(manifest.projectCallCount, 0);
  });

  test('顯著位移產生的事件，距離為投影前的地理距離', () {
    pipeline.ingest(at(metersNorth: 0));
    final out = pipeline.ingest(at(metersNorth: 60, second: 1));
    final e = out.events.whereType<DisplacementEvent>().single;
    expect(e.distanceMeters, closeTo(60, 1),
        reason: '不得改用吸附後的像素差反算——兩者差距可達吸附上限，且逐筆累積');
  });
}
```

- [ ] **步驟 2：執行，確認失敗**
- [ ] **步驟 3：寫實作**

`ingest` 嚴格依 §3.0 第 3~12 步串接，各步驟只做委派，不含自己的判定邏輯。
**第 12 步的距離用第 7 步之前的地理距離**（即 `SignificanceGate` 回傳值），與投影、吸附無關。

- [ ] **步驟 4：執行，確認通過**
- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: compose the location pipeline in a fixed order

Order changes results, so it is pinned in one place rather than implied
across a dozen requirements. Two orderings matter most: the bounds check
precedes projection, and the distance that reaches the buckets is the
geographic distance measured before projection, not a pixel difference
converted back after snapping — those differ by up to the snap limit on
every step and would compound."
```

---

### Task 13：平滑位移與公尺換算

**實作：** REQ-C-06 全部；AC-6.1~6.9；NFR-4

**檔案：**
- 建立：`lib/domain/location/smoothing/position_smoother.dart`
- 測試：`test/domain/location/smoothing/position_smoother_test.dart`

**介面：**
- 消費：`OverworldMapManifest`（僅用 `metersPerPixelAt`）
- 產出：

```dart
class PositionSmoother {
  PositionSmoother({
    required OverworldMapManifest manifest,   // 只用 metersPerPixelAt
    required Duration halfLife,               // 1.0s
    required double arrivalMeters,            // 2
    required double headingMeters,            // 5
  });

  /// 設定目標點。此時以【當前顯示點】查詢公尺/像素比例並重算門檻，
  /// 沿用至下次呼叫（規格 REQ-C-06 規則 7 的求值契約）。
  void setTarget(Vector2 target);

  /// 換層或首次定位：不平滑，直接指定顯示點並重算門檻。
  void jumpTo(Vector2 position);

  void update(double dt);
  Vector2 get rendered;
  double get headingRadians;
  double get arrivalThresholdPixels;   // AC-6.7 斷言此值
  double get headingThresholdPixels;   // AC-6.9 斷言此值
}
```

> **為什麼收 manifest 而非 `double metersPerPixel`**：規格 REQ-C-06 規則 7 要求「以**當前顯示點**查詢比例」。若簽章只收一個 `double`，smoother 永遠不知道自己在哪，求值契約與 AC-6.8 就無處實作。

- [ ] **步驟 1：先寫失敗的測試**

```dart
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/smoothing/position_smoother.dart';

PositionSmoother smoother({OverworldMapManifest? manifest}) => PositionSmoother(
      manifest: manifest ?? FakeMapManifest.linear(),   // 公尺/像素 = 1.0
      halfLife: const Duration(seconds: 1),
      arrivalMeters: 2,
      headingMeters: 5,
    );

void main() {
  test('AC-6.2 幀率無關：30fps 與 120fps 推進 1 秒，差距 < 初始距離的 1%', () {
    final a = smoother()..setTarget(Vector2(100, 0));
    final b = smoother()..setTarget(Vector2(100, 0));
    for (var i = 0; i < 30; i++) { a.update(1 / 30); }
    for (var i = 0; i < 120; i++) { b.update(1 / 120); }
    expect((a.rendered - b.rendered).length, lessThan(1.0));
  });

  test('AC-6.3 經過一個半衰期，剩餘距離為初始的 50% ± 5%', () {
    final s = smoother()..setTarget(Vector2(100, 0));
    for (var i = 0; i < 60; i++) { s.update(1 / 60); }
    final remaining = (Vector2(100, 0) - s.rendered).length;
    expect(remaining, inInclusiveRange(45, 55));
    // 加嚴：把指數形式釘死。k = 1/halfLife 的誤寫會得 36.8；
    // Euler 近似會得約 50.3，仍在 ±5 內，但這條 0.05 的容差擋得住。
    expect(remaining, closeTo(50.0, 0.05));
  });

  test('AC-6.6 顯示點與目標點無別名', () {
    final target = Vector2(100, 0);
    final s = smoother()..setTarget(target);
    s.update(1.0);
    final before = s.rendered.clone();
    target.setValues(999, 999); // 直接改呼叫端持有的向量
    expect(s.rendered, equals(before),
        reason: 'Vector2 可變，參考指派會讓平滑靜默失效而測試照樣通過');
  });

  test('AC-6.7 抵達門檻依公尺/像素比例換算', () {
    final a = smoother()..setTarget(Vector2(0, 0));                       // mpp = 1.0
    final b = smoother(manifest: FakeMapManifest.fixedScale(370.4))
      ..setTarget(Vector2(0, 0));
    expect(a.arrivalThresholdPixels, closeTo(2.0, 0.01));
    expect(b.arrivalThresholdPixels, closeTo(0.0054, 0.0005));
  });

  test('AC-6.1 距離單調遞減', () {
    final s = smoother()..setTarget(Vector2(100, 0));
    var prev = 100.0;
    for (var i = 0; i < 30; i++) {
      s.update(1 / 30);
      final d = (Vector2(100, 0) - s.rendered).length;
      expect(d, lessThan(prev));
      prev = d;
    }
  });

  test('AC-6.8 換算值以【當時顯示點】重算，同一次更新期間不再變動', () {
    // nonLinear: mpp = 1.0 + x/1000
    final s = smoother(manifest: FakeMapManifest.nonLinear())
      ..setTarget(Vector2(1000, 0));
    final atStart = s.arrivalThresholdPixels;   // 顯示點在 x=0 → mpp=1.0 → 2 px
    expect(atStart, closeTo(2.0, 0.01));
    for (var i = 0; i < 60; i++) { s.update(1 / 60); }
    expect(s.arrivalThresholdPixels, atStart,
        reason: '同一次目標點更新期間不得重算');
    s.setTarget(Vector2(1000, 0));              // 顯示點已移到 x≈500 → mpp≈1.5
    expect(s.arrivalThresholdPixels, lessThan(atStart));
  });

  test('AC-6.9 位移超過朝向門檻則朝向更新', () {
    final s = smoother()..setTarget(Vector2(100, 0));
    final h0 = s.headingRadians;
    s.update(0.5);   // 單幀位移約 29 px > 5 px 門檻
    expect(s.headingRadians, isNot(h0));
  });

  test('AC-6.4 已抵達後不再變動', () {
    final s = smoother()..setTarget(Vector2(0.0001, 0));
    s.update(1.0);
    final r = s.rendered.clone();
    s.update(1.0);
    expect(s.rendered, equals(r));
  });

  test('AC-6.9 位移小於朝向門檻則朝向不變', () {
    final s = smoother()..setTarget(Vector2(1, 0));
    final h0 = s.headingRadians;
    s.update(1 / 60);
    expect(s.headingRadians, h0);
  });
}
```

- [ ] **步驟 2：執行，確認失敗**
- [ ] **步驟 3：寫實作**

```dart
/// 平滑位移。
///
/// GPS 只寫目標點，顯示點逐幀趨近它。收斂用 1 - exp(-k·dt) 而非固定係數的
/// lerp：後者在 120Hz 與 30Hz 裝置上速度不同，同樣的一秒走過不同的距離。
///
/// 門檻以公尺定義再換算成像素。用像素定義會隨地圖尺度失真——在大地圖上
/// 1 像素等於 370 公尺，玩家在一個街區內移動會被判定為「已抵達」。
///
/// 換算的求值契約：以當前顯示點查詢比例，每次目標點更新時重算一次並沿用。
/// 非線性地圖上這個比例逐點變化，不釘死求值點與時機，兩個人會寫出行為不同
/// 而各自「正確」的實作。
class PositionSmoother {
  // 成員見本任務「介面」段落，該處已列出完整簽章
}
```

`setTarget` 必須 `_target.setFrom(target)` 而非 `_target = target`，並在檔內註明理由。

**NFR-4（每幀常數時間）**：`update()` 內不得呼叫 `metersPerPixelAt` —— 門檻只在 `setTarget`／`jumpTo` 時重算一次。非線性圖資的比例查詢可能牽涉插值運算，放進每幀會讓幀成本取決於投影演算法。

- [ ] **步驟 4：執行，確認通過（6 tests passed）**
- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add frame-rate independent position smoothing

GPS writes only the target; the rendered point chases it. Convergence
uses 1 - exp(-k·dt) rather than a fixed lerp factor, which would cover
different ground in the same second on a 120Hz device than on a 30Hz one.

Thresholds are metres converted to pixels at the current scale. Defined
in pixels they distort with the map: one pixel is 370 metres on the
overworld, so a player crossing a city block would read as arrived.

The target is copied into place rather than assigned by reference.
Vector2 is mutable, so an assignment would let a later write to the
caller's vector move the rendered point too — and 'rendered approaches
target' would still pass while smoothing did nothing."
```

---

## Phase 3 — 服務層

### Task 14：定位來源抽象與虛擬來源

**實作：** REQ-C-10 全部；AC-10.1~10.6

**檔案：**
- 建立：`lib/data/location/location_source.dart`
- 建立：`lib/data/location/virtual_location_source.dart`
- 測試：`test/data/location/virtual_location_source_test.dart`

**介面：**
- 消費：`Clock`、`BuildFlags`、`OverworldMapManifest`
- 產出：

```dart
abstract class LocationSource {
  Stream<GeoFix> get fixes;
  Future<void> start();
  Future<void> stop();
}

class VirtualLocationSource implements LocationSource {
  void setDirection(Vector2 unitDirection);   // 方向鍵
  void stopMoving();
  void teleportTo(double lat, double lng);    // 僅除錯
  void tapNavigateTo(Vector2 pixel);          // 僅除錯
}

/// release 時回傳 null，故除錯入口在正式建置不存在。
VirtualLocationSource? debugSourceFactory({
  required BuildFlags flags,
  required OverworldMapManifest manifest,
  required Clock clock,
});
```

**虛擬 Fix 的欄位約定**（規格 REQ-C-10 規則 5）：`sourceMode = virtual`、`accuracyMeters = 1.0`、`hasAccuracy = true`、`hasSpeed = false`、`isMocked = false`。
管線見到 `sourceMode == virtual` 即跳過品質閘門（§3.0 第 3~5 步），故其地理速度雖遠超門檻也不會被丟棄。

- [ ] **步驟 1：先寫失敗的測試**

```dart
void main() {
  late FakeClock clock;
  late FakeMapManifest manifest;
  late VirtualLocationSource source;

  setUp(() {
    clock = FakeClock();
    manifest = FakeMapManifest.linear();   // dpadSpeedPixelsPerSecond = 40
    source = VirtualLocationSource(manifest: manifest, clock: clock, hertz: 15);
  });

  test('AC-10.2 方向鍵 10 秒產生約 150 筆，位移符合圖層宣告速度', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.setDirection(Vector2(1, 0));
    for (var i = 0; i < 150; i++) { clock.advance(const Duration(milliseconds: 67)); }
    await sub.cancel();

    expect(received.length, inInclusiveRange(145, 155));
    final first = manifest.projectToPixel(received.first.latitude, received.first.longitude);
    final last = manifest.projectToPixel(received.last.latitude, received.last.longitude);
    expect((last - first).length, closeTo(40 * 10, 20),
        reason: '40 px/s × 10 s = 400 px');
  });

  test('AC-10.1 點擊尋路：反投影往返誤差 < 2 像素', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.tapNavigateTo(Vector2(120, 140));   // 在 linear() 的範圍內
    clock.advance(const Duration(milliseconds: 67));
    await sub.cancel();

    final back = manifest.projectToPixel(received.last.latitude, received.last.longitude);
    expect((back - Vector2(120, 140)).length, lessThan(2.0));
  });

  test('AC-10.5 每筆 Fix 的 sourceMode 為 virtual', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.setDirection(Vector2(0, 1));
    clock.advance(const Duration(milliseconds: 335));   // 約 5 筆
    await sub.cancel();
    expect(received, isNotEmpty);
    expect(received.every((f) => f.sourceMode == SourceMode.virtual), isTrue);
  });

  test('AC-10.4 release 旗標下除錯工廠回傳 null', () {
    expect(
      debugSourceFactory(
          flags: const BuildFlags.release(), manifest: manifest, clock: clock),
      isNull,
    );
    expect(
      debugSourceFactory(
          flags: const BuildFlags.debug(), manifest: manifest, clock: clock),
      isNotNull,
    );
  });

  test('AC-10.3 同一組管線測試對虛擬與真實來源皆通過', () {
    // 同一組斷言跑兩次，只換 sourceMode。
    for (final mode in SourceMode.values) {
      final pipeline = LocationPipeline(manifest: FakeMapManifest.linear(), clock: FakeClock());
      pipeline.ingest(at(metersNorth: 0, mode: mode));
      final out = pipeline.ingest(at(metersNorth: 60, second: 1, mode: mode));
      expect(out.targetPixel, isNotNull, reason: '$mode 下管線行為不一致');
      expect(out.events.whereType<DisplacementEvent>().single.sourceMode, mode);
    }
  });

  test('虛擬 Fix 的精度已量測且為小值', () async {
    final received = <GeoFix>[];
    final sub = source.fixes.listen(received.add);
    await source.start();
    source.setDirection(Vector2(1, 0));
    clock.advance(const Duration(milliseconds: 67));
    await sub.cancel();
    expect(received.first.hasAccuracy, isTrue);
    expect(received.first.accuracyMeters, lessThan(5));
  });
}
```

> `at(...)` 輔助函式沿用 Task 12 測試檔的定義，複製到本檔。

- [ ] **步驟 2：執行，確認失敗**
- [ ] **步驟 3：寫實作**

Fix 產生用 `Stream` 由 `FakeClock` 驅動（測試）或 `Timer.periodic`（正式）。
把時間來源做成建構子參數，測試才不需要真的等 10 秒。

- [ ] **步驟 4：執行，確認通過**
- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add location source abstraction and virtual source

The virtual source serves two purposes through one abstraction: the
shipping d-pad mode and debug navigation. Downstream code cannot tell
which source it is reading, which is what lets the whole pipeline be
tested without a device.

It bypasses the platform distance filter and the application throttle.
Walking at 5 km/h through a 10-metre filter yields one fix every seven
seconds, which would make the d-pad unplayable, and the d-pad is a
shipping feature rather than a debug affordance.

Debug entry points come from a factory that returns null under the
release flag, so their absence in a release build is a test rather than
a convention."
```

---

### Task 15：權限、服務與精度等級

**實作：** REQ-C-01 全部；AC-1.1~1.8

**檔案：**
- 建立：`lib/data/location/location_permission_gateway.dart`
- 建立：`lib/domain/location/pipeline/permission_resolver.dart`
- 測試：`test/domain/location/pipeline/permission_resolver_test.dart`

**介面：**
- 產出：

```dart
abstract class LocationPermissionGateway {
  Future<bool> isServiceEnabled();
  Future<PlatformPermission> checkPermission();
  Future<PlatformPermission> requestPermission();
  Future<PlatformAccuracy> getAccuracy();       // precise / reduced
  Stream<bool> get serviceEnabledChanges;
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class PermissionResolver {
  Future<PermissionState> resolve();            // 去重的並發請求
  Stream<PermissionState> get states;           // 服務狀態變化驅動
  /// 輔助啟發式：在品質過濾【之前】對原始 Fix 評估（§3.0 第 2 步、AC-0.2）。
  void observeRawFix({required double accuracyMeters});
}
```

- [ ] **步驟 1：先寫失敗的測試**

建立 `test/fakes/fake_permission_gateway.dart`：

```dart
class FakePermissionGateway implements LocationPermissionGateway {
  bool serviceEnabled = true;
  PlatformPermission permission = PlatformPermission.granted;
  PlatformAccuracy accuracy = PlatformAccuracy.precise;
  int requestCallCount = 0;
  final _serviceChanges = StreamController<bool>.broadcast();

  void pushServiceEnabled(bool v) { serviceEnabled = v; _serviceChanges.add(v); }

  @override Future<bool> isServiceEnabled() async => serviceEnabled;
  @override Future<PlatformPermission> checkPermission() async => permission;
  @override Future<PlatformPermission> requestPermission() async {
    requestCallCount++;
    return permission;
  }
  @override Future<PlatformAccuracy> getAccuracy() async => accuracy;
  @override Stream<bool> get serviceEnabledChanges => _serviceChanges.stream;
  @override Future<void> openAppSettings() async {}
  @override Future<void> openLocationSettings() async {}
}
```

`test/domain/location/pipeline/permission_resolver_test.dart`：

```dart
void main() {
  late FakePermissionGateway gateway;
  late PermissionResolver resolver;

  setUp(() {
    gateway = FakePermissionGateway();
    resolver = PermissionResolver(gateway: gateway);
  });

  test('AC-1.1 服務關閉時不請求權限', () async {
    gateway.serviceEnabled = false;
    expect(await resolver.resolve(), PermissionState.serviceDisabled);
    expect(gateway.requestCallCount, 0,
        reason: '服務總開關關閉時請求權限會靜默失敗');
  });

  test('AC-1.2 權限未決 → 恰請求一次；允許後為 ready', () async {
    gateway.permission = PlatformPermission.notDetermined;
    final first = await resolver.resolve();
    expect(gateway.requestCallCount, 1);
    gateway.permission = PlatformPermission.granted;
    expect(await resolver.resolve(), PermissionState.ready);
    expect(first, isNot(PermissionState.ready));
  });

  test('AC-1.4 並發呼叫 3 次，權限請求器只被呼叫 1 次', () async {
    gateway.permission = PlatformPermission.notDetermined;
    await Future.wait([resolver.resolve(), resolver.resolve(), resolver.resolve()]);
    expect(gateway.requestCallCount, 1);
  });

  test('AC-1.5 平台回報 reduced → approximate，不需等待任何 Fix', () async {
    gateway.accuracy = PlatformAccuracy.reduced;
    expect(await resolver.resolve(), PermissionState.approximate);
  });

  test('AC-1.6 approximate 的恢復不依賴訂閱', () async {
    gateway.accuracy = PlatformAccuracy.reduced;
    expect(await resolver.resolve(), PermissionState.approximate);
    // 不餵任何 Fix、不建立任何訂閱
    gateway.accuracy = PlatformAccuracy.precise;
    expect(await resolver.resolve(), PermissionState.ready,
        reason: 'approximate 期間訂閱已取消，恢復路徑不得依賴它');
  });

  test('AC-1.7 前景中服務被關閉 → serviceDisabled', () async {
    final states = <PermissionState>[];
    final sub = resolver.states.listen(states.add);
    gateway.pushServiceEnabled(false);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(states.last, PermissionState.serviceDisabled);
  });

  test('AC-1.8 服務恢復 → 重新檢查並更新', () async {
    gateway.pushServiceEnabled(false);
    await Future<void>.delayed(Duration.zero);
    gateway.pushServiceEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(await resolver.resolve(), PermissionState.ready);
  });

  test('AC-0.2 精度啟發式在品質過濾之前評估', () async {
    // 注入恆為 2000 m 的原始 Fix；它們會被品質閘門丟棄，
    // 但精度等級仍必須判定得出來。
    for (var i = 0; i < 3; i++) {
      resolver.observeRawFix(accuracyMeters: 2000);
    }
    expect(await resolver.resolve(), PermissionState.approximate);
  });
}
```

- [ ] **步驟 2：執行，確認失敗**
- [ ] **步驟 3：寫實作**

`resolve()` 內以一個 `Future?` 欄位做在途請求去重。
精度主判定用 `getAccuracy()`；連續 3 筆 > 500m 的啟發式作為輔助，在品質過濾**之前**評估。

- [ ] **步驟 4：執行，確認通過**
- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: resolve permission, service and accuracy level

Accuracy level comes from the platform's own query rather than from
watching fixes degrade. Under Android's approximate location and iOS's
reduced accuracy the permission check reports granted while every fix is
several hundred metres wide and gets discarded, so the player is
authorised and frozen with nothing to explain it.

That also fixes the recovery path: since the query needs no subscription,
a player who enables precise location in settings gets out of the state,
where a rule that waited for fixes could not — the subscription had
already been cancelled for being in it."
```

---
### Task 16：串流節流、生命週期與省電

**實作：** REQ-C-02 規則 3、5~7；REQ-C-11 規則 1~3（P0）；AC-2.1~2.7、AC-11.1~11.3

**檔案：**
- 建立：`lib/data/location/geolocator_location_source.dart`
- 建立：`lib/data/location/location_subscription_manager.dart`
- 建立：`lib/domain/location/pipeline/fix_throttle.dart`
- 測試：`test/domain/location/pipeline/fix_throttle_test.dart`
- 測試：`test/data/location/lifecycle_test.dart`

**介面：**
- 產出：`FixThrottle`（throttleLatest：leading + trailing，窗長注入）
- 產出：`LocationSubscriptionManager`（背景 20 秒才取消、恢復 2 秒 debounce、`PowerMode` 查詢）

- [ ] **步驟 1：先寫失敗的測試**

```dart
void main() {
  group('節流', () {
    late FakeClock clock;
    late FixThrottle throttle;
    late List<GeoFix> out;

    setUp(() {
      clock = FakeClock();
      throttle = FixThrottle(clock: clock, window: const Duration(seconds: 1));
      out = [];
      throttle.output.listen(out.add);
    });

    test('AC-2.1 以 2 秒間隔推送 5 筆 → 收到 5 筆，順序內容一致', () {
      for (var i = 0; i < 5; i++) {
        throttle.add(at(metersNorth: i * 100.0, second: i * 2));
        clock.advance(const Duration(seconds: 2));
      }
      expect(out.length, 5);
      expect(out.map((f) => f.timestampUtc.second), [0, 2, 4, 6, 8]);
    });

    test('AC-2.2 1 秒內推送 10 筆 → 收到 2 筆：第 1 筆與窗尾最新筆', () {
      for (var i = 0; i < 10; i++) {
        throttle.add(at(metersNorth: i.toDouble(), second: i));
        clock.advance(const Duration(milliseconds: 90));
      }
      clock.advance(const Duration(seconds: 1));   // 觸發窗尾補發
      expect(out.length, 2);
      expect(out.last.timestampUtc.second, 9,
          reason: '窗尾補發的必須是最新那筆，不是第 2 筆');
    });

    test('AC-10.6 虛擬來源的 Fix 不被合併', () {
      for (var i = 0; i < 10; i++) {
        throttle.add(at(metersNorth: i.toDouble(), second: i, mode: SourceMode.virtual));
        clock.advance(const Duration(milliseconds: 10));
      }
      expect(out.length, 10);
    });
  });

  group('生命週期與省電', () {
    late FakeClock clock;
    late FakeLocationSource source;
    late LocationSubscriptionManager manager;

    setUp(() {
      clock = FakeClock();
      source = FakeLocationSource();
      manager = LocationSubscriptionManager(
        source: source, clock: clock,
        backgroundGrace: const Duration(seconds: 20),
        resumeDebounce: const Duration(seconds: 2),
      );
      manager.start();
    });

    test('AC-2.3 背景 5 秒後返回 → 訂閱未曾取消', () {
      manager.onBackground();
      clock.advance(const Duration(seconds: 5));
      manager.onForeground();
      expect(source.cancelCount, 0);
      expect(manager.activeSubscriptionCount, 1);
    });

    test('AC-2.4 背景 30 秒後返回 → 曾取消，恢復在 debounce 之後，訂閱數為 1', () {
      manager.onBackground();
      clock.advance(const Duration(seconds: 30));
      expect(source.cancelCount, 1);
      manager.onForeground();
      expect(manager.activeSubscriptionCount, 0, reason: 'debounce 尚未過');
      clock.advance(const Duration(seconds: 2));
      expect(manager.activeSubscriptionCount, 1);
    });

    test('AC-2.5 dispose 後 activeSubscriptionCount == 0', () {
      manager.dispose();
      expect(manager.activeSubscriptionCount, 0);
    });

    test('AC-11.1 進入 Mini-game → 訂閱取消', () {
      manager.setPowerMode(PowerMode.suspended);
      expect(manager.activeSubscriptionCount, 0);
    });

    test('AC-11.2 切換為 virtual → GPS 訂閱取消', () {
      manager.onModeChanged(SourceMode.virtual);
      expect(manager.activeSubscriptionCount, 0);
    });

    test('AC-11.3 suspended 期間不產生任何位置更新', () {
      final received = <GeoFix>[];
      manager.fixes.listen(received.add);
      manager.setPowerMode(PowerMode.suspended);
      source.emit(at(metersNorth: 100));
      expect(received, isEmpty);
    });
  });

  group('冷啟動', () {
    test('AC-2.6 顯示點等於預設降落點，且未查詢平台的最後已知位置', () {
      final manifest = FakeMapManifest.linear();
      final source = FakeLocationSource();
      final manager = LocationSubscriptionManager(
          source: source, clock: FakeClock(), manifest: manifest);
      expect(manager.initialRenderedPixel, manifest.defaultSpawnPixel);
      expect(source.lastKnownQueryCount, 0,
          reason: '不查詢最後已知位置——它省下一秒空白，代價是整條管線的特例規則');
    });

    test('AC-2.7 冷啟動首筆即使距降落點數百公里 → 不發傳送事件，兩桶不變', () {
      final pipeline = LocationPipeline(
          manifest: FakeMapManifest.linear(), clock: FakeClock());
      final out = pipeline.ingest(at(metersNorth: 0));   // 首筆
      expect(out.events.whereType<RelocationEvent>(), isEmpty);
      expect(out.events.whereType<DisplacementEvent>(), isEmpty);
    });
  });
}
```

> `at(...)` 沿用 Task 12 測試檔的定義。`FakeLocationSource` 建立於 `test/fakes/fake_location_source.dart`，需暴露 `cancelCount`、`lastKnownQueryCount` 與 `emit(GeoFix)`。

- [ ] **步驟 2：執行，確認失敗**
- [ ] **步驟 3：寫實作**

節流用注入的 `Clock` 與可測的排程器，**不要**用真實 `Timer` 讓測試等待。
`GeolocatorLocationSource` 只做型別轉換（`Position` → `GeoFix`，含 `hasAccuracy`/`hasSpeed` 旗標），不含任何判定邏輯 —— 判定全在 domain。

- [ ] **步驟 4：執行，確認通過**
- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add fix throttling, lifecycle and power management

Throttling is leading-plus-trailing rather than trailing-only sampling,
which would add a fixed second of lag and work against the smoothing
this spec spends most of its length on. Virtual fixes bypass it entirely.

A brief trip to the background — a call, the notification shade, the
camera — does not cancel the subscription, and resuming is debounced.
Rebuilding the stream on every transition forces a GPS cold start each
time, which on a device with busy notifications makes the game unusable.

Cold start uses the manifest's spawn point and never queries the
platform's last known position. That saved a second of blank screen at
the cost of a special case threaded through the whole pipeline, and left
no answer to what the first real fix's jump was measured from."
```

---

## Phase 4 — 接線

### Task 17：狀態控制器與隱私 DTO

**實作：** REQ-C-13 規則 1~3、5、12；REQ-C-12；REQ-C-14 整合；AC-13.1~13.3、13.8~13.10、AC-12.1、12.2、AC-14.6

**檔案：**
- 建立：`lib/state/location/location_controller.dart`
- 建立：`lib/state/location/location_providers.dart`
- 建立：`lib/domain/location/models/location_snapshot_dto.dart`
- 測試：`test/state/location/location_controller_test.dart`

**介面：**
- 產出：`LocationControllerState`（freezed）：`status`（五維度）、`diagnostics`、`renderedPixel`、`realDistanceMeters`、`virtualDistanceMeters`。
  > `Notifier<LocationStatus>` 放不下診斷與分桶距離（AC-14.6、AC-11.4、AC-13.4 都要斷言它們），故 state 為一個聚合物件。
- 產出：`LocationController extends Notifier<LocationControllerState>`，暴露語意化方法 `switchMode(SourceMode, {required bool automatic})`、`ingest(GeoFix)`、`onPermissionChanged(PermissionState)`，**不暴露 setter**。
- 產出：`LocationSnapshotDto`（可持久化，**不含經緯度**）：`renderedPixelX/Y`、`realDistanceMeters`、`virtualDistanceMeters`、`mode`、`savedAtUtc`。

- [ ] **步驟 1：先寫失敗的測試**

```dart
void main() {
  late ProviderContainer container;
  late FakeClock clock;
  late FakeMapManifest manifest;

  LocationController controller() => container.read(locationControllerProvider.notifier);
  LocationControllerState state() => container.read(locationControllerProvider);

  setUp(() {
    clock = FakeClock();
    manifest = FakeMapManifest.linear();
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock),
      mapManifestProvider.overrideWithValue(manifest),
      buildFlagsProvider.overrideWithValue(const BuildFlags.debug()),
    ]);
    addTearDown(container.dispose);
  });

  test('AC-13.1 手動切換即時生效', () {
    controller().switchMode(SourceMode.virtual, automatic: false);
    expect(state().status.mode, SourceMode.virtual);
  });

  test('AC-13.2 權限被拒 → 自動切 virtual 並標記為自動', () {
    controller().onPermissionChanged(PermissionState.denied);
    expect(state().status.mode, SourceMode.virtual);
    expect(controller().lastSwitchWasAutomatic, isTrue);
  });

  test('AC-13.3 定位恢復可用 → mode 維持 virtual', () {
    controller().onPermissionChanged(PermissionState.denied);
    controller().onPermissionChanged(PermissionState.ready);
    expect(state().status.mode, SourceMode.virtual,
        reason: '恢復後不自動切回，由玩家決定');
  });

  test('AC-13.8 isMocked 的 Fix 在 gps 模式下，位移計入 virtual 桶', () {
    controller().ingest(at(metersNorth: 0).copyWith(isMocked: true));
    controller().ingest(at(metersNorth: 60, second: 1).copyWith(isMocked: true));
    expect(state().virtualDistanceMeters, closeTo(60, 2));
    expect(state().realDistanceMeters, 0);
  });

  test('AC-13.9 除錯旗標開啟時，isMocked 仍依 mode 歸屬', () {
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock),
      mapManifestProvider.overrideWithValue(manifest),
      buildFlagsProvider.overrideWithValue(const BuildFlags.debug()),
      ignoreMockedFlagProvider.overrideWithValue(true),
    ]);
    controller().ingest(at(metersNorth: 0).copyWith(isMocked: true));
    controller().ingest(at(metersNorth: 60, second: 1).copyWith(isMocked: true));
    expect(state().realDistanceMeters, closeTo(60, 2),
        reason: '模擬器與 GPX 除錯期間 isMocked 恆為真，不覆寫就無法驗證 gps 模式');
  });

  test('AC-12.1 持久化 DTO 的序列化結果不含座標鍵', () {
    final json = LocationSnapshotDto(
      renderedPixelX: 100, renderedPixelY: 200,
      realDistanceMeters: 500, virtualDistanceMeters: 0,
      mode: SourceMode.gps, savedAtUtc: DateTime.utc(2026),
    ).toJson();
    for (final k in ['lat', 'lng', 'latitude', 'longitude']) {
      expect(json.keys.map((e) => e.toLowerCase()), isNot(contains(k)));
    }
  });

  test('AC-12.2 release 旗標下，注入的假 logger 不含任何座標字串', () {
    final logger = FakeLogger();
    final c = LocationController.forTest(
        logger: logger, flags: const BuildFlags.release(), manifest: manifest, clock: clock);
    c.ingest(at(metersNorth: 0));
    expect(logger.lines.join('\n'), isNot(contains('24.0')));
    expect(logger.lines.join('\n'), isNot(contains('121.0')));
  });

  test('AC-13.10 第一版不持久化模式，重啟後依當時權限重新判定', () {
    // 規格 Q18 把跨進程持久化列為 P1，相依任務 B 的持久化層。
    controller().switchMode(SourceMode.virtual, automatic: false);
    final restored = LocationController.forTest(
        flags: const BuildFlags.debug(), manifest: manifest, clock: clock);
    expect(restored.state.status.mode, SourceMode.gps,
        reason: 'P0 行為：不持久化。持久化為 P1，相依任務 B');
  });

  test('AC-14.6 診斷計數隨丟棄遞增', () {
    controller().ingest(at(metersNorth: 0, accuracy: 150));
    expect(state().diagnostics.rejectedFixCount, 1);
    expect(state().diagnostics.rejectionsByReason[RejectionReason.accuracy], 1);
  });
}
```

- [ ] **步驟 2：執行，確認失敗**
- [ ] **步驟 3：寫實作**

`LocationController` 是**唯一寫入點**。Flame 元件與 HUD 只讀，不得持有可變狀態。
`Notifier` 內組裝 T6~T13 的純函式模組，自身不含判定邏輯。

`location_providers.dart` 需提供可覆寫的注入點：`clockProvider`、`mapManifestProvider`、`buildFlagsProvider`、`ignoreMockedFlagProvider`、`locationControllerProvider`。
另提供 `LocationController.forTest({...})` 具名建構子，供不經 `ProviderContainer` 的斷言使用。

- [ ] **步驟 4：執行，確認通過**
- [ ] **步驟 5：提交**

```bash
git add -A
git commit -m "feat: add location controller as the single write point

The controller assembles the pure modules and exposes intent-shaped
methods rather than setters, so game values have exactly one path in.

Mock-flagged fixes are attributed to the virtual bucket. This is not a
defence — Android needs API 18, iOS needs 15 and catches only software
simulation, and the flag defaults to false when unavailable — it only
keeps the attribution honest, and a debug override exists because the
simulator sets the flag and would otherwise make gps mode untestable.

The persisted DTO carries no coordinates, asserted on the serialised
keys rather than trusted to review."
```

---

### Task 18：Flame 橋接與既有技術債清償

**實作：** PRE-3、PRE-5、PRE-7；NFR-5；Task 1 跳過的架構測試

**檔案：**
- 建立：`lib/game/components/player_component.dart`
- 修改：`lib/game/universal_overworld_game.dart`（全檔）
- 修改：`lib/main.dart`（注入 manifest）
- 修改：`test/architecture/layer_boundaries_test.dart`（移除 skip）
- 測試：`test/game/player_component_test.dart`

- [ ] **步驟 1：移除 Task 1 的 skip，確認測試變紅**

```bash
flutter test test/architecture/layer_boundaries_test.dart
```

預期：「通用引擎不得引用具名城市模組」FAIL。這是本任務要清償的債。

- [ ] **步驟 2：把台灣相依移出通用引擎**

- 刪除 `universal_overworld_game.dart` 對 `taiwan_geo_calibrator.dart` 的 import。
- `updatePlayerGps` 改為呼叫注入的 `LocationController`，不自行投影或吸附。
- 玩家起始位置改用 `manifest.defaultSpawnPixel`，移除 `Vector2(1162, 148)` 常數。
- `main.dart` 的 manifest 由 provider 注入，不在 `initState` 內 `new`。

- [ ] **步驟 3：建立 PlayerComponent**

```dart
/// 只負責把 domain 算出的顯示點畫出來。
///
/// 讀取 Flame 元件座標時要注意各元件的 getter 語意不一致：一者回傳活參考、
/// 一者回傳副本，兩種失效模式都不會報錯。故一律以 setFrom / clone 明確表達意圖。
class PlayerComponent extends PositionComponent {
  /// 由 LocationController 的 renderedPixel 驅動；本身不持有任何遊戲數值。
  void syncTo(Vector2 renderedPixel) => position.setFrom(renderedPixel);
}
```

- [ ] **步驟 4：驗證訂閱釋放（NFR-5）**

```dart
test('NFR-5 遊戲實例移除後，所有訂閱與計時器皆已釋放', () {
  // 建立 game、加入、再 onRemove，斷言診斷的 activeSubscriptionCount 為 0
});
```

熱重載會重建 game 實例，訂閱未釋放會累積並造成重複觸發。

- [ ] **步驟 5：執行全部測試，確認架構測試轉綠**

```bash
flutter analyze && flutter test
```

- [ ] **步驟 6：提交**

```bash
git add -A
git commit -m "refactor: remove Taiwan coupling from the generic engine (PRE-3, 5, 7)

The overworld game imported the Taiwan calibrator and called it
directly, hardcoded a Taipei spawn coordinate, and the scaffold
constructed the Taiwan manifest in initState — three ways the same
city leaked into code that is supposed to treat cities as content.

Projection, snapping and the spawn point now come from the injected
manifest, and the boundary test that was skipped for this reason is
unskipped in the same commit.

Subscriptions are released on removal. Hot reload rebuilds the game
instance, and leaked subscriptions accumulate into duplicate triggers
that are hard to attribute later."
```

---

## Phase 5 — P1 需求

### Task 19：相機跟隨狀態機

**實作：** REQ-C-08 全部；AC-8.1~8.5

**檔案：**
- 建立：`lib/domain/location/camera/camera_follow.dart`
- 測試：`test/domain/location/camera/camera_follow_test.dart`

**介面：**

```dart
enum CameraMode { following, free, returning }

class CameraFollow {
  CameraFollow({required Clock clock, required Duration returnDelay}); // 3s
  void onPan();      // 手勢平移
  void onZoom();     // 縮放：不算操作
  void recenter();   // 「回到我的位置」
  CameraMode get mode;
  Vector2 targetCenter({required Vector2 player, required double zoom,
                        required Vector2 viewportSize, required Vector2 mapSize});
}
```

- [ ] **步驟 1：先寫失敗的測試**

```dart
void main() {
  late FakeClock clock;
  late CameraFollow camera;

  setUp(() {
    clock = FakeClock();
    camera = CameraFollow(clock: clock, returnDelay: const Duration(seconds: 3));
  });

  Vector2 center({Vector2? player, double zoom = 1.0,
      Vector2? viewport, Vector2? map}) =>
      camera.targetCenter(
        player: player ?? Vector2(400, 300),
        zoom: zoom,
        viewportSize: viewport ?? Vector2(800, 600),
        mapSize: map ?? Vector2(2048, 1152),
      );

  test('AC-8.1 手勢平移 → free', () {
    expect(camera.mode, CameraMode.following);
    camera.onPan();
    expect(camera.mode, CameraMode.free);
  });

  test('AC-8.2 停止操作滿 3 秒 → returning → following', () {
    camera.onPan();
    clock.advance(const Duration(seconds: 3));
    expect(camera.mode, CameraMode.returning);
    // returning 完成後回到 following（以連續呼叫 targetCenter 推進收斂）
    for (var i = 0; i < 120; i++) { center(); }
    expect(camera.mode, CameraMode.following);
  });

  test('AC-8.3 free 下玩家移動，相機中心不變', () {
    camera.onPan();
    final before = center(player: Vector2(400, 300));
    final after = center(player: Vector2(900, 700));
    expect(after, before);
  });

  test('AC-8.4 地圖小於視口時，中心為地圖中點', () {
    final c = center(map: Vector2(100, 100), viewport: Vector2(800, 600));
    expect(c, Vector2(50, 50));
  });

  test('AC-8.4b 任意 zoom 下中心不越界', () {
    for (final z in [0.5, 1.0, 2.5]) {
      final c = center(player: Vector2(0, 0), zoom: z);
      final halfW = 800 / (2 * z);
      final halfH = 600 / (2 * z);
      expect(c.x, greaterThanOrEqualTo(halfW.clamp(0, 1024)));
      expect(c.y, greaterThanOrEqualTo(halfH.clamp(0, 576)));
    }
  });

  test('AC-8.5 free 期間僅縮放 → 回歸計時器不重置', () {
    camera.onPan();
    clock.advance(const Duration(seconds: 2));
    camera.onZoom();                     // 縮放不算操作
    clock.advance(const Duration(seconds: 1));
    expect(camera.mode, CameraMode.returning,
        reason: '若縮放重置了計時器，此時仍會是 free');
  });
}
```

- [ ] **步驟 2：執行，確認失敗**

```bash
flutter test test/domain/location/camera/camera_follow_test.dart
```

- [ ] **步驟 3：寫實作**

- [ ] **步驟 4：執行，確認通過（6 tests passed）**

- [ ] **步驟 5：提交**

實作必須是純函式狀態機，**不得**碰 `CameraComponent`，否則只能寫成 widget test，違反 NFR-1。
邊界限制沿用 `universal_overworld_game.dart:_clampCameraBounds` 的既有邏輯，搬到此處成為純函式。

```bash
git commit -m "feat: extract camera follow as a pure state machine

Follow, free and returning are decided from player position, gesture
events and elapsed time alone, with no reference to the engine's camera.
Written against CameraComponent these rules could only be exercised in a
widget test, which the testability requirement rules out.

Zoom deliberately does not count as interaction: pinching to look around
should not be treated as taking manual control and should not restart
the return timer."
```

---

### Task 20：執行期換層

**實作：** REQ-C-15 全部；AC-15.1~15.6

**檔案：**
- 修改：`lib/state/location/location_controller.dart`
- 測試：`test/state/location/layer_switch_test.dart`

- [ ] **步驟 1：先寫失敗的測試**

```dart
void main() {
  late LocationController c;
  late FakeMapManifest layerA;
  late FakeMapManifest layerB;

  setUp(() {
    layerA = FakeMapManifest.linear();
    layerB = FakeMapManifest.linear(originPixel: Vector2(500, 500));
    c = LocationController.forTest(
        flags: const BuildFlags.debug(), manifest: layerA, clock: FakeClock());
  });

  test('AC-15.1 換層後目標點來自新模組', () {
    c.ingest(at(metersNorth: 0));
    final before = c.state.renderedPixel;
    c.switchLayer(layerB);
    expect(c.state.renderedPixel, isNot(before));
    expect(c.state.renderedPixel, layerB.projectToPixel(24.0, 121.0));
  });

  test('AC-15.2 換層不發出任何傳送事件', () {
    c.ingest(at(metersNorth: 0));
    c.clearEvents();
    c.switchLayer(layerB);
    expect(c.emittedEvents.whereType<RelocationEvent>(), isEmpty,
        reason: '大跨距判準是地理位移，換層時地理位置不變 → 位移為 0，'
            '該路徑在建構上不可達');
  });

  test('AC-15.3 換層前後分桶距離連續', () {
    c.ingest(at(metersNorth: 0));
    c.ingest(at(metersNorth: 60, second: 1));
    final before = c.state.realDistanceMeters;
    c.switchLayer(layerB);
    expect(c.state.realDistanceMeters, before);
    c.ingest(at(metersNorth: 120, second: 2));
    expect(c.state.realDistanceMeters, greaterThan(before));
  });

  test('AC-15.4 換層後首筆 Fix 不因速度規則被丟棄', () {
    c.ingest(at(metersNorth: 0));
    c.switchLayer(layerB);
    // 相對前一筆是巨大位移，但基準已重置，應被接受
    final out = c.ingest(at(metersNorth: 100000, second: 1));
    expect(out.rejection, isNull);
  });

  test('AC-15.5 公尺門檻依新圖層重算', () {
    final scaled = FakeMapManifest.fixedScale(370.4);
    c.ingest(at(metersNorth: 0));
    final before = c.arrivalThresholdPixels;   // mpp 1.0 → 2 px
    c.switchLayer(scaled);
    expect(c.arrivalThresholdPixels, lessThan(before));
    expect(c.arrivalThresholdPixels, closeTo(0.0054, 0.0005));
  });

  test('AC-15.6 換層後位置在新模組範圍外 → 換層仍成功，coverage = outside', () {
    final farLayer = FakeMapManifest.linearAt(minLat: 40, minLng: 100);
    c.ingest(at(metersNorth: 0));
    c.switchLayer(farLayer);
    expect(c.state.status.coverage, CoverageState.outside);
    expect(c.activeManifest, farLayer, reason: '不得拒絕換層，否則玩家卡在舊圖層');
  });
}
```

> `FakeMapManifest.linearAt({required double minLat, required double minLng})` 為 T4a 的 `linear()` 加上可移動的地理原點，於本任務一併補上。

- [ ] **步驟 2：執行，確認失敗**
- [ ] **步驟 3：寫實作**
- [ ] **步驟 4：執行，確認通過（6 tests passed）**
- [ ] **步驟 5：提交**

```bash
git commit -m "feat: support switching projection layer at runtime

Switching resets the quality and significance baselines, reprojects the
current geographic position through the new manifest and assigns the
rendered point directly. It does not go through relocation detection:
the geographic position does not change across a switch, so under
metre-based thresholds the displacement is zero and that path is
unreachable by construction.

A position outside the new layer's coverage does not block the switch,
it just reports as outside — refusing would strand the player on the
layer they were trying to leave."
```

---

## 自我檢查

**規格覆蓋（v5.1）**

| 需求 | 任務 |
|---|---|
| §3.0 處理管線（含 AC-0.1~0.4） | T12 |
| REQ-C-14 可觀測狀態與診斷 | T5（狀態、AC-14.7）、T8（motion／acquisition）、T17（AC-14.6 整合） |
| REQ-C-01 權限、服務、精度 | T15（含 AC-0.2 的啟發式） |
| REQ-C-02 串流與節流 | T3（Fix 欄位）、T16 |
| REQ-C-03 品質過濾與靜止判定 | T6、T7 |
| REQ-C-04 範圍檢查、投影、吸附 | T9 |
| REQ-C-05 範圍外處理 | T9（規則 1，P0）、T17（規則 2、3，P1） |
| REQ-C-06 平滑位移（含 NFR-4） | T13 |
| REQ-C-07 大跨距 | T10 |
| REQ-C-08 相機 | T19 |
| REQ-C-10 虛擬來源（含旁路品質閘門） | T14、T12（AC-0.4） |
| REQ-C-11 省電 | T16 |
| REQ-C-12 隱私 | T17 |
| REQ-C-13 模式與位移歸屬（含規則 13~15） | T11（事件酬載、AC-13.11~13.13）、T17（模式切換、AC-13.8~13.10） |
| REQ-C-15 執行期換層 | T20 |
| PRE-1、9 | T1 |
| PRE-2、4、7、11 | T4a（契約）、T4b（台灣實作） |
| PRE-3、5 | T18 |
| PRE-6 | 已完成（`d02b6e5`） |
| PRE-8、10 | **不在本計劃**：路網拓撲與觸發半徑屬任務 A／D。T9 的幾何測試以 skip 標記並附實測數據 |
| NFR-1 | T1（架構測試）、全篇（一律注入 fake） |
| NFR-2 | T2 |
| NFR-3 | T2、T8、T16 |
| NFR-4 | T13 |
| NFR-5 | T18 |
| NFR-6 | T15 |
| CC-1（UUID） | T11（`MovementEventFactory` + AC-CC-1.1） |
| CC-2（UTC／單調） | T2、T3 |
| CC-3（事件欄位、重播決定性） | T11 |
| CC-5（隱私封閉清單） | T11（AC-13.12）、T17（AC-12.1） |

**已知的紅燈與跳過**

| 位置 | 原因 | 何時解除 |
|---|---|---|
| `layer_boundaries_test` 的城市引用檢查 | PRE-3 未清償 | T18 |
| `manifest_geometry_check_test` 的台灣資料組 | PRE-8：4 個道路節點與 POI 同座標（實測間距 0.000 px） | 路網升級為路段拓撲後（任務 A／D） |

**型別一致性**：`GeoFix`／`SourceMode`（T3）、`OverworldMapManifest`／`GeoPoint`／`PoiMarker`（T4a）、`LocationStatus` 及五個維度列舉／`RejectionReason`（T5）、`GateResult`（T6）、`RelocationDecision`／`RelocationCause`／`RelocationNote`（T10）、`MovementEvent` 三個變體／`MovementEventFactory`（T11）、`PipelineOutput`／`LocationPipeline`（T12）、`PositionSmoother`（T13）、`LocationSource`（T14）、`LocationPermissionGateway`（T15）、`LocationSubscriptionManager`／`FixThrottle`（T16）、`LocationControllerState`／`LocationController`／`LocationSnapshotDto`（T17）、`CameraFollow`（T19）——後續任務的引用皆對應上述定義。

**測試替身清單**（全部位於 `test/fakes/`）

| 替身 | 建立於 | 需暴露 |
|---|---|---|
| `FakeClock` | T2 | `advance`、`setWallClock` |
| `FakeMapManifest` | T4a | `linear`／`nonLinear`／`fixedScale`／`linearAt`、`projectCallCount`、`snapCallCount`、`resetCallCounts` |
| `FakePermissionGateway` | T15 | `requestCallCount`、`pushServiceEnabled` |
| `FakeLocationSource` | T16 | `cancelCount`、`lastKnownQueryCount`、`emit` |
| `FakeLogger` | T17 | `lines` |

**風險**

1. **T4b 的 `unprojectToGeo` 迭代法可能不收斂**。IDW 不是自身的逆函數，計劃給的是牛頓式迭代加局部雅可比。若某些控制點附近達不到 AC-10.1 的 2 像素往返誤差，**回報而非放寬門檻**——那是除錯點擊尋路與正式路徑一致性的下限。
2. **`dpadSpeedPixelsPerSecond = 40` 已由桌面實測確認**（原為暫定，Q15）。它換算成地理速度是每秒十餘公里，正因如此虛擬 Fix 必須旁路品質閘門（規格 v5.1 REQ-C-10 規則 5）。若日後改為地方層的真實速度，旁路仍應保留——合成資料本來就沒有量測誤差。
3. **`triggerRadiusMeters = 50` 是暫定值**（PRE-10／Q16 屬任務 A），僅供 T9 的幾何檢查參數化使用。
4. **T16 的節流測試依賴 `FixThrottle` 由 `Clock` 驅動而非真實 `Timer`**。若實作改用 `Timer`，測試會變成需要真實等待，違反 NFR-1 的精神。`Clock` 因此需要 `delay(Duration)`。

---

## 執行方式

逐任務執行。每個任務結束時：**先跑 codegen**，再 `flutter analyze` 無 issue、該任務測試全綠、提交一次。

```bash
dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
```

**關鍵路徑**：T1 → T2 → T4a → T9／T13 → T12 → T17 → T18。

> **執行中修正的相依（T9）**：AC-4.6 對台灣圖資的驗證需要 `TaiwanMapManifest`
> 實作 `snapLimitMeters` 與 `metersPerPixelAt`，那是 T4b 的產出。該條測試已移至
> T4b；T9 只保留以合成資料驗證規則本身的兩條。原相依圖漏了這條邊。
**可並行**：T6／T8／T9／T10／T11／T13 六者互不相干；T4b 與 T15 亦可與純函式任務並行。
