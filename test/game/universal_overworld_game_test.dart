import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';
import 'package:share_tour/domain/location/camera/camera_follow.dart';
import 'package:share_tour/game/universal_overworld_game.dart';
import '../fakes/fake_clock.dart';
import '../fakes/fake_map_manifest.dart';

void main() {
  test('UniversalOverworldGame 初始化與最大縮放支援 4.0', () {
    final manifest = FakeMapManifest.linear();
    final game = UniversalOverworldGame(
      manifest: manifest,
      onTick: (_) {},
      renderedPixelOf: () => Vector2.zero(),
      cameraFollow: CameraFollow(
        clock: FakeClock(),
        returnDelay: const Duration(seconds: 3),
      ),
    );

    expect(game.minZoom, 0.5);
    expect(game.maxZoom, 4.0);
  });

  test('保留初始 action 與 direction，尚未建立 player 時 command 不拋錯', () {
    const action = CharacterAction(locomotion: CharacterLocomotion.run);
    final game = UniversalOverworldGame(
      manifest: FakeMapManifest.linear(),
      onTick: (_) {},
      renderedPixelOf: () => Vector2.zero(),
      cameraFollow: CameraFollow(
        clock: FakeClock(),
        returnDelay: const Duration(seconds: 3),
      ),
      initialAction: action,
      initialDirection: CharacterDirection.right,
    );

    expect(game.initialAction, action);
    expect(game.initialDirection, CharacterDirection.right);
    expect(
      () => game.playPlayerAction(const CharacterAction()),
      returnsNormally,
    );
    expect(
      () => game.setPlayerDirection(CharacterDirection.back),
      returnsNormally,
    );
  });
}
