import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/shot_tier.dart';
import 'package:share_tour/domain/core_loop/models/shutter_difficulty.dart';
import 'package:share_tour/domain/core_loop/shutter/shutter_params.dart';

void main() {
  group('kDifficultyTimings（REQ-M5-01.8）', () {
    test('tourist 參數', () {
      final t = kDifficultyTimings[ShutterDifficulty.tourist]!;
      expect(t.tMatchMs, 1400);
      expect(t.perfectWindowMs, 800);
      expect(t.normalWindowMs, isNull);
      expect(t.animationLengthMs, 2000);
    });

    test('photographer 參數（v9 收窄後的 160）', () {
      final t = kDifficultyTimings[ShutterDifficulty.photographer]!;
      expect(t.tMatchMs, 1100);
      expect(t.perfectWindowMs, 160);
      expect(t.normalWindowMs, 720);
      expect(t.animationLengthMs, 1600);
    });

    test('decisiveMoment 參數', () {
      final t = kDifficultyTimings[ShutterDifficulty.decisiveMoment]!;
      expect(t.tMatchMs, 800);
      expect(t.perfectWindowMs, 120);
      expect(t.normalWindowMs, 300);
      expect(t.animationLengthMs, 1200);
    });

    test('AC-M5-1.4: 三檔難度 Wp >= 120 ms', () {
      for (final d in ShutterDifficulty.values) {
        expect(kDifficultyTimings[d]!.perfectWindowMs, greaterThanOrEqualTo(120));
      }
    });
  });

  group('tierFactorFor（AC-M5-2.3，兩張表）', () {
    test('非絕景表逐格核對', () {
      expect(
        tierFactorFor(ShutterDifficulty.tourist, ShotTier.failed, isSpotlight: false),
        0.90,
      );
      expect(
        tierFactorFor(ShutterDifficulty.tourist, ShotTier.normal, isSpotlight: false),
        1.00,
      );
      expect(
        tierFactorFor(ShutterDifficulty.tourist, ShotTier.perfect, isSpotlight: false),
        1.05,
      );
      expect(
        tierFactorFor(ShutterDifficulty.photographer, ShotTier.failed, isSpotlight: false),
        0.72,
      );
      expect(
        tierFactorFor(ShutterDifficulty.photographer, ShotTier.perfect, isSpotlight: false),
        1.22,
      );
      expect(
        tierFactorFor(ShutterDifficulty.decisiveMoment, ShotTier.failed, isSpotlight: false),
        0.62,
      );
      expect(
        tierFactorFor(ShutterDifficulty.decisiveMoment, ShotTier.perfect, isSpotlight: false),
        1.70,
      );
    });

    test('絕景表逐格核對（v7 定案，覆核 P0）', () {
      expect(
        tierFactorFor(ShutterDifficulty.tourist, ShotTier.perfect, isSpotlight: true),
        1.05,
        reason: 'tourist 絕景沿用非絕景表',
      );
      expect(
        tierFactorFor(ShutterDifficulty.photographer, ShotTier.failed, isSpotlight: true),
        0.938,
      );
      expect(
        tierFactorFor(ShutterDifficulty.photographer, ShotTier.perfect, isSpotlight: true),
        1.292,
      );
      expect(
        tierFactorFor(ShutterDifficulty.decisiveMoment, ShotTier.failed, isSpotlight: true),
        0.735,
      );
      expect(
        tierFactorFor(ShutterDifficulty.decisiveMoment, ShotTier.perfect, isSpotlight: true),
        2.031,
      );
    });

    test('normal 恆為 1.00（含絕景）', () {
      for (final d in ShutterDifficulty.values) {
        expect(tierFactorFor(d, ShotTier.normal, isSpotlight: false), 1.00);
        expect(tierFactorFor(d, ShotTier.normal, isSpotlight: true), 1.00);
      }
    });
  });

  group('靜態檢查', () {
    test('AC-M5-1.8: 參數表模組原始碼不出現 riskLevel/cameraLevel', () async {
      final src = await File(
        'lib/domain/core_loop/shutter/shutter_params.dart',
      ).readAsString();
      expect(src.contains('riskLevel'), isFalse);
      expect(src.contains('cameraLevel'), isFalse);
    });
  });
}
