import 'dart:async';

import 'package:share_tour/data/location/location_source.dart';
import 'package:share_tour/domain/location/models/geo_fix.dart';

class FakeLocationSource implements LocationSource {
  final _controller = StreamController<GeoFix>.broadcast();
  int startCount = 0;
  int cancelCount = 0;
  int lastKnownQueryCount = 0;

  void emit(GeoFix fix) => _controller.add(fix);

  @override
  Stream<GeoFix> get fixes => _controller.stream;

  @override
  Future<void> start() async => startCount++;

  @override
  Future<void> stop() async => cancelCount++;

  void dispose() => _controller.close();
}
