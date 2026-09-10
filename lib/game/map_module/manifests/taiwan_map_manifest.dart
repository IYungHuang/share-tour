import 'package:vector_math/vector_math.dart';

import '../../../domain/location/models/district_attraction.dart';
import '../../../domain/location/projection/control_mesh.dart';
import '../../../domain/location/projection/map_manifest.dart';
import '../models/geo_anchor.dart';
import 'classification_mask.dart';
import 'taiwan_attractions_catalog.dart';

/// 台灣圖資模組。
///
/// 現行底圖為【過渡資產】：以簡化的真實海岸線搭配等距投影生成，故公尺/像素
/// 為常數。最終手繪圖會重新引入非線性誇張，屆時錨點需重新量測，而
/// metersPerPixelAt 必須改為逐點計算。
class TaiwanMapManifest implements OverworldMapManifest {
  TaiwanMapManifest._(this._mask);

  /// 遮罩解析度 256×144，主圖層 2048×1152：scale = 8。
  /// 圖檔載入是非同步的（解碼 PNG），故建構本身也是非同步——完成後
  /// containsGeo 是常數時間的陣列查詢，不會在管線每次呼叫時重新解碼。
  static Future<TaiwanMapManifest> load() async {
    final mask = await ClassificationMask.loadFromAsset(
      'assets/maps/taiwan/mask.png',
      scale: 8,
    );
    return TaiwanMapManifest._(mask);
  }

  final ClassificationMask _mask;

  @override
  String get mapId => 'taiwan_overworld';

  String get displayName => 'TAIWAN: OVERWORLD';

  @override
  String get assetPath => 'taiwan_overworld.png';

  @override
  Vector2 get mapDimensions => Vector2(2048, 1152);

  @override
  int get oceanColorArgb => 0xFF1E6F9F;

  /// 自通用引擎搬來（PRE-7）：降落點是圖資的一部分，不是引擎的常數。
  @override
  Vector2 get defaultSpawnPixel => Vector2(1162, 148);

  /// 暫定值，由任務 D 依地方層尺度裁決。
  ///
  /// 以像素/秒表達而非真實速度：在 370 公尺/像素下，步行 5 km/h 要 4.4 分鐘
  /// 才移動一個像素，台北到高雄需連續操作近六小時。
  @override
  double get dpadSpeedPixelsPerSecond => 40;

  /// 過渡底圖為等距投影，故為常數；最終手繪圖需改為逐點計算。
  @override
  double metersPerPixelAt(Vector2 pixel) => 370.4;

  /// 校準控制網。
  ///
  /// 三角化是【圖資資料】，不是演算法：控制網怎麼佈取決於這張圖哪裡誇張、
  /// 哪裡忠實。此處的三角形由 8 個錨點的 Delaunay 三角化算出。
  ///
  /// 現行底圖是等距生成的，所以重心插值在這張圖上等同於原本那條線性公式——
  /// 控制點精確重現、每處的解析度都是 0.268 px / 100 公尺。手繪圖上線時，
  /// 同一套機制直接支援非線性誇張，只需重標控制點與重算三角化。
  static const List<List<int>> _triangles = [
    [3, 7, 0], // 日月潭 - 鵝鑾鼻 - 基隆
    [4, 6, 7], // 阿里山 - 高雄 - 鵝鑾鼻
    [3, 4, 7], // 日月潭 - 阿里山 - 鵝鑾鼻
    [6, 4, 5], // 高雄 - 阿里山 - 台南
    [4, 2, 5], // 阿里山 - 台中 - 台南
    [2, 4, 3], // 台中 - 阿里山 - 日月潭
    [1, 3, 0], // 台北101 - 日月潭 - 基隆
    [1, 2, 3], // 台北101 - 台中 - 日月潭
  ];

  late final ControlMesh _mesh = ControlMesh(
    points: [
      for (final a in anchors)
        ControlPoint(name: a.name, lat: a.lat, lng: a.lng, pixel: a.pixelPos),
    ],
    triangles: _triangles,
  );

  @override
  late final List<AdministrativeDistrict> administrativeDistricts =
      buildTaiwanAdministrativeDistricts(_mesh);

  @override
  late final List<DistrictAttraction> districtAttractions =
      buildTaiwanAttractionsCatalog(_mesh);

  /// 校準錨點是台灣圖資的實作細節，不在通用契約上——通用引擎不需要、
  /// 也不應該知道某份圖資是用什麼方式做投影的。
  List<GeoAnchor> get anchors => [
        GeoAnchor(name: '基隆北端', lat: 25.150, lng: 121.750, pixelPos: Vector2(1213, 113)),
        GeoAnchor(name: '台北101', lat: 25.034, lng: 121.564, pixelPos: Vector2(1162, 148)),
        GeoAnchor(name: '台中歌劇院', lat: 24.163, lng: 120.640, pixelPos: Vector2(909, 408)),
        GeoAnchor(name: '日月潭', lat: 23.858, lng: 120.916, pixelPos: Vector2(985, 499)),
        GeoAnchor(name: '阿里山', lat: 23.510, lng: 120.803, pixelPos: Vector2(954, 603)),
        GeoAnchor(name: '台南赤崁樓', lat: 22.997, lng: 120.202, pixelPos: Vector2(789, 756)),
        GeoAnchor(name: '高雄85大樓', lat: 22.611, lng: 120.300, pixelPos: Vector2(816, 871)),
        GeoAnchor(name: '鵝鑾鼻南端', lat: 21.902, lng: 120.852, pixelPos: Vector2(967, 1083)),
      ];

