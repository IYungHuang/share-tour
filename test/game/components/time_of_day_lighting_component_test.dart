import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/tour_time_of_day.dart';
import 'package:share_tour/domain/core_loop/time/game_time_snapshot.dart';
import 'package:share_tour/domain/core_loop/time/tour_period.dart';
import 'package:share_tour/game/components/time_of_day_lighting_component.dart';

void main() {
  group('Task 3: TimeOfDayLightingComponent 渲染與呼吸燈火測試', () {
    test('傳統 timeOfDayGetter 模式在各時段皆能正常渲染', () {
      TourTimeOfDay currentTime = TourTimeOfDay.dawn;

      final component = TimeOfDayLightingComponent(
        mapSize: Vector2(1024, 1024),
        timeOfDayGetter: () => currentTime,
        playerPositionGetter: () => Vector2(512, 512),
        lightPositionsGetter: () => [Vector2(100, 100), Vector2(200, 200)],
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      currentTime = TourTimeOfDay.dawn;
      expect(() => component.render(canvas), returnsNormally);

      currentTime = TourTimeOfDay.midday;
      expect(() => component.render(canvas), returnsNormally);

      currentTime = TourTimeOfDay.dusk;
      expect(() => component.render(canvas), returnsNormally);

      currentTime = TourTimeOfDay.night;
      expect(() => component.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('現代 timeSnapshotGetter 連續漸變與呼吸微動正常工作', () {
      var currentSnapshot = const GameTimeSnapshot(
        normalizedProgress: 0.0,
        virtualHour: 6.0,
        period: TourPeriod.dawn,
        ambientColorArgb: 0x30A5C9E8,
        lanternIntensity: 0.0,
      );

      final component = TimeOfDayLightingComponent(
        mapSize: Vector2(1024, 1024),
        timeSnapshotGetter: () => currentSnapshot,
        playerPositionGetter: () => Vector2(512, 512),
        lightPositionsGetter: () => [Vector2(100, 100), Vector2(200, 200)],
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // 晨曦
      expect(() => component.render(canvas), returnsNormally);

      // 推進時間至黃昏 (觸發燈火與提燈)
      currentSnapshot = const GameTimeSnapshot(
        normalizedProgress: 0.60,
        virtualHour: 16.8,
        period: TourPeriod.dusk,
        ambientColorArgb: 0x55F59E0B,
        lanternIntensity: 0.40,
      );

      // 模擬經過 1 秒以觸發呼吸微動
      component.update(1.0);
      expect(() => component.render(canvas), returnsNormally);

      // 推進至深夜
      currentSnapshot = const GameTimeSnapshot(
        normalizedProgress: 1.0,
        virtualHour: 24.0,
        period: TourPeriod.night,
        ambientColorArgb: 0x800B132B,
        lanternIntensity: 1.0,
      );
      component.update(0.5);
      expect(() => component.render(canvas), returnsNormally);

      // 測試切換地圖 switchMap
      component.switchMap(
        mapSize: Vector2(2048, 2048),
        lightPositions: [Vector2(300, 300)],
      );
      expect(component.mapSize, Vector2(2048, 2048));
      expect(() => component.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });
  });
}
