/// 平台回報的權限狀態。
enum PlatformPermission { notDetermined, denied, deniedForever, granted }

/// 平台回報的精度等級。
enum PlatformAccuracy { precise, reduced, unavailable }

/// 定位權限、服務與精度的查詢介面。
///
/// geolocator 的這些能力全是靜態方法，不注入就無法在沒有真機的條件下驗證
/// 權限流程——而規格明文要求所有邏輯需求都能在無模擬器、無真機下測試。
/// 這是本任務核准的第二條抽象，它擋住的變動軸就是「平台 API 不可替換」。
abstract class LocationPermissionGateway {
  Future<bool> isServiceEnabled();
  Future<PlatformPermission> checkPermission();
  Future<PlatformPermission> requestPermission();
  Future<PlatformAccuracy> getAccuracy();
  Stream<bool> get serviceEnabledChanges;
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}
