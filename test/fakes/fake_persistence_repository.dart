import 'package:share_tour/domain/core_loop/models/curator_save_data.dart';
import 'package:share_tour/domain/core_loop/models/persistence_repository.dart';

/// 存檔持久化純記憶體 Fake 實作 (供秒級單元測試)
class FakePersistenceRepository implements PersistenceRepository {
  FakePersistenceRepository({CuratorSaveData? initialData})
      : _currentData = initialData;

  CuratorSaveData? _currentData;
  bool simulateCorruption = false;
  int saveCount = 0;
  final List<CuratorSaveData> savedHistory = [];

  @override
  Future<CuratorSaveData> loadSave() async {
    if (simulateCorruption) {
      return CuratorSaveData.initial();
    }
    return _currentData ?? CuratorSaveData.initial();
  }

  @override
  Future<void> save(CuratorSaveData data) async {
    saveCount++;
    savedHistory.add(data);
    _currentData = data;
  }

  @override
  Future<void> clearSave() async {
    _currentData = null;
    savedHistory.clear();
  }
}
