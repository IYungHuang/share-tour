import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../domain/core_loop/models/tour_time_of_day.dart';
import '../domain/location/camera/camera_follow.dart';
import '../domain/location/models/district_attraction.dart';
import 'components/attraction_layer_component.dart';
import 'components/ocean_waves_component.dart';
import 'components/player_component.dart';
import 'components/time_of_day_lighting_component.dart';
import 'map_module/overworld_map_manifest.dart';

class UniversalOverworldGame extends FlameGame with ScaleDetector, TapCallbacks {
  UniversalOverworldGame({
    required OverworldMapManifest manifest,
    required this.onTick,
    required this.renderedPixelOf,
    required this.cameraFollow,
    this.onAttractionSelected,
    this.onDistrictRevealed,
    this.timeOfDayGetter,
  }) : _manifest = manifest;

  OverworldMapManifest _manifest;
  OverworldMapManifest get manifest => _manifest;

  /// 每幀交還給 domain 推進平滑。引擎不自己算位置。
  final void Function(double dt) onTick;

  /// 讀取 domain 當前的顯示點。
  final Vector2 Function() renderedPixelOf;

  /// 相機跟隨的純邏輯狀態機。引擎只負責把算出來的中心點套上去。
  final CameraFollow cameraFollow;

  /// 點選景點回調
  final void Function(DistrictAttraction? attraction)? onAttractionSelected;

  /// 縮放聚焦行政區變更回調
  final void Function(AdministrativeDistrict? district, int visibleCount)?
      onDistrictRevealed;
  final TourTimeOfDay Function()? timeOfDayGetter;

  late final World mapWorld;
  late final CameraComponent cameraComponent;
  late final SpriteComponent mapComponent;
  late final PlayerComponent playerComponent;
  late final AttractionLayerComponent attractionLayer;
  late final TimeOfDayLightingComponent lightingComponent;

  double _baseZoom = 1.0;
  final double minZoom = 0.5;
  final double maxZoom = 4.0;

  @override
  Color backgroundColor() {
    final baseColor = Color(manifest.oceanColorArgb);
    final time = timeOfDayGetter?.call() ?? TourTimeOfDay.dawn;
    switch (time) {
      case TourTimeOfDay.dawn:
        return Color.alphaBlend(const Color(0x33BBE1FA), baseColor);
      case TourTimeOfDay.midday:
        return Color.alphaBlend(const Color(0x15FFFBEB), baseColor);
      case TourTimeOfDay.dusk:
        return Color.alphaBlend(const Color(0x40F59E0B), baseColor);
      case TourTimeOfDay.night:
        return baseColor;
    }
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    mapWorld = World();
    cameraComponent = CameraComponent(world: mapWorld);
    await addAll([mapWorld, cameraComponent]);

    // 1. 載入並強制關閉抗鋸齒 (維持 8-Bit 硬邊)
    final sprite = await loadSprite(manifest.assetPath);
    mapComponent = SpriteComponent(
      sprite: sprite,
      size: manifest.mapDimensions,
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    await mapWorld.add(mapComponent);

    // 2. 加入動態水波組件 (Option B: Dynamic JRPG Ocean Waves，僅限含海域圖資)
    if (manifest.hasOceanWaves) {
      final waveImage = await images.load('ocean_wave_sheet.png');
      await mapWorld.add(OceanWavesComponent(waveImage: waveImage));
    }

    // 3. 加入玩家佔位圖標 (像素紅點小人)
    playerComponent =
        PlayerComponent(position: manifest.defaultSpawnPixel.clone());
    await mapWorld.add(playerComponent);

    // 4. 加入行政區熱門旅遊景點圖層 (雙手放大地圖時動態增添揭露)
    attractionLayer = AttractionLayerComponent(
      manifest: manifest,
      onAttractionTapped: (attraction) {
        attractionLayer.selectAttraction(attraction);
        onAttractionSelected?.call(attraction);
      },
      onDistrictChanged: onDistrictRevealed,
    );
    await mapWorld.add(attractionLayer);

    // 5. 加入動態四幕光照與環境燈火圖層 (晨曦／午後／黃昏／深夜)
    lightingComponent = TimeOfDayLightingComponent(
      mapSize: manifest.mapDimensions,
      timeOfDayGetter: timeOfDayGetter ?? () => TourTimeOfDay.dawn,
      playerPositionGetter: () => playerComponent.position,
      lightPositionsGetter: () =>
          manifest.districtAttractions.map((a) => a.pixel).toList(),
      priority: 25,
    );
    await mapWorld.add(lightingComponent);

    // 6. 初始化視口相機
    cameraComponent.viewfinder.anchor = Anchor.center;
    cameraComponent.viewfinder.position = playerComponent.position;
    cameraComponent.viewfinder.zoom = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    onTick(dt);
    playerComponent.syncTo(renderedPixelOf());
    cameraComponent.viewfinder.position = cameraFollow.targetCenter(
      player: playerComponent.position,
      zoom: cameraComponent.viewfinder.zoom,
      viewportSize: cameraComponent.viewport.size,
      mapSize: manifest.mapDimensions,
    );
    attractionLayer.updateVisibility(
      zoom: cameraComponent.viewfinder.zoom,
      cameraCenter: cameraComponent.viewfinder.position,
    );
  }

  // --- 手勢事件處理 ---

  @override
  void onScaleStart(ScaleStartInfo info) {
    _baseZoom = cameraComponent.viewfinder.zoom;
  }

  /// 回到我的位置。
  void recenterOnPlayer() => cameraFollow.recenter();

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final currentZoom = cameraComponent.viewfinder.zoom;

    // 縮放刻意不算「操作」：捏合只是想看看四周，不該被當成接管相機。
    if (info.scale.global.x != 1.0) {
      cameraFollow.onZoom();
      cameraComponent.viewfinder.zoom =
          (_baseZoom * info.scale.global.x).clamp(minZoom, maxZoom);
      return;
    }

    if (info.delta.global.length2 > 0) {
      // 位移量交給狀態機，引擎不自己寫相機位置：update() 每幀都會用
      // targetCenter 的結果覆寫，兩邊都寫的話手勢會被靜默蓋掉。
      cameraFollow.onPan(info.delta.global / currentZoom);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    final zoom = cameraComponent.viewfinder.zoom;
    final worldPoint = cameraComponent.globalToLocal(event.canvasPosition);

    final hit = attractionLayer.findAttractionAt(
      worldPoint,
      thresholdPixels: 48.0 / zoom.clamp(0.5, 4.0),
    );
    attractionLayer.selectAttraction(hit);
    onAttractionSelected?.call(hit);
  }

  /// 實作地圖分進層次熱切換（宏觀盆地 ⇄ 中觀街區）
  Future<void> switchMap(
    OverworldMapManifest newManifest, {
    Vector2? newSpawnPixel,
  }) async {
    _manifest = newManifest;

    // 1. 換掉底圖 Sprite
    final sprite = await loadSprite(newManifest.assetPath);
    mapComponent.sprite = sprite;
    mapComponent.size = newManifest.mapDimensions;

    // 2. 換掉景點圖層
    attractionLayer.switchManifest(newManifest);

    // 3. 換掉動態光照組件
    lightingComponent.switchMap(
      mapSize: newManifest.mapDimensions,
      lightPositions:
          newManifest.districtAttractions.map((a) => a.pixel).toList(),
    );

    // 4. 重設玩家座標與相機視口
    final spawn = newSpawnPixel ?? newManifest.defaultSpawnPixel;
    playerComponent.position = spawn.clone();
    cameraComponent.viewfinder.position = spawn.clone();
    cameraFollow.recenter();
  }
}
