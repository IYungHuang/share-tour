import 'kyoto_district_street_manifest.dart';

/// 京都中觀街區圖資模組（洛中・河原町散步區）
///
/// 1024x1024 獨立町家街區像素地圖，呈現木屋町、先斗町、錦市場等 9 大核心景點。
/// 支援從京都盆地宏觀層以 16-Bit 馬賽克蒙太奇轉場切換進入。
class KyotoStreetBlockManifest extends KyotoDistrictStreetManifest {
  const KyotoStreetBlockManifest() : super(KyotoDistrictType.nakagyo);

  static Future<KyotoStreetBlockManifest> load() async =>
      const KyotoStreetBlockManifest();

  static const double minLat = 35.0000;
  static const double maxLat = 35.0120;
  static const double minLng = 135.7480;
  static const double maxLng = 135.7760;
}
