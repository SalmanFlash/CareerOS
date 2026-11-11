import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:careeros/backup.dart';
import 'package:careeros/plan.dart';

void main() {
  Plan fixture() => Plan()
    ..missions.add(
      Mission(
        'one',
        '2026-11-11',
        title: 'Private assignment',
        note: 'آزمائش',
        campus: 'Karachi',
        step: 1,
        state: 'running',
        suggestedDeadline: '2026-11-15',
        deadlineEvidence: 'Due 2026-11-15',
        noticeFingerprint: 'same-notice',
      ),
    );
  test(
    'backup round trip preserves notes, candidate dates and checkpoints',
    () {
      final p = fixture();
      expect(readBackup(writeBackup(p)).toJson(), p.toJson());
    },
  );
  test('merge preserves local conflicts, preferences and both input plans', () {
    final current = fixture()..english = true;
    current.missions.first.note = 'Newer local work';
    final incoming = fixture()..examUntil = '2026-11-20';
    incoming.missions.addAll([
      Mission('copied-notice', '2026-11-11', noticeFingerprint: 'same-notice'),
      Mission(
        'new',
        '2026-11-11',
        title: 'New task',
        url: 'https://example.com/job',
      ),
      Mission('same-link', '2026-11-11', url: 'https://example.com/job'),
    ]);
    final result = mergeBackup(current, incoming);
    expect(result.added, 1);
    expect(result.kept, 3);
    expect(result.plan.english, true);
    expect(result.plan.examUntil, '');
    expect(result.plan.missions.first.note, 'Newer local work');
    expect(current.missions.length, 1);
    expect(incoming.missions.length, 4);
    expect(mergeBackup(result.plan, incoming).added, 0);
  });
  test(
    'unsafe URLs, bad dates, invalid steps and unknown future fields are rejected',
    () {
      for (final edit in <void Function(Map)>[
        (m) => m['url'] = 'javascript:alert(1)',
        (m) => m['url'] = 'https://user:secret@example.com',
        (m) => m['deadline'] = '2026-02-30',
        (m) => m['day'] = 'not-a-date',
        (m) => m['step'] = 3,
        (m) => m['step'] = -1,
        (m) => m['state'] = 'submitted',
        (m) => m['note'] = 42,
        (m) => m['futureFeature'] = 'must not silently drop',
      ]) {
        final data = jsonDecode(writeBackup(fixture()));
        edit(data['plan']['missions'][0]);
        expect(() => readBackup(jsonEncode(data)), throwsFormatException);
      }
    },
  );
  test('unsupported schemas and duplicate ids cannot partially import', () {
    final data = jsonDecode(writeBackup(fixture()));
    data['plan']['missions'].add(data['plan']['missions'][0]);
    expect(() => readBackup(jsonEncode(data)), throwsFormatException);
    expect(() => readBackup('{"version":99}'), throwsFormatException);
    expect(() => readBackup('not json'), throwsFormatException);
  });
}
