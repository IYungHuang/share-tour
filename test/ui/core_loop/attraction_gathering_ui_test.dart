import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/location/location_controller.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/state/location/location_providers.dart';
import 'package:share_tour/ui/core_loop/field/attraction_detail_card.dart';
import 'package:share_tour/ui/core_loop/field/gathering_replace_bottom_sheet.dart';
import 'package:share_tour/ui/core_loop/field/shutter_qte_overlay.dart';
import 'package:vector_math/vector_math.dart';

import '../../fakes/fake_wakelock_control.dart';

class FakePoiResolver implements PoiMaterialResolver {
  final Map<String, TravelMaterial> map;
  FakePoiResolver(this.map);
  @override
  TravelMaterial? resolveMaterialFor(String poiId) => map[poiId];
}

class FakeSimpleManifest implements OverworldMapManifest {
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

  group('AttractionDetailCard UI 測試 (G4, AC-M3-2, AC-M3-4)', () {
    const sampleMaterial = TravelMaterial(
      id: 'mat_101',
      name: '台北101天際線',
      tags: ['#地標', '#夜景'],
      themeValue: 30,
      hypeValue: 80,
      cost: 600,
      riskLevel: 2, // 14 HP
    );

    final attractionReady = DistrictAttraction(
      id: 'poi_101',
      title: '台北101觀景台',
      districtCode: 'taipei',
      districtName: '台北市',
      geo: const GeoPoint(25.0339, 121.5645),
      pixel: Vector2(100, 130), // 30m <= 50m
      rating: 4.8,
      reviewCount: 90000,
      category: AttractionCategory.landmark,
      triggerRadiusMeters: 50.0,
    );

    final attractionFar = DistrictAttraction(
      id: 'poi_far',
      title: '遠方景點',
      districtCode: 'taipei',
      districtName: '台北市',
      geo: const GeoPoint(25.0, 121.0),
      pixel: Vector2(100, 200), // 100m > 50m
      rating: 4.5,
      reviewCount: 100,
      category: AttractionCategory.nature,
      triggerRadiusMeters: 50.0,
    );

    late FakePoiResolver fakeResolver;

    Future<void> resolveQte(WidgetTester tester) async {
      await tester.pump();
      expect(find.byType(ShutterQteOverlay), findsOneWidget);
      await tester.tap(find.byType(ShutterQteOverlay));
      await tester.pumpAndSettle();
    }

    setUp(() {
      fakeResolver = FakePoiResolver({
        'poi_101': sampleMaterial,
        'poi_far': sampleMaterial,
      });
    });

    Widget buildTestWidget({
      required ValueNotifier<DistrictAttraction?> selected,
      CuratorRunState? state,
      void Function(TravelMaterial, int)? onGathered,
    }) {
      return ProviderScope(
        key: UniqueKey(),
        overrides: [
          mapManifestProvider.overrideWithValue(FakeSimpleManifest()),
          locationControllerProvider.overrideWith(
            () => FakeLocationNotifier(Vector2(100, 100)),
          ),
          curatorMaterialPoolProvider.overrideWithValue([sampleMaterial]),
          poiMaterialResolverProvider.overrideWithValue(fakeResolver),
          wakelockControlProvider.overrideWithValue(FakeWakelockControl()),
          if (state != null)
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
            ),
          ),
        ),
      );
    }

    testWidgets('AC-M3-2.1: 範圍內景點顯示「📸 踩線取材」並預覽代價 -12 HP 與 ¥600', (
      tester,
    ) async {
      final selected = ValueNotifier<DistrictAttraction?>(attractionReady);
      final state = CuratorRunState.initial(
        initialBudget: 2000,
        initialHp: 100,
      );

      await tester.pumpWidget(
        buildTestWidget(selected: selected, state: state),
      );

      expect(find.text('台北101觀景台'), findsOneWidget);
      expect(find.textContaining('-12 HP'), findsOneWidget);
      expect(find.textContaining('¥600'), findsOneWidget);
      expect(find.text('📸 踩線取材'), findsOneWidget);
    });

