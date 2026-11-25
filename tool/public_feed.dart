import 'dart:convert';
import 'dart:io';
import 'package:careeros/discovery.dart';
import 'package:careeros/public_feed.dart';

Future<Map> publicJson(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    return await (() async {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != 200)
        throw const FormatException('Source unavailable');
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 4 * 1024 * 1024)
          throw const FormatException('Source too large');
        bytes.addAll(chunk);
      }
      return jsonDecode(utf8.decode(bytes)) as Map;
    })().timeout(const Duration(seconds: 20));
  } finally {
    client.close(force: true);
  }
}

Future<PublicFeed> collectPublicFeed(
  PublicFeed? previous,
  Future<Map> Function(String) fetch,
  DateTime now,
) async {
  final snapshots = <String, BoardSnapshot>{...?previous?.boards};
  final failed = <String>{};
  // Five bounded, sequential public GETs. No credentials, mail or browser data.
  for (final key in boards.keys) {
    try {
      final jobs = parseBoard(key, await fetch(key));
      if (jobs.length > 500) throw const FormatException('Too many listings');
      final candidate = BoardSnapshot(now, jobs);
      readPublicFeed(PublicFeed(now, {key: candidate}, {}).toJson(), now);
      snapshots[key] = candidate;
    } catch (_) {
      failed.add(key); // Preserve the last successful timestamp on failure.
    }
  }
  return readPublicFeed(PublicFeed(now, snapshots, failed).toJson(), now);
}

Future<void> main(List<String> args) async {
  PublicFeed? previous;
  final now = DateTime.now().toUtc();
  try {
    previous = readPublicFeed(
      await publicJson(
        Uri.parse(
          'https://salmanflash.github.io/CareerOS/public-opportunities.json',
        ),
      ),
      now,
    );
  } catch (_) {
    stderr.writeln(
      'Previous public snapshot unavailable; successful boards can still refresh.',
    );
  }
  final result = await collectPublicFeed(
    previous,
    (key) => publicJson(
      Uri.parse('https://boards-api.greenhouse.io/v1/boards/$key/jobs'),
    ),
    now,
  );
  await File(
    (args.isEmpty ? 'build/web' : args.single) + '/public-opportunities.json',
  ).writeAsString(jsonEncode(result.toJson()));
  stdout.writeln(
    'Public snapshot: ${result.boards.length} boards; ${result.failed.length} failed checks.',
  );
}
