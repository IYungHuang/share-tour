import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import '../../../fakes/fake_map_manifest.dart';

void main() {
  test('反投影是投影的逆運算，誤差小於 2 像素', () {
    final m = FakeMapManifest.linear();
    final pixel = Vector2(120, 140);
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

  test('已驗算的投影對照表', () {
    final m = FakeMapManifest.linear();
    expect(m.projectToPixel(24.0, 121.0), Vector2(100, 100), reason: '恰在路網上');
    expect(m.projectToPixel(24.9, 121.0), Vector2(100, 10), reason: '距路網 90px');
    expect(m.projectToPixel(25.0, 120.0), Vector2(0, 0), reason: '左上角');
    expect(m.containsGeo(80.0, 0.0), isFalse, reason: '範圍外');
  });
}
