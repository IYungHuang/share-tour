import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/core_loop/models/curator_save_data.dart';
import '../../domain/core_loop/models/persistence_repository.dart';

/// 存檔持久化儲存庫注入點 (由 main.dart 注入 LocalPersistenceRepository，測試注入 Fake)
final persistenceRepositoryProvider = Provider<PersistenceRepository>((ref) {
  throw UnimplementedError('persistenceRepositoryProvider 必須由 main.dart 或測試注入');
});

/// 啟動時預載水合之初始存檔資料 Provider (同步提供，首幀無 FOUC)
final initialSaveDataProvider = Provider<CuratorSaveData>((ref) {
  return CuratorSaveData.initial();
});