  /// 觸發半徑暫定 50 公尺，最終數值由任務 A 裁決（PRE-10）。
  /// 原本是 35 像素——在此尺度下等於 12.96 公里，站在新竹就會觸發台北 101。
  @override
  List<PoiMarker> get poiNodes => [
        // --- 台灣前 10 大知名景點 ---
        PoiMarker(id: 'taipei_101', pixel: Vector2(1162, 148), triggerRadiusMeters: 50),
        PoiMarker(id: 'palace_museum', pixel: Vector2(1158, 128), triggerRadiusMeters: 50),
        PoiMarker(id: 'jiufen', pixel: Vector2(1222, 128), triggerRadiusMeters: 50),
        PoiMarker(id: 'taichung_opera', pixel: Vector2(909, 408), triggerRadiusMeters: 50),
        PoiMarker(id: 'taroko', pixel: Vector2(1178, 409), triggerRadiusMeters: 50),
        PoiMarker(id: 'sun_moon_lake', pixel: Vector2(985, 499), triggerRadiusMeters: 50),
        PoiMarker(id: 'alishan', pixel: Vector2(954, 603), triggerRadiusMeters: 50),
        PoiMarker(id: 'chihkan_tower', pixel: Vector2(789, 756), triggerRadiusMeters: 50),
        PoiMarker(id: 'kaohsiung_85', pixel: Vector2(816, 871), triggerRadiusMeters: 50),
        PoiMarker(id: 'eluanbi', pixel: Vector2(963, 1070), triggerRadiusMeters: 50),

        // --- 台灣高鐵全線 12 座車站 ---
        PoiMarker(id: 'thsr_nangang', pixel: Vector2(1174, 142), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_taipei', pixel: Vector2(1149, 144), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_banqiao', pixel: Vector2(1134, 154), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_taoyuan', pixel: Vector2(1066, 154), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_hsinchu', pixel: Vector2(1019, 215), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_miaoli', pixel: Vector2(960, 276), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_taichung', pixel: Vector2(903, 423), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_changhua', pixel: Vector2(891, 494), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_yunlin', pixel: Vector2(851, 535), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_chiayi', pixel: Vector2(822, 618), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_tainan', pixel: Vector2(812, 777), triggerRadiusMeters: 50),
        PoiMarker(id: 'thsr_zuoying', pixel: Vector2(818, 849), triggerRadiusMeters: 50),

        // --- 台灣前 10 大知名夜市 ---
        PoiMarker(id: 'market_keelung', pixel: Vector2(1211, 120), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_shilin', pixel: Vector2(1151, 132), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_raohe', pixel: Vector2(1168, 142), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_ningxia', pixel: Vector2(1144, 139), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_fengjia', pixel: Vector2(911, 403), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_wenhua', pixel: Vector2(857, 612), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_garden', pixel: Vector2(793, 752), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_liuhe', pixel: Vector2(822, 865), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_ruifeng', pixel: Vector2(816, 855), triggerRadiusMeters: 50),
        PoiMarker(id: 'market_luodong', pixel: Vector2(1217, 254), triggerRadiusMeters: 50),

        // --- 台灣百岳前 10 名 ---
        PoiMarker(id: 'peak_yushan', pixel: Vector2(996, 615), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_xueshan', pixel: Vector2(1071, 342), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_xiuguluan', pixel: Vector2(1023, 581), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_nanhu', pixel: Vector2(1128, 349), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_zhongyangjian', pixel: Vector2(1121, 363), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_guanshan', pixel: Vector2(982, 687), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_qilai', pixel: Vector2(1096, 421), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_dabajian', pixel: Vector2(1078, 319), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_hehuan', pixel: Vector2(1082, 414), triggerRadiusMeters: 50),
        PoiMarker(id: 'peak_beidawu', pixel: Vector2(941, 866), triggerRadiusMeters: 50),
      ];

  /// 地理範圍判定改由分類遮罩查詢（修訂四，v6），取代先前的矩形框
  /// （`lat ∈ [21.4, 25.7]`、`lng ∈ [119.7, 122.3]`——台灣海峽、太平洋皆在
  /// 框內）。查詢用的像素座標來自本模組自己的控制網投影，與 §3.0 管線
  /// 之後會再次執行的投影步驟相互獨立，不違反「範圍檢查必須在投影之前」
  /// 的排序契約——那條契約管的是管線的輸出順序，不是本模組內部怎麼求值。
  @override
  bool containsGeo(double lat, double lng) =>
      _mask.isInside(_mesh.projectToPixel(lat, lng));

  @override
  Vector2 projectToPixel(double lat, double lng) =>
      _mesh.projectToPixel(lat, lng);

  @override
  GeoPoint unprojectToGeo(Vector2 pixel) => _mesh.unprojectToGeo(pixel);
}
