import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';

void main() {
  group('AC-M5-2.1: 三態文案無缺漏（首發 37 段範圍）', () {
    test('32 張皆有 perfectDescription（非 null）', () {
      for (final m in kyotoNightMaterials) {
        expect(
          m.perfectDescription,
          isNotNull,
          reason: '${m.id} 缺少 perfectDescription',
        );
      }
    });

    test('白名單集合：failedDescription 為 null 的 id 恰等於非絕景 id 集合', () {
      final noFailed = kyotoNightMaterials
          .where((m) => m.failedDescription == null)
          .map((m) => m.id)
          .toSet();
      final nonSpotlight = kyotoNightMaterials
          .where((m) => !m.isSpotlight)
          .map((m) => m.id)
          .toSet();
      expect(
        noFailed,
        nonSpotlight,
        reason: '回退是刻意而非遺漏——白名單集合須恰等於非絕景 id 集合',
      );
    });

    test('5 張絕景皆有 failedDescription', () {
      final spotlights = kyotoNightMaterials.where((m) => m.isSpotlight);
      expect(spotlights.length, 5);
      for (final m in spotlights) {
        expect(m.failedDescription, isNotNull, reason: '${m.id} 缺少 failedDescription');
      }
    });
  });

  group('AC-M5-12.1~12.3: 文案護欄（僅比對有撰寫版本者）', () {
    test('perfect 與 normal 兩兩相異，長度比 <= 1.5，不互為子字串', () {
      for (final m in kyotoNightMaterials) {
        final normal = m.description;
        final perfect = m.perfectDescription!;
        expect(perfect, isNot(normal), reason: '${m.id} perfect == normal');
        final ratio = [normal.characters.length, perfect.characters.length]
            .reduce((a, b) => a > b ? a : b) /
            [normal.characters.length, perfect.characters.length]
                .reduce((a, b) => a < b ? a : b);
        expect(ratio, lessThanOrEqualTo(1.5), reason: '${m.id} perfect 長度比超標');
        expect(perfect.contains(normal), isFalse, reason: '${m.id} perfect 包含 normal');
      }
    });

    test('絕景 failed 與 normal 兩兩相異，長度比 <= 1.5，不互為子字串', () {
      for (final m in kyotoNightMaterials.where((m) => m.isSpotlight)) {
        final normal = m.description;
        final failed = m.failedDescription!;
        expect(failed, isNot(normal), reason: '${m.id} failed == normal');
        final ratio = [normal.characters.length, failed.characters.length]
            .reduce((a, b) => a > b ? a : b) /
            [normal.characters.length, failed.characters.length]
                .reduce((a, b) => a < b ? a : b);
        expect(ratio, lessThanOrEqualTo(1.5), reason: '${m.id} failed 長度比超標');
        expect(failed.contains(normal), isFalse, reason: '${m.id} failed 包含 normal');
      }
    });
  });
}
