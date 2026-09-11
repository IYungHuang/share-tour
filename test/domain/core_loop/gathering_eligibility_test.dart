import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/domain/core_loop/models/gathering_eligibility.dart';
import 'package:share_tour/domain/core_loop/models/guide_resources.dart';
import 'package:share_tour/domain/core_loop/models/material_inventory.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:vector_math/vector_math.dart';

class FakeSimpleManifest implements OverworldMapManifest {
  FakeSimpleManifest([this._attractions = const []]);

  final List<DistrictAttraction> _attractions;
  int metersPerPixelCalls = 0;

  @override
  double metersPerPixelAt(Vector2 pixel) {
    metersPerPixelCalls++;
    return 1.0; // 1 pixel = 1 meter
  }

  @override
  String get mapId => 'fake_map';
  @override
  String get assetPath => '';
  @override
  Vector2 get mapDimensions => Vector2(1000, 1000);
  @override
  int get oceanColorArgb => 0;
  @override
  Vector2 get defaultSpawnPixel => Vector2(100, 100);
  @override
  double get dpadSpeedPixelsPerSecond => 50;
  @override
  List<PoiMarker> get poiNodes => const [];
  @override
  List<DistrictAttraction> get districtAttractions => _attractions;
  @override
  List<AdministrativeDistrict> get administrativeDistricts => const [];
  @override
  bool containsGeo(double lat, double lng) => true;
  @override
  Vector2 projectToPixel(double lat, double lng) => Vector2(lat, lng);
  @override
  GeoPoint unprojectToGeo(Vector2 pixel) => GeoPoint(pixel.x, pixel.y);
}

