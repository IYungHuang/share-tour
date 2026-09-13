import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/core_loop_exceptions.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:vector_math/vector_math.dart';

class FakePoiMaterialResolver implements PoiMaterialResolver {
  final Map<String, TravelMaterial> mapping;
  FakePoiMaterialResolver([this.mapping = const {}]);

  @override
  TravelMaterial? resolveMaterialFor(String poiId) => mapping[poiId];
}

class FakeSimpleManifest implements OverworldMapManifest {
  FakeSimpleManifest([this._attractions = const []]);
  final List<DistrictAttraction> _attractions;

  @override
  double metersPerPixelAt(Vector2 pixel) => 1.0;
  @override
  String get mapId => 'fake_map';
  @override
  String get assetPath => '';
  @override
  Vector2 get mapDimensions => Vector2(1000, 1000);
  @override
  int get oceanColorArgb => 0;
  @override
  bool get hasOceanWaves => false;
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
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleMaterial = TravelMaterial(
    id: 'mat_1',
    name: '測試素材',
    tags: [],
    themeValue: 20,
    hypeValue: 30,
    cost: 100,
    riskLevel: 1,
  );

  late ProviderContainer container;
  late FakePoiMaterialResolver fakeResolver;

  setUp(() {
    fakeResolver = FakePoiMaterialResolver({'poi_1': sampleMaterial});
    container = ProviderContainer(
      overrides: [
        curatorMaterialPoolProvider.overrideWithValue([sampleMaterial]),
        poiMaterialResolverProvider.overrideWithValue(fakeResolver),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('AC-M5-3.1: shotTier 正確寫入入袋素材', () {
    test('gatherPoi 傳入 shotTier: perfect，入袋素材的 shotTier 為 perfect', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      controller.gatherPoi('poi_1', shotTier: ShotTier.perfect);
      final state = container.read(curatorRunControllerProvider);
      expect(state.inventory.materials.first.shotTier, ShotTier.perfect);
    });

    test('未指定 shotTier 時預設 normal（既有呼叫零改動）', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      controller.gatherPoi('poi_1');
      final state = container.read(curatorRunControllerProvider);
      expect(state.inventory.materials.first.shotTier, ShotTier.normal);
    });
  });

  group('AC-M5-3.2/3.3: 三態不改變 HP/Budget 扣減，failed 仍照常扣除並入袋', () {
    test('failed 態的資源扣減與 normal 態相同', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      final before = container.read(curatorRunControllerProvider).resources;
      controller.gatherPoi('poi_1', shotTier: ShotTier.failed);
      final after = container.read(curatorRunControllerProvider);
      expect(before.hp - after.resources.hp, 6); // riskLevel 1 * 6
      expect(before.budget - after.resources.budget, 100);
      expect(after.gatheredPoiIds, contains('poi_1'));
      expect(after.inventory.count, 1);
    });
  });

  group('REQ-M5-07.1: expectedPoiId 防護', () {
    test('expectedPoiId 失配時拋出 PoiTargetChangedException，狀態零副作用', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      final before = container.read(curatorRunControllerProvider);
      expect(
        () => controller.gatherPoi(
          'poi_1',
          expectedPoiId: 'poi_moved_away',
        ),
        throwsA(isA<PoiTargetChangedException>()),
      );
      final after = container.read(curatorRunControllerProvider);
      expect(after.gatheredPoiIds, before.gatheredPoiIds);
      expect(after.inventory.count, before.inventory.count);
      expect(after.resources.hp, before.resources.hp);
    });

    test('expectedPoiId 相符時正常取材', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      final result = controller.gatherPoi('poi_1', expectedPoiId: 'poi_1');
      expect(result.material.id, 'mat_1');
    });
  });

  group('難度選定與中斷記錄接線', () {
    test('selectDifficulty 寫入狀態並追加事件（不拋例外）', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      expect(
        () => controller.selectDifficulty(ShutterDifficulty.photographer),
        returnsNormally,
      );
      expect(
        container.read(curatorRunControllerProvider).shutterDifficulty,
        ShutterDifficulty.photographer,
      );
    });

    test('recordShutterInterruption 累加中斷次數', () {
      final controller = container.read(curatorRunControllerProvider.notifier);
      controller.recordShutterInterruption();
      controller.recordShutterInterruption();
      expect(
        container.read(curatorRunControllerProvider).interruptionCount,
        2,
      );
    });
  });
}
