import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/game/characters/guide_action_sheet_registry.dart';

void main() {
  test('maps walk and run to four-frame non-directional sequences', () {
    final walk = actionSheetAnimationFor(
      'guide',
      const CharacterAction(locomotion: CharacterLocomotion.walk),
    );
    final run = actionSheetAnimationFor(
      'guide',
      const CharacterAction(locomotion: CharacterLocomotion.run),
    );

    expect(walk, isNotNull);
    expect(walk!.cells, hasLength(4));
    expect(walk.cells.first.cellId, 'guide_action_r2_c1');
    expect(run!.cells, hasLength(4));
    expect(run.cells.first.cellId, 'guide_action_r3_c1');
    expect(run.loop, isTrue);
  });

  test('does not map idle or special actions to locomotion cycles', () {
    expect(actionSheetAnimationFor('guide', const CharacterAction()), isNull);
    expect(
      actionSheetAnimationFor(
        'guide',
        const CharacterAction(activity: CharacterActivity.eat),
      ),
      isNull,
    );
  });
}
