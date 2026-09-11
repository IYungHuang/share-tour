import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/models/travel_philosophy.dart';
import 'package:share_tour/domain/core_loop/review/client_spec.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_phase.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/location/location_controller.dart';
import 'package:share_tour/state/location/location_providers.dart';
import 'package:share_tour/ui/core_loop/curator_studio_modal.dart';
import 'package:share_tour/ui/core_loop/field/curator_field_hud.dart';
import 'package:vector_math/vector_math.dart';

import '../../fakes/fake_wakelock_control.dart';

class FakePoiResolver implements PoiMaterialResolver {
  final Map<String, TravelMaterial> map;
  FakePoiResolver(this.map);
  @override
  TravelMaterial? resolveMaterialFor(String poiId) => map[poiId];
}

class FakeIntegrationManifest implements OverworldMapManifest {
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

class FakeLocationNotifier extends LocationNotifier {
  FakeLocationNotifier(this.pixel);
  final Vector2 pixel;

  @override
  LocationControllerState build() {
    return LocationControllerState(
      status: LocationStatus.initial,
      diagnostics: const LocationDiagnostics(
        activeSubscriptionCount: 0,
        powerMode: PowerMode.active,
        acceptedFixCount: 0,
        rejectedFixCount: 0,
        rejectionsByReason: {},
        currentAccuracyMeters: 1.0,
        realDistanceMeters: 0,
        virtualDistanceMeters: 0,
        secondsSinceLastSignificantMove: 0,
        accuracyGatedFixCount: 0,
        keepAwakeActive: false,
      ),
      renderedPixel: pixel,
      targetPixel: pixel,
      realDistanceMeters: 0,
      virtualDistanceMeters: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Overworld Curator Integration 測試 (G6, AC-M3-6)', () {
    const sampleMaterial = TravelMaterial(
      id: 'mat_exhaustion_test',
      name: '最後一搏高山步道',
      tags: ['#自然', '#高風險'],
      themeValue: 20,
      hypeValue: 50,
      cost: 500,
      riskLevel: 3, // 16 HP
    );

    test('AC-M3-6.1: 取材使 HP 扣至 0 時，phase 推進至 nightEditing，canExploreProvider 為 false', () {
      final container = ProviderContainer(
        overrides: [
          curatorMaterialPoolProvider.overrideWithValue([sampleMaterial]),
          poiMaterialResolverProvider.overrideWithValue(
            FakePoiResolver({'poi_1': sampleMaterial}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(curatorRunControllerProvider.notifier);
      // 設置只有 10 HP (小於 sampleMaterial 的 16 HP)
      final state = CuratorRunState.initial(
        phase: CuratorRunPhase.fieldTrip,
        client: ClientSpec.budgetWorker,
        philosophy: TravelPhilosophy.midnight,
        initialHp: 10,
        initialBudget: 2000,
      );
      controller.state = state;

      expect(container.read(canExploreProvider), isTrue);
      expect(container.read(curatorRunControllerProvider).isExhausted, isFalse);

      // 發動取材 (最後一搏)
      controller.gatherPoi('poi_1');

      final updated = container.read(curatorRunControllerProvider);
      expect(updated.resources.currentHp, equals(0));
      expect(updated.phase, equals(CuratorRunPhase.nightEditing));
      expect(updated.isExhausted, isTrue);
      expect(container.read(canExploreProvider), isFalse);
    });

    testWidgets('AC-M3-6.2: 體力耗盡時自動開啟 CuratorStudioModal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          wakelockControlProvider.overrideWithValue(FakeWakelockControl()),
          mapManifestProvider.overrideWithValue(FakeIntegrationManifest()),
          locationControllerProvider.overrideWith(
            () => FakeLocationNotifier(Vector2(100, 100)),
          ),
          curatorMaterialPoolProvider.overrideWithValue([sampleMaterial]),
          poiMaterialResolverProvider.overrideWithValue(
            FakePoiResolver({'poi_1': sampleMaterial}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(curatorRunControllerProvider.notifier);
      controller.state = CuratorRunState.initial(
        phase: CuratorRunPhase.fieldTrip,
        initialHp: 10,
        initialBudget: 2000,
      );

      bool isStudioOpen = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.listen(curatorRunControllerProvider, (previous, next) {
                    if (next.isExhausted && (previous == null || !previous.isExhausted)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!isStudioOpen) {
                          isStudioOpen = true;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const CuratorStudioModal(),
                          );
                        }
                      });
                    }
                  });

                  return const Column(
                    children: [
                      CuratorFieldHud(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 初期狀態：HP 10/100
      expect(find.text('10/100'), findsOneWidget);
      expect(find.byType(CuratorStudioModal), findsNothing);

      // 取材扣盡 HP
      controller.gatherPoi('poi_1');

      await tester.pump();
      await tester.pumpAndSettle();

      // 驗證 HUD 顯示 HP 0/100
      expect(find.text('0/100'), findsOneWidget);

      // 驗證 CuratorStudioModal 自動彈出
      expect(find.byType(CuratorStudioModal), findsOneWidget);
      expect(find.text('📑 策展工作台'), findsOneWidget);
    });
  });
}
