import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/character_action/character_action.dart';

void main() {
  test('default action uses idle standing and empty channels', () {
    const action = CharacterAction();

    expect(
      action.canonicalKey,
      'locomotion=idle|posture=standing|activity=none|heldItem=none|special=none',
    );
  });

  test('composes shorthand tokens into fixed canonical key order', () {
    expect(
      CharacterAction.fromShorthand(['sit', 'drink']).canonicalKey,
      'locomotion=idle|posture=sitting|activity=drink|heldItem=none|special=none',
    );
    expect(
      CharacterAction.fromShorthand(['walk', 'oneHand']).canonicalKey,
      'locomotion=walk|posture=standing|activity=none|heldItem=oneHand|special=none',
    );
    expect(
      CharacterAction.fromShorthand(['run', 'guide.point']).canonicalKey,
      'locomotion=run|posture=standing|activity=none|heldItem=none|special=guide.point',
    );
  });

  test('action equality includes every channel', () {
    const first = CharacterAction(
      locomotion: CharacterLocomotion.walk,
      heldItem: CharacterHeldItem.oneHand,
    );
    const same = CharacterAction(
      locomotion: CharacterLocomotion.walk,
      heldItem: CharacterHeldItem.oneHand,
    );
    const different = CharacterAction(
      locomotion: CharacterLocomotion.walk,
      heldItem: CharacterHeldItem.twoHands,
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(different));
  });

  test('rejects duplicate values in one channel', () {
    expect(
      () => CharacterAction.fromShorthand(['sit', 'crouch']),
      throwsA(isA<InvalidCharacterActionException>()),
    );
    expect(
      () => CharacterAction.fromShorthand(['walk', 'run']),
      throwsA(isA<InvalidCharacterActionException>()),
    );
  });

  test('rejects unknown shorthand and invalid special namespace', () {
    expect(
      () => CharacterAction.fromShorthand(['fly']),
      throwsA(isA<InvalidCharacterActionException>()),
    );
    expect(
      () => CharacterAction.fromShorthand(['Guide.Point']),
      throwsA(isA<InvalidCharacterActionException>()),
    );
  });
}
