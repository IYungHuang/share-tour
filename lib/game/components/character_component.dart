import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/character_action/character_action_controller.dart';
import '../../game/characters/character_asset_loader.dart';
import '../../game/characters/guide_action_sheet_registry.dart';

/// Flame adapter for one pure-Dart character action controller.
class CharacterComponent extends PositionComponent {
  CharacterComponent({
    required this.controller,
    required this.loader,
    super.position,
  });

  final CharacterActionController controller;
  final CharacterAssetLoader loader;

  SpriteComponent? _spriteChild;
  SpriteAnimation? _animation;
  CharacterActionSheetCell? _activeCell;
  double _cellElapsed = 0;

  SpriteComponent? get spriteChild => _spriteChild;
  SpriteAnimation? get animation => _animation;

  /// Deliberately null: playback has one clock, owned by [controller].
  Object? get animationTicker => null;
  CharacterActionSheetCell? get activeCell => _activeCell;

  Future<void> playCell(CharacterActionSheetCell cell) async {
    final sprite = await loader.loadCell(cell);
    _activeCell = cell;
    _cellElapsed = 0;
    final child = _spriteChild;
    if (child == null) return;
    child.sprite = sprite;
    child.size.setValues(cell.renderWidth, cell.renderHeight);
    size.setValues(cell.renderWidth, cell.renderHeight);
  }

  @override
  Future<void> onLoad() async {
    final resolved = controller.resolvedAnimation;
    if (resolved == null) {
      return;
    }

    final loaded = await loader.load(resolved.asset);
    _animation = loaded.animation;
    _spriteChild = SpriteComponent(
      sprite: _animation!.frames[controller.frameIndex].sprite,
      autoResize: false,
      size: Vector2(loaded.asset.renderWidth, loaded.asset.renderHeight),
      position: Vector2.zero(),
      anchor: Anchor(loaded.asset.anchor.x, loaded.asset.anchor.y),
    )..paint.filterQuality = FilterQuality.none;
    add(_spriteChild!);
    size.setValues(loaded.asset.renderWidth, loaded.asset.renderHeight);
    anchor = Anchor(loaded.asset.anchor.x, loaded.asset.anchor.y);
  }

  @override
  void update(double dt) {
    controller.update(dt);
    final cell = _activeCell;
    if (cell != null) {
      _cellElapsed += dt;
      if (!cell.loop && _cellElapsed >= 1 / cell.fps) {
        _activeCell = null;
      }
    }
    final child = _spriteChild;
    final animation = _animation;
    if (child != null && animation != null && _activeCell == null) {
      child.sprite = animation.frames[controller.frameIndex].sprite;
    }
    super.update(dt);
  }
}
