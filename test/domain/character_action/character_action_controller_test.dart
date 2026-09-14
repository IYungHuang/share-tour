import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/domain/character_action/character_action_controller.dart';
import 'package:share_tour/domain/character_action/character_action_descriptor.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/domain/character_action/character_animation_resolver.dart';
import 'package:share_tour/domain/character_action/character_capability_registry.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';

List<CharacterAnimationAsset> assetsFor(
  CharacterAction action, {
  int frameCount = 4,
  double fps = 4,
}) {
  return CharacterDirection.values.map((direction) {
    return CharacterAnimationAsset(
      characterId: 'guide',
      actionId: action.canonicalKey,
      direction: direction,
      assetKind: CharacterAssetKind.overworld,
      assetPath: 'guide/${action.canonicalKey}.png',
      frameWidth: 1,
      frameHeight: 1,
      frameCount: frameCount,
      fps: fps,
      loop:
          action.locomotion != CharacterLocomotion.dash &&
          action.locomotion != CharacterLocomotion.jump &&
          action.activity != CharacterActivity.eat &&
          action.activity != CharacterActivity.drink,
      anchor: const NormalizedAnchor(0.5, 1),
      renderWidth: 16,
      renderHeight: 24,
      directionAxis: CharacterDirectionAxis.row,
      sourceOrigin: PixelPoint.zero,
      padding: PixelPadding.zero,
      spacing: PixelSpacing.zero,
      animationKey: '${action.canonicalKey}/${direction.name}',
    );
  }).toList();
}

CharacterActionController makeController() {
  const idle = CharacterAction();
  final walk = const CharacterAction(locomotion: CharacterLocomotion.walk);
  final run = const CharacterAction(locomotion: CharacterLocomotion.run);
  final dash = const CharacterAction(locomotion: CharacterLocomotion.dash);
  final jump = const CharacterAction(locomotion: CharacterLocomotion.jump);
  final sleep = const CharacterAction(activity: CharacterActivity.sleep);
  final eat = const CharacterAction(activity: CharacterActivity.eat);
  final drink = const CharacterAction(activity: CharacterActivity.drink);
  const point = CharacterAction(special: 'guide.point');
  const samePriority = CharacterAction(special: 'guide.samePriority');

  final descriptors = CharacterActionDescriptorRegistry([
    ...CharacterActionDescriptorRegistry.standard().values,
    const CharacterActionDescriptor(
      action: point,
      loop: false,
      priority: 80,
      canInterrupt: true,
      fallbackAction: idle,
      animationKey: 'guide.point',
    ),
    const CharacterActionDescriptor(
      action: samePriority,
      loop: false,
      priority: 50,
      canInterrupt: true,
      fallbackAction: idle,
      animationKey: 'guide.samePriority',
    ),
  ]);
  final manifest = CharacterAnimationManifest([
    ...assetsFor(idle),
    ...assetsFor(walk),
    ...assetsFor(run),
    ...assetsFor(dash),
    ...assetsFor(jump),
    ...assetsFor(sleep),
    ...assetsFor(eat),
    ...assetsFor(drink),
    ...assetsFor(point),
    ...assetsFor(samePriority),
  ]);

  return CharacterActionController(
    characterId: 'guide',
    descriptors: descriptors,
    resolver: CharacterAnimationResolver(manifest),
    capabilities: CharacterCapabilityRegistry({
      'guide': {'guide.point'},
    }),
  );
}

void main() {
  test('loop frame uses manifest duration and wraps after one duration', () {
    final controller = makeController();
    final walk = const CharacterAction(locomotion: CharacterLocomotion.walk);

    controller.play(walk);
    expect(controller.frameIndex, 0);
    controller.update(0.26);
    expect(controller.frameIndex, 1);
    controller.update(0.74);
    expect(controller.action, walk);
    expect(controller.frameIndex, 0);
    expect(controller.isCompleted, isFalse);
  });

  test('same action does not reset playback frame', () {
    final controller = makeController();
    final walk = const CharacterAction(locomotion: CharacterLocomotion.walk);

    controller.play(walk);
    controller.update(0.25);
    controller.play(walk);
    controller.update(0.25);

    expect(controller.frameIndex, 2);
  });

  test('direction change keeps normalized playback progress', () {
    final controller = makeController();
    final walk = const CharacterAction(locomotion: CharacterLocomotion.walk);

    controller.play(walk);
    controller.update(0.375);
    controller.setDirection(CharacterDirection.left);

    expect(controller.direction, CharacterDirection.left);
    expect(controller.normalizedProgress, closeTo(0.375, 0.0001));
    expect(controller.frameIndex, 1);
  });

  test(
    'non-interruptible sleep rejects walk but higher priority jump wins',
    () {
      final controller = makeController();
      final sleep = const CharacterAction(activity: CharacterActivity.sleep);
      final walk = const CharacterAction(locomotion: CharacterLocomotion.walk);
      final jump = const CharacterAction(locomotion: CharacterLocomotion.jump);

      controller.play(sleep);
      expect(controller.play(walk), isFalse);
      expect(controller.action, sleep);
      expect(controller.play(jump), isTrue);
      expect(controller.action, jump);
    },
  );

  test('same-priority special cannot bypass non-interruptible action', () {
    final controller = makeController();
    final sleep = const CharacterAction(activity: CharacterActivity.sleep);
    final samePriority = const CharacterAction(special: 'guide.samePriority');

    controller.play(sleep);
    expect(controller.play(samePriority), isFalse);
    expect(controller.action, sleep);
  });

  test('same-priority eat replaces interruptible drink', () {
    final controller = makeController();
    final drink = const CharacterAction(activity: CharacterActivity.drink);
    final eat = const CharacterAction(activity: CharacterActivity.eat);

    controller.play(drink);
    expect(controller.play(eat), isTrue);
    expect(controller.action, eat);
  });

  test('walk dash jump restores one resume snapshot after jump completes', () {
    final controller = makeController();
    final walk = const CharacterAction(locomotion: CharacterLocomotion.walk);
    final dash = const CharacterAction(locomotion: CharacterLocomotion.dash);
    final jump = const CharacterAction(locomotion: CharacterLocomotion.jump);

    controller.play(walk);
    controller.update(0.25);
    controller.play(dash);
    expect(controller.play(jump), isTrue);
    controller.update(1);

    expect(controller.action, walk);
    expect(controller.normalizedProgress, closeTo(0.25, 0.0001));
    expect(controller.frameIndex, 1);
  });

  test('completed one-shot falls back to idle when no resume exists', () {
    final controller = makeController();
    final jump = const CharacterAction(locomotion: CharacterLocomotion.jump);

    controller.play(jump);
    controller.update(1);

    expect(controller.action, const CharacterAction());
    expect(controller.isCompleted, isFalse);
  });

  test('stop clears resume state before next one-shot', () {
    final controller = makeController();
    final walk = const CharacterAction(locomotion: CharacterLocomotion.walk);
    final dash = const CharacterAction(locomotion: CharacterLocomotion.dash);
    final jump = const CharacterAction(locomotion: CharacterLocomotion.jump);

    controller.play(walk);
    controller.play(dash);
    controller.stop();
    controller.play(jump);
    controller.update(1);

    expect(controller.action, const CharacterAction());
  });

  test('unregistered action uses idle instead of partial fallback', () {
    final controller = makeController();
    final unregistered = const CharacterAction(
      locomotion: CharacterLocomotion.run,
      special: 'guide.unknown',
    );

    expect(controller.play(unregistered), isTrue);
    expect(controller.action, const CharacterAction());
  });
}
