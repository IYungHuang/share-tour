import 'meta_equipment.dart';

/// 阿導 3+1 核心資源狀態機 (HP, Budget, Theme, Hype)
class GuideResources {
  const GuideResources({
    required this.hp,
    required this.maxHp,
    required this.budget,
    required this.theme,
    required this.hype,
  });

  /// 建立新局初始資源
  factory GuideResources.initial({
    required int startingBudget,
    required EquipmentInventory equipment,
  }) {
    final maxHp = equipment.sneakers.maxHp;
    return GuideResources(
      hp: maxHp,
      maxHp: maxHp,
      budget: startingBudget,
      theme: 50,
      hype: 0,
    );
  }

  /// 體力資源 (介於 0 與 maxHp 之間)
  final int hp;

  /// 當前上限 (由球鞋等級決定：100 / 115 / 130)
  final int maxHp;

  /// 旅行開銷預算 (允許負數表示赤字)
  final int budget;

  /// 主題靈魂分數 (恆介於 0 與 100 之間)
  final int theme;

  /// 亮點熱度分數 (大於等於 0)
  final int hype;

  /// 體力是否透支 (強制回辦公室)
  bool get isExhausted => hp <= 0;

  /// 當前 HP 別名
  int get currentHp => hp;

  /// 是否處於預算赤字狀態
  bool get isDeficit => budget < 0;

  /// 當前 Budget 別名
  int get currentBudget => budget;

  /// 消耗體力
  GuideResources consumeHp(int amount) {
    assert(amount >= 0, '消耗體力必須大於等於 0');
    final nextHp = (hp - amount).clamp(0, maxHp);
    return copyWith(hp: nextHp);
  }

  /// 回復體力
  GuideResources restoreHp(int amount) {
    assert(amount >= 0, '回復體力必須大於等於 0');
    final nextHp = (hp + amount).clamp(0, maxHp);
    return copyWith(hp: nextHp);
  }

  /// 開銷預算 (可為負數)
  GuideResources spendBudget(int amount) {
    return copyWith(budget: budget - amount);
  }

  /// 增減主題分數 (自帶 [0, 100] clamp)
  GuideResources adjustTheme(int delta) {
    final nextTheme = (theme + delta).clamp(0, 100);
    return copyWith(theme: nextTheme);
  }

  /// 增加熱度分數
  GuideResources addHype(int amount) {
    assert(amount >= 0, '增加熱度必須大於等於 0');
    return copyWith(hype: hype + amount);
  }

  GuideResources copyWith({
    int? hp,
    int? maxHp,
    int? budget,
    int? theme,
    int? hype,
  }) => GuideResources(
    hp: hp ?? this.hp,
    maxHp: maxHp ?? this.maxHp,
    budget: budget ?? this.budget,
    theme: theme ?? this.theme,
    hype: hype ?? this.hype,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuideResources &&
          runtimeType == other.runtimeType &&
          hp == other.hp &&
          maxHp == other.maxHp &&
          budget == other.budget &&
          theme == other.theme &&
          hype == other.hype;

  @override
  int get hashCode => Object.hash(hp, maxHp, budget, theme, hype);

  @override
  String toString() =>
      'GuideResources(hp: $hp/$maxHp, budget: $budget, theme: $theme, hype: $hype)';
}
