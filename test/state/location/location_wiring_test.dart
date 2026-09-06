import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/core/time/clock.dart';
import 'package:share_tour/data/location/location_permission_gateway.dart';
import 'package:share_tour/data/location/location_source.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/state/location/location_providers.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_location_source.dart';
import '../../fakes/fake_map_manifest.dart';
import '../../fakes/fake_permission_gateway.dart';

/// 接線層的測試。
///
/// 這些需求的元件早就寫好也測過了，缺的是「有沒有接進產品路徑」——真機上
/// 兩個 bug 都是這種形狀：元件正確、接線沒人測。所以這裡一律從 Notifier
/// 的對外方法出發，斷言可觀測的診斷欄位，不直接碰內部模組。
GeoFix at({
  required double metersNorth,
  double accuracy = 20,
  int second = 0,
  SourceMode mode = SourceMode.gps,
}) =>
    GeoFix(
      latitude: 24.0 + metersNorth / 110574.0,
      longitude: 121.0,
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
  late FakeClock clock;
  late FakeMapManifest manifest;
  late FakeLocationSource source;
  late FakePermissionGateway gateway;
  late ProviderContainer container;

  setUp(() {
    clock = FakeClock();
    manifest = FakeMapManifest.linear();
    source = FakeLocationSource();
    gateway = FakePermissionGateway();
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock as Clock),
      mapManifestProvider.overrideWithValue(manifest as OverworldMapManifest),
      realSourceProvider.overrideWithValue(source as LocationSource),
      permissionGatewayProvider
          .overrideWithValue(gateway as LocationPermissionGateway),
    ]);
  });

  tearDown(() {
    container.dispose();
    source.dispose();
    gateway.dispose();
  });

  LocationNotifier notifier() =>
      container.read(locationControllerProvider.notifier);

  /// 讓串流事件送達。來源 → 訂閱管理器 → 節流 → 控制器共三段串流跳接，
  /// 每一段都是非同步的；不先讓它們跑完就推進時鐘，事件會在推進【之後】
  /// 才被吃進去，於是「距上次顯著位移多久」永遠量到 0。
  Future<void> pump() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<LocationNotifier> gpsMode() async {
    final n = notifier();
    n.controller.traceIngestion = false; // 逐筆追蹤會淹沒測試輸出
    await n.requestGpsMode();
    return n;
  }

  test('AC-2.2 應用層節流已接線：1 秒內 10 筆只進去 2 筆', () async {
    final n = await gpsMode();

    for (var i = 0; i < 10; i++) {
      source.emit(at(metersNorth: i * 50.0, second: i));
      await clock.advanceAsync(const Duration(milliseconds: 90));
    }
    await clock.advanceAsync(const Duration(seconds: 1));

    final d = n.state.diagnostics;
    expect(d.acceptedFixCount + d.rejectedFixCount, 2,
        reason: 'leading 一筆、窗尾 trailing 一筆');
  });

  test('AC-2.3 背景 5 秒後返回：訂閱未曾取消', () async {
    final n = await gpsMode();
    expect(n.state.diagnostics.activeSubscriptionCount, 1);

    n.onAppBackground();
    await clock.advanceAsync(const Duration(seconds: 5));
    await n.onAppForeground();

    expect(source.cancelCount, 0);
    expect(n.state.diagnostics.activeSubscriptionCount, 1);
  });

  test('AC-2.4 背景 30 秒後返回：訂閱曾取消，恢復發生於 debounce 之後', () async {
    final n = await gpsMode();

    n.onAppBackground();
    await clock.advanceAsync(const Duration(seconds: 30));
    expect(source.cancelCount, 1, reason: '超過 20 秒寬限期');
    expect(n.state.diagnostics.activeSubscriptionCount, 0);

    final startsBefore = source.startCount;
    final resume = n.onAppForeground();
    await clock.advanceAsync(const Duration(milliseconds: 500));
    expect(source.startCount, startsBefore, reason: 'debounce 未滿不得恢復');

    await clock.advanceAsync(const Duration(seconds: 2));
    await resume;
    expect(n.state.diagnostics.activeSubscriptionCount, 1);
  });

  test('AC-11.2 切換為 virtual → GPS 訂閱取消', () async {
    final n = await gpsMode();
    expect(n.state.diagnostics.activeSubscriptionCount, 1);

    await n.switchToVirtual();

    expect(source.cancelCount, 1);
    expect(n.state.diagnostics.activeSubscriptionCount, 0);
  });

  test('診斷的 powerMode 反映實際狀態，不是寫死的 active', () async {
    final n = await gpsMode();
    expect(n.state.diagnostics.powerMode, PowerMode.active);

    n.onAppBackground();
    await clock.advanceAsync(const Duration(seconds: 30));

    expect(n.state.diagnostics.powerMode, PowerMode.suspended);
  });

  test('診斷的 secondsSinceLastSignificantMove 為真值，不是寫死的 0', () async {
    final n = await gpsMode();
    source.emit(at(metersNorth: 0));
    await pump();
    await clock.advanceAsync(const Duration(seconds: 2));
    source.emit(at(metersNorth: 200, second: 2));
    await pump();
    await clock.advanceAsync(const Duration(seconds: 10));

    // 讀控制器而非 Riverpod 的快取 state：state 是上一次事件當下的快照，
    // 而「距上次顯著位移多久」本來就會隨時間變化，不會有人推事件來更新它。
    expect(n.controller.state.diagnostics.secondsSinceLastSignificantMove, 10);
  });

  test('AC-2.5 dispose 後 activeSubscriptionCount 為 0', () async {
    final n = await gpsMode();
    expect(n.state.diagnostics.activeSubscriptionCount, 1);

    container.dispose();

    expect(source.cancelCount, 1);
  });

  // --- B：其餘的不連續路徑與 REQ-C-01 的串流 ---

  test('背景恢復後的首筆 Fix 不計入里程（backgroundResume）', () async {
    final n = await gpsMode();
    source.emit(at(metersNorth: 0));
    await pump();
    // 節流窗長 1 秒：不推進時鐘的話第二筆會被當成窗內的 trailing 壓住。
    await clock.advanceAsync(const Duration(seconds: 2));
    source.emit(at(metersNorth: 200, second: 2));
    await pump();
    final before = n.controller.state.realDistanceMeters;
    expect(before, greaterThan(0), reason: '前置條件：正常里程有在累計');

    n.onAppBackground();
    await clock.advanceAsync(const Duration(seconds: 30));
    final resume = n.onAppForeground();
    await clock.advanceAsync(const Duration(seconds: 2));
    await resume;

    source.emit(at(metersNorth: 5000, second: 60));
    await pump();

    expect(n.controller.state.realDistanceMeters, before,
        reason: 'app 沒在追蹤的期間，無從得知玩家是走的還是搭車的');
  });

  test('AC-1.7 前景中服務被關閉 → serviceDisabled 並自動退回方向鍵', () async {
    final n = await gpsMode();

    gateway.pushServiceEnabled(false);
    await pump();

    expect(n.controller.state.status.permission,
        PermissionState.serviceDisabled);
    expect(n.controller.state.status.mode, SourceMode.virtual);
    expect(source.cancelCount, 1, reason: '定位不可用時不該繼續持有訂閱');
  });

  test('REQ-C-01 規則 4 啟發式：連續 3 筆原始精度 > 500 m → approximate', () async {
    final n = await gpsMode();

    for (var i = 0; i < 3; i++) {
      source.emit(at(metersNorth: i * 10.0, accuracy: 2000, second: i));
      await pump();
      await clock.advanceAsync(const Duration(seconds: 2));
    }
    await pump();

    expect(n.controller.state.status.permission, PermissionState.approximate,
        reason: '這些 Fix 全被精度閘門丟棄，啟發式必須在過濾【之前】評估');
    expect(n.controller.state.status.mode, SourceMode.virtual);
  });

}
