import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/game/map_module/manifests/taiwan_map_manifest.dart';
import '../../../fakes/fake_map_manifest.dart';

/// 投影的契約檢查：不得存在「死區」。
///
/// 這條測試存在的理由是一個真實事故：先前用反距離加權插值（IDW），其權重
/// 1/d² 在控制點處發散，使插值函數在每個控制點附近變成**局部常數**。玩家在
/// 台北 101 附近走 100 公尺，投影位移是 0.00 像素——小人完全不動。
///
/// 而出生點正好就是一個控制點，所以整個功能從第一次啟動就是壞的。
///
/// 先前的回歸測試只驗「控制點之間的方位與單調性」，全部通過，因為死區只在
/// 控制點【附近】。任何新的投影實作都必須通過本檢查。

/// 往返解析度：以圖資自己的單位表達，與比例尺無關。
///
/// 反投影一個像素點，再反投影它右邊 d 個像素的點，兩者投影回來應相距約 d。
/// 這正是方向鍵需要的性質——它在像素空間移動，經過經緯度再轉回像素。
/// IDW 在控制點附近做不到：兩個像素點反投影後幾乎相同，投影回來位移為 0。
void expectRoundTripResolution(
  OverworldMapManifest manifest,
  List<(String, Vector2)> samples, {
  double deltaPixels = 2.67, // 一個方向鍵 tick：40 px/s ÷ 15 Hz
  double tolerance = 0.5,
}) {
  for (final (name, pixel) in samples) {
    final a = manifest.unprojectToGeo(pixel);
    final b = manifest.unprojectToGeo(pixel + Vector2(deltaPixels, 0));
    final pa = manifest.projectToPixel(a.latitude, a.longitude);
    final pb = manifest.projectToPixel(b.latitude, b.longitude);
    final moved = (pb - pa).length;
    expect(moved, closeTo(deltaPixels, tolerance),
        reason: '$name 移動 $deltaPixels 像素，往返後只剩 '
            '${moved.toStringAsFixed(4)} px——投影在此處沒有解析度');
  }
}

/// 以公尺表達的敏感度檢查。只對真實地理圖資有意義。
void expectNoDeadZones(
  OverworldMapManifest manifest,
  List<(String, double, double)> samples, {
  double moveMeters = 100,
  double minPixels = 0.2,
}) {
  for (final (name, lat, lng) in samples) {
    final before = manifest.projectToPixel(lat, lng);
    final after = manifest.projectToPixel(lat, lng + moveMeters / 102000.0);
    final moved = (after - before).length;
    expect(moved, greaterThan(minPixels),
        reason: '$name 附近東移 $moveMeters 公尺只位移 '
            '${moved.toStringAsFixed(4)} px——這是死區');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('台灣圖資', () {
    late TaiwanMapManifest m;

    setUpAll(() async {
      m = await TaiwanMapManifest.load();
    });

    test('每個控制點附近都沒有死區', () {
      expectNoDeadZones(
        m,
        [for (final a in m.anchors) (a.name, a.lat, a.lng)],
      );
    });

    test('控制點之間也沒有死區', () {
      final samples = <(String, double, double)>[];
      for (var lat = 22.0; lat <= 25.5; lat += 0.25) {
        for (var lng = 120.2; lng <= 121.8; lng += 0.25) {
          samples.add(('($lat, $lng)', lat, lng));
        }
      }
      expectNoDeadZones(m, samples);
    });

    test('控制點被精確重現', () {
      for (final a in m.anchors) {
        final p = m.projectToPixel(a.lat, a.lng);
        expect((p - a.pixelPos).length, lessThan(0.01), reason: a.name);
      }
    });

    test('反投影往返誤差小於 2 像素（AC-10.1）', () {
      for (final a in m.anchors) {
        for (final offset in [0.0, 5.0, 40.0]) {
          final target = a.pixelPos + Vector2(offset, offset);
          final geo = m.unprojectToGeo(target);
          final back = m.projectToPixel(geo.latitude, geo.longitude);
          expect((back - target).length, lessThan(2.0),
              reason: '${a.name} 偏移 $offset 往返失敗');
        }
      }
    });

    test('每個控制點的往返解析度都成立', () {
      expectRoundTripResolution(
        m,
        [for (final a in m.anchors) (a.name, a.pixelPos)],
      );
    });

    test('一個方向鍵 tick 的位移確實改變投影結果', () {
      // 這正是紅點不動的那個情境：出生點在控制點上，
      // 移動 2.67 像素（40 px/s ÷ 15 Hz）必須真的動。
      final spawn = m.defaultSpawnPixel;
      final geoA = m.unprojectToGeo(spawn);
      final geoB = m.unprojectToGeo(spawn + Vector2(2.67, 2.67));
      final back = m.projectToPixel(geoB.latitude, geoB.longitude);
      expect((back - m.projectToPixel(geoA.latitude, geoA.longitude)).length,
          greaterThan(1.0));
    });
  });

  group('假圖資', () {
    test('往返解析度成立', () {
      expectRoundTripResolution(
        FakeMapManifest.linear(),
        [
          ('中心', Vector2(100, 100)),
          ('左上', Vector2(0, 0)),
          ('右下', Vector2(200, 200)),
        ],
      );
    });
  });
}
