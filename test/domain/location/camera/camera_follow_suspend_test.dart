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

  group('AC-M5-4.4: QTE 期間相機回歸計時不推進', () {
    test('對照組：不暫停時，推進 3.2 秒（超過 returnDelay 3 秒）會翻 returning', () {
      camera.onPan(Vector2.zero());
      clock.advance(const Duration(milliseconds: 3200));
      center();
      expect(camera.mode, CameraMode.returning);
    });

    test('suspend 期間推進 3.2 秒，resume 後 mode 仍為 free（未翻 returning）', () {
      camera.onPan(Vector2.zero());
      camera.suspend();
      clock.advance(const Duration(milliseconds: 3200));
      camera.resume();
      center();
      expect(camera.mode, CameraMode.free);
    });

    test('resume 後繼續推進到真正的 returnDelay 才翻 returning', () {
      camera.onPan(Vector2.zero());
      camera.suspend();
      clock.advance(const Duration(milliseconds: 3200)); // 暫停期間，不計
      camera.resume();
      center(); // free，未翻
      expect(camera.mode, CameraMode.free);
      clock.advance(const Duration(milliseconds: 3100)); // resume 後再等 3.1 秒
      center();
      expect(camera.mode, CameraMode.returning);
    });
  });

  group('AC-M5-4.3a: side-effect-free 讀出點', () {
    test('QTE 前後（suspend→resume）mode/frozenCenter/pendingPan/lastInteraction 不變', () {
      camera.onPan(Vector2(10, 5));
      center(); // 消化一次 pendingPan，凍結中心成立
      final modeBefore = camera.mode;
      final frozenBefore = camera.frozenCenterForTest;
      final pendingBefore = camera.pendingPanForTest;
      final lastBefore = camera.lastInteractionForTest;

      camera.suspend();
      clock.advance(const Duration(milliseconds: 500));
      camera.resume();

      expect(camera.mode, modeBefore);
      expect(camera.frozenCenterForTest, frozenBefore);
      expect(camera.pendingPanForTest, pendingBefore);
      expect(camera.lastInteractionForTest, lastBefore);
    });
  });

  test('recenter 清空 suspend 相關狀態', () {
    camera.onPan(Vector2.zero());
    camera.suspend();
    camera.recenter();
    clock.advance(const Duration(seconds: 10));
    camera.onPan(Vector2.zero());
    clock.advance(const Duration(milliseconds: 3200));
    center();
    expect(camera.mode, CameraMode.returning, reason: 'recenter 後不該殘留暫停位移');
  });
}
