import 'clock.dart';

class SystemClock implements Clock {
  SystemClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  Future<void> delay(Duration duration) => Future<void>.delayed(duration);
}
