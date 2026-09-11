import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math.dart';

import 'package:share_tour/core/time/clock.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/data/core_loop/kyoto_poi_material_resolver.dart';
import 'package:share_tour/data/core_loop/local_persistence_repository.dart';
import 'package:share_tour/data/location/virtual_location_source.dart';
import 'package:share_tour/domain/core_loop/models/curator_save_data.dart';
import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';
import 'package:share_tour/domain/core_loop/run/curator_run_state.dart';
import 'package:share_tour/domain/location/models/district_attraction.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';
import 'package:share_tour/state/core_loop/curator_run_controller.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/core_loop/persistence_providers.dart';
import 'package:share_tour/state/location/location_providers.dart';

import '../fakes/fake_clock.dart';

/// 採集事件記錄
class WalkGatherEvent {
  final DistrictAttraction attraction;
  final TravelMaterial material;
  final int hpSpent;
  final Duration elapsed;
  final Vector2 playerPixel;

  const WalkGatherEvent({
    required this.attraction,
    required this.material,
    required this.hpSpent,
    required this.elapsed,
    required this.playerPixel,
  });
}

/// 京都夜間街區步行採集測試驅動器 (Commit 14, T12, AC-A1-4.1)
class KyotoWalkDriver {
  final ProviderContainer container;
  final FakeClock clock;
  final KyotoNightMapManifest manifest;
  final List<WalkGatherEvent> gatherEvents = [];

  KyotoWalkDriver._({
    required this.container,
    required this.clock,
    required this.manifest,
  });

  /// 以 Production Kyoto 裝配環境建立測試驅動器
  static Future<KyotoWalkDriver> create({
    FakeClock? clock,
    CuratorSaveData? initialSave,
  }) async {
    final fakeClock = clock ?? FakeClock();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = LocalPersistenceRepository(prefs: prefs);
    final save = initialSave ?? CuratorSaveData.initial(profileId: 'kyoto-driver-save');
    const activeManifest = KyotoNightMapManifest();

    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(fakeClock as Clock),
        mapManifestProvider.overrideWithValue(activeManifest),
        curatorMaterialPoolProvider.overrideWithValue(kyotoNightMaterials),
        poiMaterialResolverProvider.overrideWithValue(
          const KyotoPoiMaterialResolver(),
        ),
        persistenceRepositoryProvider.overrideWithValue(repository),
        initialSaveDataProvider.overrideWithValue(save),
      ],
    );

    // 推進讓 LocationNotifier._bindSource(SourceMode.virtual) 異步建立完成
    container.read(locationControllerProvider.notifier);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    // 行前選定第一個旅行哲學並出發至 fieldTrip 踩線階段
    final runController = container.read(curatorRunControllerProvider.notifier);
    final runState = container.read(curatorRunControllerProvider);
    runController.selectPhilosophy(runState.philosophyChoices.first);
    runController.departToFieldTrip();

    return KyotoWalkDriver._(
      container: container,
      clock: fakeClock,
      manifest: activeManifest,
    );
  }

  VirtualLocationSource get virtualSource =>
      container.read(virtualSourceProvider);

  LocationNotifier get locationNotifier =>
      container.read(locationControllerProvider.notifier);

  CuratorRunController get runController =>
      container.read(curatorRunControllerProvider.notifier);

  CuratorRunState get runState => container.read(curatorRunControllerProvider);

  Vector2 get renderedPixel =>
      container.read(locationControllerProvider).renderedPixel;

  PoiMaterialResolver get resolver =>
      container.read(poiMaterialResolverProvider);

  Duration get elapsed => clock.elapsed;

  /// 執行單一邏輯步行 Tick：
  /// 1. setDirection(direction)
  /// 2. FakeClock.advanceAsync(virtualSource.interval)
  /// 3. 推進 microtask 確保串流與節流送達
  /// 4. LocationController.tick(dt) 推進 renderedPixel
  /// 5. 經 T9b 正式最近 POI 入口嘗試採集
  Future<WalkGatherEvent?> tick({
    required Vector2 direction,
    bool autoGather = true,
  }) async {
    virtualSource.setDirection(direction);

    await clock.advanceAsync(virtualSource.interval);

    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    final dt = virtualSource.interval.inMicroseconds / 1e6;
    locationNotifier.controller.tick(dt);

    if (!autoGather) return null;

    return tryGatherNearest();
  }

  /// 經 T9b 正式最近 POI 仲裁與入口採集
  WalkGatherEvent? tryGatherNearest() {
    final currentPixel = renderedPixel;
    final nearest = nearestGatherablePoi(
      attractions: manifest.districtAttractions,
      run: runState,
      playerPixel: currentPixel,
      manifest: manifest,
      resolver: resolver,
    );

    if (nearest == null) return null;

    final result = runController.gatherPoi(
      nearest.attraction.id,
      manifest: manifest,
      playerPixel: currentPixel,
    );

    final event = WalkGatherEvent(
      attraction: result.attraction,
      material: result.material,
      hpSpent: result.hpSpent,
      elapsed: clock.elapsed,
      playerPixel: currentPixel.clone(),
    );
    gatherEvents.add(event);
    return event;
  }

  /// 依指定方向走指定步數 (ticks)
  Future<void> walkTicks({
    required Vector2 direction,
    required int count,
    bool autoGather = true,
  }) async {
    for (var i = 0; i < count; i++) {
      await tick(direction: direction, autoGather: autoGather);
    }
  }

  /// 釋放驅動器與 ProviderContainer
  void dispose() {
    container.dispose();
  }
}
