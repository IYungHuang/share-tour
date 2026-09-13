import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';

void main() {
  group('DistrictAttraction 模型測試', () {
    test('建立景點資料並正確讀取各欄位', () {
      final attraction = DistrictAttraction(
        id: 'spot_1',
        title: '宏偉地標',
        districtCode: 'district_north',
        districtName: '北部行政區',
        geo: const GeoPoint(25.0, 121.5),
        pixel: Vector2(100, 200),
        rating: 4.7,
        reviewCount: 52000,
        category: AttractionCategory.landmark,
        description: '極具人氣的代表性地標。',
        minZoom: 1.2,
      );

      expect(attraction.id, 'spot_1');
      expect(attraction.title, '宏偉地標');
      expect(attraction.districtCode, 'district_north');
      expect(attraction.districtName, '北部行政區');
      expect(attraction.rating, 4.7);
      expect(attraction.reviewCount, 52000);
      expect(attraction.category, AttractionCategory.landmark);
      expect(attraction.minZoom, 1.2);
      expect(attraction.triggerRadiusMeters, 50.0);
      expect(attraction.triggerRadiusPixels, isNull);
    });

    test('支援 optional triggerRadiusPixels，toPoiMarker 仍保有公尺幾何語意', () {
      final attraction = DistrictAttraction(
        id: 'spot_px',
        title: '京都街區景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(100, 200),
        rating: 4.8,
        reviewCount: 1000,
        category: AttractionCategory.landmark,
        triggerRadiusPixels: 35.0,
      );

      expect(attraction.triggerRadiusPixels, 35.0);
      expect(attraction.triggerRadiusMeters, 50.0);

      final marker = attraction.toPoiMarker();
      expect(marker.triggerRadiusMeters, 50.0);
      expect(marker.id, 'spot_px');
    });

    test('景點與目標像素的距離計算', () {
      final attraction = DistrictAttraction(
        id: 'spot_1',
        title: '海灘奇觀',
        districtCode: 'district_east',
        districtName: '東部行政區',
        geo: const GeoPoint(24.0, 121.6),
        pixel: Vector2(100, 100),
        rating: 4.6,
        reviewCount: 30000,
        category: AttractionCategory.nature,
      );

      final distancePixels = attraction.distancePixelsTo(Vector2(103, 104));
      expect(distancePixels, closeTo(5.0, 1e-4));
    });
  });

  group('雙手放大縮放過濾 (AttractionFilter)', () {
    final spots = [
      DistrictAttraction(
        id: 'macro_landmark',
        title: '國家級指標',
        districtCode: 'metro_a',
        districtName: '甲行政區',
        geo: const GeoPoint(25.0, 121.0),
        pixel: Vector2(50, 50),
        rating: 4.8,
        reviewCount: 80000,
        category: AttractionCategory.landmark,
        minZoom: 0.5, // 任何縮放階層皆可見
      ),
      DistrictAttraction(
        id: 'district_a_park',
        title: '甲區特色公園',
        districtCode: 'metro_a',
        districtName: '甲行政區',
        geo: const GeoPoint(25.1, 121.1),
        pixel: Vector2(60, 55),
        rating: 4.5,
        reviewCount: 15000,
        category: AttractionCategory.nature,
        minZoom: 1.5, // 放大至 1.5 時出現
      ),
      DistrictAttraction(
        id: 'district_a_hidden_food',
        title: '甲區私房美食街',
        districtCode: 'metro_a',
        districtName: '甲行政區',
        geo: const GeoPoint(25.12, 121.15),
        pixel: Vector2(65, 58),
        rating: 4.6,
        reviewCount: 8000,
        category: AttractionCategory.food,
        minZoom: 2.2, // 深度放大至 2.2 時出現
      ),
      DistrictAttraction(
        id: 'district_b_temple',
        title: '乙區古老廟宇',
        districtCode: 'metro_b',
        districtName: '乙行政區',
        geo: const GeoPoint(24.0, 120.5),
        pixel: Vector2(200, 300),
        rating: 4.7,
        reviewCount: 25000,
        category: AttractionCategory.culture,
        minZoom: 1.5, // 放大至 1.5 時出現
      ),
    ];

    test('全圖宏觀縮放時 (zoom = 1.0)，僅顯示國家級核心地標', () {
      final visible = AttractionFilter.visibleAttractions(
        attractions: spots,
        currentZoom: 1.0,
      );

      expect(visible.map((s) => s.id), ['macro_landmark']);
    });

    test('雙手放大至 1.6 時，增添該階層的熱門景點', () {
      final visible = AttractionFilter.visibleAttractions(
        attractions: spots,
        currentZoom: 1.6,
      );

      final visibleIds = visible.map((s) => s.id).toSet();
      expect(visibleIds, containsAll(['macro_landmark', 'district_a_park', 'district_b_temple']));
      expect(visibleIds, isNot(contains('district_a_hidden_food')));
    });

    test('雙手深度放大至 2.5 時，增添更深入的在地私房熱門景點', () {
      final visible = AttractionFilter.visibleAttractions(
        attractions: spots,
        currentZoom: 2.5,
      );

      final visibleIds = visible.map((s) => s.id).toSet();
      expect(visibleIds.length, 4);
      expect(visibleIds, contains('district_a_hidden_food'));
    });

    test('依特定行政區篩選景點', () {
      final filtered = AttractionFilter.byDistrict(
        attractions: spots,
        districtCode: 'metro_a',
      );

      expect(filtered.length, 3);
      expect(filtered.every((s) => s.districtCode == 'metro_a'), isTrue);
    });

    test('依視口中心判定最接近的行政區', () {
      final districts = [
        AdministrativeDistrict(
          code: 'metro_a',
          name: '甲行政區',
          centerGeo: const GeoPoint(25.05, 121.05),
          centerPixel: Vector2(55, 55),
        ),
        AdministrativeDistrict(
          code: 'metro_b',
          name: '乙行政區',
          centerGeo: const GeoPoint(24.0, 120.5),
          centerPixel: Vector2(200, 300),
        ),
      ];

      final focusedA = AttractionFilter.findFocusedDistrict(
        districts: districts,
        cameraCenter: Vector2(58, 52),
      );
      expect(focusedA?.code, 'metro_a');

      final focusedB = AttractionFilter.findFocusedDistrict(
        districts: districts,
        cameraCenter: Vector2(195, 290),
      );
      expect(focusedB?.code, 'metro_b');
    });

    test('方案 A：依玩家角色實際像素座標 (findDistrictAtPosition) 精確感應踏入行政區邊界', () {
      final districts = [
        AdministrativeDistrict(
          code: 'nakagyo',
          name: '河原町',
          centerGeo: const GeoPoint(35.006, 135.768),
          centerPixel: Vector2(400, 400),
          radiusPixels: 100.0,
        ),
        AdministrativeDistrict(
          code: 'higashiyama',
          name: '祇園清水',
          centerGeo: const GeoPoint(35.000, 135.778),
          centerPixel: Vector2(600, 600),
          radiusPixels: 100.0,
        ),
      ];

      // 1. 玩家在 nakagyo 中心 50px 處（< 100px），應踏入 nakagyo
      final inNakagyo = AttractionFilter.findDistrictAtPosition(
        districts: districts,
        playerPosition: Vector2(430, 440),
      );
      expect(inNakagyo?.code, 'nakagyo');

      // 2. 玩家在兩者之間的盆地無人區 (100, 100)，未在任何感應圈內
      final inWilderness = AttractionFilter.findDistrictAtPosition(
        districts: districts,
        playerPosition: Vector2(100, 100),
      );
      expect(inWilderness, isNull);

      // 3. 玩家移至 higashiyama 範圍內 (580, 610)
      final inHigashiyama = AttractionFilter.findDistrictAtPosition(
        districts: districts,
        playerPosition: Vector2(580, 610),
      );
      expect(inHigashiyama?.code, 'higashiyama');
    });

    test('多核心聚類判定：支援主中心與次要中心 (additionalCenters) 精確觸發同行政區', () {
      final multiClusterDistricts = [
        AdministrativeDistrict(
          code: 'kyoto_fushimi_uji',
          name: '洛南・伏見宇治',
          centerGeo: const GeoPoint(34.9400, 135.7700),
          centerPixel: Vector2(416.0, 818.0),
          additionalCenters: [
            Vector2(899.2, 954.4), // 宇治川浮島鵜飼中心
            Vector2(615.4, 55.0),   // 鞍馬深山列車衛星中心
          ],
          radiusPixels: 130.0,
        ),
      ];

      // 1. 玩家在主核心（伏見稻荷 443, 815 附近）
      final atFushimi = AttractionFilter.findDistrictAtPosition(
        districts: multiClusterDistricts,
        playerPosition: Vector2(440.0, 815.0),
      );
      expect(atFushimi?.code, 'kyoto_fushimi_uji');

      // 2. 玩家在次核心（宇治川 900, 950 附近）
      final atUji = AttractionFilter.findDistrictAtPosition(
        districts: multiClusterDistricts,
        playerPosition: Vector2(900.0, 950.0),
      );
      expect(atUji?.code, 'kyoto_fushimi_uji');

      // 3. 玩家在衛星中心（鞍馬深山 615, 60 附近）
      final atKurama = AttractionFilter.findDistrictAtPosition(
        districts: multiClusterDistricts,
        playerPosition: Vector2(615.0, 60.0),
      );
      expect(atKurama?.code, 'kyoto_fushimi_uji');

      // 4. 玩家在無人空曠區 (300, 300)
      final atEmpty = AttractionFilter.findDistrictAtPosition(
        districts: multiClusterDistricts,
        playerPosition: Vector2(300.0, 300.0),
      );
      expect(atEmpty, isNull);
    });
  });
}
