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

  /// 推進時間並讓等待中的非同步工作有機會執行。
  ///
  /// 需要它是因為 delay 的完成走 microtask：只呼叫 advance 的話，被喚醒的
  /// 迴圈還沒機會跑到下一輪就又被推進了。
  Future<void> advanceAsync(Duration d) async {
    advance(d);
    await Future<void>.delayed(Duration.zero);
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
