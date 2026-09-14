import 'character_action.dart';

class CharacterCapabilityRegistry {
  CharacterCapabilityRegistry(Map<String, Set<String>> capabilities)
    : _capabilities = Map.unmodifiable({
        for (final entry in capabilities.entries)
          entry.key: Set.unmodifiable(entry.value),
      });

  final Map<String, Set<String>> _capabilities;

  bool canPlay(String characterId, CharacterAction action) {
    final special = action.special;
    if (special == null) {
      return true;
    }
    return _capabilities[characterId]?.contains(special) ?? false;
  }
}
