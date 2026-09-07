import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/models/movement_event.dart';
import 'package:share_tour/domain/location/models/rejection_reason.dart';
import 'package:share_tour/domain/location/pipeline/location_pipeline.dart';
import 'package:share_tour/domain/location/pipeline/relocation_detector.dart';
import '../../../fakes/fake_clock.dart';
import '../../../fakes/fake_map_manifest.dart';

/// FakeMapManifest.linear() 座標系：(24.0, 121.0) → (100, 100)，恰在路網上。
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
    final out = pipeline.ingest(at(metersNorth: 15, second: 1));
    expect(out.targetPixel, isNull);
    expect(out.events, isEmpty);
    expect(manifest.projectCallCount, 0);
  });

  test('AC-0.4 virtual 的 Fix 跳過品質閘門', () {
    pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
    manifest.resetCallCounts();
    // 位移 5000 公尺、間隔 1 秒 → 18000 km/h，遠超速度門檻
    final out = pipeline
        .ingest(at(metersNorth: 5000, second: 1, mode: SourceMode.virtual));
    expect(out.rejection, isNull, reason: '合成資料沒有量測誤差，品質閘門不適用');
    expect(out.targetPixel, isNotNull);
    expect(manifest.projectCallCount, 1);
  });

  test('品質閘門丟棄者不進入其後任何步驟', () {
    manifest.resetCallCounts();
    final out = pipeline.ingest(at(metersNorth: 0, accuracy: 150));
    expect(out.rejection, RejectionReason.accuracy);
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

  test('首筆只建立基準，不產生位移事件', () {
    final out = pipeline.ingest(at(metersNorth: 0));
    expect(out.events, isEmpty);
    expect(out.targetPixel, isNull);
  });

  test('診斷計數隨丟棄遞增', () {
    pipeline.ingest(at(metersNorth: 0, accuracy: 150));
    pipeline.ingest(at(metersNorth: 0).copyWith(hasAccuracy: false));
    expect(pipeline.rejectionsByReason[RejectionReason.accuracy], 1);
    expect(pipeline.rejectionsByReason[RejectionReason.unmeasuredAccuracy], 1);
  });

  // 切換移動模式造成的不連續（REQ-C-13 規則 5 → REQ-C-07 成因 discontinuity）。
  //
  // 虛擬來源與真實來源的位置毫無關係：玩家可能用方向鍵把小人開到台北，
  // 而人在台中。切換時若不重置基準，首筆真實 Fix 會拿虛擬基準來比，
  // 那段從未有人走過的距離就被記進 realDistanceMeters。實測灌進 13 萬公尺。
  group('切換模式的不連續', () {
    test('標記不連續後的首筆：更新目標點，但不發位移事件、不累計距離', () {
      pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
      pipeline.markDiscontinuity(RelocationNote.modeSwitch);

      final out = pipeline.ingest(at(metersNorth: 5000, second: 60));

      expect(out.targetPixel, isNotNull, reason: '顯示點必須跳到真實位置');
      expect(out.events.whereType<DisplacementEvent>(), isEmpty,
          reason: '這段距離沒有人走過，不得計入任何桶');
    });

    test('跨距超過門檻 → 發出 discontinuity 傳送事件', () {
      pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
      pipeline.markDiscontinuity(RelocationNote.modeSwitch);

      final out = pipeline.ingest(at(metersNorth: 5000, second: 60));

      final ev = out.events.whereType<RelocationEvent>().single;
      expect(ev.cause, RelocationCause.discontinuity);
      expect(ev.note, RelocationNote.modeSwitch);
      expect(ev.distanceMeters, closeTo(5000, 50));
    });

    test('原地切換（跨距未達門檻）→ 不發任何事件，目標點仍更新', () {
      pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
      pipeline.markDiscontinuity(RelocationNote.modeSwitch);

      final out = pipeline.ingest(at(metersNorth: 5, second: 60));

      expect(out.targetPixel, isNotNull);
      expect(out.events, isEmpty);
    });

    test('不連續之後恢復正常累計，基準為不連續的那一筆', () {
      pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
      pipeline.markDiscontinuity(RelocationNote.modeSwitch);
      pipeline.ingest(at(metersNorth: 5000, second: 60));

      final out = pipeline.ingest(at(metersNorth: 5100, second: 120));

      final d = out.events.whereType<DisplacementEvent>().single;
      expect(d.distanceMeters, closeTo(100, 5));
    });

    test('傳送事件的起點為前一個像素位置，不是原點', () {
      // 要有「前一個像素位置」得先有一次顯著位移：首筆只設基準、不更新目標點。
      pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
      final first = pipeline.ingest(
          at(metersNorth: 100, second: 10, mode: SourceMode.virtual));
      pipeline.markDiscontinuity(RelocationNote.modeSwitch);

      final out = pipeline.ingest(at(metersNorth: 5000, second: 60));
      final ev = out.events.whereType<RelocationEvent>().single;

      expect(first.targetPixel, isNotNull);
      expect(ev.fromPixelX, closeTo(first.targetPixel!.x, 0.01));
      expect(ev.fromPixelY, closeTo(first.targetPixel!.y, 0.01));
    });
  });


  // 圖資範圍外再回到範圍內（REQ-C-05 規則 4 → REQ-C-07 成因 discontinuity）。
  //
  // 範圍檢查排在顯著位移閘門【之後】，所以境外的 Fix 雖然不計距離，卻已經把
  // 顯著性基準推到境外那一點。回到範圍內時，首筆會把整段境外行程算成里程。
  group('範圍恢復的不連續', () {
    test('回到範圍內的首筆不累計距離，但目標點更新', () {
      pipeline.ingest(at(metersNorth: 0));
      pipeline.ingest(at(metersNorth: 200000, second: 3600)); // 出界

      final out = pipeline.ingest(at(metersNorth: 300, second: 7200));

      expect(out.targetPixel, isNotNull);
      expect(out.events.whereType<DisplacementEvent>(), isEmpty,
          reason: '境外那段沒有圖資可投影，距離也就不可信');
    });

    test('回到範圍內發出 coverageRecovered 的傳送事件', () {
      pipeline.ingest(at(metersNorth: 0));
      pipeline.ingest(at(metersNorth: 200000, second: 3600));

      final out = pipeline.ingest(at(metersNorth: 300, second: 7200));

      final ev = out.events.whereType<RelocationEvent>().single;
      expect(ev.cause, RelocationCause.discontinuity);
      expect(ev.note, RelocationNote.coverageRecovered);
    });

    test('回到範圍內之後恢復正常累計', () {
      pipeline.ingest(at(metersNorth: 0));
      pipeline.ingest(at(metersNorth: 200000, second: 3600));
      pipeline.ingest(at(metersNorth: 300, second: 7200));

      final out = pipeline.ingest(at(metersNorth: 400, second: 7260));

      expect(out.events.whereType<DisplacementEvent>().single.distanceMeters,
          closeTo(100, 5));
    });
  });

  // 品質標記（REQ-C-13 規則 16、17，修訂二）。
  //
  // 精度 > 30 m 的 Fix 仍走管線、仍更新顯示點，但不得成為任何基準——不只是
  // 顯著性閘門的基準，連「不連續路徑要跟誰比」的 _lastKnown 也不行，否則
  // 一筆精度差但恰好離得很遠的 Fix，會讓下一筆合格 Fix 算出錯誤的大跨距。
  group('品質標記', () {
    test('AC-13.14 精度不合格：更新顯示點，不推進 motion，不計入任何桶', () {
      pipeline.ingest(at(metersNorth: 0, accuracy: 24));
      final out =
          pipeline.ingest(at(metersNorth: 96, accuracy: 40, second: 5));

      expect(out.targetPixel, isNotNull, reason: '仍要更新顯示點');
      expect(out.qualityGated, isTrue);
      expect(out.events, isEmpty);
      expect(pipeline.motion, MotionState.still,
          reason: '不合格 Fix 不推進 motion');
    });

    test('AC-13.15 不合格 Fix 不成為顯著性基準：下一筆合格 Fix 仍與原基準比較',
        () {
      pipeline.ingest(at(metersNorth: 0, accuracy: 24));
      pipeline.ingest(at(metersNorth: 96, accuracy: 40, second: 5)); // 不合格
      final out = pipeline.ingest(at(metersNorth: 200, accuracy: 20, second: 10));

      final events = out.events.whereType<DisplacementEvent>();
      expect(events.length, 1);
      expect(events.single.distanceMeters, closeTo(200, 5),
          reason: '若不合格 Fix 帶走了基準，錯誤實作只會得到約 104m');
    });

    test('AC-13.16 品質標記門檻：30m 視為合格，30.1m 不合格', () {
      pipeline.ingest(at(metersNorth: 0, accuracy: 20));
      final out30 =
          pipeline.ingest(at(metersNorth: 100, accuracy: 30, second: 5));
      expect(out30.events.whereType<DisplacementEvent>().single.distanceMeters,
          closeTo(100, 1));
      expect(out30.qualityGated, isFalse);

      final other = LocationPipeline(manifest: manifest, clock: FakeClock());
      other.ingest(at(metersNorth: 0, accuracy: 20));
      final out301 =
          other.ingest(at(metersNorth: 100, accuracy: 30.1, second: 5));
      expect(out301.events, isEmpty);
      expect(out301.qualityGated, isTrue);
    });

    test('AC-13.17 不合格 Fix 不消耗不連續標記；下一筆合格 Fix 才消耗', () {
      pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
      pipeline.markDiscontinuity(RelocationNote.modeSwitch);

      // P1：精度 50m（不合格），距切換前最後已知位置（metersNorth 0）5000m。
      final p1 = pipeline
          .ingest(at(metersNorth: 5000, accuracy: 50, second: 60));
      expect(p1.events, isEmpty, reason: '第一筆不合格 Fix 不產生任何事件');
      expect(p1.qualityGated, isTrue);

      // P2：精度 20m（合格），距 P1 100m、+5s。
      final p2 = pipeline
          .ingest(at(metersNorth: 5100, accuracy: 20, second: 65));

      expect(p2.events.length, 1,
          reason: '恰好一筆傳送事件——若 P1 錯誤地消耗了標記或成為基準，'
              'P2 距 P1 僅 100m/5s，不會觸發大跨距判定');
      final ev = p2.events.whereType<RelocationEvent>().single;
      expect(ev.cause, RelocationCause.discontinuity);
      expect(ev.note, RelocationNote.modeSwitch);
      expect(p2.events.whereType<DisplacementEvent>(), isEmpty);
    });

    test('AC-0.4 / AC-13.18 虛擬 Fix 一律標記為合格', () {
      pipeline.ingest(at(metersNorth: 0, mode: SourceMode.virtual));
      final out = pipeline.ingest(
          at(metersNorth: 96, accuracy: 1, second: 1, mode: SourceMode.virtual));
      expect(out.qualityGated, isFalse);
    });
  });
}
