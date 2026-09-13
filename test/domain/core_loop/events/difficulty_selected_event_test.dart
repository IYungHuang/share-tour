import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/events/curator_event.dart';
import 'package:share_tour/domain/core_loop/events/curator_event_replay.dart';

CuratorEvent seq1(CuratorEventType type, Map<String, Object?> payload) =>
    CuratorEventDraft(
      eventId: 'e1',
      type: type,
      occurredAtUtc: DateTime.utc(2026, 1, 1),
      payload: payload,
    ).seal(1);

void main() {
  group('REQ-M5-06: difficultySelected 事件', () {
    test('不拋例外，且不影響存檔投影其餘欄位', () {
      final events = [
        seq1(CuratorEventType.profileCreated, {'profileId': 'p1'}),
        CuratorEventDraft(
          eventId: 'e2',
          type: CuratorEventType.difficultySelected,
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          payload: {'difficulty': 'decisiveMoment'},
        ).seal(2),
      ];
      expect(() => replayCuratorEvents(events), returnsNormally);
      final save = replayCuratorEvents(events);
      expect(save.profileId, 'p1');
      expect(save.coins, 0);
    });
  });
}
