import 'character_action.dart';
import 'character_action_descriptor.dart';
import 'character_animation_resolver.dart';
import 'character_direction.dart';

class CharacterActionResumeState {
  const CharacterActionResumeState({
    required this.action,
    required this.direction,
    required this.normalizedProgress,
  });

  final CharacterAction action;
  final CharacterDirection direction;
  final double normalizedProgress;
}

class CharacterActionState {
  const CharacterActionState({
    required this.action,
    required this.direction,
    required this.descriptor,
    required this.resolvedAnimation,
    required this.elapsed,
    required this.frameIndex,
    required this.isCompleted,
  });

  final CharacterAction action;
  final CharacterDirection direction;
  final CharacterActionDescriptor descriptor;
  final ResolvedCharacterAnimation? resolvedAnimation;
  final double elapsed;
  final int frameIndex;
  final bool isCompleted;

  double get normalizedProgress {
    final animation = resolvedAnimation;
    if (animation == null || animation.duration <= 0) {
      return 0;
    }
    if (descriptor.loop) {
      return (elapsed / animation.duration).clamp(0.0, 1.0);
    }
    return (elapsed / animation.duration).clamp(0.0, 1.0);
  }
}
