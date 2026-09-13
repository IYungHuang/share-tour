import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/game/characters/guide_action_sheet_registry.dart';

void main() {
  test('registers row-four cells with stable, character-scoped IDs', () {
    expect(guideActionSheetRegistry, hasLength(4));
    expect(femaleGuideActionSheetRegistry, hasLength(4));

    final cells = [
      ...guideActionSheetRegistry,
      ...femaleGuideActionSheetRegistry,
    ];
    expect(cells.map((cell) => cell.cellId).toSet(), hasLength(8));
    expect(
      cells.every((cell) => cell.cellId.startsWith('${cell.characterId}_')),
      isTrue,
    );
    expect(cells.every((cell) => cell.loop == false), isTrue);
    expect(cells.every((cell) => cell.semanticCandidates.isNotEmpty), isTrue);
  });

  test('keeps candidate semantics separate from stable cell IDs', () {
    final maleC1 = guideActionSheetRegistry[0];
    final maleC3 = guideActionSheetRegistry[2];

    expect(maleC1.cellId, 'guide_action_r4_c1');
    expect(maleC1.observationalTags, contains('arm_extended_left'));
    expect(maleC1.semanticCandidates, contains('directional_gesture'));
    expect(maleC3.cellId, 'guide_action_r4_c3');
    expect(maleC3.observationalTags, contains('hand_near_face'));
    expect(maleC3.semanticCandidates, contains('attention_gesture'));
    expect(maleC3.semanticCandidates, contains('greeting_gesture'));
  });

  test('uses explicit grid origins for generated sheets', () {
    expect(
      guideActionSheetRegistry.first.sourceOrigin,
      const PixelPoint(0, 947),
    );
    expect(
      femaleGuideActionSheetRegistry.first.sourceOrigin,
      const PixelPoint(0, 947),
    );
    expect(
      guideActionSheetRegistry.last.sourceOrigin,
      const PixelPoint(934, 947),
    );
    expect(
      femaleGuideActionSheetRegistry.last.sourceOrigin,
      const PixelPoint(934, 947),
    );
  });
}
