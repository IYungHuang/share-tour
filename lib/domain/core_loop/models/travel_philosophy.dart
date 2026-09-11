import 'travel_material.dart';

/// 五大固定旅行哲學枚舉
enum TravelPhilosophy {
  midnight(
    displayName: '午夜探索',
    quote: '凌晨的城市，才會說真話。',
    preferredTags: ['#深夜', '#怪談', '#孤獨'],
    repelledTags: [],
  ),
  slow(
    displayName: '慢旅行',
    quote: '真正的旅行，是留時間給偶然。',
    preferredTags: ['#放空', '#老街', '#偶然'],
    repelledTags: [],
  ),
  gourmet(
    displayName: '美食朝聖',
    quote: '一座城市的靈魂藏在它的深夜食堂。',
    preferredTags: ['#深夜食堂', '#地道', '#銅板美食'],
    repelledTags: [],
  ),
  antiTourism(
    displayName: '反觀光',
    quote: '真正的生活藏在觀光客看不到的地方。',
    preferredTags: ['#巷弄秘境', '#無人', '#廢墟'],
    repelledTags: ['#大眾名店'],
  ),
  chaos(
    displayName: '混亂冒險',
    quote: '最好的旅行通常從計畫失敗開始。',
    preferredTags: ['#高風險', '#突發', '#奇葩'],
    repelledTags: [],
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

  /// 評估單項素材在該哲學下的主題分數貢獻
  PhilosophyContribution evaluateMaterial(TravelMaterial material) {
    final hitsRepelled = repelledTags.any((tag) => material.hasTag(tag));
    if (hitsRepelled) {
      // 排斥標籤優先懲罰：貢獻打五折，且額外扣除 5 點 Theme
      return PhilosophyContribution(
        effectiveTheme: (material.themeValue * 0.5).round(),
        flatThemePenalty: 5,
      );
    }

    final hitsPreferred = preferredTags.any((tag) => material.hasTag(tag));
    if (hitsPreferred) {
      // 偏好標籤加成：一次性 +50% 加成
      return PhilosophyContribution(
        effectiveTheme: (material.themeValue * 1.5).round(),
        flatThemePenalty: 0,
      );
    }

    // 中性素材：按原本數值計算
    return PhilosophyContribution(
      effectiveTheme: material.themeValue,
      flatThemePenalty: 0,
    );
  }
}

/// 旅行哲學評估結果
class PhilosophyContribution {
  const PhilosophyContribution({
    required this.effectiveTheme,
    required this.flatThemePenalty,
  });

  /// 經加權後的實際主題分數
  final int effectiveTheme;

  /// 額外扣減的固定 Theme 點數 (如排斥標籤罰 5 點)
  final int flatThemePenalty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhilosophyContribution &&
          runtimeType == other.runtimeType &&
          effectiveTheme == other.effectiveTheme &&
          flatThemePenalty == other.flatThemePenalty;

  @override
  int get hashCode => Object.hash(effectiveTheme, flatThemePenalty);
}
