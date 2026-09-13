// 煙霧測試等級（`CLAUDE.md` §2：`ui/` 不追求覆蓋率）。
//
// 驗證 G13 的實際接線：QTE 覆蓋層真的被觸發（不是靠 pumpAndSettle 逾時
// 兜底）、suspendCameraForQte/resumeCameraFromQte 呼叫時機正確、
// PoiTargetChangedException 靜默取消（AC-M5-3.6 系列）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/location/location_controller.dart';
import 'package:share_tour/state/location/location_providers.dart';
import 'package:share_tour/ui/core_loop/field/attraction_detail_card.dart';
import 'package:share_tour/ui/core_loop/field/shutter_qte_overlay.dart';
import 'package:vector_math/vector_math.dart';

import '../../../fakes/fake_wakelock_control.dart';

class _FakePoiResolver implements PoiMaterialResolver {
  _FakePoiResolver(this.map);
  final Map<String, TravelMaterial> map;
  @override
  TravelMaterial? resolveMaterialFor(String poiId) => map[poiId];
}

class _FakeSimpleManifest implements OverworldMapManifest {
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

class _FakeLocationNotifier extends LocationNotifier {
  _FakeLocationNotifier(this.pixel);
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

  const sampleMaterial = TravelMaterial(
    id: 'mat_101',
    name: '測試景點',
    tags: [],
    themeValue: 30,
    hypeValue: 80,
    cost: 600,
    riskLevel: 2,
  );

  final attractionReady = DistrictAttraction(
    id: 'poi_101',
    title: '測試景點',
    districtCode: 'x',
    districtName: 'x',
    geo: const GeoPoint(0, 0),
    pixel: Vector2(100, 130),
    rating: 4.8,
    reviewCount: 1,
    category: AttractionCategory.landmark,
    triggerRadiusMeters: 50.0,
  );

  late _FakePoiResolver fakeResolver;

  setUp(() {
    fakeResolver = _FakePoiResolver({'poi_101': sampleMaterial});
  });

  Widget buildTestWidget({
    required ValueNotifier<DistrictAttraction?> selected,
    required CuratorRunState state,
    void Function(TravelMaterial, int)? onGathered,
    VoidCallback? onSuspend,
    VoidCallback? onResume,
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        mapManifestProvider.overrideWithValue(_FakeSimpleManifest()),
        locationControllerProvider.overrideWith(() => _FakeLocationNotifier(Vector2(100, 100))),
        curatorMaterialPoolProvider.overrideWithValue([sampleMaterial]),
        poiMaterialResolverProvider.overrideWithValue(fakeResolver),
        wakelockControlProvider.overrideWithValue(FakeWakelockControl()),
        curatorRunControllerProvider.overrideWith((ref) {
          return CuratorRunController(
            materialPool: [sampleMaterial],
            resolver: fakeResolver,
            initialState: state,
          );
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AttractionDetailCard(
            selectedAttraction: selected,
            onGathered: onGathered,
            onSuspendCameraForQte: onSuspend,
            onResumeCameraFromQte: onResume,
          ),
        ),
      ),
    );
  }

  testWidgets('點擊踩線取材先開出 QTE 覆蓋層，未點擊前不觸發 gatherPoi', (tester) async {
    final selected = ValueNotifier<DistrictAttraction?>(attractionReady);
    final state = CuratorRunState.initial(initialBudget: 2000, initialHp: 100);
    var gathered = false;

    await tester.pumpWidget(buildTestWidget(
      selected: selected,
      state: state,
      onGathered: (_, _) => gathered = true,
    ));

    await tester.tap(find.text('📸 踩線取材'));
    await tester.pump();

    expect(find.byType(ShutterQteOverlay), findsOneWidget, reason: 'QTE 覆蓋層必須真的被打開');
    expect(gathered, isFalse, reason: 'QTE 判定完成前不得提前取材');
  });

  testWidgets('QTE 判定後才呼叫 gatherPoi，且 suspend/resume 依序各呼叫一次', (tester) async {
    final selected = ValueNotifier<DistrictAttraction?>(attractionReady);
    final state = CuratorRunState.initial(initialBudget: 2000, initialHp: 100);
    TravelMaterial? gatheredItem;
    final callOrder = <String>[];

    await tester.pumpWidget(buildTestWidget(
      selected: selected,
      state: state,
      onGathered: (m, _) => gatheredItem = m,
      onSuspend: () => callOrder.add('suspend'),
      onResume: () => callOrder.add('resume'),
    ));

    await tester.tap(find.text('📸 踩線取材'));
    await tester.pump();

    expect(callOrder, ['suspend'], reason: '開啟 QTE 時應立即暫停相機回歸計時');

    // 立即放開（down/up 皆預設 timeStamp=Duration.zero）：以預設 tourist
    // 難度判定，delta 遠超完美窗但 tourist 無 failed（AC-M5-1.4）。
    await tester.tap(find.byType(ShutterQteOverlay));
    await tester.pumpAndSettle();

    expect(gatheredItem, isNotNull, reason: 'QTE 判定完成後才觸發取材');
    expect(gatheredItem!.shotTier, ShotTier.normal);
    expect(callOrder, ['suspend', 'resume'], reason: '判定完成後應恢復相機回歸計時');
    expect(find.byType(ShutterQteOverlay), findsNothing, reason: 'QTE 覆蓋層應已關閉');
  });
}
