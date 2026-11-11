import 'dart:convert';
import 'package:careeros/plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const day = '2026-11-04';
  test(
    'application records never infer submission from mission completion',
    () {
      final m = Mission('listing', day, url: 'https://example.com/job');
      m.state = 'done';
      expect(m.tracked, false);
      m.recordApplication('applied', day, '2026-11-07', 'Check portal');
      expect(m.state, 'done');
      expect(m.appliedOn, day);
      m.recordApplication('interview', '2026-11-06', '2026-11-09', 'Prepare');
      expect(m.appliedOn, day);
      expect(m.applicationUpdated, '2026-11-06');
      final restored = Mission.read(m.toJson());
      expect(restored.toJson(), m.toJson());
      m.recordApplication(
        'closed',
        '2026-11-07',
        '2026-11-09',
        'No longer pursuing',
      );
      expect(m.followUp, '');
      expect(m.state, 'done');
    },
  );
  test(
    'due follow-ups persist independently of skipped or completed missions',
    () {
      final p = Plan();
      for (final (id, due, stage, state) in [
        ('later', '2026-11-05', 'applied', 'done'),
        ('overdue', '2026-11-02', 'preparing', 'skipped'),
        ('today', day, 'interview', 'done'),
        ('closed', day, 'closed', 'done'),
      ]) {
        final m = Mission(
          id,
          day,
          url: 'https://example.com/$id',
          state: state,
        );
        m.recordApplication(stage, day, due, '');
        p.missions.add(m);
      }
      expect(p.followUps(day).map((m) => m.id), ['overdue', 'today']);
      p.examUntil = day;
      expect(p.followUps(day).length, 2);
    },
  );
  test('invalid application updates cannot partially mutate a record', () {
    final m = Mission('listing', day, url: 'https://example.com/job');
    final before = m.toJson();
    for (final (stage, date, next) in [
      ('sent', day, ''),
      ('applied', 'bad', ''),
      ('applied', day, '2026-02-30'),
    ]) {
      expect(
        () => m.recordApplication(stage, date, next, ''),
        throwsFormatException,
      );
      expect(m.toJson(), before);
    }
    for (final m in [
      Mission('demo0', day, url: 'https://example.com'),
      Mission('mail', day, url: 'https://example.com', campus: 'Lahore'),
    ]) {
      expect(
        () => m.recordApplication('applied', day, '', ''),
        throwsFormatException,
      );
    }
  });
  test(
    'a saved notice remains linked when the other campus copy becomes newest',
    () {
      final original = Plan()
        ..missions.add(
          Mission(
            'karachi-message',
            day,
            noticeFingerprint: 'same-source-content',
            state: 'done',
          ),
        );
      final restored = Plan.read(jsonDecode(jsonEncode(original.toJson())));
      expect(
        restored.noticeMission('lahore-copy', 'same-source-content')?.id,
        'karachi-message',
      );
      expect(restored.noticeMission('unrelated', ''), isNull);
      expect(restored.noticeMission('karachi-message', ''), isNotNull);
    },
  );
  test(
    'upcoming FAST deadline leads in Exam Mode without changing postponed tasks',
    () {
      final p = Plan()..examUntil = day;
      p.missions.addAll([
        Mission('a', day),
        Mission('later', '2026-11-06', campus: 'Lahore', deadline: day),
        Mission(
          'urgent',
          day,
          title: 'Upload project',
          subject: 'Submission',
          campus: 'Karachi',
          deadline: '2026-11-05',
        ),
      ]);
      final restored = Plan.read(jsonDecode(jsonEncode(p.toJson())));
      final notice = restored.today(day).single;
      expect(notice.id, 'urgent');
      expect(notice.steps[1].$2, 'Upload project');
      expect(notice.subject, 'Submission');
      notice.state = 'done';
      expect(restored.today(day).single.id, 'a');
    },
  );
  test('legacy mission without notice fields loads', () {
    final m = Mission.read({
      'id': 'demo0',
      'day': day,
      'title': '',
      'state': 'running',
      'step': 1,
      'note': '',
      'url': '',
    });
    expect(m.campus, isEmpty);
    expect(m.steps, cvSteps);
  });
  test('PKT day rolls over at 19:00 UTC', () {
    expect(dayAt(DateTime.utc(2026, 11, 3, 18, 59)), '2026-11-03');
    expect(dayAt(DateTime.utc(2026, 11, 3, 19)), day);
  });
  test('overdue tasks return, postponed and finished tasks stay out', () {
    final p = Plan()
      ..missions.addAll([
        Mission('old', '2026-11-03'),
        Mission('later', '2026-11-05'),
        Mission('finished', day, state: 'done'),
        Mission('skip', day, state: 'skipped'),
      ]);
    expect(p.today(day).map((m) => m.id), ['old']);
    expect(p.today('2026-11-05').map((m) => m.id), ['old', 'later']);
  });
  test('Exam Mode pauses growth, shrinks daily workload and expires', () {
    final p = Plan()..examUntil = day;
    for (final id in ['growth', 'a', 'b', 'c']) {
      p.missions.add(Mission(id, day));
    }
    expect(p.today(day).map((m) => m.id), ['a']);
    expect(p.today('2026-11-05').length, 3);
  });
  test(
    'language, exam mode, mission notes and checkpoint survive a reload',
    () {
      final p = Plan()
        ..english = true
        ..examUntil = day;
      p.missions.add(
        Mission('demo0', day, state: 'running', step: 2, note: 'draft'),
      );
      final restored = Plan.read(jsonDecode(jsonEncode(p.toJson())));
      expect(restored.toJson(), p.toJson());
      expect(restored.find('demo0')!.demo, isTrue);
      expect(Mission('listing-1', day).demo, isFalse);
    },
  );
}
