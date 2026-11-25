import 'discovery.dart';

class PublicFeed {
  PublicFeed(this.generated, this.boards, this.failed);
  final DateTime generated;
  final Map<String, BoardSnapshot> boards;
  final Set<String> failed;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'generated': generated.toUtc().toIso8601String(),
    'boards': boards.map((k, v) => MapEntry(k, v.toJson())),
    'failed': failed.toList(),
  };
}

PublicFeed readPublicFeed(Map data, DateTime now) {
  final generated = DateTime.tryParse(
    data['generated'] is String ? data['generated'] : '',
  );
  final snapshots = data['boards'];
  final failed = data['failed'];
  if (data['version'] != 1 ||
      generated == null ||
      generated.isAfter(now.add(const Duration(minutes: 5))) ||
      snapshots is! Map ||
      failed is! List ||
      failed.length > boards.length ||
      failed.any((k) => !boards.containsKey(k)) ||
      snapshots.keys.any((k) => !boards.containsKey(k)))
    throw const FormatException();
  final parsed = <String, BoardSnapshot>{};
  for (final key in snapshots.keys) {
    final raw = snapshots[key];
    if (raw is! Map ||
        raw['checked'] is! String ||
        raw['jobs'] is! List ||
        (raw['jobs'] as List).length > 500)
      throw const FormatException();
    final checked = DateTime.tryParse(raw['checked']);
    if (checked == null || checked.isAfter(generated))
      throw const FormatException();
    final jobs = <Listing>[];
    final ids = <String>{};
    for (final job in raw['jobs']) {
      if (job is! Map ||
          [
            'id',
            'title',
            'location',
            'url',
            'source',
          ].any((k) => job[k] is! String || (job[k] as String).length > 8192) ||
          job['source'] != key ||
          !RegExp('^gh-' + key + r'-\d+$').hasMatch(job['id']) ||
          !ids.add(job['id']))
        throw const FormatException();
      final uri = Uri.tryParse(job['url']);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty)
        throw const FormatException();
      jobs.add(Listing.fromJson(job));
    }
    parsed[key] = BoardSnapshot(checked, jobs);
  }
  return PublicFeed(generated, parsed, failed.cast<String>().toSet());
}

/// A scheduled snapshot must not overwrite a newer direct check on this device.
void mergePublicFeed(
  Map<String, BoardSnapshot> current,
  Set<String> failed,
  PublicFeed incoming,
) {
  for (final key in boards.keys) {
    final local = current[key], remote = incoming.boards[key];
    if (local != null && local.checked.isAfter(incoming.generated)) continue;
    if (remote != null &&
        (local == null || !local.checked.isAfter(remote.checked))) {
      current[key] = remote;
      if (!incoming.failed.contains(key)) failed.remove(key);
    }
    if (incoming.failed.contains(key)) failed.add(key);
  }
}
