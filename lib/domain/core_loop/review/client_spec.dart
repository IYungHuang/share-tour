/// 委託客戶類型枚舉
enum ClientType {
  budgetWorker, // 極限窮遊社畜
  hypeInfluencer, // IG 網紅
}

/// 委託客戶規格值物件
class ClientSpec {
  const ClientSpec({
    required this.type,
    required this.personaName,
    required this.displayName,
    required this.description,
    required this.targetBudget,
    required this.minTheme,
    required this.targetHype,
    required this.baseCommission,
    this.themeWeight = 56,
    this.themeFloor = 44,
    this.overspendPenaltyPoints = 100,
    this.boredomHypeRatio = 560,
  });

  final ClientType type;
  final String personaName;
  final String displayName;
  final String description;
  final int targetBudget;
  final int minTheme;
  final int targetHype;
  final int baseCommission;
  final int themeWeight;
  final int themeFloor;

  /// 超支每一整份 targetBudget 扣除的預算分數 (D7: 100)
  final int overspendPenaltyPoints;

  /// 反無聊門檻佔 targetHype 的百分比 (D7: 560%)
  final int boredomHypeRatio;

  /// 反無聊 Hype 門檻 (D7: 依 targetHype 比例計算，30 * 560% = 168)
  int get boredomThreshold => (targetHype * boredomHypeRatio / 100).round();

  /// 客戶 A：極限窮遊社畜
  static const budgetWorker = ClientSpec(
    type: ClientType.budgetWorker,
    personaName: '小林',
    displayName: '極限窮遊社畜',
    description: '預算極低、精打細算，極度痛恨超支，但也拒絕坐牢般的無聊行程。',
    targetBudget: 2000,
    minTheme: 60,
    targetHype: 30,
    baseCommission: 1000,
    themeWeight: 56,
    overspendPenaltyPoints: 100,
    boredomHypeRatio: 560,
  );

  /// 客戶 B：IG 網紅
  static const hypeInfluencer = ClientSpec(
    type: ClientType.hypeInfluencer,
    personaName: '安娜',
    displayName: 'IG 網紅',
    description: '預算無上限，追求爆點絕景打卡照，絕不能有疲勞脫妝的拉車行程。',
    targetBudget: 8000,
    minTheme: 50,
    targetHype: 150,
    baseCommission: 1500,
    themeFloor: 44,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientSpec &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;
}
