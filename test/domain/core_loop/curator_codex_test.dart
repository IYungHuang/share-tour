import 'package:flutter_test/flutter_test.dart';
import 'package:share_tour/domain/core_loop/causal/curator_codex.dart';

void main() {
  group('CuratorCodex 詞庫契約測試 (AC-CF-2.2)', () {
    const expectedReasonCodes = [
      'fatigue_spike',
      'fatigue_hype_penalty',
      'chaotic_combo',
      'rhythm_complement',
      'philosophy_repelled',
      'philosophy_matched_major',
      'philosophy_matched_minor',
      'budget_overrun_minor',
      'budget_overrun_major',
      'spotlight_shortfall',
      'spotlight_full',
      'boredom_risk',
      'tag_synergy',
      'ambient_slot_affinity',
    ];

    test('全數 14 個 reasonCode 皆有非空詞條且欄位完整', () {
      expect(CuratorCodex.entries.length, equals(14));

      for (final code in expectedReasonCodes) {
        final entry = CuratorCodex.lookup(code);
        expect(entry, isNotNull, reason: '找不到 reasonCode: $code 的詞條');
        expect(entry!.title, isNotEmpty, reason: '$code 的 title 不得為空');
        expect(entry.jargon, isNotEmpty, reason: '$code 的 jargon 不得為空');
        expect(entry.explanation, isNotEmpty, reason: '$code 的 explanation 不得為空');
        expect(entry.guideNote, isNotEmpty, reason: '$code 的 guideNote 不得為空');
      }
    });

    test('詞庫全文不含具名城市字串 (taiwan, kyoto, 台灣, 京都)', () {
      final forbiddenWords = ['taiwan', 'kyoto', '台灣', '京都'];

      for (final entry in CuratorCodex.entries.values) {
        final fullText = '${entry.title} ${entry.jargon} ${entry.explanation} ${entry.guideNote}'.toLowerCase();
        for (final word in forbiddenWords) {
          expect(fullText.contains(word.toLowerCase()), isFalse,
              reason: '詞條 ${entry.title} 包含具名城市詞彙: $word');
        }
      }
    });
  });
}
