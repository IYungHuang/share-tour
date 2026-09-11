import 'package:share_tour/domain/core_loop/models/poi_material_resolver.dart';
import 'package:share_tour/domain/core_loop/models/travel_material.dart';

/// 台灣各大熱門景點專屬素材對照庫 (城市即實體 DLC，G7)
final Map<String, TravelMaterial> taiwanAttractionMaterials = {
  // 台北
  'tp_101': const TravelMaterial(
    id: 'mat_tp_101',
    name: '台北101觀景台',
    tags: ['#地標', '#夜景', '#絕景'],
    themeValue: 35,
    hypeValue: 90,
    isSpotlight: true,
    storyValue: 5,
    cost: 600,
    riskLevel: 2,
    description: '俯瞰整座璀璨台北盆地天際線，黃昏日落與夜景雙重震撼。',
  ),
  'tp_palace_museum': const TravelMaterial(
    id: 'mat_tp_palace',
    name: '國立故宮博物院',
    tags: ['#歷史', '#古蹟', '#偶然'],
    themeValue: 30,
    hypeValue: 70,
    isSpotlight: false,
    storyValue: 5,
    cost: 350,
    riskLevel: 1,
    description: '典藏近七十萬件中華皇家珍寶，翠玉白菜與毛公鼎的工藝之美。',
  ),
  'tp_cksmh': const TravelMaterial(
    id: 'mat_tp_cksmh',
    name: '中正紀念堂自由廣場',
    tags: ['#散步', '#地標', '#老街'],
    themeValue: 20,
    hypeValue: 50,
    isSpotlight: false,
    storyValue: 3,
    cost: 0,
    riskLevel: 1,
    description: '宏偉八角藍白殿堂與儀隊交接，市民清晨慢跑與白鴿群聚處。',
  ),
  'tp_yangmingshan': const TravelMaterial(
    id: 'mat_tp_yangmingshan',
    name: '陽明山小油坑火山噴煙',
    tags: ['#自然', '#高風險', '#絕景'],
    themeValue: 25,
    hypeValue: 75,
    isSpotlight: true,
    storyValue: 4,
    cost: 100,
    riskLevel: 3,
    description: '後火山地質壯觀硫磺噴氣孔，山嵐與白煙交織的奇異荒野。',
  ),
  'tp_ximen': const TravelMaterial(
    id: 'mat_tp_ximen',
    name: '西門町徒步區潮流夜市',
    tags: ['#美食', '#銅板美食', '#深夜'],
    themeValue: 25,
    hypeValue: 65,
    isSpotlight: false,
    storyValue: 3,
    cost: 250,
    riskLevel: 2,
    description: '次文化與潮流聚集地，阿宗麵線與街頭藝人的深夜熱鬧。',
  ),
  'tp_raohe': const TravelMaterial(
    id: 'mat_tp_raohe',
    name: '饒河街觀光夜市胡椒餅',
    tags: ['#美食', '#深夜食堂', '#銅板美食'],
    themeValue: 30,
    hypeValue: 60,
    isSpotlight: false,
    storyValue: 3,
    cost: 200,
    riskLevel: 2,
    description: '熱氣騰騰酥脆炭烤胡椒餅與藥燉排骨，滿滿市井煙火氣。',
  ),
  'tp_dadaocheng': const TravelMaterial(
    id: 'mat_tp_dadaocheng',
    name: '大稻埕迪化街老街散策',
    tags: ['#老街', '#放空', '#慢旅行'],
    themeValue: 30,
    hypeValue: 55,
    isSpotlight: false,
    storyValue: 4,
    cost: 150,
    riskLevel: 1,
    description: '百年紅磚巴洛克洋樓、南北乾貨香與碼頭絕美夕陽貨櫃市集。',
  ),
  'tp_beitou': const TravelMaterial(
    id: 'mat_tp_beitou',
    name: '北投溫泉地熱谷硫磺青磺泉',
    tags: ['#放空', '#慢旅行', '#巷弄秘境'],
    themeValue: 28,
    hypeValue: 60,
    isSpotlight: false,
    storyValue: 4,
    cost: 300,
    riskLevel: 2,
    description: '日治和風百年溫泉鄉，煙霧繚繞如仙境的綠玉色地熱谷。',
  ),
};

/// 台灣圖資專屬 POI 素材解析器
class TaiwanPoiMaterialResolver implements PoiMaterialResolver {
  const TaiwanPoiMaterialResolver();

  @override
  TravelMaterial? resolveMaterialFor(String poiId) {
    // 1. 優先比對知名景點專屬卡牌
    if (taiwanAttractionMaterials.containsKey(poiId)) {
      return taiwanAttractionMaterials[poiId];
    }

    // 2. 通用兜底規則：根據 POI 前綴或屬性動態合成特色卡牌
    final name = _friendlyNameFor(poiId);
    return TravelMaterial(
      id: 'mat_$poiId',
      name: name,
      tags: _tagsFor(poiId),
      themeValue: 20,
      hypeValue: 45,
      storyValue: 3,
      cost: 150,
      riskLevel: 2,
      description: '在地探索與漫步取材收穫的旅行回憶。',
    );
  }

  String _friendlyNameFor(String id) {
    if (id.contains('101')) return '台北101觀景台';
    if (id.contains('palace')) return '故宮古物探秘';
    if (id.contains('night')) return '在地熱門夜市';
    if (id.contains('temple')) return '古剎香火祈福';
    if (id.contains('lake')) return '湖光山色倒影';
    if (id.contains('mountain')) return '蒼翠步道山景';
    return '在地名勝踩線取材';
  }

  List<String> _tagsFor(String id) {
    if (id.contains('food') || id.contains('night')) {
      return ['#美食', '#銅板美食', '#深夜'];
    }
    if (id.contains('culture') || id.contains('temple')) {
      return ['#歷史', '#老街', '#偶然'];
    }
    if (id.contains('nature') || id.contains('mountain')) {
      return ['#自然', '#放空', '#絕景'];
    }
    return ['#散步', '#慢旅行'];
  }
}