    testWidgets('AC-M3-2.2: 超距景點顯示「太遠 (需<50m)」且禁用', (tester) async {
      final selected = ValueNotifier<DistrictAttraction?>(attractionFar);
      final state = CuratorRunState.initial();

      await tester.pumpWidget(
        buildTestWidget(selected: selected, state: state),
      );

      expect(find.text('太遠 (需<50m)'), findsOneWidget);
    });

    testWidgets('AC-M3-3.1: 點擊「📸 踩線取材」觸發取材回調 (足額 12 HP)', (tester) async {
      final selected = ValueNotifier<DistrictAttraction?>(attractionReady);
      final state = CuratorRunState.initial(
        initialBudget: 2000,
        initialHp: 100,
      );
      TravelMaterial? gatheredItem;
      int? hpCost;

      await tester.pumpWidget(
        buildTestWidget(
          selected: selected,
          state: state,
          onGathered: (m, hp) {
            gatheredItem = m;
            hpCost = hp;
          },
        ),
      );

      await tester.tap(find.text('📸 踩線取材'));
      await resolveQte(tester);

      expect(gatheredItem, isNotNull);
      expect(gatheredItem!.id, 'mat_101');
      expect(hpCost, 12);

      // 踩線後按鈕變為「✅ 本日已踩線」
      expect(find.text('✅ 本日已踩線'), findsOneWidget);
    });

    testWidgets('AC-A1-5.5: 最後一搏時實扣回調精確為剩餘 5 HP，不得回傳名目成本 12 HP', (
      tester,
    ) async {
      final selected = ValueNotifier<DistrictAttraction?>(attractionReady);
      // 人為設定 HP = 5
      final state = CuratorRunState.initial(initialBudget: 2000, initialHp: 5);
      TravelMaterial? gatheredItem;
      int? hpCost;

      await tester.pumpWidget(
        buildTestWidget(
          selected: selected,
          state: state,
          onGathered: (m, hp) {
            gatheredItem = m;
            hpCost = hp;
          },
        ),
      );

      // 預覽仍顯示名目成本 -12 HP
      expect(find.textContaining('-12 HP'), findsOneWidget);

      await tester.tap(find.text('📸 踩線取材'));
      await resolveQte(tester);

      expect(gatheredItem, isNotNull);
      expect(hpCost, 5, reason: '最後一搏實扣量必須為 5 HP 而非名目 12 HP');
    });

    testWidgets('Task 4: 晨曦時段契合素材顯示綠色折讓文案 (時段共鳴 -3 HP) 且實扣 9 HP', (
      tester,
    ) async {
      const resonanceMaterial = TravelMaterial(
        id: 'mat_resonance',
        name: '清水寺晨間散步',
        tags: ['#散步', '#寺院'],
        themeValue: 30,
        hypeValue: 80,
        cost: 300,
        riskLevel: 2, // base 12 HP -> discount 3 HP = 9 HP
      );
      final attractionResonance = DistrictAttraction(
        id: 'poi_resonance',
        title: '清水寺',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(34.9949, 135.7850),
        pixel: Vector2(100, 120),
        rating: 4.8,
        reviewCount: 50000,
        category: AttractionCategory.landmark,
        triggerRadiusMeters: 50.0,
      );

      fakeResolver.map['poi_resonance'] = resonanceMaterial;
      final selected = ValueNotifier<DistrictAttraction?>(attractionResonance);
      final state = CuratorRunState.initial(
        initialBudget: 2000,
        initialHp: 100,
      );
      TravelMaterial? gatheredItem;
      int? hpCost;

      await tester.pumpWidget(
        buildTestWidget(
          selected: selected,
          state: state,
          onGathered: (m, hp) {
            gatheredItem = m;
            hpCost = hp;
          },
        ),
      );

      // 檢查折讓文案與實際扣額預覽
      expect(find.textContaining('-9 HP'), findsOneWidget);
      expect(find.textContaining('時段共鳴 -3 HP'), findsOneWidget);

      await tester.tap(find.text('📸 踩線取材'));
      await resolveQte(tester);

      expect(gatheredItem, isNotNull);
      expect(hpCost, 9, reason: '共鳴折讓 3 HP 後實扣 9 HP');
    });

