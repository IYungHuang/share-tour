import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/location/location_providers.dart';
import 'package:vector_math/vector_math.dart';

import '../../fakes/fake_wakelock_control.dart';

class FakePoiMaterialResolver implements PoiMaterialResolver {
  final Map<String, TravelMaterial> mapping;
  FakePoiMaterialResolver([this.mapping = const {}]);

  @override
  TravelMaterial? resolveMaterialFor(String poiId) => mapping[poiId];
}

class FakeSimpleManifest implements OverworldMapManifest {
  @override
  double metersPerPixelAt(Vector2 pixel) => 1.0; // 1 像素 = 1 公尺

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M3 狀態層取材控制器與 6 態資格狀態機測試 (G2, AC-M3-1, AC-M3-2)', () {
    const sampleMaterial = TravelMaterial(
      id: 'mat_101',
      name: '台北101天際線',
      tags: ['#地標', '#夜景'],
      themeValue: 30,
      hypeValue: 80,
      cost: 600,
      riskLevel: 2, // 10 + 2*2 = 14 HP
    );

    final attractionInRadius = DistrictAttraction(
      id: 'poi_101',
      title: '台北101觀景台',
      districtCode: 'taipei',
      districtName: '台北市',
      geo: const GeoPoint(25.0339, 121.5645),
      pixel: Vector2(100, 140), // 距離 (100, 100) 為 40 像素 = 40 公尺 (<= 50m)
      rating: 4.8,
      reviewCount: 90000,
      category: AttractionCategory.landmark,
      triggerRadiusMeters: 50.0,
    );

    final attractionOutOfRadius = DistrictAttraction(
      id: 'poi_far',
      title: '淡水老街',
      districtCode: 'new_taipei',
      districtName: '新北市',
      geo: const GeoPoint(25.1700, 121.4400),
      pixel: Vector2(100, 160), // 距離 (100, 100) 為 60 像素 = 60 公尺 (> 50m)
      rating: 4.6,
      reviewCount: 30000,
      category: AttractionCategory.food,
      triggerRadiusMeters: 50.0,
    );

    final attractionUnavailable = DistrictAttraction(
      id: 'poi_no_card',
      title: '無素材景點',
      districtCode: 'taipei',
      districtName: '台北市',
      geo: const GeoPoint(25.0, 121.5),
      pixel: Vector2(100, 120),
      rating: 4.0,
      reviewCount: 100,
      category: AttractionCategory.recreation,
    );

    late ProviderContainer container;
    late FakePoiMaterialResolver fakeResolver;

    setUp(() {
      fakeResolver = FakePoiMaterialResolver({
        'poi_101': sampleMaterial,
        'poi_far': sampleMaterial.copyWith(id: 'mat_far', name: '淡水鐵蛋'),
      });

      container = ProviderContainer(
        overrides: [
          mapManifestProvider.overrideWithValue(FakeSimpleManifest()),
          curatorMaterialPoolProvider.overrideWithValue([sampleMaterial]),
          poiMaterialResolverProvider.overrideWithValue(fakeResolver),
          wakelockControlProvider.overrideWithValue(FakeWakelockControl()),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('AC-M3-1.1 開局狀態：canExploreProvider 為 true，推進至 fieldTrip 探索', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      final briefing = container.read(curatorRunControllerProvider);
      controller.selectPhilosophy(briefing.philosophyChoices.first);
      controller.departToFieldTrip();

      final canExplore = container.read(canExploreProvider);
      final runState = container.read(curatorRunControllerProvider);

      expect(canExplore, isTrue);
      expect(runState.phase, CuratorRunPhase.fieldTrip);
      expect(runState.resources.hp, 100);
      expect(runState.inventory.count, 0);
    });

    test('AC-M3-2.1 40m (<= 50m) 且未採集，狀態為 GatheringEligibility.ready', () {
      final eligibility = container.read(attractionEligibilityProvider(attractionInRadius));
      expect(eligibility, GatheringEligibility.ready);
    });

    test('AC-M3-2.2 60m (> 50m)，狀態為 GatheringEligibility.outOfRange', () {
      final eligibility = container.read(attractionEligibilityProvider(attractionOutOfRadius));
      expect(eligibility, GatheringEligibility.outOfRange);
    });

    test('Resolver 未提供素材之景點，狀態為 GatheringEligibility.unavailable', () {
      final eligibility = container.read(attractionEligibilityProvider(attractionUnavailable));
      expect(eligibility, GatheringEligibility.unavailable);
    });

    test('AC-M3-3.1 Controller.gatherPoi 成功取材：扣除 HP 與 Budget，狀態躍遷為 alreadyGathered', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      final result = controller.gatherPoi('poi_101');

      expect(result.material.id, 'mat_101');
      expect(result.hpSpent, 12); // riskLevel 2: 2 * 6 = 12

      final runState = container.read(curatorRunControllerProvider);
      expect(runState.resources.hp, 88); // 100 - 12
      expect(runState.inventory.count, 1);
      expect(runState.gatheredPoiIds.contains('poi_101'), isTrue);

      // 資格變更為 alreadyGathered
      final eligibility = container.read(attractionEligibilityProvider(attractionInRadius));
      expect(eligibility, GatheringEligibility.alreadyGathered);
    });

    test('AC-M3-4.1 腰包已滿時，在範圍內景點之資格變更為 GatheringEligibility.inventoryFull', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      // 填滿 6 格
      for (int i = 0; i < 6; i++) {
        controller.drawSampleMaterial();
      }

      final eligibility = container.read(attractionEligibilityProvider(attractionInRadius));
      expect(eligibility, GatheringEligibility.inventoryFull);
    });

    test('AC-M3-4.3 Controller.replaceGatheredPoi 成功替換腰包素材', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      for (int i = 0; i < 6; i++) {
        controller.drawSampleMaterial();
      }

      final result = controller.replaceGatheredPoi(poiId: 'poi_101', dropIndex: 1);
      expect(result.material.id, 'mat_101');
      expect(result.hpSpent, 12);

      final runState = container.read(curatorRunControllerProvider);
      expect(runState.inventory.count, 6);
      expect(runState.inventory.materials[1].id, 'mat_101');
      expect(runState.gatheredPoiIds.contains('poi_101'), isTrue);
    });

