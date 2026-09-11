import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/domain/core_loop/models/gathering_eligibility.dart';
import 'package:share_tour/domain/core_loop/models/guide_resources.dart';
import 'package:share_tour/domain/core_loop/models/material_inventory.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:vector_math/vector_math.dart';

class FakeSimpleManifest implements OverworldMapManifest {
  @override
  double metersPerPixelAt(Vector2 pixel) => 1.0; // 1 pixel = 1 meter

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
  List<DistrictAttraction> get districtAttractions => const [];
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
}
