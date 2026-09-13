import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/character_action/character_action_controller.dart';
import '../../game/characters/character_asset_loader.dart';

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

  SpriteComponent? get spriteChild => _spriteChild;
  SpriteAnimation? get animation => _animation;

  /// Deliberately null: playback has one clock, owned by [controller].
  Object? get animationTicker => null;

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
    final child = _spriteChild;
    final animation = _animation;
    if (child != null && animation != null) {
      child.sprite = animation.frames[controller.frameIndex].sprite;
    }
    super.update(dt);
  }
}
