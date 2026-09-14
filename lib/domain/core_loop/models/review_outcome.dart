/// 客戶審查評判結果枚舉
enum ReviewOutcome {
  perfect(commissionRate: 1.5, label: '完美通關'),
  pass(commissionRate: 1.0, label: '普通驗收'),
  nearMiss(commissionRate: 0.3, label: '差一點點'),
  rejected(commissionRate: 0.0, label: '慘遭退件');

  const ReviewOutcome({required this.commissionRate, required this.label});

  final double commissionRate;
  final String label;
}

/// 審查結算報告實體 (含前端動畫所需之分步子分數)
class ReviewReport {
  const ReviewReport({
    required this.clientType,
    required this.satisfaction,
    required this.outcome,
    required this.earnedCoins,
    required this.feedbackQuote,
    required this.subscores,
  });

  /// 客戶代碼 (budgetWorker / hypeInfluencer)
  final String clientType;

  /// 最終滿意度分數 (0~100)
  final int satisfaction;

  /// 四級評判結果
  final ReviewOutcome outcome;

  /// 本局結算賺取之總佣金 (含故事星等折現)
  final int earnedCoins;

  /// 客戶毒舌或吹捧的反饋台詞
  final String feedbackQuote;

  /// 視覺動畫所需之子步驟分數 (View-Ready Subscores)
  final Map<String, num> subscores;

  /// 第二層分數本身（`reach` 或 `valueIndex`，REQ-M5-02.4）——
  /// 這是玩家看到的核心回饋，`l2Coins` 只是把它折成的一點點尾款。
  int get l2Score => (subscores['l2Score'] ?? 0).toInt();

  /// 第二層折算的金幣（REQ-M5-02.6），已計入 [earnedCoins]。
  int get l2Coins => (subscores['l2Coins'] ?? 0).toInt();

  int get purityBonus => (subscores['purityBonus'] ?? 0).toInt();
  int get themeFatigue => (subscores['themeFatigue'] ?? 0).toInt();
  int get adventureCombo => (subscores['adventureCombo'] ?? 0).toInt();
  int get hypeFatigue => (subscores['hypeFatigue'] ?? 0).toInt();
  int get spotlightCount => (subscores['spotlightCount'] ?? 0).toInt();
  int get boredomThreshold => (subscores['boredomThreshold'] ?? 168).toInt();
  int get maxBudgetScore => (subscores['maxBudgetScore'] ?? 44).toInt();
  int get themeWeight => (subscores['themeWeight'] ?? 56).toInt();
  bool get hasPurityBonus => subscores.containsKey('purityBonus');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewReport &&
          runtimeType == other.runtimeType &&
          clientType == other.clientType &&
          satisfaction == other.satisfaction &&
          outcome == other.outcome &&
          earnedCoins == other.earnedCoins;

  @override
  int get hashCode =>
      Object.hash(clientType, satisfaction, outcome, earnedCoins);

  @override
  String toString() =>
      'ReviewReport($clientType: $satisfaction分 [${outcome.label}], 佣金: $earnedCoins, 台詞: "$feedbackQuote")';
}
