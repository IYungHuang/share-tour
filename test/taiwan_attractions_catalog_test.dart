import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/game/map_module/manifests/taiwan_map_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TaiwanMapManifest manifest;

  setUpAll(() async {
    manifest = await TaiwanMapManifest.load();
  });

  group('台灣熱門景點庫 (Google Maps 參考資料) 測試', () {
    test('景點資料庫不為空，涵蓋主要行政區', () {
      final attractions = manifest.districtAttractions;
      expect(attractions, isNotEmpty);
      expect(attractions.length, greaterThanOrEqualTo(50));

      final districtCodes = attractions.map((a) => a.districtCode).toSet();
      expect(districtCodes, containsAll([
        'taipei',
        'new_taipei',
        'keelung',
        'taoyuan',
        'hsinchu',
        'miaoli',
        'taichung',
        'changhua',
        'nantou',
        'yunlin',
        'chiayi',
        'tainan',
        'kaohsiung',
        'pingtung',
        'yilan',
        'hualien',
        'taitung',
        'penghu',
      ]));
    });

    test('行政區清單正確初始化且座標落在畫布內', () {
      final districts = manifest.administrativeDistricts;
      expect(districts.length, 18);

      for (final d in districts) {
        expect(d.centerPixel.x, inInclusiveRange(0, manifest.mapDimensions.x),
            reason: '${d.name} 中心 x 越界: ${d.centerPixel.x}');
        expect(d.centerPixel.y, inInclusiveRange(0, manifest.mapDimensions.y),
            reason: '${d.name} 中心 y 越界: ${d.centerPixel.y}');
      }
    });

    test('所有熱門景點經投影後皆落在畫布範圍內', () {
      for (final a in manifest.districtAttractions) {
        expect(a.pixel.x, inInclusiveRange(0, manifest.mapDimensions.x),
            reason: '${a.title} 像素 x 越界: ${a.pixel.x}');
        expect(a.pixel.y, inInclusiveRange(0, manifest.mapDimensions.y),
            reason: '${a.title} 像素 y 越界: ${a.pixel.y}');
      }
    });

    test('Google Maps 評分與評論數合理性 (4.0~5.0 星，評論 > 1000)', () {
      for (final a in manifest.districtAttractions) {
        expect(a.rating, inInclusiveRange(4.0, 5.0),
            reason: '${a.title} 評分異常: ${a.rating}');
        expect(a.reviewCount, greaterThan(1000),
            reason: '${a.title} 評論數過少: ${a.reviewCount}');
      }
    });

    test('雙手放大地圖時，景點數量隨縮放倍率單調遞增', () {
      final all = manifest.districtAttractions;

      final atOverview = AttractionFilter.visibleAttractions(
        attractions: all,
        currentZoom: 1.0,
      );

      final atGentleZoom = AttractionFilter.visibleAttractions(
        attractions: all,
        currentZoom: 1.5,
      );

      final atMediumZoom = AttractionFilter.visibleAttractions(
        attractions: all,
        currentZoom: 2.0,
      );

      final atDeepZoom = AttractionFilter.visibleAttractions(
        attractions: all,
        currentZoom: 3.0,
      );

      expect(atOverview.length, greaterThan(0));
      expect(atGentleZoom.length, greaterThan(atOverview.length));
      expect(atMediumZoom.length, greaterThan(atGentleZoom.length));
      expect(atDeepZoom.length, greaterThanOrEqualTo(atMediumZoom.length));
      expect(atDeepZoom.length, equals(all.length));
    });

    test('雙手放大至特定行政區時，該區景點能被完整解鎖與顯現', () {
      final taichungSpots = AttractionFilter.byDistrict(
        attractions: manifest.districtAttractions,
        districtCode: 'taichung',
      );

      expect(taichungSpots, isNotEmpty);
      expect(taichungSpots.map((s) => s.title), contains('高美濕地天空之鏡'));
      expect(taichungSpots.map((s) => s.title), contains('彩虹眷村'));
      expect(taichungSpots.map((s) => s.title), contains('台中國家歌劇院'));

      // 在 zoom 1.0 下高美濕地 (minZoom 1.2) 尚未顯現
      final visibleAt1 = AttractionFilter.visibleAttractions(
        attractions: taichungSpots,
        currentZoom: 1.0,
      );
      expect(visibleAt1.any((s) => s.id == 'tc_gaomei_wetland'), isFalse);

      // 雙手放大至 1.5 時高美濕地顯現
      final visibleAt1_5 = AttractionFilter.visibleAttractions(
        attractions: taichungSpots,
        currentZoom: 1.5,
      );
      expect(visibleAt1_5.any((s) => s.id == 'tc_gaomei_wetland'), isTrue);
    });
  });
}
