import '../models/review_outcome.dart';
import '../models/timeline_itinerary.dart';
import 'client_spec.dart';

/// 雙客戶 100 分制審查與結算引擎 (純領域無副作用純函式)
class ClientReviewEngine {
  /// 執行客戶滿意度審查並輸出結算報告
  static ReviewReport evaluate({
    required ClientSpec client,
    required ItineraryStats stats,
  }) {
    switch (client.type) {
      case ClientType.budgetWorker:
        return _evaluateBudgetWorker(client, stats);
      case ClientType.hypeInfluencer:
        return _evaluateHypeInfluencer(client, stats);
    }
  }

  /// 客戶 A：極限窮遊社畜審查邏輯
  static ReviewReport _evaluateBudgetWorker(
    ClientSpec client,
    ItineraryStats stats,
  ) {
    final themeWeight = client.themeWeight;
    final maxBudgetScore = 100 - themeWeight;

    // 1. 預算得分 (滿分 100 - themeWeight = 44): 不超支得滿分，超支每 10 円扣 2 分
    final int budgetScore;
    if (stats.totalCost <= client.targetBudget) {
      budgetScore = maxBudgetScore;
    } else {
      final overspent = stats.totalCost - client.targetBudget;
      final penalty = (overspent ~/ 10) * 2;
      budgetScore = (maxBudgetScore - penalty).clamp(0, maxBudgetScore);
    }

    // 2. 主題得分 (滿分 themeWeight = 56): round(themeWeight * finalTheme / 100)
    final int themeScore = (themeWeight * stats.finalTheme / 100).round();

    // 3. 反無聊懲罰 (Boredom Penalty): Hype < 30 扣 25 分
    final int boredomPenalty = (stats.totalHype < 30) ? 25 : 0;

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

    final earnedCoins =
        (client.baseCommission * outcome.commissionRate).round() +
        (stats.totalStory * 5);

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
        'totalCost': stats.totalCost,
        'targetBudget': client.targetBudget,
      },
    );
  }

  /// 客戶 B：IG 網紅審查邏輯
  static ReviewReport _evaluateHypeInfluencer(
    ClientSpec client,
    ItineraryStats stats,
  ) {
    // 1. 疲勞脫妝懲罰: 每次拉車疲勞扣 15 Hype
    final fatiguePenaltyHype = stats.fatiguePairs.length * 15;
    final netHype = (stats.totalHype - fatiguePenaltyHype).clamp(0, 999999);

    // 2. 絕景打五折: 無 isSpotlight 乘 0.5
    final spotlightMultiplier = stats.hasSpotlight ? 1.0 : 0.5;
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

    final earnedCoins =
        (client.baseCommission * outcome.commissionRate).round() +
        (stats.totalStory * 5);

    return ReviewReport(
      clientType: client.type.name,
      satisfaction: satisfaction,
      outcome: outcome,
      earnedCoins: earnedCoins,
      feedbackQuote: quote,
      subscores: {
        'netHype': netHype,
        'fatiguePenaltyHype': fatiguePenaltyHype,
        'effectiveHype': effectiveHype,
        'spotlightMultiplier': spotlightMultiplier,
        'themeFactor': themeFactor,
      },
    );
  }
}