    test('AC-M3-6.1 體力透支後，canExploreProvider 變為 false，資格變為 exhausted', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      final risk4Material = sampleMaterial.copyWith(riskLevel: 4); // deltaHp = 4 * 6 = 24 HP

      // 4 次取材 (96 HP, 剩餘 4 HP)
      for (int i = 0; i < 4; i++) {
        fakeResolver.mapping['poi_step_$i'] = risk4Material.copyWith(id: 'mat_$i');
        controller.gatherPoi('poi_step_$i');
      }
      expect(container.read(curatorRunControllerProvider).resources.hp, 4); // 100 - 24*4 = 4

      // 第 5 次取材 (消耗 24 HP，實扣剩餘 4 HP -> 0 HP，容量 5/6 未滿)
      fakeResolver.mapping['poi_step_last'] = risk4Material.copyWith(id: 'mat_last');
      final resultLast = controller.gatherPoi('poi_step_last');
      expect(resultLast.hpSpent, 4, reason: '最後一搏實扣量為剩餘 4 HP');

      final runState = container.read(curatorRunControllerProvider);
      expect(runState.resources.hp, 0);
      expect(runState.resources.isExhausted, isTrue);
      expect(runState.phase, CuratorRunPhase.nightEditing);

      expect(container.read(canExploreProvider), isFalse);

      final unusedAttraction = DistrictAttraction(
        id: 'poi_unused',
        title: '某景點',
        districtCode: 'taipei',
        districtName: '台北市',
        geo: const GeoPoint(25.0, 121.0),
        pixel: Vector2(100, 110),
        rating: 4.5,
        reviewCount: 100,
        category: AttractionCategory.nature,
      );
      fakeResolver.mapping['poi_unused'] = sampleMaterial;
      final eligibility = container.read(attractionEligibilityProvider(unusedAttraction));
      expect(eligibility, GatheringEligibility.exhausted);
    });

    test('AC-A1-5.5: Controller 取材回傳實扣 HP，足額與最後一搏實扣量精確自洽', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      final risk2Mat = sampleMaterial.copyWith(riskLevel: 2); // 12 HP
      fakeResolver.mapping['poi_a'] = risk2Mat;

      // 足額扣除
      final r1 = controller.gatherPoi('poi_a');
      expect(r1.hpSpent, 12);
      expect(container.read(curatorRunControllerProvider).resources.hp, 88);

      // 人為設定剩餘 5 HP
      controller.state = controller.state.copyWith(
        resources: controller.state.resources.consumeHp(83),
      );
      expect(container.read(curatorRunControllerProvider).resources.hp, 5);

      // 最後一搏：面對 12 HP 代價，實扣 5 HP
      fakeResolver.mapping['poi_b'] = risk2Mat.copyWith(id: 'mat_b');
      final r2 = controller.gatherPoi('poi_b');
      expect(r2.hpSpent, 5);
      expect(container.read(curatorRunControllerProvider).resources.hp, 0);
      expect(container.read(curatorRunControllerProvider).phase, CuratorRunPhase.nightEditing);
    });
  });
}
