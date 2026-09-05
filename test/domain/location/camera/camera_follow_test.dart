import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/camera/camera_follow.dart';
import '../../../fakes/fake_clock.dart';

void main() {
  late FakeClock clock;
  late CameraFollow camera;

  setUp(() {
    clock = FakeClock();
    camera = CameraFollow(clock: clock, returnDelay: const Duration(seconds: 3));
  });

  Vector2 center({
    Vector2? player,
    double zoom = 1.0,
    Vector2? viewport,
    Vector2? map,
  }) =>
      camera.targetCenter(
        player: player ?? Vector2(400, 300),
        zoom: zoom,
        viewportSize: viewport ?? Vector2(800, 600),
        mapSize: map ?? Vector2(2048, 1152),
      );

  test('AC-8.1 手勢平移 → free', () {
    expect(camera.mode, CameraMode.following);
    camera.onPan();
    expect(camera.mode, CameraMode.free);
  });

  test('AC-8.2 停止操作滿 3 秒 → returning，回歸完成後 following', () {
    camera.onPan();
    clock.advance(const Duration(seconds: 3));
    center();
    expect(camera.mode, CameraMode.returning);
    for (var i = 0; i < 240; i++) {
      center();
    }
    expect(camera.mode, CameraMode.following);
  });

  test('AC-8.3 free 下玩家移動，相機中心不變', () {
    camera.onPan();
    final before = center(player: Vector2(400, 300));
    final after = center(player: Vector2(900, 700));
    expect(after, before);
  });

  test('AC-8.4 地圖小於視口時，中心為地圖中點', () {
    final c = center(map: Vector2(100, 100), viewport: Vector2(800, 600));
    expect(c, Vector2(50, 50));
  });

  test('AC-8.4b 任意 zoom 下相機中心不越界', () {
    for (final z in [0.5, 1.0, 2.5]) {
      final c = center(player: Vector2(0, 0), zoom: z);
      final halfW = 800 / (2 * z);
      final halfH = 600 / (2 * z);
      // 地圖 2048x1152：半視口大於半地圖時取中點，否則夾在邊界內
      final expectedX = halfW * 2 >= 2048 ? 1024.0 : halfW;
      final expectedY = halfH * 2 >= 1152 ? 576.0 : halfH;
      expect(c.x, closeTo(expectedX, 0.01), reason: 'zoom $z');
      expect(c.y, closeTo(expectedY, 0.01), reason: 'zoom $z');
    }
  });

  test('AC-8.5 free 期間僅縮放 → 回歸計時器不重置', () {
    camera.onPan();
    clock.advance(const Duration(seconds: 2));
    camera.onZoom(); // 縮放不算操作
    clock.advance(const Duration(seconds: 1));
    center();
    expect(camera.mode, CameraMode.returning,
        reason: '若縮放重置了計時器，此時仍會是 free');
  });

  test('recenter 立即回到 following', () {
    camera.onPan();
    camera.recenter();
    expect(camera.mode, CameraMode.following);
    expect(center(player: Vector2(900, 700)).x, closeTo(900, 0.01));
  });

  test('回歸過程中再次平移 → 回到 free', () {
    camera.onPan();
    clock.advance(const Duration(seconds: 3));
    center();
    expect(camera.mode, CameraMode.returning);
    camera.onPan();
    expect(camera.mode, CameraMode.free);
  });
}
