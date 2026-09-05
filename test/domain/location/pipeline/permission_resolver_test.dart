import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/data/location/location_permission_gateway.dart';
import 'package:share_tour/domain/location/models/location_status.dart';
import 'package:share_tour/domain/location/pipeline/permission_resolver.dart';
import '../../../fakes/fake_permission_gateway.dart';

void main() {
  late FakePermissionGateway gateway;
  late PermissionResolver resolver;

  setUp(() {
    gateway = FakePermissionGateway();
    resolver = PermissionResolver(gateway: gateway);
  });

  tearDown(() {
    resolver.dispose();
    gateway.dispose();
  });

  test('AC-1.1 服務關閉時不請求權限', () async {
    gateway.serviceEnabled = false;
    expect(await resolver.resolve(), PermissionState.serviceDisabled);
    expect(gateway.requestCallCount, 0,
        reason: '服務總開關關閉時請求權限會靜默失敗');
  });

  test('AC-1.2 權限為 denied → 請求一次；允許後為 ready', () async {
    // 平台語意：denied 的意思是「尚未取得，應該去請求」，不是「使用者拒絕了」。
    // 首次啟動時 checkPermission 回傳的就是 denied——把它當成終局，
    // 權限對話框永遠不會出現。這是真機測試抓到的實際缺陷。
    gateway.permission = PlatformPermission.denied;
    await resolver.resolve();
    expect(gateway.requestCallCount, 1, reason: 'denied 必須觸發請求');

    gateway.permission = PlatformPermission.granted;
    expect(await resolver.resolve(), PermissionState.ready);
  });

  test('請求後仍為 denied → 才回報 denied', () async {
    gateway.permission = PlatformPermission.denied;
    expect(await resolver.resolve(), PermissionState.denied);
    expect(gateway.requestCallCount, 1);
  });

  test('notDetermined（僅 web）同樣觸發請求', () async {
    gateway.permission = PlatformPermission.notDetermined;
    await resolver.resolve();
    expect(gateway.requestCallCount, 1);
  });

  test('AC-1.4 並發呼叫 3 次，權限請求器只被呼叫 1 次', () async {
    gateway.permission = PlatformPermission.denied;
    await Future.wait(
        [resolver.resolve(), resolver.resolve(), resolver.resolve()]);
    expect(gateway.requestCallCount, 1);
  });

  test('AC-1.5 平台回報 reduced → approximate，不需等待任何 Fix', () async {
    gateway.accuracy = PlatformAccuracy.reduced;
    expect(await resolver.resolve(), PermissionState.approximate);
  });

  test('AC-1.6 approximate 的恢復不依賴訂閱', () async {
    gateway.accuracy = PlatformAccuracy.reduced;
    expect(await resolver.resolve(), PermissionState.approximate);
    // 不餵任何 Fix、不建立任何訂閱
    gateway.accuracy = PlatformAccuracy.precise;
    expect(await resolver.resolve(), PermissionState.ready,
        reason: 'approximate 期間訂閱已取消，恢復路徑不得依賴它');
  });

  test('AC-1.7 前景中服務被關閉 → serviceDisabled', () async {
    final states = <PermissionState>[];
    final sub = resolver.states.listen(states.add);
    gateway.pushServiceEnabled(false);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(states.last, PermissionState.serviceDisabled);
  });

  test('AC-1.8 服務恢復 → 重新檢查並更新', () async {
    gateway.pushServiceEnabled(false);
    await Future<void>.delayed(Duration.zero);
    gateway.pushServiceEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(await resolver.resolve(), PermissionState.ready);
  });

  test('AC-0.2 精度啟發式在品質過濾之前評估', () async {
    // 注入恆為 2000 m 的原始 Fix：它們會被品質閘門丟棄，
    // 但精度等級仍必須判定得出來。
    for (var i = 0; i < 3; i++) {
      resolver.observeRawFix(accuracyMeters: 2000);
    }
    expect(await resolver.resolve(), PermissionState.approximate);
  });

  test('啟發式需連續 3 筆，中間插入好的讀數就重算', () async {
    resolver.observeRawFix(accuracyMeters: 2000);
    resolver.observeRawFix(accuracyMeters: 20);
    resolver.observeRawFix(accuracyMeters: 2000);
    resolver.observeRawFix(accuracyMeters: 2000);
    expect(await resolver.resolve(), PermissionState.ready);
  });

  test('permission 為 deniedForever 時不請求', () async {
    gateway.permission = PlatformPermission.deniedForever;
    expect(await resolver.resolve(), PermissionState.deniedForever);
    expect(gateway.requestCallCount, 0);
  });
}
