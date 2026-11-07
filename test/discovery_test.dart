import 'package:careeros/discovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final job = {
    'id': 123,
    'internal_job_id': 42,
    'title': 'Software Engineer Intern',
    'location': {'name': 'Remote - Karachi'},
    'absolute_url': 'https://example.org/opening/123',
  };
  test(
    'only technical internships with a usable employer link are included',
    () {
      final jobs = [
        job,
        job,
        {...job, 'internal_job_id': null},
        {...job, 'title': 'Internal Software Engineer'},
        {...job, 'title': 'HR Intern'},
        {...job, 'absolute_url': 'javascript:alert(1)'},
      ];
      final parsed = parseBoard('careem', {'jobs': jobs});
      expect(parsed.single.pakistan, isTrue);
      expect(parsed.single.id, 'gh-careem-123');
    },
  );
  test(
    'remote status and references to Pakistan in boilerplate do not confirm eligibility',
    () {
      final abroad = {
        ...job,
        'location': {'name': 'Remote - California'},
        'content': 'We have offices in Pakistan',
      };
      final listing = parseBoard('careem', {
        'jobs': [abroad],
      }).single;
      expect(listing.pakistan, isFalse);
      final checked = DateTime.utc(2026, 11, 4);
      final restored = BoardSnapshot.fromJson(
        BoardSnapshot(checked, [listing]).toJson(),
      );
      expect(restored.stale(checked.add(const Duration(days: 1))), isTrue);
      expect(restored.listings.single.url, listing.url);
    },
  );
  test('successful empty board and malformed response are different', () {
    expect(parseBoard('careem', {'jobs': []}), isEmpty);
    expect(
      () => parseBoard('careem', {'error': 'rate-limited'}),
      throwsFormatException,
    );
  });
}
