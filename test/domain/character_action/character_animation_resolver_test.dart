import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/domain/character_action/character_animation_resolver.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';

CharacterAnimationAsset asset(
  CharacterAction action,
  CharacterDirection direction, {
  CharacterAssetKind kind = CharacterAssetKind.overworld,
}) {
  return CharacterAnimationAsset(
    characterId: 'guide',
    actionId: action.canonicalKey,
    direction: direction,
    assetKind: kind,
    assetPath: 'guide/${action.locomotion.name}.png',
    frameWidth: 16,
    frameHeight: 24,
    frameCount: 4,
    fps: 8,
    loop: true,
    anchor: const NormalizedAnchor(0.5, 1),
    renderWidth: 16,
    renderHeight: 24,
    directionAxis: CharacterDirectionAxis.row,
    sourceOrigin: PixelPoint.zero,
    padding: PixelPadding.zero,
    spacing: PixelSpacing.zero,
    animationKey: '${action.canonicalKey}/${direction.name}',
  );
}

void main() {
  final idle = CharacterAction();
  final walk = const CharacterAction(locomotion: CharacterLocomotion.walk);

  test('resolves exact character action and direction metadata', () {
    final resolver = CharacterAnimationResolver(
      CharacterAnimationManifest([
        asset(idle, CharacterDirection.front),
        asset(idle, CharacterDirection.left),
        asset(walk, CharacterDirection.front),
      ]),
    );

    final result = resolver.resolve('guide', walk, CharacterDirection.front);

    expect(result, isNotNull);
    expect(result!.characterId, 'guide');
    expect(result.action, walk);
    expect(result.direction, CharacterDirection.front);
    expect(result.assetPath, 'guide/walk.png');
    expect(result.frameCount, 4);
    expect(result.duration, 0.5);
    expect(result.animationKey, '${walk.canonicalKey}/front');
  });

  test('does not decompose unregistered action into partial descriptors', () {
    final combined = const CharacterAction(
      locomotion: CharacterLocomotion.run,
      special: 'guide.point',
    );
    final resolver = CharacterAnimationResolver(
      CharacterAnimationManifest([asset(combined, CharacterDirection.front)]),
    );

    expect(
      resolver.resolve(
        'guide',
        const CharacterAction(
          locomotion: CharacterLocomotion.run,
          special: 'guide.waveFlag',
        ),
        CharacterDirection.front,
      ),
      isNull,
    );
  });

  test('does not resolve semantic non-overworld assets', () {
    final resolver = CharacterAnimationResolver(
      CharacterAnimationManifest([
        asset(
          idle,
          CharacterDirection.front,
          kind: CharacterAssetKind.dialogue,
        ),
      ]),
    );

    expect(resolver.resolve('guide', idle, CharacterDirection.front), isNull);
  });
}
