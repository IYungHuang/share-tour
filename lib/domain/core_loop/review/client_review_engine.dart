import '../models/review_outcome.dart';
import '../models/shot_tier.dart';
import '../models/shutter_difficulty.dart';
import '../models/timeline_itinerary.dart';
import '../models/travel_philosophy.dart';
import '../shutter/shutter_params.dart';
import 'client_spec.dart';

/// 雙客戶 100 分制審查與結算引擎 (純領域無副作用純函式)
class ClientReviewEngine {
  /// 焦點絕景階梯乘數 (D5: 0, 1, 2, 3, 4 張)
  static const List<double> spotlightLadder = [0.70, 0.75, 0.80, 0.85, 1.00];

  /// 退件故事金幣折算率 (D11: 30%)
  static const int rejectedStoryRatePercent = 30;

  /// 第二層分數折金幣係數（REQ-M5-02.6，v9 定案為 0.36）。
  ///
  /// 由 32 張全池最壞情況反推：4 絕景全 `perfect` × `decisiveMoment`，
  /// reach 上界 619.5，$c=0.36$ 得 223 金幣，貼著 15% 上界 225（餘裕
  /// 0.9%）。**紀錄性風味，不是報酬通道**——中位數金幣只佔佣金低個位數
  /// 百分比是封閉解，換哪個 c 都一樣；真正的經濟誘因在難度的絕對期望值
  /// 上（見 SPEC §1.4 意圖 2），不需要靠金幣再加碼一次。
  static const double secondLayerCoinRate = 0.36;

  /// CP 值分母下限（REQ-M5-02.4）：擋掉「幾乎不花錢」造成的 CP 爆衝，
  /// 也讓上界反推不需要 clamp。
  static const int cpFloor = 2000;

  /// 第二層金幣硬性上界佔 `baseCommission` 的比例（AC-M5-5.8）。
  static const double secondLayerCoinCapRatio = 0.15;

  /// 執行客戶滿意度審查並輸出結算報告
  static ReviewReport evaluate({
    required ClientSpec client,
    required ItineraryStats stats,
    required TravelPhilosophy philosophy,
    ShutterDifficulty difficulty = ShutterDifficulty.tourist,
    double interruptionDiscount = 1.0,
  }) {
    switch (client.type) {
      case ClientType.budgetWorker:
        return _evaluateBudgetWorker(
          client,
          stats,
          philosophy,
          difficulty,
          interruptionDiscount,
        );
      case ClientType.hypeInfluencer:
        return _evaluateHypeInfluencer(
          client,
          stats,
          philosophy,
          difficulty,
          interruptionDiscount,
        );
    }
  }

  /// 第二層原始量：六分量各自乘上對應 `tierFactor` 後加總。
  /// 未套絕景階梯／CP 分母——那是兩個客戶各自的加工，留給呼叫端。
  static double _secondLayerRaw(
    ItineraryStats stats,
    ShutterDifficulty difficulty,
  ) {
    double f(ShotTier tier, {required bool isSpotlight}) =>
        tierFactorFor(difficulty, tier, isSpotlight: isSpotlight);
    return stats.failedSpotlightHype * f(ShotTier.failed, isSpotlight: true) +
        stats.failedNonSpotlightHype * f(ShotTier.failed, isSpotlight: false) +
        stats.normalSpotlightHype * f(ShotTier.normal, isSpotlight: true) +
        stats.normalNonSpotlightHype *
            f(ShotTier.normal, isSpotlight: false) +
        stats.perfectSpotlightHype * f(ShotTier.perfect, isSpotlight: true) +
        stats.perfectNonSpotlightHype *
            f(ShotTier.perfect, isSpotlight: false);
  }