    testWidgets('AC-M3-4.1 & 4.3: 腰包滿額時顯示「👝 踩線換牌」，點擊彈出換牌抽屜', (tester) async {
      final selected = ValueNotifier<DistrictAttraction?>(attractionReady);
      var state = CuratorRunState.initial(initialBudget: 2000, initialHp: 100);
      // 填滿 6 張素材
      for (int i = 0; i < 6; i++) {
        state = state.copyWith(
          inventory: state.inventory.add(
            sampleMaterial.copyWith(id: 'mat_old_$i', name: '舊卡 $i'),
          ),
        );
      }

      TravelMaterial? gatheredItem;
      int? hpCost;

      await tester.pumpWidget(
        buildTestWidget(
          selected: selected,
          state: state,
          onGathered: (m, hp) {
            gatheredItem = m;
            hpCost = hp;
          },
        ),
      );

      expect(find.text('👝 踩線換牌'), findsOneWidget);

      await tester.tap(find.text('👝 踩線換牌'));
      await tester.pumpAndSettle();

      // 驗證彈出換牌抽屜
      expect(find.text('👝 腰包客滿！選擇一張舊卡替換'), findsOneWidget);
      expect(find.text('舊卡 0'), findsOneWidget);
      expect(find.text('捨棄此卡'), findsNWidgets(6));

      // 點擊第一張舊卡的捨棄
      await tester.tap(find.text('捨棄此卡').first);
      await resolveQte(tester);

      // 換牌完成，抽屜關閉，景點標記為已踩線，回調實扣 12 HP
      expect(find.text('✅ 本日已踩線'), findsOneWidget);
      expect(gatheredItem, isNotNull);
      expect(hpCost, 12);
    });

    testWidgets('AC-A1-5.5: 換牌取消不扣資源、不出浮字', (tester) async {
      final selected = ValueNotifier<DistrictAttraction?>(attractionReady);
      var state = CuratorRunState.initial(initialBudget: 2000, initialHp: 100);
      for (int i = 0; i < 6; i++) {
        state = state.copyWith(
          inventory: state.inventory.add(
            sampleMaterial.copyWith(id: 'mat_old_$i', name: '舊卡 $i'),
          ),
        );
      }

      var onGatheredCalled = false;
      await tester.pumpWidget(
        buildTestWidget(
          selected: selected,
          state: state,
          onGathered: (m, hp) {
            onGatheredCalled = true;
          },
        ),
      );

      await tester.tap(find.text('👝 踩線換牌'));
      await tester.pumpAndSettle();

      // 點擊空白處關閉抽屜 (取消換牌)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // 未發生取材回調
      expect(onGatheredCalled, isFalse);
      expect(find.text('👝 踩線換牌'), findsOneWidget);
    });

    testWidgets('T9b 像素模式：顯示 px 資格與距離提示，公尺模式保留 m 與既有門檻', (tester) async {
      final pixelAttraction = DistrictAttraction(
        id: 'poi_pixel',
        title: '京都像素景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(100, 130), // 30 px <= 35 px
        rating: 4.8,
        reviewCount: 500,
        category: AttractionCategory.landmark,
        triggerRadiusPixels: 35.0,
      );
      fakeResolver.map['poi_pixel'] = sampleMaterial;

      final selected = ValueNotifier<DistrictAttraction?>(pixelAttraction);
      await tester.pumpWidget(buildTestWidget(selected: selected));
      await tester.pumpAndSettle();

      // 像素模式距離徽章顯示 px
      expect(find.text('距玩家: 30 px'), findsOneWidget);
      // 範圍內顯示踩線取材
      expect(find.text('📸 踩線取材'), findsOneWidget);

      // 超距測試：距離 40 px > 35 px
      final pixelFar = DistrictAttraction(
        id: 'poi_pixel_far',
        title: '京都超距景點',
        districtCode: 'kyoto',
        districtName: '京都',
        geo: const GeoPoint(35.0, 135.7),
        pixel: Vector2(100, 140), // 40 px
        rating: 4.8,
        reviewCount: 500,
        category: AttractionCategory.landmark,
        triggerRadiusPixels: 35.0,
      );
      fakeResolver.map['poi_pixel_far'] = sampleMaterial;
      selected.value = pixelFar;
      await tester.pumpAndSettle();

      expect(find.text('距玩家: 40 px'), findsOneWidget);
      expect(find.text('太遠 (需<35px)'), findsOneWidget);
    });

