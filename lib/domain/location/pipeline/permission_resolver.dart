import 'dart:async';

import '../models/location_permission_gateway.dart';
import '../models/location_status.dart';

/// 解析權限、服務與精度等級。
///
/// 精度等級以平台的權威查詢為主判定，不靠觀察 Fix 劣化。Android 的概略位置與
/// iOS 的降低精確度之下，權限查詢回報的就是「已授權」，而每一筆 Fix 都有數百
/// 公尺誤差並被品質閘門丟光——玩家看到的是授權正常但角色永遠不動，沒有任何
/// 線索可循。
///
/// 這也順帶修好恢復路徑：查詢不需要訂閱，所以玩家去系統設定打開精確位置後
/// 就能脫離該狀態。若改用「等 Fix 變好」判定，訂閱早已因為進入該狀態而取消，
/// 永遠等不到。
class PermissionResolver {
  PermissionResolver({required LocationPermissionGateway gateway})
      : _gateway = gateway {
    _serviceSub = _gateway.serviceEnabledChanges.listen((_) async {
      _controller.add(await resolve());
    });
  }

  final LocationPermissionGateway _gateway;
  final _controller = StreamController<PermissionState>.broadcast();
  StreamSubscription<bool>? _serviceSub;

  /// 在途的請求，用於去重：並發呼叫共用同一個 Future，
  /// 否則系統對話框會被重複跳出。
  Future<PermissionState>? _inFlight;

  int _consecutiveCoarse = 0;
  static const _coarseThresholdMeters = 500.0;
  static const _coarseRunLength = 3;

  Stream<PermissionState> get states => _controller.stream;

  void dispose() {
    _serviceSub?.cancel();
    _controller.close();
  }

  /// 輔助啟發式：在品質過濾【之前】對原始 Fix 評估。
  /// 若排在過濾之後，這些 Fix 早已被丟光，精度等級就無從判定。
  void observeRawFix({required double accuracyMeters}) {
    if (accuracyMeters > _coarseThresholdMeters) {
      _consecutiveCoarse++;
      // 恰好跨過門檻時推一次。啟發式若只在 resolve() 被呼叫時才生效，
      // 就得靠輪詢或運氣——而規則 4 的情境（精度持續劣化）不會自己觸發查詢。
      if (_consecutiveCoarse == _coarseRunLength) {
        unawaited(_emitResolved());
      }
    } else {
      _consecutiveCoarse = 0;
    }
  }

  Future<void> _emitResolved() async {
    final state = await resolve();
    if (!_controller.isClosed) _controller.add(state);
  }

  Future<PermissionState> resolve() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _resolve();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<PermissionState> _resolve() async {
    // 順序固定：服務總開關 → 權限 →（必要時）請求。
    // 服務關閉時請求權限會靜默失敗，所以不能顛倒。
    if (!await _gateway.isServiceEnabled()) {
      return PermissionState.serviceDisabled;
    }

    var permission = await _gateway.checkPermission();

    // 平台語意：denied 的意思是「尚未取得，應該去請求」，不是「使用者拒絕了」。
    // Android 首次啟動時 checkPermission 回傳的就是 denied；把它當成終局，
    // 權限對話框永遠不會出現，玩家看到的是一個從未問過就宣稱被拒的 app。
    //
    // deniedForever 才是終局——那時再請求，系統也不會顯示對話框。
    if (permission == PlatformPermission.denied ||
        permission == PlatformPermission.notDetermined) {
      permission = await _gateway.requestPermission();
    }

    switch (permission) {
      case PlatformPermission.denied:
        return PermissionState.denied;
      case PlatformPermission.deniedForever:
        return PermissionState.deniedForever;
      case PlatformPermission.notDetermined:
        return PermissionState.denied;
      case PlatformPermission.granted:
        break;
    }

    final accuracy = await _gateway.getAccuracy();
    if (accuracy == PlatformAccuracy.unavailable) {
      return PermissionState.unavailable;
    }
    if (accuracy == PlatformAccuracy.reduced ||
        _consecutiveCoarse >= _coarseRunLength) {
      return PermissionState.approximate;
    }
    return PermissionState.ready;
  }
}
