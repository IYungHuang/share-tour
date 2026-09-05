import 'dart:async';

import 'package:share_tour/core/time/clock.dart';

class FakeClock implements Clock {
  DateTime _wall = DateTime.utc(2026, 1, 1);
  Duration _elapsed = Duration.zero;
  final List<_PendingDelay> _pending = [];

  void advance(Duration d) {
    _elapsed += d;
    _wall = _wall.add(d);
    final due = _pending.where((p) => p.dueAt <= _elapsed).toList();
    for (final p in due) {
      _pending.remove(p);
      p.completer.complete();
    }
  }

  /// 只動牆鐘，不動單調時間——模擬使用者調整系統時間或 NTP 回跳。
  void setWallClock(DateTime t) => _wall = t.toUtc();

  @override
  DateTime nowUtc() => _wall;

  @override
  Duration get elapsed => _elapsed;

  @override
  Future<void> delay(Duration duration) {
    final completer = Completer<void>();
    _pending.add(_PendingDelay(_elapsed + duration, completer));
    return completer.future;
  }
}

class _PendingDelay {
  _PendingDelay(this.dueAt, this.completer);
  final Duration dueAt;
  final Completer<void> completer;
}
