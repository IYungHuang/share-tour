import 'character_action.dart';
import 'character_action_descriptor.dart';
import 'character_action_state.dart';
import 'character_animation_resolver.dart';
import 'character_capability_registry.dart';
import 'character_direction.dart';

class CharacterActionController {
  CharacterActionController({
    required this.characterId,
    required this.descriptors,
    required this.resolver,
    required this.capabilities,
    CharacterAction initialAction = const CharacterAction(),
    CharacterDirection initialDirection = CharacterDirection.front,
  }) {
    final initial = _resolve(initialAction, initialDirection);
    _state = _stateFor(initial, initialDirection, progress: 0);
  }

  final String characterId;
  final CharacterActionDescriptorRegistry descriptors;
  final CharacterAnimationResolver resolver;
  final CharacterCapabilityRegistry capabilities;

  late CharacterActionState _state;
  CharacterActionResumeState? _resumeState;

  CharacterActionState get state => _state;
  CharacterAction get action => _state.action;
  CharacterDirection get direction => _state.direction;
  int get frameIndex => _state.frameIndex;
  double get normalizedProgress => _state.normalizedProgress;
  bool get isCompleted => _state.isCompleted;
  ResolvedCharacterAnimation? get resolvedAnimation => _state.resolvedAnimation;

  bool play(CharacterAction requestedAction) {
    final candidate = _resolve(requestedAction, _state.direction);
    if (candidate.action == _state.action) {
      return true;
    }
    if (!_canInterrupt(candidate.descriptor)) {
      return false;
    }

    if (_state.descriptor.loop && !candidate.descriptor.loop) {
      _resumeState ??= CharacterActionResumeState(
        action: _state.action,
        direction: _state.direction,
        normalizedProgress: normalizedProgress,
      );
    }
    _state = _stateFor(candidate, _state.direction, progress: 0);
    return true;
  }

  void setDirection(CharacterDirection nextDirection) {
    if (nextDirection == _state.direction) {
      return;
    }
    _state = _stateFor(
      _resolve(_state.action, nextDirection),
      nextDirection,
      progress: normalizedProgress,
    );
  }

  void stop() {
    _resumeState = null;
    final idle = _resolve(const CharacterAction(), _state.direction);
    _state = _stateFor(idle, _state.direction, progress: 0);
  }

  /// Sole playback clock. Flame adapters must call this exactly once per tick.
  void update(double dt) {
    if (dt <= 0 || _state.resolvedAnimation == null) {
      return;
    }
    final animation = _state.resolvedAnimation!;
    final duration = animation.duration;
    if (duration <= 0) {
      return;
    }

    if (_state.descriptor.loop) {
      final elapsed = (_state.elapsed + dt) % duration;
      _state = _stateForElapsed(_state, elapsed, isCompleted: false);
      return;
    }

    final elapsed = (_state.elapsed + dt).clamp(0.0, duration);
    if (elapsed >= duration) {
      _completeOneShot();
    } else {
      _state = _stateForElapsed(_state, elapsed, isCompleted: false);
    }
  }

  bool _canInterrupt(CharacterActionDescriptor candidate) {
    if (_state.descriptor.canInterrupt) {
      return true;
    }
    return candidate.priority > _state.descriptor.priority;
  }

  _Candidate _resolve(CharacterAction requested, CharacterDirection direction) {
    final visited = <String>{};
    var current = requested;
    while (visited.add(current.canonicalKey)) {
      final descriptor = descriptors[current];
      if (descriptor == null) {
        return _idleCandidate(direction);
      }
      if (!capabilities.canPlay(characterId, current)) {
        current = descriptor.fallbackAction;
        continue;
      }
      final animation = resolver.resolve(characterId, current, direction);
      if (animation != null) {
        return _Candidate(current, descriptor, animation);
      }
      current = descriptor.fallbackAction;
    }
    return _idleCandidate(direction);
  }

  _Candidate _idleCandidate(CharacterDirection direction) {
    const idle = CharacterAction();
    final descriptor = descriptors[idle];
    if (descriptor == null) {
      throw StateError('Idle action descriptor is not registered');
    }
    return _Candidate(
      idle,
      descriptor,
      resolver.resolve(characterId, idle, direction),
    );
  }

  CharacterActionState _stateFor(
    _Candidate candidate,
    CharacterDirection direction, {
    required double progress,
  }) {
    final animation = candidate.animation;
    final elapsed = animation == null
        ? 0.0
        : (animation.duration * progress).clamp(0.0, animation.duration);
    return _stateForElapsed(
      CharacterActionState(
        action: candidate.action,
        direction: direction,
        descriptor: candidate.descriptor,
        resolvedAnimation: animation,
        elapsed: elapsed,
        frameIndex: 0,
        isCompleted: false,
      ),
      elapsed,
      isCompleted: false,
    );
  }

  CharacterActionState _stateForElapsed(
    CharacterActionState state,
    double elapsed, {
    required bool isCompleted,
  }) {
    final animation = state.resolvedAnimation;
    if (animation == null || animation.frameCount <= 0 || animation.fps <= 0) {
      return CharacterActionState(
        action: state.action,
        direction: state.direction,
        descriptor: state.descriptor,
        resolvedAnimation: animation,
        elapsed: elapsed,
        frameIndex: 0,
        isCompleted: isCompleted,
      );
    }
    final rawFrame = (elapsed * animation.fps).floor();
    final frameIndex = state.descriptor.loop
        ? rawFrame % animation.frameCount
        : rawFrame.clamp(0, animation.frameCount - 1);
    return CharacterActionState(
      action: state.action,
      direction: state.direction,
      descriptor: state.descriptor,
      resolvedAnimation: animation,
      elapsed: elapsed,
      frameIndex: frameIndex,
      isCompleted: isCompleted,
    );
  }

  void _completeOneShot() {
    final resume = _resumeState;
    _resumeState = null;
    if (resume != null) {
      final restored = _resolve(resume.action, resume.direction);
      if (restored.action == resume.action && restored.animation != null) {
        _state = _stateFor(
          restored,
          resume.direction,
          progress: resume.normalizedProgress,
        );
        return;
      }
    }
    final fallback = _resolve(
      _state.descriptor.fallbackAction,
      _state.direction,
    );
    _state = _stateFor(fallback, _state.direction, progress: 0);
  }
}

class _Candidate {
  const _Candidate(this.action, this.descriptor, this.animation);

  final CharacterAction action;
  final CharacterActionDescriptor descriptor;
  final ResolvedCharacterAnimation? animation;
}
