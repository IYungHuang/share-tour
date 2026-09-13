import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/character_action/character_action_controller.dart';
import '../../domain/character_action/character_animation_manifest.dart';
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
  String? _loadedAnimationKey;
  String? _loadingAnimationKey;
  bool _usingSheetAnimation = false;
  int _sheetFrameIndex = 0;
  double _sheetElapsed = 0;
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

    await _loadAnimation(resolved.asset, createChild: true);
  }

  Future<void> _loadAnimation(
    CharacterAnimationAsset asset, {
    bool createChild = false,
  }) async {
    final key = asset.animationKey;
    if (_loadingAnimationKey == key) return;
    _loadingAnimationKey = key;
    try {
      final sheet = actionSheetAnimationFor(
        controller.characterId,
        controller.action,
      );
      final loadedAnimation = sheet == null
          ? (await loader.load(asset)).animation
          : await loader.loadSheetAnimation(sheet);
      if (controller.resolvedAnimation?.asset.animationKey != key) return;
      _animation = loadedAnimation;
      _loadedAnimationKey = key;
      _usingSheetAnimation = sheet != null;
      _sheetFrameIndex = 0;
      _sheetElapsed = 0;
      final child = _spriteChild;
      if (child == null && createChild) {
        _spriteChild = SpriteComponent(
          sprite: _animation!.frames[_displayFrameIndex].sprite,
          autoResize: false,
          size: Vector2(asset.renderWidth, asset.renderHeight),
          position: Vector2.zero(),
          anchor: Anchor(asset.anchor.x, asset.anchor.y),
        )..paint.filterQuality = FilterQuality.none;
        add(_spriteChild!);
      } else if (child != null) {
        child.sprite = _animation!.frames[_displayFrameIndex].sprite;
        child.size.setValues(asset.renderWidth, asset.renderHeight);
        child.anchor = Anchor(asset.anchor.x, asset.anchor.y);
      }
      size.setValues(asset.renderWidth, asset.renderHeight);
      anchor = Anchor(asset.anchor.x, asset.anchor.y);
    } finally {
      _loadingAnimationKey = null;
    }
  }

  @override
  void update(double dt) {
    controller.update(dt);
    final resolved = controller.resolvedAnimation;
    if (resolved != null &&
        resolved.asset.animationKey != _loadedAnimationKey &&
        resolved.asset.animationKey != _loadingAnimationKey) {
      _loadAnimation(resolved.asset);
    }
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
      if (_usingSheetAnimation && animation.frames.isNotEmpty) {
        _sheetElapsed += dt;
        final stepTime = animation.frames[_sheetFrameIndex].stepTime;
        while (_sheetElapsed >= stepTime) {
          _sheetElapsed -= stepTime;
          _sheetFrameIndex = (_sheetFrameIndex + 1) % animation.frames.length;
        }
      } else {
        _sheetFrameIndex = controller.frameIndex;
      }
      child.sprite = animation.frames[_displayFrameIndex].sprite;
    }
    super.update(dt);
  }

  int get _displayFrameIndex =>
      _usingSheetAnimation ? _sheetFrameIndex : controller.frameIndex;
}
