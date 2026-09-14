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

  test('QTE game bridge 暫停並恢復相機回歸計時', () {
    final clock = FakeClock();
    final cameraFollow = CameraFollow(
      clock: clock,
      returnDelay: const Duration(seconds: 3),
    );
    final game = UniversalOverworldGame(
      manifest: FakeMapManifest.linear(),
      onTick: (_) {},
      renderedPixelOf: () => Vector2.zero(),
      cameraFollow: cameraFollow,
    );
    Vector2 center() => cameraFollow.targetCenter(
      player: Vector2(400, 300),
      zoom: 1,
      viewportSize: Vector2(800, 600),
      mapSize: Vector2(2048, 1152),
    );

    cameraFollow.onPan(Vector2.zero());
    game.suspendCameraForQte();
    clock.advance(const Duration(milliseconds: 3200));
    center();
    expect(cameraFollow.mode, CameraMode.free);

    game.resumeCameraFromQte();
    clock.advance(const Duration(milliseconds: 3100));
    center();
    expect(cameraFollow.mode, CameraMode.returning);
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
    expect(() => game.setPlayerMoving(true), returnsNormally);
    expect(() => game.setPlayerMoving(false), returnsNormally);
  });

  test('尚未載入時 switchMap 更新 manifest 且不存取 Flame 元件', () async {
    final first = FakeMapManifest.linear();
    final second = FakeMapManifest.linear(originPixel: Vector2(80, 90));
    final game = UniversalOverworldGame(
      manifest: first,
      onTick: (_) {},
      renderedPixelOf: () => Vector2.zero(),
      cameraFollow: CameraFollow(
        clock: FakeClock(),
        returnDelay: const Duration(seconds: 3),
      ),
    );

    await game.switchMap(second, newSpawnPixel: Vector2(12, 13));

    expect(game.manifest, same(second));
  });
}
