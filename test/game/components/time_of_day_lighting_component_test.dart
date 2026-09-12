import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/models/tour_time_of_day.dart';
import 'package:share_tour/game/components/time_of_day_lighting_component.dart';

void main() {
  group('TimeOfDayLightingComponent 測試', () {
    test('在各時段皆能正常渲染且無例外', () {
      TourTimeOfDay currentTime = TourTimeOfDay.dawn;

      final component = TimeOfDayLightingComponent(
        mapSize: Vector2(1024, 1024),
        timeOfDayGetter: () => currentTime,
        playerPositionGetter: () => Vector2(512, 512),
        lightPositionsGetter: () => [Vector2(100, 100), Vector2(200, 200)],
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // 晨曦
      currentTime = TourTimeOfDay.dawn;
      expect(() => component.render(canvas), returnsNormally);

      // 午後
      currentTime = TourTimeOfDay.midday;
      expect(() => component.render(canvas), returnsNormally);

      // 黃昏 (觸發暖黃燈籠與提燈)
      currentTime = TourTimeOfDay.dusk;
      expect(() => component.render(canvas), returnsNormally);

      // 深夜 (強烈暗夜與暖光)
      currentTime = TourTimeOfDay.night;
      expect(() => component.render(canvas), returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });
  });
}