void main() {
  group('GatheringEligibility Domain 純函式測試 (T9a)', () {
    final manifest = FakeSimpleManifest();

    final attraction = DistrictAttraction(
      id: 'test_poi',
      title: '測試景點',
      districtCode: 'kyoto',
      districtName: '京都',
      geo: const GeoPoint(35.005, 135.705),
      pixel: Vector2(100, 100),
      rating: 4.5,
      reviewCount: 100,
      category: AttractionCategory.sightseeing,
      triggerRadiusMeters: 50.0,
    );

    final sampleMaterial = kyotoNightMaterials.first;

    CuratorRunState createRunState({
      Set<String> gatheredPoiIds = const {},
      int hp = 100,
      bool fullInventory = false,
    }) {
      final inventory = fullInventory
          ? MaterialInventory(
              capacity: 6,
              materials: kyotoNightMaterials.take(6).toList(),
            )
          : MaterialInventory(capacity: 6);

      return CuratorRunState.initial().copyWith(
        gatheredPoiIds: gatheredPoiIds,
        resources: GuideResources(
          hp: hp,
          maxHp: 100,
          budget: 2000,
          theme: 50,
          hype: 0,
        ),
        inventory: inventory,
      );
    }

    test('1. material 為 null 時回傳 unavailable', () {
      final result = evaluateAttractionEligibility(
        attraction: attraction,
        run: createRunState(),
        material: null,
        playerPixel: Vector2(100, 100),
        manifest: manifest,
      );
      expect(result, equals(GatheringEligibility.unavailable));
    });

    test('2. 景點已在 gatheredPoiIds 時回傳 alreadyGathered (優先於透支與超距)', () {
      final result = evaluateAttractionEligibility(
        attraction: attraction,
        run: createRunState(gatheredPoiIds: {'test_poi'}, hp: 0),
        material: sampleMaterial,
        playerPixel: Vector2(999, 999), // 超距
        manifest: manifest,
      );
      expect(result, equals(GatheringEligibility.alreadyGathered));
    });

    test('3. 體力透支 (hp <= 0) 時回傳 exhausted (優先於超距)', () {
      final resHp0 = evaluateAttractionEligibility(
        attraction: attraction,
        run: createRunState(hp: 0),
        material: sampleMaterial,
        playerPixel: Vector2(100, 100),
        manifest: manifest,
      );
      expect(resHp0, equals(GatheringEligibility.exhausted));

      final resHpNegative = evaluateAttractionEligibility(
        attraction: attraction,
        run: createRunState(hp: -5),
        material: sampleMaterial,
        playerPixel: Vector2(999, 999),
        manifest: manifest,
      );
      expect(resHpNegative, equals(GatheringEligibility.exhausted));
    });

    test('4. 距離大於 triggerRadiusMeters 時回傳 outOfRange', () {
      // attraction 在 (100, 100), player 在 (100, 151) -> distM = 51m > 50m
      final result = evaluateAttractionEligibility(
        attraction: attraction,
        run: createRunState(),
        material: sampleMaterial,
        playerPixel: Vector2(100, 151),
        manifest: manifest,
      );
      expect(result, equals(GatheringEligibility.outOfRange));
    });

    test('5. 邊界測試：距離恰好等於 triggerRadiusMeters (50m) 時視為在範圍內', () {
      // player 在 (100, 150) -> distM = 50.0m <= 50m
      final result = evaluateAttractionEligibility(
        attraction: attraction,
        run: createRunState(),
        material: sampleMaterial,
        playerPixel: Vector2(100, 150),
        manifest: manifest,
      );
      expect(result, equals(GatheringEligibility.ready));
    });

    test('6. 範圍內但腰包已滿時回傳 inventoryFull', () {
      final result = evaluateAttractionEligibility(
        attraction: attraction,
        run: createRunState(fullInventory: true),
        material: sampleMaterial,
        playerPixel: Vector2(100, 100),
        manifest: manifest,
      );
      expect(result, equals(GatheringEligibility.inventoryFull));
    });

    test('7. 範圍內、未滿包、有體力且有素材時回傳 ready', () {
      final result = evaluateAttractionEligibility(
        attraction: attraction,
        run: createRunState(),
        material: sampleMaterial,
        playerPixel: Vector2(120, 100), // 20m <= 50m
        manifest: manifest,
      );
      expect(result, equals(GatheringEligibility.ready));
    });
  });

  group('T9b 像素半徑與最近 POI 原子取材判定 (AC-A1-4.3)', () {
    final sampleMaterial = kyotoNightMaterials.first;

    CuratorRunState createRunState({
      Set<String> gatheredPoiIds = const {},
      int hp = 100,
      bool fullInventory = false,
    }) {
      final inventory = fullInventory
          ? MaterialInventory(
              capacity: 6,
              materials: kyotoNightMaterials.take(6).toList(),
            )
          : MaterialInventory(capacity: 6);

      return CuratorRunState.initial().copyWith(
        gatheredPoiIds: gatheredPoiIds,
        resources: GuideResources(
          hp: hp,
          maxHp: 100,
          budget: 2000,
          theme: 50,
          hype: 0,
        ),
        inventory: inventory,
      );
    }

    test('像素半徑非 null 時直接比 pixel 且不呼叫 metersPerPixelAt；null 時公尺邊界與既有行為一致', () {
      final manifest = FakeSimpleManifest();

      // 像素半徑 35px
      final pixelAttraction = DistrictAttraction(
        id: 'pixel_poi',
        title: '京都街區景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(100, 100),
        rating: 4.8,
        reviewCount: 500,
        category: AttractionCategory.landmark,
        triggerRadiusMeters: 50.0,
        triggerRadiusPixels: 35.0,
      );

      // 1. 距離 30 px <= 35 px: ready, 且完全不呼叫 metersPerPixelAt
      manifest.metersPerPixelCalls = 0;
      final readyRes = evaluateAttractionEligibility(
        attraction: pixelAttraction,
        run: createRunState(),
        material: sampleMaterial,
        playerPixel: Vector2(100, 130), // 30 px
        manifest: manifest,
      );
      expect(readyRes, equals(GatheringEligibility.ready));
      expect(manifest.metersPerPixelCalls, equals(0), reason: '像素模式不得呼叫 metersPerPixelAt');

      // 2. 距離 36 px > 35 px: outOfRange, 且完全不呼叫 metersPerPixelAt
      manifest.metersPerPixelCalls = 0;
      final outRes = evaluateAttractionEligibility(
        attraction: pixelAttraction,
        run: createRunState(),
        material: sampleMaterial,
        playerPixel: Vector2(100, 136), // 36 px
        manifest: manifest,
      );
      expect(outRes, equals(GatheringEligibility.outOfRange));
      expect(manifest.metersPerPixelCalls, equals(0), reason: '像素模式不得呼叫 metersPerPixelAt');

      // 3. triggerRadiusPixels 為 null 時，使用公尺判定並呼叫 metersPerPixelAt
      final meterAttraction = DistrictAttraction(
        id: 'meter_poi',
        title: '台灣公尺景點',
        districtCode: 'taipei',
        districtName: '台北',
        geo: const GeoPoint(25.0, 121.5),
        pixel: Vector2(100, 100),
        rating: 4.5,
        reviewCount: 100,
        category: AttractionCategory.sightseeing,
        triggerRadiusMeters: 50.0,
        triggerRadiusPixels: null,
      );

      manifest.metersPerPixelCalls = 0;
      final meterReady = evaluateAttractionEligibility(
        attraction: meterAttraction,
        run: createRunState(),
        material: sampleMaterial,
        playerPixel: Vector2(100, 140), // 40 px * 1.0 m/px = 40m <= 50m
        manifest: manifest,
      );
      expect(meterReady, equals(GatheringEligibility.ready));
      expect(manifest.metersPerPixelCalls, greaterThan(0), reason: '公尺模式必須呼叫 metersPerPixelAt');
    });

    test('nearestGatherablePoi: 最近點按距離，等距按 ID 字典序，重排輸入結果不變', () {
      final poiNear = DistrictAttraction(
        id: 'poi_b_near',
        title: '近景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(100, 110), // dist = 10 px
        rating: 4.5,
        reviewCount: 100,
        category: AttractionCategory.sightseeing,
        triggerRadiusPixels: 35.0,
      );

      final poiFar = DistrictAttraction(
        id: 'poi_a_far',
        title: '遠景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(100, 120), // dist = 20 px
        rating: 4.5,
        reviewCount: 100,
        category: AttractionCategory.sightseeing,
        triggerRadiusPixels: 35.0,
      );

      final manifest = FakeSimpleManifest([poiNear, poiFar]);
      final resolver = FakeSimpleResolver({
        'poi_b_near': kyotoNightMaterials[0],
        'poi_a_far': kyotoNightMaterials[1],
      });

      final run = createRunState();
      final playerPixel = Vector2(100, 100);

      // 距離近者優先 (10 px < 20 px)，即便 poi_a_far 字典序在前面
      final result1 = nearestGatherablePoi(
        attractions: [poiFar, poiNear],
        run: run,
        playerPixel: playerPixel,
        manifest: manifest,
        resolver: resolver,
      );
      expect(result1?.attraction.id, equals('poi_b_near'));

      // 重排輸入順序，結果不變
      final result2 = nearestGatherablePoi(
        attractions: [poiNear, poiFar],
        run: run,
        playerPixel: playerPixel,
        manifest: manifest,
        resolver: resolver,
      );
      expect(result2?.attraction.id, equals('poi_b_near'));

      // 等距測試: 兩景點距離均為 10 px，ID 分別為 'poi_alpha' 與 'poi_zebra'
      final poiAlpha = DistrictAttraction(
        id: 'poi_alpha',
        title: 'Alpha 景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(90, 100), // dist = 10 px
        rating: 4.5,
        reviewCount: 100,
        category: AttractionCategory.sightseeing,
        triggerRadiusPixels: 35.0,
      );
      final poiZebra = DistrictAttraction(
        id: 'poi_zebra',
        title: 'Zebra 景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(110, 100), // dist = 10 px
        rating: 4.5,
        reviewCount: 100,
        category: AttractionCategory.sightseeing,
        triggerRadiusPixels: 35.0,
      );
      final tieResolver = FakeSimpleResolver({
        'poi_alpha': kyotoNightMaterials[0],
        'poi_zebra': kyotoNightMaterials[1],
      });

      // 字典序 'poi_alpha' < 'poi_zebra'
      final tieRes1 = nearestGatherablePoi(
        attractions: [poiZebra, poiAlpha],
        run: run,
        playerPixel: playerPixel,
        manifest: manifest,
        resolver: tieResolver,
      );
      expect(tieRes1?.attraction.id, equals('poi_alpha'));

      final tieRes2 = nearestGatherablePoi(
        attractions: [poiAlpha, poiZebra],
        run: run,
        playerPixel: playerPixel,
        manifest: manifest,
        resolver: tieResolver,
      );
      expect(tieRes2?.attraction.id, equals('poi_alpha'));
    });

    test('nearestGatherablePoi: 已採集、透支、超距、無素材之景點皆被排除', () {
      final poiReady = DistrictAttraction(
        id: 'poi_ready',
        title: '可用景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(100, 115), // dist = 15 px
        rating: 4.5,
        reviewCount: 100,
        category: AttractionCategory.sightseeing,
        triggerRadiusPixels: 35.0,
      );

      final poiCloserGathered = DistrictAttraction(
        id: 'poi_closer_gathered',
        title: '已採集近景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(100, 105), // dist = 5 px
        rating: 4.5,
        reviewCount: 100,
        category: AttractionCategory.sightseeing,
        triggerRadiusPixels: 35.0,
      );

      final manifest = FakeSimpleManifest([poiReady, poiCloserGathered]);
      final resolver = FakeSimpleResolver({
        'poi_ready': kyotoNightMaterials[0],
        'poi_closer_gathered': kyotoNightMaterials[1],
      });

      // 雖然 poiCloserGathered 更近，但已在 gatheredPoiIds 中，應回傳 poi_ready
      final runWithGathered = createRunState(gatheredPoiIds: {'poi_closer_gathered'});
      final res = nearestGatherablePoi(
        attractions: [poiReady, poiCloserGathered],
        run: runWithGathered,
        playerPixel: Vector2(100, 100),
        manifest: manifest,
        resolver: resolver,
      );
      expect(res?.attraction.id, equals('poi_ready'));

      // 當體力透支時，回傳 null
      final runExhausted = createRunState(hp: 0);
      final resExhausted = nearestGatherablePoi(
        attractions: [poiReady],
        run: runExhausted,
        playerPixel: Vector2(100, 100),
        manifest: manifest,
        resolver: resolver,
      );
      expect(resExhausted, isNull);
    });
  });
}

class FakeSimpleResolver implements PoiMaterialResolver {
  final Map<String, TravelMaterial> mapping;
  FakeSimpleResolver(this.mapping);

  @override
  TravelMaterial? resolveMaterialFor(String poiId) => mapping[poiId];
}
