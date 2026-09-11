import 'dart:async';

import 'package:share_tour/domain/location/models/location_permission_gateway.dart';

class FakePermissionGateway implements LocationPermissionGateway {
  bool serviceEnabled = true;
  PlatformPermission permission = PlatformPermission.granted;
  PlatformAccuracy accuracy = PlatformAccuracy.precise;
  int requestCallCount = 0;

  final _serviceChanges = StreamController<bool>.broadcast();

  void pushServiceEnabled(bool v) {
    serviceEnabled = v;
    _serviceChanges.add(v);
  }

  void dispose() => _serviceChanges.close();

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<PlatformPermission> checkPermission() async => permission;

  @override
  Future<PlatformPermission> requestPermission() async {
    requestCallCount++;
    return permission;
  }

  @override
  Future<PlatformAccuracy> getAccuracy() async => accuracy;

  @override
  Stream<bool> get serviceEnabledChanges => _serviceChanges.stream;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}
