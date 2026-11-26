import 'package:flutter_test/flutter_test.dart';
import 'package:careeros/discovery.dart';
import 'package:careeros/public_feed.dart';
import '../tool/public_feed.dart' show collectPublicFeed;

void main() {
  final summer = {
    'id': '123',
    'name': 'CERN Summer Student Programme 2027 (Member and Non-Member State)',
    'company': {'identifier': 'CERN'},
    'visibility': 'PUBLIC',
    'location': {'fullLocation': 'Geneva, Switzerland'},
    'unpublishOn': '2027-01-21T23:00:00Z',
  };
  test(
    'only public CERN summer families enter research feed; no deadline inferred',
    () {
      final result = parseBoard('cern', {
        'content': [
          summer,
          summer,
          {
            ...summer,
            'id': '456',
            'name': 'CERN OPENLAB Summer Student Programme 2027',
          },
          {...summer, 'id': '789', 'name': 'Software Engineer'},
          {
            ...summer,
            'id': '800',
            'name': 'Short-Term Internship 2027 - Information Technologies',
          },
          {...summer, 'visibility': 'INTERNAL'},
          {
            ...summer,
            'company': {'identifier': 'Other'},
          },
          {...summer, 'id': '../private'},
        ],
      });
      expect(result.map((x) => x.id), ['sr-cern-123', 'sr-cern-456']);
      expect(result.first.url, 'https://jobs.smartrecruiters.com/CERN/123');
      expect(result.first.pakistan, false);
      final now = DateTime.utc(2026, 11, 26);
      final restored = readPublicFeed(
        PublicFeed(now, {'cern': BoardSnapshot(now, result)}, {}).toJson(),
        now,
      );
      expect(restored.boards['cern']!.listings.length, 2);
      expect(restored.toJson().toString(), isNot(contains('unpublishOn')));
    },
  );
  test(
    'pagination reads later matching postings with fixed public requests',
    () async {
      final offsets = <String>[];
      final raw = await fetchBoardData('cern', (uri) async {
        expect(uri.host, 'api.smartrecruiters.com');
        expect(uri.path, '/v1/companies/CERN/postings');
        expect(uri.queryParameters['destination'], 'PUBLIC');
        expect(uri.queryParameters['limit'], '100');
        offsets.add(uri.queryParameters['offset']!);
        final offset = int.parse(offsets.last);
        return {
          'offset': offset,
          'totalFound': 101,
          'content': offset == 0
              ? List.generate(
                  100,
                  (i) => {'id': 'other-$i', 'name': 'Other role'},
                )
              : [summer],
        };
      });
      expect(offsets, ['0', '100']);
      expect(parseBoard('cern', raw).single.id, 'sr-cern-123');
    },
  );
  test(
    'truncated, inconsistent, oversized and repeating pages fail closed',
    () async {
      for (final mode in [
        'empty',
        'repeat',
        'changed',
        'wrong-offset',
        'oversize',
        'network',
      ]) {
        var count = 0;
        await expectLater(
          fetchBoardData('cern', (uri) async {
            final offset = int.parse(uri.queryParameters['offset']!);
            count++;
            if (mode == 'network' && count > 1) throw const FormatException();
            return {
              'offset': mode == 'wrong-offset' ? -1 : offset,
              'totalFound': mode == 'oversize'
                  ? 501
                  : (mode == 'changed' && count > 1 ? 3 : 2),
              'content': mode == 'empty' ? [] : [summer],
            };
          }),
          throwsFormatException,
          reason: mode,
        );
        expect(count, lessThanOrEqualTo(2));
      }
    },
  );
  test(
    'CERN page failure preserves previous timestamp and listings in collector',
    () async {
      final old = DateTime.utc(2026, 11, 25), now = DateTime.utc(2026, 11, 26);
      final previous = PublicFeed(old, {
        'cern': BoardSnapshot(
          old,
          parseBoard('cern', {
            'content': [summer],
          }),
        ),
      }, {});
      final result = await collectPublicFeed(previous, (key) async {
        if (key == 'cern') throw const FormatException('Partial page');
        return {'jobs': []};
      }, now);
      expect(result.failed, {'cern'});
      expect(result.boards['cern']!.checked, old);
      expect(result.boards['cern']!.listings.single.id, 'sr-cern-123');
      expect(
        await fetchBoardData(
          'cern',
          (_) async => {'offset': 0, 'totalFound': 0, 'content': []},
        ),
        {'content': []},
      );
    },
  );
}
