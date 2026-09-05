import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/location/location_subscription_manager.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_location_source.dart';
import '../../fakes/fake_map_manifest.dart';

GeoFix at({int second = 0}) => GeoFix(
      latitude: 24.0,
      longitude: 121.0,
      accuracyMeters: 20,
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
  late FakeClock clock;
  late FakeLocationSource source;
  late FakeMapManifest manifest;
  late LocationSubscriptionManager manager;

  setUp(() async {
    clock = FakeClock();
    source = FakeLocationSource();
    manifest = FakeMapManifest.linear();
    manager = LocationSubscriptionManager(
      source: source,
      clock: clock,
      manifest: manifest,
      backgroundGrace: const Duration(seconds: 20),
      resumeDebounce: const Duration(seconds: 2),
    );
    await manager.start();
  });

  tearDown(() {
    manager.dispose();
    source.dispose();
  });

  test('AC-2.3 背景 5 秒後返回 → 訂閱未曾取消', () async {
    manager.onBackground();
    await clock.advanceAsync(const Duration(seconds: 5));
    await manager.onForeground();
    expect(source.cancelCount, 0);
    expect(manager.activeSubscriptionCount, 1);
  });

  test('AC-2.4 背景 30 秒後返回 → 曾取消，恢復在 debounce 之後', () async {
    manager.onBackground();
    await clock.advanceAsync(const Duration(seconds: 30));
    expect(source.cancelCount, 1);
    expect(manager.activeSubscriptionCount, 0);

    final resuming = manager.onForeground();
    expect(manager.activeSubscriptionCount, 0, reason: 'debounce 尚未過');
    await clock.advanceAsync(const Duration(seconds: 2));
    await resuming;
    expect(manager.activeSubscriptionCount, 1);
  });

  test('AC-2.5 dispose 後 activeSubscriptionCount == 0', () {
    manager.dispose();
    expect(manager.activeSubscriptionCount, 0);
  });

  test('AC-11.1 進入 Mini-game → 訂閱取消', () async {
    await manager.setPowerMode(PowerMode.suspended);
    expect(manager.activeSubscriptionCount, 0);
  });

  test('AC-11.2 切換為 virtual → GPS 訂閱取消', () async {
    await manager.onModeChanged(SourceMode.virtual);
    expect(manager.activeSubscriptionCount, 0);
  });

  test('AC-11.3 suspended 期間不產生任何位置更新', () async {
    final received = <GeoFix>[];
    manager.fixes.listen(received.add);
    await manager.setPowerMode(PowerMode.suspended);
    source.emit(at());
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
  });

  test('AC-2.6 冷啟動顯示點為預設降落點，且未查詢最後已知位置', () {
    expect(manager.initialRenderedPixel, manifest.defaultSpawnPixel);
    expect(source.lastKnownQueryCount, 0,
        reason: '不查詢最後已知位置——它省下一秒空白，'
            '代價是整條管線都要傳遞一條特例規則');
  });
}
