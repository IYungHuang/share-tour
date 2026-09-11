import 'travel_material.dart';

/// 腰包容量已滿異常
class InventoryFullException implements Exception {
  const InventoryFullException(this.capacity);
  final int capacity;

  @override
  String toString() => 'InventoryFullException: 腰包已達容量上限 ($capacity)，無法直接加入新素材';
}

/// 腰包素材庫存管理實體 (不可變集合)
class MaterialInventory {
  MaterialInventory({required this.capacity, List<TravelMaterial>? materials})
    : materials = List.unmodifiable(materials ?? const []);

  /// 容量上限 (由腰包裝備等級決定：6 / 8 / 10)
  final int capacity;

  /// 已持有的旅行素材清單 (不可變清單)
  final List<TravelMaterial> materials;

  /// 當前素材數量
  int get count => materials.length;

  /// 是否已滿
  bool get isFull => count >= capacity;

  /// 加入新素材 (若滿額拋出 InventoryFullException)
  MaterialInventory add(TravelMaterial item) {
    if (isFull) {
      throw InventoryFullException(capacity);
    }
    final nextList = List<TravelMaterial>.from(materials)..add(item);
    return MaterialInventory(capacity: capacity, materials: nextList);
  }

  /// 滿額替換 (剔除 dropIndex 素材並在該位置或尾端存入 newItem)
  MaterialInventory replace({
    required int dropIndex,
    required TravelMaterial newItem,
  }) {
    if (dropIndex < 0 || dropIndex >= materials.length) {
      throw RangeError.index(dropIndex, materials, 'dropIndex');
    }
    final nextList = List<TravelMaterial>.from(materials);
    nextList[dropIndex] = newItem;
    return MaterialInventory(capacity: capacity, materials: nextList);
  }

  /// 移除指定素材
  MaterialInventory removeAt(int index) {
    if (index < 0 || index >= materials.length) {
      throw RangeError.index(index, materials, 'index');
    }
    final nextList = List<TravelMaterial>.from(materials)..removeAt(index);
    return MaterialInventory(capacity: capacity, materials: nextList);
  }

  /// 清空腰包
  MaterialInventory clear() =>
      MaterialInventory(capacity: capacity, materials: const []);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialInventory &&
          runtimeType == other.runtimeType &&
          capacity == other.capacity &&
          count == other.count &&
          _listEquals(materials, other.materials);

  static bool _listEquals(List<TravelMaterial> a, List<TravelMaterial> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(capacity, Object.hashAll(materials));
}
