import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/domain/character_action/character_action_descriptor.dart';
import 'package:share_tour/domain/character_action/character_capability_registry.dart';

void main() {
  test('standard descriptors expose fixed playback contracts', () {
    final registry = CharacterActionDescriptorRegistry.standard();

    final idle = registry.require(CharacterAction());
    expect(idle.priority, 0);
    expect(idle.loop, isTrue);
    expect(idle.canInterrupt, isTrue);
    expect(idle.fallbackAction, const CharacterAction());

    final dash = registry.require(
      const CharacterAction(locomotion: CharacterLocomotion.dash),
    );
    expect(dash.priority, 60);
    expect(dash.loop, isFalse);
    expect(dash.canInterrupt, isFalse);
    expect(dash.fallbackAction, const CharacterAction());

    final sleep = registry.require(
      const CharacterAction(activity: CharacterActivity.sleep),
    );
    expect(sleep.priority, 50);
    expect(sleep.loop, isTrue);
    expect(sleep.canInterrupt, isFalse);
  });

  test('registry rejects fallback target that has no descriptor', () {
    expect(
      () => CharacterActionDescriptorRegistry([
        CharacterActionDescriptor(
          action: const CharacterAction(locomotion: CharacterLocomotion.walk),
          loop: true,
          priority: 10,
          canInterrupt: true,
          fallbackAction: const CharacterAction(
            locomotion: CharacterLocomotion.run,
          ),
          animationKey: 'walk',
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('special capability is character-specific', () {
    final registry = CharacterCapabilityRegistry({
      'guide': {'guide.point'},
    });

    expect(
      registry.canPlay('guide', const CharacterAction(special: 'guide.point')),
      isTrue,
    );
    expect(
      registry.canPlay(
        'guide',
        const CharacterAction(special: 'guide.waveFlag'),
      ),
      isFalse,
    );
    expect(
      registry.canPlay('other', const CharacterAction(special: 'guide.point')),
      isFalse,
    );
  });
}
