import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
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
}
