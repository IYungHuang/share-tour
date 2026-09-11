/// 裝備類型枚舉
enum EquipmentType {
  sneakers, // 球鞋 (擴充 HP 上限)
  camera, // 相機 (提升黃昏高潮槽位 Hype 倍率)
  waistBag, // 腰包 (擴充隨身素材攜帶上限)
}

/// 裝備升級餘額不足異常
class InsufficientCoinsException implements Exception {
  const InsufficientCoinsException(this.required, this.current);
  final int required;
  final int current;

  @override
  String toString() =>
      'InsufficientCoinsException: 升級需要 $required 幣，當前僅有 $current 幣';
}

/// 裝備已達最高等級異常
class MaxLevelReachedException implements Exception {
  const MaxLevelReachedException(this.type, this.level);
  final EquipmentType type;
  final int level;

  @override
  String toString() => 'MaxLevelReachedException: 裝備 $type 已達最高等級 $level';
}

/// 單項裝備值物件
class EquipmentItem {
  const EquipmentItem({required this.type, required this.level})
    : assert(level >= 1 && level <= 3, '裝備等級必須介於 1 與 3 之間');

  final EquipmentType type;
  final int level;

  /// 球鞋數值映射：HP 上限 (Lv.1: 100, Lv.2: 125, Lv.3: 155)
  int get maxHp {
    return switch (level) {
      1 => 100,
      2 => 125,
      _ => 155,
    };
  }

  /// 相機數值映射：黃昏高潮槽位倍率 (Lv.1: 1.5, Lv.2: 1.8, Lv.3: 2.2)
  double get cameraMultiplier {
    return switch (level) {
      1 => 1.5,
      2 => 1.8,
      _ => 2.2,
    };
  }

  /// 腰包數值映射：素材容量上限 (Lv.1: 6, Lv.2: 8, Lv.3: 10)
  int get capacity {
    return switch (level) {
      1 => 6,
      2 => 8,
      _ => 10,
    };
  }

  /// 升級下一級所需花費 (Lv.1 -> Lv.2: 300, Lv.2 -> Lv.3: 1200)
  int? get nextUpgradeCost {
    return switch (level) {
      1 => 300,
      2 => 1200,
      _ => null,
    };
  }

  /// 是否已達最高等級 (Lv.3)
  bool get isMaxLevel => level >= 3;

  /// 是否有足夠金幣進行下一級升級
  bool canAffordUpgrade(int currentCoins) =>
      nextUpgradeCost != null && currentCoins >= nextUpgradeCost!;

  EquipmentItem copyWith({int? level}) =>
      EquipmentItem(type: type, level: level ?? this.level);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentItem &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          level == other.level;

  @override
  int get hashCode => Object.hash(type, level);
}

/// 局外裝備庫存與升級狀態機
class EquipmentInventory {
  const EquipmentInventory({
    required this.coins,
    required this.sneakers,
    required this.camera,
    required this.waistBag,
  });

  /// 初始裝備 (全 Lv.1，0 金幣)
  factory EquipmentInventory.initial() => const EquipmentInventory(
    coins: 0,
    sneakers: EquipmentItem(type: EquipmentType.sneakers, level: 1),
    camera: EquipmentItem(type: EquipmentType.camera, level: 1),
    waistBag: EquipmentItem(type: EquipmentType.waistBag, level: 1),
  );

  final int coins;
  final EquipmentItem sneakers;
  final EquipmentItem camera;
  final EquipmentItem waistBag;

  /// 取出指定種類的裝備
  EquipmentItem itemOf(EquipmentType type) => switch (type) {
    EquipmentType.sneakers => sneakers,
    EquipmentType.camera => camera,
    EquipmentType.waistBag => waistBag,
  };

  /// 執行裝備升級
  EquipmentInventory upgrade(EquipmentType type) {
    final item = switch (type) {
      EquipmentType.sneakers => sneakers,
      EquipmentType.camera => camera,
      EquipmentType.waistBag => waistBag,
    };

    if (item.level >= 3) {
      throw MaxLevelReachedException(type, item.level);
    }

    final cost = item.nextUpgradeCost!;
    if (coins < cost) {
      throw InsufficientCoinsException(cost, coins);
    }

    final upgradedItem = item.copyWith(level: item.level + 1);
    final remainingCoins = coins - cost;

    return switch (type) {
      EquipmentType.sneakers => copyWith(
        coins: remainingCoins,
        sneakers: upgradedItem,
      ),
      EquipmentType.camera => copyWith(
        coins: remainingCoins,
        camera: upgradedItem,
      ),
      EquipmentType.waistBag => copyWith(
        coins: remainingCoins,
        waistBag: upgradedItem,
      ),
    };
  }

  /// 累積佣金
  EquipmentInventory addCoins(int amount) => copyWith(coins: coins + amount);

  EquipmentInventory copyWith({
    int? coins,
    EquipmentItem? sneakers,
    EquipmentItem? camera,
    EquipmentItem? waistBag,
  }) => EquipmentInventory(
    coins: coins ?? this.coins,
    sneakers: sneakers ?? this.sneakers,
    camera: camera ?? this.camera,
    waistBag: waistBag ?? this.waistBag,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentInventory &&
          runtimeType == other.runtimeType &&
          coins == other.coins &&
          sneakers == other.sneakers &&
          camera == other.camera &&
          waistBag == other.waistBag;

  @override
  int get hashCode => Object.hash(coins, sneakers, camera, waistBag);
}
