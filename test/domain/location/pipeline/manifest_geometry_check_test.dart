import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/domain/location/pipeline/manifest_geometry_check.dart';
import 'package:share_tour/game/map_module/manifests/taiwan_map_manifest.dart';

/// REQ-C-18 規則 3 的幾何約束：d(A, B) > r_A + r_B + positionErrorBound。
/// 玩家可能站在 A 觸發範圍內任一點（距 A 最遠 r_A），量測點偏離真位置最多
/// positionErrorBound，要求量測點距 B 超過 r_B——對稱式，每對 POI 驗一次。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('規則本身正確：合法資料無衝突', () {
    final conflicts = findPoiProximityConflicts(
      pois: [
        PoiMarker(id: 'a', pixel: Vector2(0, 0), triggerRadiusMeters: 50),
        PoiMarker(id: 'b', pixel: Vector2(1000, 0), triggerRadiusMeters: 50),
      ],
      positionErrorBound: 33,
      metersPerPixel: 1.0,
    );
    expect(conflicts, isEmpty);
  });

  test('AC-18.3：以刻意違規的資料驗證——兩 POI 相距 0.2 像素、r 各 50m、'
      'e=52.5m → 必須被抓到', () {
    final conflicts = findPoiProximityConflicts(
      pois: [
        PoiMarker(id: 'x', pixel: Vector2(0, 0), triggerRadiusMeters: 50),
        PoiMarker(id: 'y', pixel: Vector2(0.2, 0), triggerRadiusMeters: 50),
      ],
      positionErrorBound: 52.5,
      metersPerPixel: 1.0,
    );
    expect(conflicts, hasLength(1),
        reason: '0.2m < 50+50+52.5=152.5m 的門檻，規則本身必須偵測到違規；'
            '若這條測試意外綠燈，代表規則寫錯了');
    expect(conflicts.single, contains('x'));
    expect(conflicts.single, contains('y'));
  });

  test('以 TaiwanMapManifest 驗證：目前綠燈，但綠燈源自地圖尺度（370.4 '
      '公尺/像素）非佈點品質——地方層（任務 D）上線後必須重驗', () async {
    final manifest = await TaiwanMapManifest.load();
    final conflicts = findPoiProximityConflicts(
      pois: manifest.poiNodes,
      // 量測資料：離散度上界 33.0m。此數字不得用以論證任何 POI 佈點合格
      // （SPEC C v6 REQ-C-18 規則 2），此處僅用來跑通規則本身。
      positionErrorBound: 33,
      metersPerPixel: manifest.metersPerPixelAt(Vector2.zero()),
    );
    expect(conflicts, isEmpty);
  });
}
