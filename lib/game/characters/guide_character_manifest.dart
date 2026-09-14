import '../../domain/character_action/character_action.dart';
import '../../domain/character_action/character_animation_manifest.dart';
import '../../domain/character_action/character_direction.dart';

final guideCharacterManifest = _makeManifest(
  'guide',
  'guide_overworld_sheet_v1_generated.png',
);

final femaleGuideCharacterManifest = _makeManifest(
  'guide_female',
  'guide_female_overworld_sheet_v3_generated.png',
);

CharacterAnimationManifest characterManifestFor(String characterId) {
  return switch (characterId) {
    'guide' => guideCharacterManifest,
    'guide_female' => femaleGuideCharacterManifest,
    _ => throw ArgumentError('Unknown character id: $characterId'),
  };
}

final _actions = [
  const CharacterAction(),
  const CharacterAction(locomotion: CharacterLocomotion.walk),
  const CharacterAction(locomotion: CharacterLocomotion.run),
];

CharacterAnimationManifest _makeManifest(String characterId, String assetPath) {
  return CharacterAnimationManifest([
    for (var actionIndex = 0; actionIndex < _actions.length; actionIndex++)
      for (final direction in CharacterDirection.values)
        CharacterAnimationAsset(
          characterId: characterId,
          actionId: _actions[actionIndex].canonicalKey,
          direction: direction,
          assetKind: CharacterAssetKind.overworld,
          assetPath: assetPath,
          frameWidth: 362,
          frameHeight: 362,
          frameCount: 1,
          playbackFrameCount:
              _actions[actionIndex].locomotion == CharacterLocomotion.idle
              ? null
              : 4,
          fps: 8,
          loop: true,
          anchor: const NormalizedAnchor(0.5, 1),
          renderWidth: 24,
          renderHeight: 24,
          directionAxis: CharacterDirectionAxis.column,
          sourceOrigin: PixelPoint(0, actionIndex * 362),
          padding: PixelPadding.zero,
          spacing: PixelSpacing.zero,
          animationKey:
              '$characterId.${_actions[actionIndex].locomotion.name}.${direction.name}',
        ),
  ]);
}
