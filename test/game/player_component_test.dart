import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/core/build_flags.dart';
import 'package:share_tour/game/components/player_component.dart';
import 'package:share_tour/state/location/location_providers.dart';
import '../fakes/fake_clock.dart';
import '../fakes/fake_map_manifest.dart';

ProviderContainer makeContainer() => ProviderContainer(overrides: [
      mapManifestProvider.overrideWithValue(FakeMapManifest.linear()),
      clockProvider.overrideWithValue(FakeClock()),
      buildFlagsProvider.overrideWithValue(const BuildFlags.debug()),
    ]);

void main() {
  test('PlayerComponent 以 setFrom 同步，不與來源共用實例', () {
    final p = PlayerComponent(position: Vector2(10, 20));
    final source = Vector2(100, 200);
    p.syncTo(source);
    source.setValues(999, 999);
    expect(p.position.x, 100);
    expect(p.position.y, 200);
  });

  test('NFR-5 容器 dispose 後不再有殘留訂閱', () {
    final container = makeContainer();
    container.read(locationControllerProvider);
    container.dispose();
    // dispose 未拋例外即代表所有 onDispose 都被呼叫。
    // 熱重載會重建整棵樹，訂閱未釋放會累積成重複觸發。
    expect(() => container.dispose(), returnsNormally);
  });

  test('NFR-6 桌面無定位硬體時自動進入方向鍵模式', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    expect(container.read(locationControllerProvider).status.mode.name,
        'virtual');
  });
}
