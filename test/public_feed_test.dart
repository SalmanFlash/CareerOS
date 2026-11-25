import 'package:flutter_test/flutter_test.dart';
import 'package:careeros/discovery.dart';
import 'package:careeros/public_feed.dart';
import '../tool/public_feed.dart' show collectPublicFeed;

void main() {
  final old = DateTime.utc(2026, 11, 25), now = DateTime.utc(2026, 11, 26);
  final job = Listing(
    'gh-careem-123',
    'Software Intern',
    'Remote',
    'https://example.org/job',
    'careem',
  );
  test(
    'scheduled failures preserve timestamps; empty success removes old listings',
    () async {
      final previous = PublicFeed(old, {
        'careem': BoardSnapshot(old, [job]),
        'canonical': BoardSnapshot(old, []),
      }, {});
      final calls = <String>[];
      final result = await collectPublicFeed(previous, (key) async {
        calls.add(key);
        if (key == 'careem') throw const FormatException();
        return {'jobs': []};
      }, now);
      expect(calls, boards.keys.toList());
      expect(result.failed, {'careem'});
      expect(result.boards['careem']!.checked, old);
      expect(result.boards['careem']!.listings.single.url, job.url);
      expect(result.boards['canonical']!.checked, now);
      expect(result.boards['canonical']!.listings, isEmpty);
    },
  );
  test('published snapshots cannot replace newer direct checks', () {
    final current = {
      'careem': BoardSnapshot(now.add(const Duration(minutes: 1)), []),
    };
    final failed = <String>{};
    mergePublicFeed(
      current,
      failed,
      PublicFeed(
        now,
        {
          'careem': BoardSnapshot(old, [job]),
        },
        {'careem'},
      ),
    );
    expect(current['careem']!.listings, isEmpty);
    expect(failed, isEmpty);
    mergePublicFeed(
      current,
      failed,
      PublicFeed(now, {'canonical': BoardSnapshot(now, [])}, {'cloudflare'}),
    );
    expect(current['canonical']!.checked, now);
    expect(failed, {'cloudflare'});
  });
  test(
    'public parsing rejects unsafe URLs, unknown boards and future timestamps',
    () {
      Map fixture() => PublicFeed(now, {
        'careem': BoardSnapshot(old, [job]),
      }, {}).toJson();
      for (final change in <void Function(Map)>[
        (m) =>
            m['generated'] = now.add(const Duration(days: 1)).toIso8601String(),
        (m) => m['failed'] = ['unknown'],
        (m) => m['boards']['careem']['jobs'][0]['url'] =
            'https://user:secret@example.org/',
        (m) => m['boards']['careem']['jobs'][0]['source'] = 'canonical',
        (m) => m['boards']['careem']['jobs'][0]['id'] = 'private-note',
      ]) {
        final m = fixture();
        change(m);
        expect(() => readPublicFeed(m, now), throwsFormatException);
      }
      final m = fixture();
      m['private'] = 'not copied';
      m['boards']['careem']['jobs'][0]['description'] = 'not copied';
      expect(
        readPublicFeed(m, now).toJson().toString(),
        isNot(contains('not copied')),
      );
    },
  );
}
