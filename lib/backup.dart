import 'dart:convert';
import 'plan.dart';

const _fields = {
  'id',
  'day',
  'title',
  'url',
  'state',
  'step',
  'note',
  'campus',
  'subject',
  'deadline',
  'suggestedDeadline',
  'deadlineEvidence',
  'noticeFingerprint',
  'applicationStage',
  'followUp',
  'applicationNote',
  'applicationUpdated',
  'appliedOn',
  'workflow',
};

bool _date(String value, {bool optional = false}) =>
    validDay(value, optional: optional);

Plan readBackup(String text) {
  if (utf8.encode(text).length > 4 * 1024 * 1024) throw const FormatException();
  final data = jsonDecode(text);
  if (data is! Map ||
      data['format'] != 'careeros-missions' ||
      data['version'] != 1)
    throw const FormatException();
  final plan = data['plan'];
  if (plan is! Map ||
      plan['version'] != 1 ||
      plan['english'] is! bool ||
      plan['examUntil'] is! String ||
      !_date(plan['examUntil'], optional: true) ||
      plan.keys.any(
        (k) => !{'version', 'english', 'examUntil', 'missions'}.contains(k),
      ))
    throw const FormatException();
  final missions = plan['missions'];
  if (missions is! List || missions.length > 2000)
    throw const FormatException();
  final ids = <String>{};
  for (final m in missions) {
    if (m is! Map || m.keys.any((k) => !_fields.contains(k)))
      throw const FormatException();
    for (final field in ['id', 'day', 'title', 'url', 'state', 'note']) {
      if (m[field] is! String) throw const FormatException();
    }
    for (final field in _fields.difference({'step'})) {
      if (m.containsKey(field) &&
          (m[field] is! String ||
              (m[field] as String).length > (field == 'note' ? 100000 : 8192)))
        throw const FormatException();
    }
    if ((m['id'] as String).isEmpty ||
        !ids.add(m['id']) ||
        !_date(m['day']) ||
        !{'planned', 'running', 'done', 'skipped'}.contains(m['state']) ||
        !{'', 'Karachi', 'Lahore'}.contains(m['campus'] ?? '') ||
        !_date(m['deadline'] ?? '', optional: true) ||
        !_date(m['suggestedDeadline'] ?? '', optional: true))
      throw const FormatException();
    final url = m['url'] as String;
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty)
        throw const FormatException();
    }
    final workflow = m['workflow'] ?? '';
    if (workflow != '' &&
        (!growthWorkflows.containsKey(workflow) ||
            (m['campus'] ?? '') != '' ||
            {'demo0', 'demo1', 'growth'}.contains(m['id'])))
      throw const FormatException();
    if (m['step'] is! int ||
        m['step'] < 0 ||
        m['step'] >= Mission.read(m).steps.length)
      throw const FormatException();
    final mission = Mission.read(m);
    if (!{'', ...applicationStages.keys}.contains(mission.applicationStage) ||
        !_date(mission.followUp, optional: true) ||
        !_date(mission.applicationUpdated, optional: true) ||
        !_date(mission.appliedOn, optional: true) ||
        (mission.tracked &&
            (!mission.canTrackApplication ||
                !_date(mission.applicationUpdated))) ||
        (mission.applicationStage == 'applied' && mission.appliedOn.isEmpty) ||
        (!mission.tracked &&
            [
              mission.followUp,
              mission.applicationUpdated,
              mission.appliedOn,
              mission.applicationNote,
            ].any((v) => v.isNotEmpty)) ||
        (mission.applicationStage == 'closed' && mission.followUp.isNotEmpty))
      throw const FormatException();
  }
  return Plan.read(plan);
}

String writeBackup(Plan plan) {
  final text = jsonEncode({
    'format': 'careeros-missions',
    'version': 1,
    'plan': plan.toJson(),
  });
  readBackup(text); // Export only data that this version can restore safely.
  return text;
}

class BackupMerge {
  BackupMerge(this.plan, this.added, this.kept);
  final Plan plan;
  final int added, kept;
}

BackupMerge mergeBackup(Plan current, Plan incoming) {
  final result = Plan.read(jsonDecode(jsonEncode(current.toJson())));
  var added = 0, kept = 0;
  for (final mission in incoming.missions) {
    final duplicate =
        result.noticeMission(mission.id, mission.noticeFingerprint) != null ||
        (mission.campus.isEmpty &&
            mission.url.isNotEmpty &&
            result.missions.any(
              (m) => m.campus.isEmpty && m.url == mission.url,
            ));
    if (duplicate) {
      kept++;
      continue;
    }
    result.missions.add(Mission.read(mission.toJson()));
    added++;
  }
  // Existing missions, notes, language and Exam Mode always win.
  if (result.missions.length > 2000) throw const FormatException();
  writeBackup(result);
  return BackupMerge(result, added, kept);
}
