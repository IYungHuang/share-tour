import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_action_controller.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/domain/character_action/character_action_descriptor.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/domain/character_action/character_animation_resolver.dart';
import 'package:share_tour/domain/character_action/character_capability_registry.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';
import 'package:share_tour/game/characters/character_asset_loader.dart';
import 'package:share_tour/game/characters/guide_action_sheet_registry.dart';
import 'package:share_tour/game/characters/guide_character_manifest.dart';
import 'package:share_tour/game/components/character_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads action cell sprite from explicit source rectangle', () async {
    final cell = guideActionSheetRegistry.first;
    final sprite = await CharacterAssetLoader(images: Images()).loadCell(cell);

    expect(sprite.src.left, cell.sourceOrigin.x);
    expect(sprite.src.top, cell.sourceOrigin.y);
    expect(sprite.src.width, cell.frameWidth);
    expect(sprite.src.height, cell.frameHeight);
  });

  test(
    'plays one-shot action cell, then returns to controller animation',
    () async {
      final manifest = CharacterAnimationManifest(
        CharacterDirection.values.map(
          (direction) => CharacterAnimationAsset(
            characterId: 'guide',
            actionId: const CharacterAction().canonicalKey,
            direction: direction,
            assetKind: CharacterAssetKind.overworld,
            assetPath: 'guide_overworld_sheet_v1_generated.png',
            frameWidth: 362,
            frameHeight: 362,
            frameCount: 1,
            fps: 8,
            loop: true,
            anchor: const NormalizedAnchor(0.5, 1),
            renderWidth: 24,
            renderHeight: 24,
            directionAxis: CharacterDirectionAxis.column,
            sourceOrigin: PixelPoint.zero,
            padding: PixelPadding.zero,
            spacing: PixelSpacing.zero,
            animationKey: 'guide.idle.${direction.name}',
          ),
        ),
      );
      final component = CharacterComponent(
        controller: CharacterActionController(
          characterId: 'guide',
          descriptors: CharacterActionDescriptorRegistry.standard(),
          resolver: CharacterAnimationResolver(manifest),
          capabilities: CharacterCapabilityRegistry(const {}),
        ),
        loader: CharacterAssetLoader(images: Images()),
      );

      await component.onLoad();
      expect(component.spriteChild, isNotNull);
      await component.playCell(guideActionSheetRegistry.last);
      expect(component.activeCell, isNotNull);
      expect(component.spriteChild!.sprite, isNotNull);
      expect(component.spriteChild!.sprite!.src.left, 934);

      component.update(0.2);
      expect(component.activeCell, isNull);
      expect(component.spriteChild!.sprite!.src.width, 362);
    },
  );

  test('reloads sprite sheet when controller changes to run', () async {
    final controller = CharacterActionController(
      characterId: 'guide',
      descriptors: CharacterActionDescriptorRegistry.standard(),
      resolver: CharacterAnimationResolver(guideCharacterManifest),
      capabilities: CharacterCapabilityRegistry(const {}),
    );
    final component = CharacterComponent(
      controller: controller,
      loader: CharacterAssetLoader(images: Images()),
    );

    await component.onLoad();
    expect(component.spriteChild!.sprite!.src.top, 0);
    expect(
      controller.play(
        const CharacterAction(locomotion: CharacterLocomotion.run),
      ),
      isTrue,
    );
    component.update(0.01);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(component.spriteChild!.sprite!.src.top, 724);
  });
}
