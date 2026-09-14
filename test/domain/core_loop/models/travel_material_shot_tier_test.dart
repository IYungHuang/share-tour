import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';

TravelMaterial baseMaterial({
  ShotTier shotTier = ShotTier.normal,
  String? perfectDescription,
  String? failedDescription,
}) => TravelMaterial(
  id: 'kyoto_test_card',
  name: '測試景點',
  tags: const ['#測試'],
  themeValue: 30,
  hypeValue: 40,
  storyValue: 2,
  cost: 100,
  riskLevel: 2,
  description: '普通版描述。',
  shotTier: shotTier,
  perfectDescription: perfectDescription,
  failedDescription: failedDescription,
);

void main() {
  group('AC-M5-2.6: shotTier 預設為 normal', () {
    test('未指定時預設 normal，既有建構呼叫零改動即通過', () {
      const m = TravelMaterial(
        id: 'x',
        name: 'x',
        tags: [],
        themeValue: 1,
        hypeValue: 1,
      );
      expect(m.shotTier, ShotTier.normal);
      expect(m.perfectDescription, isNull);
      expect(m.failedDescription, isNull);
    });
  });

  group('descriptionFor: 回退語意', () {
    test('normal 回既有 description', () {
      final m = baseMaterial();
      expect(m.descriptionFor(ShotTier.normal), '普通版描述。');
    });

    test('perfect 有設定值時回該值', () {
      final m = baseMaterial(perfectDescription: '完美版描述。');
      expect(m.descriptionFor(ShotTier.perfect), '完美版描述。');
    });

    test('perfect 未設定時回退 description', () {
      final m = baseMaterial();
      expect(m.descriptionFor(ShotTier.perfect), '普通版描述。');
    });

    test('failed 有設定值時回該值，未設定時回退 description', () {
      final withFailed = baseMaterial(failedDescription: '失手版描述。');
      expect(withFailed.descriptionFor(ShotTier.failed), '失手版描述。');
      final withoutFailed = baseMaterial();
      expect(withoutFailed.descriptionFor(ShotTier.failed), '普通版描述。');
    });
  });

  group('AC-M5-2.2: 凍結欄位——三態變體除 shotTier/description 外全等', () {
    test('相等語意不納入 shotTier/perfectDescription/failedDescription', () {
      final normal = baseMaterial();
      final perfect = baseMaterial(
        shotTier: ShotTier.perfect,
        perfectDescription: '完美版描述。',
      );
      final failed = baseMaterial(
        shotTier: ShotTier.failed,
        failedDescription: '失手版描述。',
      );
      expect(normal, equals(perfect));
      expect(normal, equals(failed));
      expect(normal.hashCode, perfect.hashCode);
      expect(normal.hashCode, failed.hashCode);
    });
  });

  group('copyWith 支援三態欄位', () {
    test('copyWith 可設定 shotTier 與兩個文案欄位', () {
      final m = baseMaterial();
      final copied = m.copyWith(
        shotTier: ShotTier.perfect,
        perfectDescription: '新完美描述',
      );
      expect(copied.shotTier, ShotTier.perfect);
      expect(copied.perfectDescription, '新完美描述');
      // 其餘欄位不變
      expect(copied.id, m.id);
      expect(copied.hypeValue, m.hypeValue);
    });
  });
}