  /// 客戶 A：極限窮遊社畜審查邏輯
  static ReviewReport _evaluateBudgetWorker(
    ClientSpec client,
    ItineraryStats stats,
    TravelPhilosophy philosophy,
    ShutterDifficulty difficulty,
    double interruptionDiscount,
  ) {
    final themeWeight = client.themeWeight;
    final maxBudgetScore = 100 - themeWeight;

    // 1. 預算得分 (滿分 100 - themeWeight = 44): 不超支得滿分，超支依預算比例扣分 (D7)
    final int budgetScore;
    if (stats.totalCost <= client.targetBudget) {
      budgetScore = maxBudgetScore;
    } else {
      final overspendRatio =
          (stats.totalCost - client.targetBudget) / client.targetBudget;
      final penalty = (overspendRatio * client.overspendPenaltyPoints).round();
      budgetScore = (maxBudgetScore - penalty).clamp(0, maxBudgetScore);
    }

    // 2. 主題得分 (滿分 themeWeight = 56): round(themeWeight * finalTheme / 100)
    final int themeScore = (themeWeight * stats.finalTheme / 100).round();

    // 3. 反無聊懲罰 (Boredom Penalty): Hype < client.boredomThreshold 扣 25 分 (D7)
    final int boredomPenalty =
        (stats.totalHype < client.boredomThreshold) ? 25 : 0;

    // 4. 總滿意度計算
    final int satisfaction = (budgetScore + themeScore - boredomPenalty).clamp(
      0,
      100,
    );

    // 5. 評判分級 (Perfect >= 90, Pass >= 70, Near Miss >= 60, Rejected < 60)
    final ReviewOutcome outcome;
    final String quote;
    if (satisfaction >= 90) {
      outcome = ReviewOutcome.perfect;
      quote = '太神了阿導！用這麼少預算竟然玩得這麼充實，下個月我還要找你！';
    } else if (satisfaction >= 70) {
      outcome = ReviewOutcome.pass;
      quote = '還不錯，錢花得剛剛好，至少休假沒被浪費掉。';
    } else if (satisfaction >= 60) {
      outcome = ReviewOutcome.nearMiss;
      if (boredomPenalty > 0) {
        quote = '差一點點！雖然省了錢，但這行程也未免太像坐牢了…稍微來點亮點好嗎？';
      } else {
        quote = '差一點點就過關了！可惜最後稍微超支了一點點，荷包在淌血啊…';
      }
    } else {
      outcome = ReviewOutcome.rejected;
      if (boredomPenalty > 0) {
        quote = '退件！我是窮，但我不是來受罪坐牢的！這行程無聊透頂！';
      } else {
        quote = '退件！超支成這樣，我下半個月只能吃土了！這筆帳我不認！';
      }
    }

    final storyBonus = outcome == ReviewOutcome.rejected
        ? (stats.totalStory * 5 * rejectedStoryRatePercent / 100).round()
        : stats.totalStory * 5;

    // 第二層：社畜「CP 值」（REQ-M5-02.4）。地板擋掉幾乎不花錢造成的爆衝，
    // 也擋掉「只排免費卡靠極小分母換巨大 CP」的退化策略。
    final secondLayerRaw = _secondLayerRaw(stats, difficulty);
    final costDenominator = stats.totalCost < cpFloor ? cpFloor : stats.totalCost;
    final valueIndex = (secondLayerRaw / costDenominator * 1000).round();
    final l2CoinsBeforeRejection =
        (valueIndex * secondLayerCoinRate * interruptionDiscount).round();
    final l2Coins = outcome == ReviewOutcome.rejected
        ? (l2CoinsBeforeRejection * rejectedStoryRatePercent / 100).round()
        : l2CoinsBeforeRejection;

    final earnedCoins =
        (client.baseCommission * outcome.commissionRate).round() +
            storyBonus +
            l2Coins;

    final purityBonus = stats.purityBonus;
    final themeFatigue = stats.fatiguePairs.length * 10;

    return ReviewReport(
      clientType: client.type.name,
      satisfaction: satisfaction,
      outcome: outcome,
      earnedCoins: earnedCoins,
      feedbackQuote: quote,
      subscores: {
        'budgetScore': budgetScore,
        'themeScore': themeScore,
        'boredomPenalty': boredomPenalty,
        'boredomThreshold': client.boredomThreshold,
        'maxBudgetScore': maxBudgetScore,
        'themeWeight': themeWeight,
        'totalCost': stats.totalCost,
        'targetBudget': client.targetBudget,
        'l2Score': valueIndex,
        'l2Coins': l2Coins,
        'purityBonus': purityBonus,
        'themeFatigue': themeFatigue,
      },
    );
  }

