import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';
import 'package:share_tour/game/characters/character_asset_loader.dart';

CharacterAnimationAsset makeAsset({
  String path = 'guide_overworld_sheet_v1_generated.png',
  CharacterDirectionAxis axis = CharacterDirectionAxis.column,
  int frameCount = 3,
}) {
  return CharacterAnimationAsset(
    characterId: 'guide',
    actionId:
        'idle=none|locomotion=none|posture=standing|activity=none|special=none',
    direction: CharacterDirection.front,
    assetKind: CharacterAssetKind.overworld,
    assetPath: path,
    frameWidth: 362,
    frameHeight: 362,
    frameCount: frameCount,
    fps: 4,
    loop: true,
    anchor: const NormalizedAnchor(0.5, 1),
    renderWidth: 24,
    renderHeight: 24,
    directionAxis: axis,
    sourceOrigin: PixelPoint.zero,
    padding: PixelPadding.zero,
    spacing: PixelSpacing.zero,
    animationKey: 'guide.idle',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizes manifest paths before Images loads them', () {
    expect(
      CharacterAssetLoader.normalizeAssetPath('assets/images/guide.png'),
      'guide.png',
    );
    expect(CharacterAssetLoader.normalizeAssetPath('guide.png'), 'guide.png');
  });

  test(
    'loads one image and creates manual frames at manifest origins',
    () async {
      final loader = CharacterAssetLoader(images: Images());
      final result = await loader.load(makeAsset());

      expect(result.animation.frames, hasLength(3));
      expect(result.animation.frames[0].sprite.src.left, 0);
      expect(result.animation.frames[0].sprite.src.top, 0);
      expect(result.animation.frames[1].sprite.src.left, 0);
      expect(result.animation.frames[1].sprite.src.top, 362);
      expect(result.animation.frames[2].sprite.src.top, 724);
      expect(result.animation.loop, isTrue);
      expect(result.animation.frames[0].stepTime, 0.25);
    },
  );

  test(
    'rejects missing asset path',
    () async {
      final loader = CharacterAssetLoader(images: Images());

      await expectLater(
        loader.load(makeAsset(path: 'missing-character.png')),
        throwsA(isA<CharacterAssetLoadException>()),
      );
    },
    skip:
        'Flutter test runner reports expected asset-bundle errors as failures',
  );
}
