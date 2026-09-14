import 'shot_tier.dart';

/// 旅行素材不可變實體
class TravelMaterial {
  const TravelMaterial({
    required this.id,
    required this.name,
    required this.tags,
    required this.themeValue,
    required this.hypeValue,
    this.isSpotlight = false,
    this.storyValue = 1,
    this.cost = 0,
    this.riskLevel = 1,
    this.description = '',
    this.shotTier = ShotTier.normal,
    this.perfectDescription,
    this.failedDescription,
  }) : assert(themeValue >= 0, 'themeValue 必須大於等於 0'),
       assert(hypeValue >= 0, 'hypeValue 必須大於等於 0'),
       assert(storyValue >= 1 && storyValue <= 5, 'storyValue 必須介於 1 與 5 之間'),
       assert(cost >= 0, 'cost 必須大於等於 0'),
       assert(riskLevel >= 1 && riskLevel <= 5, 'riskLevel 必須介於 1 與 5 之間');

  /// 素材唯一代碼
  final String id;

  /// 素材名稱 (例：01:00 幽靈自販機、先斗町迷路三花貓)
  final String name;

  /// 主題標籤 (例：#深夜, #怪談, #銅板美食)
  final List<String> tags;

  /// 基礎主題分數
  final int themeValue;

  /// 基礎熱度分數
  final int hypeValue;

  /// 是否為焦點絕景 (IG 網紅核心訴求)
  final bool isSpotlight;

  /// 故事厚度 (1~5 星；結算時每 1 星折算 5 點佣金)
  final int storyValue;

  /// 採集/踩線預算開銷
  final int cost;

  /// 風險等級 (1~5 星)
  final int riskLevel;

  /// 描述文案（`normal` 版）
  final String description;

  /// 快門三態（REQ-M5-01.1），預設 `normal`——既有卡表與測試零改動。
  final ShotTier shotTier;

  /// `perfect` 版描述文案，`null` 時 [descriptionFor] 回退至 [description]。
  final String? perfectDescription;

  /// `failed` 版描述文案（僅絕景素材撰寫，REQ-M5-12.5），
  /// `null` 時 [descriptionFor] 回退至 [description]。
  final String? failedDescription;

  /// 依三態取得對應描述文案（REQ-M5-02.9）。
  String descriptionFor(ShotTier tier) => switch (tier) {
    ShotTier.normal => description,
    ShotTier.perfect => perfectDescription ?? description,
    ShotTier.failed => failedDescription ?? description,
  };

  /// 是否包含特定標籤
  bool hasTag(String tag) => tags.contains(tag);

  /// 是否具備拉車疲勞風險 (riskLevel >= 3)
  bool get hasFatigueRisk => riskLevel >= 3;

  /// 與另一個素材是否具備至少 1 個共同標籤
  bool sharesTagWith(TravelMaterial other) =>
      tags.any((tag) => other.tags.contains(tag));

  TravelMaterial copyWith({
    String? id,
    String? name,
    List<String>? tags,
    int? themeValue,
    int? hypeValue,
    bool? isSpotlight,
    int? storyValue,
    int? cost,
    int? riskLevel,
    String? description,
    ShotTier? shotTier,
    String? perfectDescription,
    String? failedDescription,
  }) => TravelMaterial(
    id: id ?? this.id,
    name: name ?? this.name,
    tags: tags != null ? List.unmodifiable(tags) : this.tags,
    themeValue: themeValue ?? this.themeValue,
    hypeValue: hypeValue ?? this.hypeValue,
    isSpotlight: isSpotlight ?? this.isSpotlight,
    storyValue: storyValue ?? this.storyValue,
    cost: cost ?? this.cost,
    riskLevel: riskLevel ?? this.riskLevel,
    description: description ?? this.description,
    shotTier: shotTier ?? this.shotTier,
    perfectDescription: perfectDescription ?? this.perfectDescription,
    failedDescription: failedDescription ?? this.failedDescription,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TravelMaterial &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          themeValue == other.themeValue &&
          hypeValue == other.hypeValue &&
          isSpotlight == other.isSpotlight &&
          storyValue == other.storyValue &&
          cost == other.cost &&
          riskLevel == other.riskLevel;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    themeValue,
    hypeValue,
    isSpotlight,
    storyValue,
    cost,
    riskLevel,
  );

  @override
  String toString() =>
      'TravelMaterial($id, $name, tags: $tags, hype: $hypeValue, theme: $themeValue, risk: $riskLevel)';
}
