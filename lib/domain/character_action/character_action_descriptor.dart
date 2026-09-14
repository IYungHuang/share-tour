import 'character_action.dart';

class CharacterActionDescriptor {
  const CharacterActionDescriptor({
    required this.action,
    required this.loop,
    required this.priority,
    required this.canInterrupt,
    required this.fallbackAction,
    required this.animationKey,
  });

  final CharacterAction action;
  final bool loop;
  final int priority;
  final bool canInterrupt;
  final CharacterAction fallbackAction;
  final String animationKey;
}

class CharacterActionDescriptorRegistry {
  CharacterActionDescriptorRegistry(
    Iterable<CharacterActionDescriptor> descriptors,
  ) : _byKey = _index(descriptors) {
    _validateFallbacks();
  }

  final Map<String, CharacterActionDescriptor> _byKey;

  Iterable<CharacterActionDescriptor> get values => _byKey.values;

  static CharacterActionDescriptorRegistry standard() {
    const idle = CharacterAction();
    return CharacterActionDescriptorRegistry([
      const CharacterActionDescriptor(
        action: idle,
        loop: true,
        priority: 0,
        canInterrupt: true,
        fallbackAction: idle,
        animationKey: 'idle',
      ),
      const CharacterActionDescriptor(
        action: CharacterAction(locomotion: CharacterLocomotion.walk),
        loop: true,
        priority: 10,
        canInterrupt: true,
        fallbackAction: idle,
        animationKey: 'walk',
      ),
      const CharacterActionDescriptor(
        action: CharacterAction(locomotion: CharacterLocomotion.run),
        loop: true,
        priority: 20,
        canInterrupt: true,
        fallbackAction: idle,
        animationKey: 'run',
      ),
      const CharacterActionDescriptor(
        action: CharacterAction(activity: CharacterActivity.eat),
        loop: false,
        priority: 40,
        canInterrupt: true,
        fallbackAction: idle,
        animationKey: 'eat',
      ),
      const CharacterActionDescriptor(
        action: CharacterAction(activity: CharacterActivity.drink),
        loop: false,
        priority: 40,
        canInterrupt: true,
        fallbackAction: idle,
        animationKey: 'drink',
      ),
      const CharacterActionDescriptor(
        action: CharacterAction(activity: CharacterActivity.sleep),
        loop: true,
        priority: 50,
        canInterrupt: false,
        fallbackAction: idle,
        animationKey: 'sleep',
      ),
      const CharacterActionDescriptor(
        action: CharacterAction(locomotion: CharacterLocomotion.dash),
        loop: false,
        priority: 60,
        canInterrupt: false,
        fallbackAction: idle,
        animationKey: 'dash',
      ),
      const CharacterActionDescriptor(
        action: CharacterAction(locomotion: CharacterLocomotion.jump),
        loop: false,
        priority: 70,
        canInterrupt: false,
        fallbackAction: idle,
        animationKey: 'jump',
      ),
    ]);
  }

  CharacterActionDescriptor? operator [](CharacterAction action) =>
      _byKey[action.canonicalKey];

  CharacterActionDescriptor require(CharacterAction action) {
    final descriptor = this[action];
    if (descriptor == null) {
      throw ArgumentError('No descriptor for ${action.canonicalKey}');
    }
    return descriptor;
  }

  CharacterActionDescriptor? byCanonicalKey(String canonicalKey) =>
      _byKey[canonicalKey];

  static Map<String, CharacterActionDescriptor> _index(
    Iterable<CharacterActionDescriptor> descriptors,
  ) {
    final result = <String, CharacterActionDescriptor>{};
    for (final descriptor in descriptors) {
      final key = descriptor.action.canonicalKey;
      if (result.containsKey(key)) {
        throw ArgumentError('Duplicate descriptor for $key');
      }
      result[key] = descriptor;
    }
    return Map.unmodifiable(result);
  }

  void _validateFallbacks() {
    for (final descriptor in _byKey.values) {
      final fallbackKey = descriptor.fallbackAction.canonicalKey;
      if (!_byKey.containsKey(fallbackKey)) {
        throw ArgumentError(
          'Fallback $fallbackKey is not registered for ${descriptor.action.canonicalKey}',
        );
      }
      final visited = <String>{};
      var current = descriptor.action.canonicalKey;
      while (true) {
        if (!visited.add(current)) {
          throw ArgumentError('Fallback cycle detected at $current');
        }
        final next = _byKey[current]!.fallbackAction.canonicalKey;
        if (next == current) {
          break;
        }
        current = next;
      }
    }
  }
}
