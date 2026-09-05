import 'dart:async';

import '../../../core/time/clock.dart';
import '../models/geo_fix.dart';

/// throttleLatest：leading + trailing。
///
/// 窗內第一筆立即放行，其餘合併於窗尾補發一次最新的。不採用只在窗尾取樣的做法
/// ——那會固定引入一整個窗的延遲，與平滑位移追求的手感直接衝突。
///
/// 虛擬來源的 Fix 直接放行：它以固定頻率產生，本來就沒有需要合併的突發。
class FixThrottle {
  FixThrottle({required Clock clock, required this.window}) : _clock = clock;

  final Clock _clock;
  final Duration window;

  final _controller = StreamController<GeoFix>.broadcast();
  Duration? _windowOpenedAt;
  GeoFix? _pending;
  bool _trailingScheduled = false;

  Stream<GeoFix> get output => _controller.stream;

  void add(GeoFix fix) {
    if (fix.sourceMode == SourceMode.virtual) {
      _controller.add(fix);
      return;
    }

    final openedAt = _windowOpenedAt;
    if (openedAt == null || _clock.elapsed - openedAt >= window) {
      _windowOpenedAt = _clock.elapsed;
      _controller.add(fix);
      return;
    }

    _pending = fix;
    if (!_trailingScheduled) {
      _trailingScheduled = true;
      unawaited(_scheduleTrailing(openedAt));
    }
  }

  Future<void> _scheduleTrailing(Duration openedAt) async {
    final remaining = window - (_clock.elapsed - openedAt);
    await _clock.delay(remaining > Duration.zero ? remaining : Duration.zero);
    _trailingScheduled = false;
    final pending = _pending;
    _pending = null;
    if (pending != null && !_controller.isClosed) {
      _windowOpenedAt = _clock.elapsed;
      _controller.add(pending);
    }
  }

  void dispose() => _controller.close();
}
