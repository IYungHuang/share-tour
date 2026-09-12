import 'character_action.dart';
import 'character_animation_manifest.dart';
import 'character_direction.dart';

class ResolvedCharacterAnimation {
  const ResolvedCharacterAnimation({
    required this.characterId,
    required this.action,
    required this.direction,
    required this.asset,
  });

  final String characterId;
  final CharacterAction action;
  final CharacterDirection direction;
  final CharacterAnimationAsset asset;

  String get assetPath => asset.assetPath;
  int get frameWidth => asset.frameWidth;
  int get frameHeight => asset.frameHeight;
  int get frameCount => asset.frameCount;
  double get fps => asset.fps;
  bool get loop => asset.loop;
  NormalizedAnchor get anchor => asset.anchor;
  double get renderWidth => asset.renderWidth;
  double get renderHeight => asset.renderHeight;
  CharacterDirectionAxis get directionAxis => asset.directionAxis;
  PixelPoint get sourceOrigin => asset.sourceOrigin;
  String get animationKey => asset.animationKey;
  double get duration => frameCount / fps;
}

class CharacterAnimationResolver {
  CharacterAnimationResolver(CharacterAnimationManifest manifest)
    : _assets = manifest.assets;

  final List<CharacterAnimationAsset> _assets;

  /// Resolves one exact validated manifest record.
  ///
  /// Fallback selection belongs to the action controller/catalog. Keeping this
  /// lookup exact prevents a missing combination from silently becoming one of
  /// its partial channels.
  ResolvedCharacterAnimation? resolve(
    String characterId,
    CharacterAction action,
    CharacterDirection direction,
  ) {
    for (final asset in _assets) {
      if (asset.characterId == characterId &&
          asset.actionId == action.canonicalKey &&
          asset.direction == direction &&
          asset.assetKind == CharacterAssetKind.overworld) {
        return ResolvedCharacterAnimation(
          characterId: characterId,
          action: action,
          direction: direction,
          asset: asset,
        );
      }
    }
    return null;
  }
}
