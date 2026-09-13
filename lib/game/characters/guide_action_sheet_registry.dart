import '../../domain/character_action/character_action.dart';
import '../../domain/character_action/character_animation_manifest.dart';

class CharacterActionSheetCell {
  const CharacterActionSheetCell({
    required this.characterId,
    required this.cellId,
    required this.assetPath,
    required this.sourceOrigin,
    required this.frameWidth,
    required this.frameHeight,
    required this.renderWidth,
    required this.renderHeight,
    required this.observationalTags,
    required this.semanticCandidates,
    this.fps = 8,
    this.loop = false,
  });

  final String characterId;
  final String cellId;
  final String assetPath;
  final PixelPoint sourceOrigin;
  final int frameWidth;
  final int frameHeight;
  final double renderWidth;
  final double renderHeight;
  final List<String> observationalTags;
  final List<String> semanticCandidates;
  final double fps;
  final bool loop;
}

class CharacterActionSheetAnimation {
  const CharacterActionSheetAnimation({
    required this.characterId,
    required this.animationId,
    required this.cells,
    required this.fps,
    this.loop = true,
  });

  final String characterId;
  final String animationId;
  final List<CharacterActionSheetCell> cells;
  final double fps;
  final bool loop;
}

const _malePath = 'guide_action_sheet_v1_generated.png';
const _femalePath = 'guide_female_action_sheet_v1_generated.png';

const guideActionSheetRegistry = <CharacterActionSheetCell>[
  CharacterActionSheetCell(
    characterId: 'guide',
    cellId: 'guide_action_r4_c1',
    assetPath: _malePath,
    sourceOrigin: PixelPoint(0, 947),
    frameWidth: 311,
    frameHeight: 315,
    renderWidth: 24,
    renderHeight: 24,
    observationalTags: ['arm_extended_left', 'standing_pose'],
    semanticCandidates: ['directional_gesture'],
  ),
  CharacterActionSheetCell(
    characterId: 'guide',
    cellId: 'guide_action_r4_c2',
    assetPath: _malePath,
    sourceOrigin: PixelPoint(311, 947),
    frameWidth: 312,
    frameHeight: 315,
    renderWidth: 24,
    renderHeight: 24,
    observationalTags: ['arm_extended_right', 'standing_pose'],
    semanticCandidates: ['directional_gesture'],
  ),
  CharacterActionSheetCell(
    characterId: 'guide',
    cellId: 'guide_action_r4_c3',
    assetPath: _malePath,
    sourceOrigin: PixelPoint(623, 947),
    frameWidth: 311,
    frameHeight: 315,
    renderWidth: 24,
    renderHeight: 24,
    observationalTags: ['hand_near_face', 'standing_pose'],
    semanticCandidates: ['attention_gesture', 'greeting_gesture'],
  ),
  CharacterActionSheetCell(
    characterId: 'guide',
    cellId: 'guide_action_r4_c4',
    assetPath: _malePath,
    sourceOrigin: PixelPoint(934, 947),
    frameWidth: 312,
    frameHeight: 315,
    renderWidth: 24,
    renderHeight: 24,
    observationalTags: ['arms_raised', 'confetti_effect'],
    semanticCandidates: ['celebration_gesture'],
  ),
];

const femaleGuideActionSheetRegistry = <CharacterActionSheetCell>[
  CharacterActionSheetCell(
    characterId: 'guide_female',
    cellId: 'guide_female_action_r4_c1',
    assetPath: _femalePath,
    sourceOrigin: PixelPoint(0, 947),
    frameWidth: 311,
    frameHeight: 316,
    renderWidth: 24,
    renderHeight: 24,
    observationalTags: ['flag_raised', 'confetti_effect'],
    semanticCandidates: ['celebration_gesture'],
  ),
  CharacterActionSheetCell(
    characterId: 'guide_female',
    cellId: 'guide_female_action_r4_c2',
    assetPath: _femalePath,
    sourceOrigin: PixelPoint(311, 947),
    frameWidth: 312,
    frameHeight: 316,
    renderWidth: 24,
    renderHeight: 24,
    observationalTags: ['arm_extended_right', 'standing_pose'],
    semanticCandidates: ['directional_gesture'],
  ),
  CharacterActionSheetCell(
    characterId: 'guide_female',
    cellId: 'guide_female_action_r4_c3',
    assetPath: _femalePath,
    sourceOrigin: PixelPoint(623, 947),
    frameWidth: 311,
    frameHeight: 316,
    renderWidth: 24,
    renderHeight: 24,
    observationalTags: ['flag_held_front', 'confetti_effect'],
    semanticCandidates: ['celebration_gesture', 'flag_pose'],
  ),
  CharacterActionSheetCell(
    characterId: 'guide_female',
    cellId: 'guide_female_action_r4_c4',
    assetPath: _femalePath,
    sourceOrigin: PixelPoint(934, 947),
    frameWidth: 312,
    frameHeight: 316,
    renderWidth: 24,
    renderHeight: 24,
    observationalTags: ['one_leg_raised', 'fist_raised'],
    semanticCandidates: ['victory_gesture', 'celebration_gesture'],
  ),
];

final guideActionSheetAnimations = <CharacterActionSheetAnimation>[
  _makeAnimation('guide', _malePath, 'walk', 315, 'walk_cycle'),
  _makeAnimation('guide', _malePath, 'run', 631, 'run_cycle'),
];

final femaleGuideActionSheetAnimations = <CharacterActionSheetAnimation>[
  _makeAnimation('guide_female', _femalePath, 'walk', 315, 'walk_cycle'),
  _makeAnimation('guide_female', _femalePath, 'run', 631, 'run_cycle'),
];

CharacterActionSheetAnimation _makeAnimation(
  String characterId,
  String assetPath,
  String animationId,
  int y,
  String semanticCandidate,
) {
  const origins = [0, 311, 623, 934];
  const widths = [311, 312, 311, 312];
  return CharacterActionSheetAnimation(
    characterId: characterId,
    animationId: animationId,
    cells: [
      for (var index = 0; index < origins.length; index++)
        CharacterActionSheetCell(
          characterId: characterId,
          cellId: '${characterId}_action_r${y == 315 ? 2 : 3}_c${index + 1}',
          assetPath: assetPath,
          sourceOrigin: PixelPoint(origins[index], y),
          frameWidth: widths[index],
          frameHeight: characterId == 'guide' && y == 315 ? 315 : 316,
          renderWidth: 24,
          renderHeight: 24,
          observationalTags: [semanticCandidate],
          semanticCandidates: [semanticCandidate],
        ),
    ],
    fps: 8,
  );
}

CharacterActionSheetAnimation? actionSheetAnimationFor(
  String characterId,
  CharacterAction action,
) {
  final animations = characterId == 'guide'
      ? guideActionSheetAnimations
      : femaleGuideActionSheetAnimations;
  final animationId = switch (action.locomotion) {
    CharacterLocomotion.walk => 'walk',
    CharacterLocomotion.run => 'run',
    CharacterLocomotion.idle ||
    CharacterLocomotion.dash ||
    CharacterLocomotion.jump => null,
  };
  if (animationId == null) return null;
  for (final animation in animations) {
    if (animation.animationId == animationId) return animation;
  }
  return null;
}
