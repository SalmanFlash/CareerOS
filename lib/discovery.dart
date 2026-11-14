const boards = {
  'careem': 'Careem',
  'gomotive': 'Motive',
  'canonical': 'Canonical',
  'cloudflare': 'Cloudflare',
  'databricks': 'Databricks',
};

final _internship = RegExp(
  r'\b(interns?|internships?|co[ -]?op)\b',
  caseSensitive: false,
);
final _pakistan = RegExp(
  r'\b(Pakistan|Lahore|Karachi|Islamabad|Rawalpindi|Faisalabad|Peshawar)\b',
  caseSensitive: false,
);
final _technical = RegExp(
  r'\b(software|engineer\w*|infrastructure|data|security|cyber\w*|developer|programming|research|AI|ML|machine learning|technical|technology|product management|product manager)\b',
  caseSensitive: false,
);

class Listing {
  const Listing(this.id, this.title, this.location, this.url, this.source);
  final String id, title, location, url, source;
  bool get pakistan => _pakistan.hasMatch(location);
  bool get broadLocation => RegExp(
    r'\b(remote|worldwide|global)\b',
    caseSensitive: false,
  ).hasMatch(location);
  Map<String, String> toJson() => {
    'id': id,
    'title': title,
    'location': location,
    'url': url,
    'source': source,
  };
  factory Listing.fromJson(Map j) =>
      Listing(j['id'], j['title'], j['location'], j['url'], j['source']);
}

/// Only structured posting fields are used. Employer boilerplate can mention
/// countries unrelated to the role, so it is never used to confirm location.
List<Listing> parseBoard(String source, Map response) {
  final jobs = response['jobs'];
  if (jobs is! List) throw const FormatException('Invalid job board');
  final result = <String, Listing>{};
  for (final job in jobs.whereType<Map>()) {
    final title = job['title'];
    final id = job['id'];
    if (title is! String ||
        id is! int ||
        job['internal_job_id'] == null ||
        !_internship.hasMatch(title) ||
        !_technical.hasMatch(title))
      continue;
    final rawUrl = job['absolute_url'];
    final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty)
      continue;
    final location = job['location'] is Map ? job['location']['name'] : null;
    result[rawUrl] = Listing(
      'gh-$source-$id',
      title,
      location is String ? location : '',
      rawUrl,
      source,
    );
  }
  return result.values.toList();
}

class BoardSnapshot {
  BoardSnapshot(this.checked, this.listings);
  final DateTime checked;
  final List<Listing> listings;
  bool stale(DateTime now) =>
      now.difference(checked) >= const Duration(hours: 24);
  bool expired(DateTime now) =>
      now.difference(checked) >= const Duration(days: 7);
  Map<String, dynamic> toJson() => {
    'checked': checked.toUtc().toIso8601String(),
    'jobs': listings.map((l) => l.toJson()).toList(),
  };
  factory BoardSnapshot.fromJson(Map j) => BoardSnapshot(
    DateTime.parse(j['checked']),
    (j['jobs'] as List).map((l) => Listing.fromJson(l)).toList(),
  );
}
