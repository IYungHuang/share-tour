import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/shutter/framing_penalty.dart';

void main() {
  group('AC-M5-4.2: 構圖二元判定真值表（3×2 全覆蓋）', () {
    test('構圖通過：最終態等於時機態', () {
      expect(
        applyFramingPenalty(ShotTier.perfect, framingOk: true),
        ShotTier.perfect,
      );
      expect(
        applyFramingPenalty(ShotTier.normal, framingOk: true),
        ShotTier.normal,
      );
      expect(
        applyFramingPenalty(ShotTier.failed, framingOk: true),
        ShotTier.failed,
      );
    });

    test('構圖不通過：降一階', () {
      expect(
        applyFramingPenalty(ShotTier.perfect, framingOk: false),
        ShotTier.normal,
      );
      expect(
        applyFramingPenalty(ShotTier.normal, framingOk: false),
        ShotTier.failed,
      );
      expect(
        applyFramingPenalty(ShotTier.failed, framingOk: false),
        ShotTier.failed,
      );
    });
  });

  group('framingOk 二元判定', () {
    test('偏移量在門檻內為通過', () {
      expect(framingOk(0.1, 0.25), isTrue);
      expect(framingOk(0.25, 0.25), isTrue);
      expect(framingOk(0.26, 0.25), isFalse);
    });
  });
}