    testWidgets(
      'AC-CF-2.4: material.hasFatigueRisk 為真時取材卡面與替換清單皆渲染 [💀 拉車隱患]，為假時不渲染',
      (tester) async {
        // 1. 卡面測試：hasFatigueRisk == false (riskLevel: 2)
        final lowRiskPoi = DistrictAttraction(
          id: 'poi_low_risk',
          title: '低風險景點',
          districtCode: 'taipei',
          districtName: '台北',
          geo: const GeoPoint(25.0, 121.5),
          pixel: Vector2(100, 110),
          rating: 4.5,
          reviewCount: 100,
          category: AttractionCategory.landmark,
          triggerRadiusMeters: 50.0,
        );
        fakeResolver.map['poi_low_risk'] = sampleMaterial.copyWith(
          id: 'mat_low_risk',
          riskLevel: 2,
        );

        final selected = ValueNotifier<DistrictAttraction?>(lowRiskPoi);
        final normalState = CuratorRunState.initial(
          initialBudget: 2000,
          initialHp: 100,
        );
        await tester.pumpWidget(
          buildTestWidget(selected: selected, state: normalState),
        );
        await tester.pumpAndSettle();

        expect(find.text('[💀 拉車隱患]'), findsNothing);

        // 2. 卡面測試：hasFatigueRisk == true (riskLevel: 3)
        final highRiskPoi = DistrictAttraction(
          id: 'poi_high_risk',
          title: '高風險景點',
          districtCode: 'taipei',
          districtName: '台北',
          geo: const GeoPoint(25.0, 121.5),
          pixel: Vector2(100, 110),
          rating: 4.5,
          reviewCount: 100,
          category: AttractionCategory.landmark,
          triggerRadiusMeters: 50.0,
        );
        final highRiskMaterial = sampleMaterial.copyWith(
          id: 'mat_high_risk',
          riskLevel: 3,
        );
        fakeResolver.map['poi_high_risk'] = highRiskMaterial;

        selected.value = highRiskPoi;
        await tester.pumpAndSettle();

        expect(find.text('[💀 拉車隱患]'), findsOneWidget);

        // 3. 換牌抽屜測試：當腰包滿且新素材有疲勞隱患時，抽屜呈現 [💀 拉車隱患]
        var fullState = CuratorRunState.initial(
          initialBudget: 2000,
          initialHp: 100,
        );
        for (int i = 0; i < 6; i++) {
          fullState = fullState.copyWith(
            inventory: fullState.inventory.add(
              sampleMaterial.copyWith(
                id: 'mat_old_$i',
                name: '舊卡 $i',
                riskLevel: i == 0 ? 3 : 1,
              ),
            ),
          );
        }

        await tester.pumpWidget(
          buildTestWidget(selected: selected, state: fullState),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('👝 踩線換牌'));
        await tester.pumpAndSettle();

        // 新素材（highRiskMaterial）有疲勞隱患，舊卡 0 也有疲勞隱患，抽屜內共 2 個，全畫面含底層卡面共 3 個
        expect(find.text('[💀 拉車隱患]'), findsNWidgets(3));
        expect(
          find.descendant(
            of: find.byType(GatheringReplaceBottomSheet),
            matching: find.text('[💀 拉車隱患]'),
          ),
          findsNWidgets(2),
        );
      },
    );
  });
}
