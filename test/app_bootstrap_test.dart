import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/core_loop/kyoto_night_catalog.dart';
import 'package:share_tour/data/core_loop/local_persistence_repository.dart';
import 'package:share_tour/domain/core_loop/models/curator_save_data.dart';
import 'package:share_tour/game/map_module/manifests/kyoto_night_map_manifest.dart';
import 'package:share_tour/main.dart';
import 'package:share_tour/state/core_loop/curator_run_providers.dart';
import 'package:share_tour/state/location/location_providers.dart';

void main() {
  testWidgets('正式 App 啟動注入測試：驗證 buildProductionApp 預設注入京都圖資、京都卡表與嚴格解析器 (T10)', (tester) async {
    final repo = LocalPersistenceRepository();
    final initialSave = CuratorSaveData.initial();

    // 直接 pump 正式生產環境入口，不得手抄 overrides (測試契約規定)
    final app = buildProductionApp(
      repository: repo,
      initialSave: initialSave,
    );

    await tester.pumpWidget(app);

    // 從 Consumer / MaterialApp 子樹節點讀出 production providers
    final element = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(element);

    // 1. 驗證圖資 manifest 為 KyotoNightMapManifest
    final manifest = container.read(mapManifestProvider);
    expect(manifest, isA<KyotoNightMapManifest>());
    expect(manifest.mapId, 'kyoto_night_block');

    // 2. 驗證素材池為 Kyoto catalog (32 筆)
    final materialPool = container.read(curatorMaterialPoolProvider);
    expect(materialPool, equals(kyotoNightMaterials));
    expect(materialPool.length, 32);

    // 3. 驗證解析器能嚴格精確解析京都 manifest 中的每一個景點
    final resolver = container.read(poiMaterialResolverProvider);
    expect(resolver, isNotNull);
    expect(manifest.districtAttractions, isNotEmpty);
    for (final attraction in manifest.districtAttractions) {
      final material = resolver.resolveMaterialFor(attraction.id);
      expect(material, isNotNull,
          reason: '景點 ${attraction.id} 必須能被 production resolver 精確解析');
      expect(material!.id, attraction.id);
    }

    // 清理非同步虛擬定位定時器以正常退出測試
    await container.read(virtualSourceProvider).stop();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
