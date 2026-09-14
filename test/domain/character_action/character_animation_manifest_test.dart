import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';

void main() {
  test('row layout calculates direction and frame origins', () {
    const asset = CharacterAnimationAsset(
      characterId: 'guide_male',
      actionId: 'walk',
      direction: CharacterDirection.front,
      assetKind: CharacterAssetKind.overworld,
      assetPath: 'guide_male/walk.png',
      frameWidth: 16,
      frameHeight: 24,
      frameCount: 3,
      fps: 8,
      loop: true,
      anchor: NormalizedAnchor(0.5, 1),
      renderWidth: 16,
      renderHeight: 24,
      directionAxis: CharacterDirectionAxis.row,
      sourceOrigin: PixelPoint(10, 20),
      padding: PixelPadding(1, 2, 3, 4),
      spacing: PixelSpacing(2, 5),
      animationKey: 'walk/front',
    );

    expect(asset.regionWidth, 56);
    expect(asset.regionHeight, 117);
    expect(
      asset.frameOrigin(CharacterDirection.front, 0),
      const PixelPoint(11, 22),
    );
    expect(
      asset.frameOrigin(CharacterDirection.back, 2),
      const PixelPoint(47, 80),
    );
  });

  test('column layout calculates direction and frame origins', () {
    const asset = CharacterAnimationAsset(
      characterId: 'guide_female',
      actionId: 'idle',
      direction: CharacterDirection.front,
      assetKind: CharacterAssetKind.overworld,
      assetPath: 'guide_female/idle.png',
      frameWidth: 20,
      frameHeight: 18,
      frameCount: 2,
      fps: 6,
      loop: true,
      anchor: NormalizedAnchor(0.5, 1),
      renderWidth: 20,
      renderHeight: 18,
      directionAxis: CharacterDirectionAxis.column,
      sourceOrigin: PixelPoint(4, 6),
      padding: PixelPadding(1, 2, 3, 4),
      spacing: PixelSpacing(2, 5),
      animationKey: 'idle/front',
    );

    expect(asset.regionWidth, 90);
    expect(asset.regionHeight, 47);
    expect(
      asset.frameOrigin(CharacterDirection.right, 1),
      const PixelPoint(71, 31),
    );
  });

  test('all value objects use structural equality', () {
    const first = NormalizedAnchor(0.5, 1);
    const second = NormalizedAnchor(0.5, 1);

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('frame origin rejects invalid frame index', () {
    const asset = CharacterAnimationAsset(
      characterId: 'guide_male',
      actionId: 'idle',
      direction: CharacterDirection.front,
      assetKind: CharacterAssetKind.overworld,
      assetPath: 'guide_male/idle.png',
      frameWidth: 16,
      frameHeight: 16,
      frameCount: 2,
      fps: 8,
      loop: true,
      anchor: NormalizedAnchor(0.5, 1),
      renderWidth: 16,
      renderHeight: 16,
      directionAxis: CharacterDirectionAxis.row,
      sourceOrigin: PixelPoint.zero,
      padding: PixelPadding.zero,
      spacing: PixelSpacing.zero,
      animationKey: 'idle/front',
    );

    expect(
      () => asset.frameOrigin(CharacterDirection.front, 2),
      throwsRangeError,
    );
  });
}
