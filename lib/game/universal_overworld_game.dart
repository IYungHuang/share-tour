import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'components/player_component.dart';
import 'map_module/overworld_map_manifest.dart';

class UniversalOverworldGame extends FlameGame with ScaleDetector {
  UniversalOverworldGame({
    required this.manifest,
    required this.onTick,
    required this.renderedPixelOf,
  });

  final OverworldMapManifest manifest;

  /// 每幀交還給 domain 推進平滑。引擎不自己算位置。
  final void Function(double dt) onTick;

  /// 讀取 domain 當前的顯示點。
  final Vector2 Function() renderedPixelOf;

  late final World mapWorld;
  late final CameraComponent cameraComponent;
  late final SpriteComponent mapComponent;
  late final PlayerComponent playerComponent;

  double _baseZoom = 1.0;
  final double minZoom = 0.5;
  final double maxZoom = 2.5;

  @override
  Color backgroundColor() => Color(manifest.oceanColorArgb);

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

    // 2. 加入玩家佔位圖標 (像素紅點小人)
    playerComponent =
        PlayerComponent(position: manifest.defaultSpawnPixel.clone());
    await mapWorld.add(playerComponent);

    // 3. 初始化視口相機
    cameraComponent.viewfinder.anchor = Anchor.center;
    cameraComponent.viewfinder.position = playerComponent.position;
    cameraComponent.viewfinder.zoom = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    onTick(dt);
    playerComponent.syncTo(renderedPixelOf());
    if (_followPlayer) {
      cameraComponent.viewfinder.position = playerComponent.position.clone();
      _clampCameraBounds();
    }
  }

  /// 手勢平移時暫時解除跟隨。完整的回歸狀態機屬 REQ-C-08（P1）。
  bool _followPlayer = true;

  // --- 手勢事件處理 ---

  @override
  void onScaleStart(ScaleStartInfo info) {
    _baseZoom = cameraComponent.viewfinder.zoom;
    _followPlayer = false;
  }

  /// 回到我的位置。
  void recenterOnPlayer() => _followPlayer = true;

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final currentZoom = cameraComponent.viewfinder.zoom;

    // 平移：位移量按比例折算
    final delta = info.delta.global / currentZoom;
    cameraComponent.viewfinder.position -= delta;

    // 縮放
    if (info.scale.global.x != 1.0) {
      final newZoom = (_baseZoom * info.scale.global.x).clamp(minZoom, maxZoom);
      cameraComponent.viewfinder.zoom = newZoom;
    }

    _clampCameraBounds();
  }

  void _clampCameraBounds() {
    final currentZoom = cameraComponent.viewfinder.zoom;
    final viewportSize = cameraComponent.viewport.size;

    final halfW = viewportSize.x / (2 * currentZoom);
    final halfH = viewportSize.y / (2 * currentZoom);

    final mapW = manifest.mapDimensions.x;
    final mapH = manifest.mapDimensions.y;
    final curPos = cameraComponent.viewfinder.position;

    final clampedX = halfW * 2 >= mapW ? mapW / 2 : curPos.x.clamp(halfW, mapW - halfW);
    final clampedY = halfH * 2 >= mapH ? mapH / 2 : curPos.y.clamp(halfH, mapH - halfH);

    cameraComponent.viewfinder.position = Vector2(clampedX, clampedY);
  }


}
