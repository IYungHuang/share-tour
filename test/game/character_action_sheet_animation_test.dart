import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';
import 'package:share_tour/game/characters/guide_action_sheet_registry.dart';

void main() {
  test('maps walk and run to four-frame directional sequences', () {
    final walk = actionSheetAnimationFor(
      'guide',
      const CharacterAction(locomotion: CharacterLocomotion.walk),
      CharacterDirection.front,
    );
    final run = actionSheetAnimationFor(
      'guide',
      const CharacterAction(locomotion: CharacterLocomotion.run),
      CharacterDirection.front,
    );

    expect(walk, isNotNull);
    expect(walk!.cells, hasLength(4));
    expect(walk.cells.first.cellId, 'guide_walk_front_f1');
    expect(run!.cells, hasLength(4));
    expect(run.cells.first.cellId, 'guide_run_front_f1');
    expect(run.loop, isTrue);
  });

  test('does not map idle or special actions to locomotion cycles', () {
    expect(
      actionSheetAnimationFor(
        'guide',
        const CharacterAction(),
        CharacterDirection.front,
      ),
      isNull,
    );
    expect(
      actionSheetAnimationFor(
        'guide',
        const CharacterAction(activity: CharacterActivity.eat),
        CharacterDirection.front,
      ),
      isNull,
    );
  });

  test('selects distinct rows for all four directions', () {
    final rows = [
      for (final direction in CharacterDirection.values)
        actionSheetAnimationFor(
          'guide',
          const CharacterAction(locomotion: CharacterLocomotion.run),
          direction,
        )!.cells.first.sourceOrigin.y,
    ];

    expect(rows, [888, 1110, 1332, 1554]);
  });
}
