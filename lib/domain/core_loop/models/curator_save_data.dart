import 'package:uuid/uuid.dart';
import 'meta_equipment.dart';
import 'shutter_difficulty.dart';

/// 阿導永久存檔資料模型 (CC-1, CC-2, CC-3)
class CuratorSaveData {
  CuratorSaveData({
    required this.profileId,
    this.saveVersion = currentSaveVersion,
    this.lastMonotonicSeq = 0,
    required this.coins,
    required this.sneakersLevel,
    required this.cameraLevel,
    required this.waistBagLevel,
    this.completedRuns = 0,
    this.lastDifficulty = ShutterDifficulty.tourist,
    required this.updatedAtUtc,
  }) : assert(updatedAtUtc.isUtc, 'updatedAtUtc must be in UTC');

  static const int currentSaveVersion = 1;
  static const _uuid = Uuid();

  /// 實體 ID (UUID v4, CC-1)
  final String profileId;

  /// 存檔版本號 (CC-3)
  final int saveVersion;

  /// 事件日誌單調序號 (CC-3)
  final int lastMonotonicSeq;

  /// 累積總金幣 (可跨局保留並升級裝備)
  final int coins;

  /// 球鞋等級 (1..3)
  final int sneakersLevel;

  /// 相機等級 (1..3)
  final int cameraLevel;

  /// 腰包等級 (1..3)
  final int waistBagLevel;

  /// 已完成通關局數
  final int completedRuns;

  /// 最後一次選定的快門難度（REQ-M5-05.4）。
  final ShutterDifficulty lastDifficulty;

  /// 最後更新時間戳 (UTC, CC-2)
  final DateTime updatedAtUtc;

  /// 建立初始存檔 (0 金幣、全裝備 Lv.1、UUID v4)
  factory CuratorSaveData.initial({String? profileId, DateTime? nowUtc}) {
    final effectiveNow = nowUtc ?? DateTime.now().toUtc();
    return CuratorSaveData(
      profileId: profileId ?? _uuid.v4(),
      saveVersion: currentSaveVersion,
      lastMonotonicSeq: 0,
      coins: 0,
      sneakersLevel: 1,
      cameraLevel: 1,
      waistBagLevel: 1,
      completedRuns: 0,
      updatedAtUtc: effectiveNow.isUtc ? effectiveNow : effectiveNow.toUtc(),
    );
  }

  /// 還原為純領域 EquipmentInventory
  EquipmentInventory toEquipmentInventory() {
    return EquipmentInventory(
      coins: coins,
      sneakers: EquipmentItem(
        type: EquipmentType.sneakers,
        level: sneakersLevel,
      ),
      camera: EquipmentItem(type: EquipmentType.camera, level: cameraLevel),
      waistBag: EquipmentItem(
        type: EquipmentType.waistBag,
        level: waistBagLevel,
      ),
    );
  }

  // 刻意不提供 toJson / fromJson：本型別是事件日誌重播出的投影，
  // 不是持久化格式。持久化的是 CuratorEvent，最終狀態一律重播得出 (CC-3)。

  CuratorSaveData copyWith({
    String? profileId,
    int? saveVersion,
    int? lastMonotonicSeq,
    int? coins,
    int? sneakersLevel,
    int? cameraLevel,
    int? waistBagLevel,
    int? completedRuns,
    ShutterDifficulty? lastDifficulty,
    DateTime? updatedAtUtc,
  }) {
    return CuratorSaveData(
      profileId: profileId ?? this.profileId,
      saveVersion: saveVersion ?? this.saveVersion,
      lastMonotonicSeq: lastMonotonicSeq ?? this.lastMonotonicSeq,
      coins: coins ?? this.coins,
      sneakersLevel: sneakersLevel ?? this.sneakersLevel,
      cameraLevel: cameraLevel ?? this.cameraLevel,
      waistBagLevel: waistBagLevel ?? this.waistBagLevel,
      completedRuns: completedRuns ?? this.completedRuns,
      lastDifficulty: lastDifficulty ?? this.lastDifficulty,
      updatedAtUtc: (updatedAtUtc != null)
          ? (updatedAtUtc.isUtc ? updatedAtUtc : updatedAtUtc.toUtc())
          : this.updatedAtUtc,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CuratorSaveData &&
          runtimeType == other.runtimeType &&
          profileId == other.profileId &&
          saveVersion == other.saveVersion &&
          lastMonotonicSeq == other.lastMonotonicSeq &&
          coins == other.coins &&
          sneakersLevel == other.sneakersLevel &&
          cameraLevel == other.cameraLevel &&
          waistBagLevel == other.waistBagLevel &&
          completedRuns == other.completedRuns &&
          lastDifficulty == other.lastDifficulty &&
          updatedAtUtc.isAtSameMomentAs(other.updatedAtUtc);

  @override
  int get hashCode => Object.hash(
    profileId,
    saveVersion,
    lastMonotonicSeq,
    coins,
    sneakersLevel,
    cameraLevel,
    waistBagLevel,
    completedRuns,
    lastDifficulty,
    updatedAtUtc.millisecondsSinceEpoch,
  );

  @override
  String toString() =>
      'CuratorSaveData(profileId: $profileId, coins: $coins, levels: ($sneakersLevel, $cameraLevel, $waistBagLevel), runs: $completedRuns, difficulty: ${lastDifficulty.name})';
}
