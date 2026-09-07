import 'package:share_tour/data/location/wakelock_control.dart';

class FakeWakelockControl implements WakelockControl {
  int enableCount = 0;
  int disableCount = 0;

  @override
  Future<void> enable() async => enableCount++;

  @override
  Future<void> disable() async => disableCount++;
}