  /// 客戶 B：IG 網紅審查邏輯
  static ReviewReport _evaluateHypeInfluencer(
    ClientSpec client,
    ItineraryStats stats,
    TravelPhilosophy philosophy,
    ShutterDifficulty difficulty,
    double interruptionDiscount,
  ) {
    // 1. 疲勞脫妝懲罰 / 冒險連段 (D4 + REQ-A1-14)
    // 每組相鄰高風險疲勞扣除/加成 targetHype 的 14% (21 Hype)
    final fatigueDeltaHype =
        (client.targetHype * 14 / 100).round() * stats.fatiguePairs.length;
    final int netHype;
    final int adventureCombo;
    final int hypeFatigue;
    if (philosophy.turnsAdjacentHighRiskIntoHypeCombo) {
      // 混亂冒險：相鄰高風險轉為冒險連段加成
      netHype = stats.totalHype + fatigueDeltaHype;
      adventureCombo = fatigueDeltaHype;
      hypeFatigue = 0;
    } else {
      netHype = (stats.totalHype - fatigueDeltaHype).clamp(0, 999999);
      adventureCombo = 0;
      hypeFatigue = fatigueDeltaHype;
    }

    // 2. 絕景階梯係數 (D5: 0..4 階梯)
    final ladderIndex = stats.spotlightCount.clamp(0, 4);
    final spotlightMultiplier = spotlightLadder[ladderIndex];
    final effectiveHype = (netHype * spotlightMultiplier).round();

    // 3. 主題加權係數: (floor + (100 - floor) * (Theme / 100)) / 100
    final floor = client.themeFloor;
    final themeFactor =
        (floor + (100 - floor) * (stats.finalTheme / 100.0)) / 100.0;

    // 4. 滿意度計算
    final rawScore = (effectiveHype / client.targetHype) * 100.0 * themeFactor;
    final int satisfaction = rawScore.round().clamp(0, 100);

    // 5. 評判分級 (Perfect >= 90, Pass >= 70, Near Miss >= 50, Rejected < 50)
    final ReviewOutcome outcome;
    final String quote;
    if (satisfaction >= 90) {
      outcome = ReviewOutcome.perfect;
      quote = 'OMG！照片發出去讚數直接暴動！這張黃昏絕景簡視神仙機位，阿導太懂拍了！';
    } else if (satisfaction >= 70) {
      outcome = ReviewOutcome.pass;
      quote = '限時動態回響很棒，這次合作算過關啦～下次有私房秘境記得再約！';
    } else if (satisfaction >= 50) {
      outcome = ReviewOutcome.nearMiss;
      if (!stats.hasSpotlight) {
        quote = '氛圍其實很嗨，但最關鍵的黃昏時段居然沒有招牌絕景打卡照！只差臨門一腳太可惜了！';
      } else if (stats.fatiguePairs.isNotEmpty) {
        quote = '景點很美，但行程趕到我脫妝、黑眼圈都跑出來了！濾鏡都差點救不回來！';
      } else {
        quote = '熱度稍微差了一點點，要是再來一張奇蹟美照就完美了！';
      }
    } else {
      outcome = ReviewOutcome.rejected;
      quote = '退件！發出去根本沒人按讚，甚至被粉絲問是不是去踩雷！阿導你認真的嗎？！';
    }

    final storyBonus = outcome == ReviewOutcome.rejected
        ? (stats.totalStory * 5 * rejectedStoryRatePercent / 100).round()
        : stats.totalStory * 5;

    // 第二層：網紅「擴散觸及」（REQ-M5-02.4）。沿用上面已算好的絕景階梯
    // 係數——它與第一層的 hype 縮放用的是同一個 spotlightCount 索引。
    final secondLayerRaw = _secondLayerRaw(stats, difficulty);
    final reach = (secondLayerRaw * spotlightMultiplier).round();
    final l2CoinsBeforeRejection =
        (reach * secondLayerCoinRate * interruptionDiscount).round();
    final l2Coins = outcome == ReviewOutcome.rejected
        ? (l2CoinsBeforeRejection * rejectedStoryRatePercent / 100).round()
        : l2CoinsBeforeRejection;

    final earnedCoins =
        (client.baseCommission * outcome.commissionRate).round() +
            storyBonus +
            l2Coins;

    final purityBonus = stats.purityBonus;
    final themeFatigue = stats.fatiguePairs.length * 10;

    return ReviewReport(
      clientType: client.type.name,
      satisfaction: satisfaction,
      outcome: outcome,
      earnedCoins: earnedCoins,
      feedbackQuote: quote,
      subscores: {
        'netHype': netHype,
        'fatigueDeltaHype': fatigueDeltaHype,
        'effectiveHype': effectiveHype,
        'spotlightMultiplier': spotlightMultiplier,
        'spotlightCount': stats.spotlightCount,
        'themeFactor': themeFactor,
        'l2Score': reach,
        'l2Coins': l2Coins,
        'purityBonus': purityBonus,
        'themeFatigue': themeFatigue,
        'adventureCombo': adventureCombo,
        'hypeFatigue': hypeFatigue,
      },
    );
  }
}
