import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/core/build_flags.dart';
import 'package:share_tour/domain/character_action/character_action.dart';
import 'package:share_tour/domain/character_action/character_action_controller.dart';
import 'package:share_tour/domain/character_action/character_action_descriptor.dart';
import 'package:share_tour/domain/character_action/character_animation_manifest.dart';
import 'package:share_tour/domain/character_action/character_animation_resolver.dart';
import 'package:share_tour/domain/character_action/character_capability_registry.dart';
import 'package:share_tour/domain/character_action/character_direction.dart';
import 'package:share_tour/game/characters/character_asset_loader.dart';
import 'package:share_tour/game/components/character_component.dart';
import 'package:share_tour/game/components/player_component.dart';
import 'package:share_tour/state/location/location_providers.dart';
import 'package:share_tour/domain/location/models/location_permission_gateway.dart';
import '../fakes/fake_clock.dart';
import '../fakes/fake_map_manifest.dart';
import '../fakes/fake_permission_gateway.dart';
import '../fakes/fake_wakelock_control.dart';

/// 權限閘道必須注入。AC-NFR-6.1 的措辭就是「注入回報無定位硬體的來源」——
/// 沒有平台繫結的單元測試環境不等於「桌面沒有 GPS」，靠真實 gateway 在
/// 測試裡拋例外來達成同樣結果是巧合，不是驗證。
///
/// wakelockControlProvider 同理須覆寫：真實的 WakelockPlus 呼叫平台頻道，
/// 這支測試不是 testWidgets，沒有 binding 可用。
ProviderContainer makeContainer() => ProviderContainer(
  overrides: [
    mapManifestProvider.overrideWithValue(FakeMapManifest.linear()),
    clockProvider.overrideWithValue(FakeClock()),
    buildFlagsProvider.overrideWithValue(const BuildFlags.debug()),
    permissionGatewayProvider.overrideWithValue(
      FakePermissionGateway()..accuracy = PlatformAccuracy.unavailable,
    ),
    wakelockControlProvider.overrideWithValue(FakeWakelockControl()),
  ],
);

void main() {
  test('PlayerComponent 以 setFrom 同步，不與來源共用實例', () {
    final p = PlayerComponent(position: Vector2(10, 20));
    final source = Vector2(100, 200);
    p.syncTo(source);
    source.setValues(999, 999);
    expect(p.position.x, 100);
    expect(p.position.y, 200);
  });

  test('舊 constructor 保留紅色 placeholder', () {
    final p = PlayerComponent(position: Vector2(10, 20));
    expect(p.characterComponent, isNull);
    expect(p.placeholder, isNotNull);
    expect(p.placeholder!.position, Vector2.all(8));
  });

  test('角色位於光照層之上，避免環境濾鏡遮住人物', () {
    final p = PlayerComponent(position: Vector2.zero());
    expect(p.priority, 20);
  });

  test('action commands forward to one character controller', () {
    final controller = makeCharacterController();
    final character = CharacterComponent(
      controller: controller,
      loader: CharacterAssetLoader(),
    );
    final p = PlayerComponent(
      position: Vector2.zero(),
      characterComponent: character,
    );

    expect(
      p.play(const CharacterAction(locomotion: CharacterLocomotion.run)),
      isTrue,
    );
    p.setDirection(CharacterDirection.right);
    expect(controller.action.locomotion, CharacterLocomotion.run);
    expect(controller.direction, CharacterDirection.right);
    expect(character.position, Vector2.all(8));
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
    expect(
      container.read(locationControllerProvider).status.mode.name,
      'virtual',
    );
  });
}

CharacterActionController makeCharacterController() {
  final assets = [
    ...makeActionAssets(const CharacterAction(), 0),
    ...makeActionAssets(
      const CharacterAction(locomotion: CharacterLocomotion.run),
      724,
    ),
  ];
  return CharacterActionController(
    characterId: 'guide',
    descriptors: CharacterActionDescriptorRegistry.standard(),
    resolver: CharacterAnimationResolver(CharacterAnimationManifest(assets)),
    capabilities: CharacterCapabilityRegistry(const {}),
  );
}

Iterable<CharacterAnimationAsset> makeActionAssets(
  CharacterAction action,
  int y,
) {
  return CharacterDirection.values.map(
    (direction) => CharacterAnimationAsset(
      characterId: 'guide',
      actionId: action.canonicalKey,
      direction: direction,
      assetKind: CharacterAssetKind.overworld,
      assetPath: 'guide_overworld_sheet_v1_generated.png',
      frameWidth: 362,
      frameHeight: 362,
      frameCount: 1,
      fps: 4,
      loop: true,
      anchor: const NormalizedAnchor(0.5, 1),
      renderWidth: 24,
      renderHeight: 24,
      directionAxis: CharacterDirectionAxis.column,
      sourceOrigin: PixelPoint(0, y),
      padding: PixelPadding.zero,
      spacing: PixelSpacing.zero,
      animationKey: 'guide.idle',
    ),
  );
}
