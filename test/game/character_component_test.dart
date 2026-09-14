import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/domain/character_action/character_action_controller.dart';
import 'package:share_tour/domain/character_action/character_action_descriptor.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/domain/character_action/character_animation_resolver.dart';
import 'package:share_tour/domain/character_action/character_capability_registry.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';
import 'package:share_tour/game/characters/character_asset_loader.dart';
import 'package:share_tour/game/components/character_component.dart';

CharacterAnimationAsset makeAsset(CharacterDirection direction) {
  return CharacterAnimationAsset(
    characterId: 'guide',
    actionId: const CharacterAction().canonicalKey,
    direction: direction,
    assetKind: CharacterAssetKind.overworld,
    assetPath: 'guide_overworld_sheet_v1_generated.png',
    frameWidth: 362,
    frameHeight: 362,
    frameCount: 3,
    fps: 4,
    loop: true,
    anchor: const NormalizedAnchor(0.5, 1),
    renderWidth: 24,
    renderHeight: 24,
    directionAxis: CharacterDirectionAxis.column,
    sourceOrigin: PixelPoint.zero,
    padding: PixelPadding.zero,
    spacing: PixelSpacing.zero,
    animationKey: 'guide.idle',
  );
}

CharacterActionController makeController() {
  final manifest = CharacterAnimationManifest(
    CharacterDirection.values.map(makeAsset),
  );
  return CharacterActionController(
    characterId: 'guide',
    descriptors: CharacterActionDescriptorRegistry.standard(),
    resolver: CharacterAnimationResolver(manifest),
    capabilities: CharacterCapabilityRegistry(const {}),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads sprite child with logical size and normalized anchor', () async {
    final component = CharacterComponent(
      controller: makeController(),
      loader: CharacterAssetLoader(images: Images()),
      position: Vector2(10, 20),
    );

    await component.onLoad();

    expect(component.spriteChild, isNotNull);
    expect(component.spriteChild!.position, Vector2.zero());
    expect(component.spriteChild!.size, Vector2.all(24));
    expect(component.spriteChild!.anchor, Anchor.bottomCenter);
    expect(component.spriteChild!.paint.filterQuality, FilterQuality.none);
  });

  test(
    'uses controller frame index without a second animation ticker',
    () async {
      final controller = makeController();
      final component = CharacterComponent(
        controller: controller,
        loader: CharacterAssetLoader(images: Images()),
      );
      await component.onLoad();

      component.update(0.3);

      expect(controller.frameIndex, 1);
      expect(component.spriteChild!.sprite!.src.top, 362);
      expect(component.animationTicker, isNull);
    },
  );

  test('direction change preserves visual playback progress', () async {
    final controller = makeController();
    final component = CharacterComponent(
      controller: controller,
      loader: CharacterAssetLoader(images: Images()),
    );
    await component.onLoad();
    component.update(0.3);

    controller.setDirection(CharacterDirection.right);
    component.update(0);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.frameIndex, 1);
    expect(component.spriteChild!.sprite!.src.top, 362);
  });
}
