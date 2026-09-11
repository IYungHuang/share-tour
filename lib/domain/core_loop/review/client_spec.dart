/// 委託客戶類型枚舉
enum ClientType {
  budgetWorker, // 極限窮遊社畜
  hypeInfluencer, // IG 網紅
}

/// 委託客戶規格值物件
class ClientSpec {
  const ClientSpec({
    required this.type,
    required this.displayName,
    required this.description,
    required this.targetBudget,
    required this.minTheme,
    required this.targetHype,
    required this.baseCommission,
  });

  final ClientType type;
  final String displayName;
  final String description;
  final int targetBudget;
  final int minTheme;
  final int targetHype;
  final int baseCommission;

  /// 客戶 A：極限窮遊社畜
  static const budgetWorker = ClientSpec(
    type: ClientType.budgetWorker,
    displayName: '極限窮遊社畜',
    description: '預算極低、精打細算，極度痛恨超支，但也拒絕坐牢般的無聊行程。',
    targetBudget: 2000,
    minTheme: 60,
    targetHype: 30,
    baseCommission: 1000,
  );

  /// 客戶 B：IG 網紅
  static const hypeInfluencer = ClientSpec(
    type: ClientType.hypeInfluencer,
    displayName: 'IG 網紅',
    description: '預算無上限，追求爆點絕景打卡照，絕不能有疲勞脫妝的拉車行程。',
    targetBudget: 8000,
    minTheme: 50,
    targetHype: 150,
    baseCommission: 2000,
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
