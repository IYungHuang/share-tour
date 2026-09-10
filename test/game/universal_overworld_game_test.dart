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
}
