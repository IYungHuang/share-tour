import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'map_module/overworld_map_manifest.dart';

class UniversalOverworldGame extends FlameGame with ScaleDetector {
  final OverworldMapManifest manifest;

  UniversalOverworldGame({required this.manifest});

  late final World mapWorld;
  late final CameraComponent cameraComponent;
  late final SpriteComponent mapComponent;
  late final PositionComponent playerComponent;

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
    playerComponent = CircleComponent(
      radius: 8,
      paint: Paint()..color = const Color(0xFFFF4757),
      anchor: Anchor.center,
      position: manifest.defaultSpawnPixel.clone(), // 降落點由圖資提供（PRE-7）
    );
    await mapWorld.add(playerComponent);

    // 3. 初始化視口相機
    cameraComponent.viewfinder.anchor = Anchor.center;
    cameraComponent.viewfinder.position = playerComponent.position;
    cameraComponent.viewfinder.zoom = 1.0;
  }

  // --- 手勢事件處理 ---

  @override
  void onScaleStart(ScaleStartInfo info) {
    _baseZoom = cameraComponent.viewfinder.zoom;
  }

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

  /// 外部呼叫：直接指定小人的顯示點。
  ///
  /// 投影、吸附與平滑都在 domain 完成，這裡只負責畫。引擎不得自己算座標——
  /// 那正是先前把台灣專屬校準器寫進通用引擎的成因。
  void setRenderedPixel(Vector2 pixel) {
    playerComponent.position.setFrom(pixel);
  }
}
