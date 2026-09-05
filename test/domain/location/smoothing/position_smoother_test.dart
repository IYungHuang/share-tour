import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:share_tour/domain/location/projection/map_manifest.dart';
import 'package:share_tour/domain/location/smoothing/position_smoother.dart';
import '../../../fakes/fake_map_manifest.dart';

PositionSmoother smoother({OverworldMapManifest? manifest}) => PositionSmoother(
      manifest: manifest ?? FakeMapManifest.linear(), // 公尺/像素 = 1.0
      halfLife: const Duration(seconds: 1),
      arrivalMeters: 2,
      headingMeters: 5,
    );

void main() {
  test('AC-6.1 距離單調遞減', () {
    final s = smoother()..setTarget(Vector2(100, 0));
    var prev = 100.0;
    for (var i = 0; i < 30; i++) {
      s.update(1 / 30);
      final d = (Vector2(100, 0) - s.rendered).length;
      expect(d, lessThan(prev));
      prev = d;
    }
  });

  test('AC-6.2 幀率無關：30fps 與 120fps 推進 1 秒，差距 < 初始距離的 1%', () {
    final a = smoother()..setTarget(Vector2(100, 0));
    final b = smoother()..setTarget(Vector2(100, 0));
    for (var i = 0; i < 30; i++) {
      a.update(1 / 30);
    }
    for (var i = 0; i < 120; i++) {
      b.update(1 / 120);
    }
    expect((a.rendered - b.rendered).length, lessThan(1.0));
  });

  test('AC-6.3 經過一個半衰期，剩餘距離為初始的 50%', () {
    final s = smoother()..setTarget(Vector2(100, 0));
    for (var i = 0; i < 60; i++) {
      s.update(1 / 60);
    }
    final remaining = (Vector2(100, 0) - s.rendered).length;
    expect(remaining, inInclusiveRange(45, 55));
    // 加嚴：把指數形式釘死。k = 1/halfLife 的誤寫會得 36.8；
    // Euler 近似會得約 50.3，仍在 ±5 內，但這條 0.05 的容差擋得住。
    expect(remaining, closeTo(50.0, 0.05));
  });

  test('AC-6.4 已抵達後不再變動', () {
    final s = smoother()..setTarget(Vector2(0.5, 0)); // < 2px 抵達門檻
    s.update(1.0);
    final r = s.rendered.clone();
    s.update(1.0);
    expect(s.rendered, equals(r));
  });

  test('AC-6.6 顯示點與目標點無別名', () {
    final target = Vector2(100, 0);
    final s = smoother()..setTarget(target);
    s.update(1.0);
    final before = s.rendered.clone();
    target.setValues(999, 999); // 直接改呼叫端持有的向量
    s.update(1.0);
    expect((s.rendered - before).length, lessThan(60),
        reason: 'Vector2 可變，參考指派會讓平滑靜默失效而測試照樣通過');
  });

  test('AC-6.7 抵達門檻依公尺/像素比例換算', () {
    final a = smoother()..setTarget(Vector2(0, 0));
    final b = smoother(manifest: FakeMapManifest.fixedScale(370.4))
      ..setTarget(Vector2(0, 0));
    expect(a.arrivalThresholdPixels, closeTo(2.0, 0.01));
    expect(b.arrivalThresholdPixels, closeTo(0.0054, 0.0005));
  });

  test('AC-6.8 換算值以當時顯示點重算，同一次更新期間不變', () {
    // nonLinear: mpp = 1.0 + x/1000
    final s = smoother(manifest: FakeMapManifest.nonLinear())
      ..setTarget(Vector2(1000, 0));
    final atStart = s.arrivalThresholdPixels;
    expect(atStart, closeTo(2.0, 0.01), reason: '顯示點在 x=0 → mpp=1.0');
    for (var i = 0; i < 60; i++) {
      s.update(1 / 60);
    }
    expect(s.arrivalThresholdPixels, atStart,
        reason: '同一次目標點更新期間不得重算');
    s.setTarget(Vector2(1000, 0)); // 顯示點已移到 x≈500 → mpp≈1.5
    expect(s.arrivalThresholdPixels, lessThan(atStart));
  });

  test('AC-6.9 朝向門檻雙向', () {
    // 目標點刻意不在 +x 軸上：atan2(0, x) 恆為 0，會與初始朝向相同而測不出差別。
    final s = smoother()..setTarget(Vector2(0, 100));
    final h0 = s.headingRadians;
    expect(h0, 0.0);
    s.update(1 / 600); // 單幀位移遠小於 5px
    expect(s.headingRadians, h0, reason: '未達門檻不得更新朝向');
    s.update(0.5); // 單幀位移約 29px > 5px
    expect(s.headingRadians, closeTo(math.pi / 2, 0.01), reason: '朝向應轉為 +y');
  });

  test('jumpTo 不平滑，直接指定顯示點', () {
    final s = smoother()..setTarget(Vector2(0, 0));
    s.jumpTo(Vector2(500, 500));
    expect(s.rendered, Vector2(500, 500));
  });
}
