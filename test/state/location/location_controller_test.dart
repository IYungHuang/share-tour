import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/core/build_flags.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_snapshot_dto.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/models/movement_event.dart';
import 'package:share_tour/domain/location/models/rejection_reason.dart';
import 'package:share_tour/domain/location/pipeline/relocation_detector.dart';
import 'package:share_tour/state/location/location_controller.dart';
import '../../fakes/fake_clock.dart';
import '../../fakes/fake_map_manifest.dart';

GeoFix at({
  required double metersNorth,
  double accuracy = 20,
  int second = 0,
  SourceMode mode = SourceMode.gps,
  bool isMocked = false,
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
      isMocked: isMocked,
      sourceMode: mode,
    );

void main() {
  late FakeClock clock;
  late FakeMapManifest manifest;

  LocationController make({bool ignoreMocked = false}) =>
      LocationController.forTest(
        manifest: manifest,
        clock: clock,
        flags: const BuildFlags.debug(),
        ignoreMockedFlag: ignoreMocked,
      );

  setUp(() {
    clock = FakeClock();
    manifest = FakeMapManifest.linear();
  });

  test('AC-13.1 手動切換即時生效', () {
    final c = make();
    c.switchMode(SourceMode.virtual, automatic: false);
    expect(c.state.status.mode, SourceMode.virtual);
  });

  test('AC-13.2 權限被拒 → 自動切 virtual 並標記為自動', () {
    final c = make();
    c.onPermissionChanged(PermissionState.denied);
    expect(c.state.status.mode, SourceMode.virtual);
    expect(c.lastSwitchWasAutomatic, isTrue);
  });

  test('AC-13.3 定位恢復可用 → mode 維持 virtual', () {
    final c = make();
    c.onPermissionChanged(PermissionState.denied);
    c.onPermissionChanged(PermissionState.ready);
    expect(c.state.status.mode, SourceMode.virtual,
        reason: '恢復後不自動切回，由玩家決定');
  });

  test('AC-13.8 isMocked 的 Fix 在 gps 模式下，位移計入 virtual 桶', () {
    final c = make();
    c.ingest(at(metersNorth: 0, isMocked: true));
    c.ingest(at(metersNorth: 60, second: 1, isMocked: true));
    expect(c.state.virtualDistanceMeters, closeTo(60, 2));
    expect(c.state.realDistanceMeters, 0);
  });

  test('AC-13.9 除錯旗標開啟時，isMocked 仍依 mode 歸屬', () {
    final c = make(ignoreMocked: true);
    c.ingest(at(metersNorth: 0, isMocked: true));
    c.ingest(at(metersNorth: 60, second: 1, isMocked: true));
    expect(c.state.realDistanceMeters, closeTo(60, 2),
        reason: '模擬器與 GPX 除錯期間 isMocked 恆為真，不覆寫就無法驗證 gps 模式');
  });

  test('AC-13.10 第一版不持久化模式，重啟後依當時權限重新判定', () {
    final c = make();
    c.switchMode(SourceMode.virtual, automatic: false);
    final restarted = make();
    expect(restarted.state.status.mode, SourceMode.gps,
        reason: 'P0 行為：不持久化。持久化為 P1，相依任務 B 的持久化層');
  });

  test('AC-14.6 診斷計數隨丟棄遞增', () {
    final c = make();
    c.ingest(at(metersNorth: 0, accuracy: 150));
    expect(c.state.diagnostics.rejectedFixCount, 1);
    expect(c.state.diagnostics.rejectionsByReason[RejectionReason.accuracy], 1);
  });

  test('AC-14.11 品質不合格（但未被丟棄）的 Fix 計入 accuracyGatedFixCount，'
      '不計入 rejectedFixCount', () {
    final c = make();
    c.ingest(at(metersNorth: 0, accuracy: 24));
    c.ingest(at(metersNorth: 96, accuracy: 40, second: 5));

    expect(c.state.diagnostics.accuracyGatedFixCount, 1);
    expect(c.state.diagnostics.rejectedFixCount, 0,
        reason: '精度 40m 沒有超過 REQ-C-03 的 100m 丟棄門檻，這是規則 16 的品質標記，'
            '不是規則 2 的品質閘門丟棄');
  });

  // REQ-C-16：keepAwakeActive 是五維度狀態 + isForeground + featureEnabled
  // 的衍生值，不落地成獨立欄位；由接線層寫入 isForeground（比照
  // subscriptionCount／powerMode 的既有模式）。
  group('REQ-C-16 keepAwakeActive', () {
    test('AC-16.1 gps + ready + 前景 + 功能開啟 → 為真', () {
      final c = make();
      expect(c.state.diagnostics.keepAwakeActive, isTrue);
    });

    test('AC-16.2 mode=virtual → 為假', () {
      final c = make();
      c.switchMode(SourceMode.virtual, automatic: false);
      expect(c.state.diagnostics.keepAwakeActive, isFalse);
    });

    test('AC-16.3 permission 離開 ready → 為假', () {
      final c = make();
      c.onPermissionChanged(PermissionState.approximate);
      expect(c.state.diagnostics.keepAwakeActive, isFalse);
    });

    test('AC-16.4 背景 → 為假；回到前景 → 為真', () {
      final c = make();
      c.isForeground = false;
      expect(c.state.diagnostics.keepAwakeActive, isFalse);
      c.isForeground = true;
      expect(c.state.diagnostics.keepAwakeActive, isTrue);
    });

    test('AC-16.5 powerMode 變 suspended（Mini-game）而其餘條件不變 → 維持為真',
        () {
      final c = make();
      c.powerMode = PowerMode.suspended;
      expect(c.state.diagnostics.keepAwakeActive, isTrue,
          reason: 'keepAwakeActive 的述詞不吃 powerMode，Mini-game 期間'
              '玩家仍全程注視螢幕，不該被錯誤釋放');
    });

    test('AC-16.6 玩家關閉本功能 → 為假，其餘狀態不受影響', () {
      final c = make();
      c.setKeepAwakeFeatureEnabled(false);
      expect(c.state.diagnostics.keepAwakeActive, isFalse);
      expect(c.state.status.mode, SourceMode.gps);
      expect(c.state.status.permission, PermissionState.ready);
    });
  });

  test('AC-12.1 持久化 DTO 的序列化結果不含座標鍵', () {
    final json = LocationSnapshotDto(
      renderedPixelX: 100,
      renderedPixelY: 200,
      realDistanceMeters: 500,
      virtualDistanceMeters: 0,
      mode: SourceMode.gps,
      savedAtUtc: DateTime.utc(2026),
    ).toJson();
    for (final k in ['lat', 'lng', 'latitude', 'longitude']) {
      expect(json.keys.map((e) => e.toLowerCase()), isNot(contains(k)));
    }
  });

  test('顯著位移更新目標點與里程', () {
    final c = make();
    c.ingest(at(metersNorth: 0));
    c.ingest(at(metersNorth: 60, second: 1));
    expect(c.state.realDistanceMeters, closeTo(60, 2));
    expect(c.state.targetPixel, isNotNull);
  });

  test('冷啟動顯示點為預設降落點', () {
    expect(make().state.renderedPixel, manifest.defaultSpawnPixel);
  });

  test('coverage 隨範圍外的 Fix 改變，且里程不變', () {
    final c = make();
    c.ingest(at(metersNorth: 0));
    c.ingest(at(metersNorth: 60, second: 1));
    final before = c.state.realDistanceMeters;
    c.ingest(GeoFix(
      latitude: 80.0,
      longitude: 0.0,
      accuracyMeters: 20,
      hasAccuracy: true,
      speedMetersPerSecond: 1.4,
      hasSpeed: true,
      speedAccuracy: 0.5,
      hasSpeedAccuracy: true,
      timestampUtc: DateTime.utc(2026, 1, 2),
      isMocked: false,
      sourceMode: SourceMode.gps,
    ));
    expect(c.state.status.coverage, CoverageState.outside);
    expect(c.state.realDistanceMeters, before);
  });

  // 真機回歸：切到 GPS 的首筆 Fix 曾把 13 萬公尺灌進 realDistanceMeters。
  // 虛擬來源把小人開到一處，真實位置在另一處，兩者之間的距離沒有人走過。
  test('切換模式後的首筆 Fix 不得計入里程', () {
    final c = make();
    c.switchMode(SourceMode.virtual, automatic: false);
    c.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
    c.ingest(at(metersNorth: 200, second: 10, mode: SourceMode.virtual));
    final virtualBefore = c.state.virtualDistanceMeters;

    c.switchMode(SourceMode.gps, automatic: false);
    c.ingest(at(metersNorth: 50000, second: 600));

    expect(c.state.realDistanceMeters, 0,
        reason: '這段距離是模式切換造成的，不是玩家走的');
    expect(c.state.virtualDistanceMeters, virtualBefore,
        reason: '虛擬桶也不得被切換灌水');
    expect(c.state.targetPixel, isNotNull, reason: '小人仍須跳到真實位置');
  });

  test('切換模式後的第二筆起，里程正常累計', () {
    final c = make();
    c.switchMode(SourceMode.virtual, automatic: false);
    c.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
    c.switchMode(SourceMode.gps, automatic: false);
    c.ingest(at(metersNorth: 50000, second: 600));
    c.ingest(at(metersNorth: 50100, second: 660));

    expect(c.state.realDistanceMeters, closeTo(100, 5));
  });

  test('切換造成的大跨距不平滑，顯示點直接指定', () {
    final c = make();
    c.switchMode(SourceMode.virtual, automatic: false);
    c.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
    c.switchMode(SourceMode.gps, automatic: false);
    c.ingest(at(metersNorth: 50000, second: 600));

    expect(c.state.renderedPixel, c.state.targetPixel,
        reason: '傳送事件的語意是直接指定顯示點，不是平滑趨近');
  });

  test('AC-7.8 discontinuity 事件可從 controller.events 讀到，'
      '不依賴任何任務 A 專屬型別或介面（REQ-C-07 規則 6）', () {
    final c = make();
    c.switchMode(SourceMode.virtual, automatic: false);
    c.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
    c.switchMode(SourceMode.gps, automatic: false);
    c.ingest(at(metersNorth: 50000, second: 600));

    final discontinuityEvents = c.events
        .whereType<RelocationEvent>()
        .where((e) => e.cause == RelocationCause.discontinuity);
    expect(discontinuityEvents, isNotEmpty,
        reason: '畫面層須能獨立於任務 A 訂閱到不連續事件，'
            '否則玩家鎖屏長時間後回來，只有里程沒動而 HUD 顯示正常');
    expect(discontinuityEvents.single.note, RelocationNote.modeSwitch);
  });
}
