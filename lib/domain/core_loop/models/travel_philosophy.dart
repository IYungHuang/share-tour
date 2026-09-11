import 'travel_material.dart';

/// 五大固定旅行哲學枚舉
enum TravelPhilosophy {
  midnight(
    displayName: '午夜探索',
    quote: '凌晨的城市，才會說真話。',
    preferredTags: ['#深夜', '#小酌'],
    repelledTags: ['#拉車'],
  ),
  slow(
    displayName: '慢旅行',
    quote: '真正的旅行，是留時間給偶然。',
    preferredTags: ['#散步', '#古蹟'],
    repelledTags: ['#高風險'],
  ),
  gourmet(
    displayName: '美食朝聖',
    quote: '一座城市的靈魂藏在它的深夜食堂。',
    preferredTags: ['#美食', '#銅板美食', '#早餐'],
    repelledTags: ['#高風險'],
  ),
  antiTourism(
    displayName: '反觀光',
    quote: '真正的生活藏在觀光客看不到的地方。',
    preferredTags: ['#巷弄秘境', '#怪談'],
    repelledTags: ['#大眾名店'],
  ),
  chaos(
    displayName: '混亂冒險',
    quote: '最好的旅行通常從計畫失敗開始。',
    preferredTags: ['#高風險', '#拉車'],
    repelledTags: ['#散步'],
  );

  const TravelPhilosophy({
    required this.displayName,
    required this.quote,
    required this.preferredTags,
    required this.repelledTags,
  });

  final String displayName;
  final String quote;
  final List<String> preferredTags;
  final List<String> repelledTags;

  /// 評估單項素材在該哲學下的主題分數貢獻 (D2 係數分級)
  PhilosophyContribution evaluateMaterial(TravelMaterial material) {
    final hitsRepelled = repelledTags.any((tag) => material.hasTag(tag));
    if (hitsRepelled) {
      // 排斥標籤優先懲罰：單卡貢獻為 -round(themeValue * 70 / 100)
      return PhilosophyContribution(
        effectiveTheme: -(material.themeValue * 70 / 100).round(),
        flatThemePenalty: 0,
        isAligned: false,
      );
    }

    final preferredMatches =
        preferredTags.where((tag) => material.hasTag(tag)).length;
    if (preferredMatches >= 3) {
      return PhilosophyContribution(
        effectiveTheme: (material.themeValue * 92 / 100).round(),
        flatThemePenalty: 0,
        isAligned: true,
      );
    } else if (preferredMatches == 2) {
      return PhilosophyContribution(
        effectiveTheme: (material.themeValue * 90 / 100).round(),
        flatThemePenalty: 0,
        isAligned: true,
      );
    } else if (preferredMatches == 1) {
      return PhilosophyContribution(
        effectiveTheme: (material.themeValue * 40 / 100).round(),
        flatThemePenalty: 0,
        isAligned: true,
      );
    }

    // 中性素材：貢獻 0
    return const PhilosophyContribution(
      effectiveTheme: 0,
      flatThemePenalty: 0,
      isAligned: false,
    );
  }
}

/// 旅行哲學評估結果
class PhilosophyContribution {
  const PhilosophyContribution({
    required this.effectiveTheme,
    required this.flatThemePenalty,
    this.isAligned = false,
  });

  /// 經加權後的實際主題分數貢獻 (排斥為負，契合為正，中性為 0)
  final int effectiveTheme;

  /// 額外扣減的固定 Theme 點數 (保留相容性)
  final int flatThemePenalty;

  /// 是否為哲學契合素材 (命中至少 1 個偏好標籤且未排斥)
  final bool isAligned;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhilosophyContribution &&
          runtimeType == other.runtimeType &&
          effectiveTheme == other.effectiveTheme &&
          flatThemePenalty == other.flatThemePenalty &&
          isAligned == other.isAligned;

  @override
  int get hashCode => Object.hash(effectiveTheme, flatThemePenalty, isAligned);
}
