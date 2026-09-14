enum CharacterLocomotion { idle, walk, run, dash, jump }

enum CharacterPosture { standing, crouching, sitting, supine, prone }

enum CharacterActivity { none, eat, drink, sleep }

enum CharacterHeldItem { none, oneHand, twoHands }

class InvalidCharacterActionException implements Exception {
  const InvalidCharacterActionException(this.message);

  final String message;

  @override
  String toString() => 'InvalidCharacterActionException: $message';
}

class CharacterAction {
  const CharacterAction({
    this.locomotion = CharacterLocomotion.idle,
    this.posture = CharacterPosture.standing,
    this.activity = CharacterActivity.none,
    this.heldItem = CharacterHeldItem.none,
    this.special,
  });

  static const idle = CharacterAction();

  final CharacterLocomotion locomotion;
  final CharacterPosture posture;
  final CharacterActivity activity;
  final CharacterHeldItem heldItem;
  final String? special;

  String get canonicalKey => [
    'locomotion=${locomotion.name}',
    'posture=${posture.name}',
    'activity=${activity.name}',
    'heldItem=${heldItem.name}',
    'special=${special ?? 'none'}',
  ].join('|');

  static CharacterAction fromShorthand(Iterable<String> tokens) {
    var locomotion = CharacterLocomotion.idle;
    var locomotionSet = false;
    var posture = CharacterPosture.standing;
    var postureSet = false;
    var activity = CharacterActivity.none;
    var activitySet = false;
    var heldItem = CharacterHeldItem.none;
    var heldItemSet = false;
    String? special;

    for (final rawToken in tokens) {
      final token = rawToken.trim();
      if (token.isEmpty) {
        throw const InvalidCharacterActionException('empty shorthand token');
      }

      switch (token) {
        case 'idle':
        case 'walk':
        case 'run':
        case 'dash':
        case 'jump':
          if (locomotionSet) {
            throw const InvalidCharacterActionException(
              'multiple locomotion values',
            );
          }
          locomotion = CharacterLocomotion.values.byName(token);
          locomotionSet = true;
        case 'standing':
        case 'crouch':
        case 'sit':
        case 'supine':
        case 'prone':
          if (postureSet) {
            throw const InvalidCharacterActionException(
              'multiple posture values',
            );
          }
          posture = switch (token) {
            'crouch' => CharacterPosture.crouching,
            'sit' => CharacterPosture.sitting,
            _ => CharacterPosture.values.byName(token),
          };
          postureSet = true;
        case 'eat':
        case 'drink':
        case 'sleep':
          if (activitySet) {
            throw const InvalidCharacterActionException(
              'multiple activity values',
            );
          }
          activity = CharacterActivity.values.byName(token);
          activitySet = true;
        case 'oneHand':
        case 'twoHands':
          if (heldItemSet) {
            throw const InvalidCharacterActionException(
              'multiple held-item values',
            );
          }
          heldItem = CharacterHeldItem.values.byName(token);
          heldItemSet = true;
        default:
          final specialToken = token.startsWith('special=')
              ? token.substring('special='.length)
              : token;
          if (!_specialPattern.hasMatch(specialToken)) {
            throw InvalidCharacterActionException(
              'unknown or invalid shorthand token: $token',
            );
          }
          if (special != null) {
            throw const InvalidCharacterActionException(
              'multiple special values',
            );
          }
          special = specialToken;
      }
    }

    return CharacterAction(
      locomotion: locomotion,
      posture: posture,
      activity: activity,
      heldItem: heldItem,
      special: special,
    );
  }

  static final _specialPattern = RegExp(r'^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$');

  @override
  bool operator ==(Object other) =>
      other is CharacterAction &&
      other.locomotion == locomotion &&
      other.posture == posture &&
      other.activity == activity &&
      other.heldItem == heldItem &&
      other.special == special;

  @override
  int get hashCode =>
      Object.hash(locomotion, posture, activity, heldItem, special);

  @override
  String toString() => canonicalKey;
}
