import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/shutter/held_ms.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_input.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_result.dart';

HeldMs heldFor(int ms) => HeldMs(
      downTimeStamp: Duration.zero,
      upTimeStamp: Duration(milliseconds: ms),
    );

void main() {
  group('AC-M5-4.1: 分派——isSpotlight 決定是否套構圖', () {
    test('非絕景走純時機，不受 compositionOffset 影響', () {
      final tier = resolveShotTier(
        input: Pressed(heldFor(800)), // decisiveMoment tMatch=800 → perfect
        difficulty: ShutterDifficulty.decisiveMoment,
        isSpotlight: false,
        compositionOffset: 999, // 荒謬大的偏移，非絕景應忽略
      );
      expect(tier, ShotTier.perfect);
    });

    test('絕景走時機＋構圖，偏移超標則降階', () {
      final tier = resolveShotTier(
        input: Pressed(heldFor(800)),
        difficulty: ShutterDifficulty.decisiveMoment,
        isSpotlight: true,
        compositionOffset: 0.5, // 超過 decisiveMoment 門檻 0.12
      );
      expect(tier, ShotTier.normal);
    });

    test('絕景構圖通過時等於時機態', () {
      final tier = resolveShotTier(
        input: Pressed(heldFor(800)),
        difficulty: ShutterDifficulty.decisiveMoment,
        isSpotlight: true,
        compositionOffset: 0.05,
      );
      expect(tier, ShotTier.perfect);
    });
  });

  group('REQ-M5-04.2: 絕景中斷視為構圖不通過', () {
    test('compositionOffset 為 null 時視為不通過（中斷路徑重用）', () {
      final tier = resolveShotTier(
        input: Pressed(heldFor(800)),
        difficulty: ShutterDifficulty.decisiveMoment,
        isSpotlight: true,
        compositionOffset: null,
      );
      expect(tier, ShotTier.normal, reason: 'perfect 降一階為 normal');
    });

    test('非絕景中斷不受影響（compositionOffset 為 null 但非絕景時忽略）', () {
      final tier = resolveShotTier(
        input: Pressed(heldFor(800)),
        difficulty: ShutterDifficulty.decisiveMoment,
        isSpotlight: false,
        compositionOffset: null,
      );
      expect(tier, ShotTier.perfect);
    });
  });
}
