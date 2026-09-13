import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../domain/character_action/character_animation_manifest.dart';
import 'guide_action_sheet_registry.dart';

class LoadedCharacterAnimation {
  const LoadedCharacterAnimation({
    required this.animation,
    required this.asset,
  });

  final SpriteAnimation animation;
  final CharacterAnimationAsset asset;
}

class CharacterAssetLoadException implements Exception {
  const CharacterAssetLoadException(this.assetPath, this.cause);

  final String assetPath;
  final Object cause;

  @override
  String toString() => 'Unable to load character asset "$assetPath": $cause';
}

/// Loads one validated sheet and builds frames without using Flame's ticker.
class CharacterAssetLoader {
  CharacterAssetLoader({Images? images}) : _images = images ?? Images();

  final Images _images;

  static String normalizeAssetPath(String path) {
    const prefix = 'assets/images/';
    return path.startsWith(prefix) ? path.substring(prefix.length) : path;
  }

  Future<LoadedCharacterAnimation> load(CharacterAnimationAsset asset) async {
    final path = normalizeAssetPath(asset.assetPath);
    late final ui.Image image;
    try {
      image = await _images.load(path);
    } catch (error) {
      throw CharacterAssetLoadException(asset.assetPath, error);
    }
    final stepTime = 1 / asset.fps;
    final sprites = [
      for (var index = 0; index < asset.frameCount; index++)
        Sprite(
          image,
          srcPosition: Vector2(
            asset.frameOrigin(asset.direction, index).x.toDouble(),
            asset.frameOrigin(asset.direction, index).y.toDouble(),
          ),
          srcSize: Vector2(
            asset.frameWidth.toDouble(),
            asset.frameHeight.toDouble(),
          ),
        ),
    ];
    return LoadedCharacterAnimation(
      animation: SpriteAnimation.spriteList(
        sprites,
        stepTime: stepTime,
        loop: asset.loop,
      ),
      asset: asset,
    );
  }

  Future<Sprite> loadCell(CharacterActionSheetCell cell) async {
    final path = normalizeAssetPath(cell.assetPath);
    late final ui.Image image;
    try {
      image = await _images.load(path);
    } catch (error) {
      throw CharacterAssetLoadException(cell.assetPath, error);
    }
    return Sprite(
      image,
      srcPosition: Vector2(
        cell.sourceOrigin.x.toDouble(),
        cell.sourceOrigin.y.toDouble(),
      ),
      srcSize: Vector2(cell.frameWidth.toDouble(), cell.frameHeight.toDouble()),
    );
  }
}
