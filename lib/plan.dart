typedef Words = (String, String);

const opportunities = [
  (
    ('Software engineering internship', 'Software engineering internship'),
    (
      'Apne project ka ek CV bullet tayyar karo.',
      'Prepare one CV bullet about your project.',
    ),
  ),
  (
    ('Student research program', 'Student research program'),
    (
      'Apni research interest ka chhota sa note likho.',
      'Write a short note about your research interests.',
    ),
  ),
];

const cvSteps = <Words>[
  ('Role ki ek requirement chuno.', 'Choose one requirement from the role.'),
  (
    'Apna ek project chuno jo is skill ko dikhata ho.',
    'Pick one project that demonstrates this skill.',
  ),
  (
    'CV ke liye ek line likho: kya banaya aur us se kya hua?',
    'Write one CV bullet describing what you built and its result.',
  ),
];
const researchSteps = <Words>[
  ('Research ka ek topic chuno.', 'Choose one research topic.'),
  (
    'Apne kisi course ya project se uska link likho.',
    'Connect it to a course or project you have done.',
  ),
  (
    'Teen jumlon mein batao ke tum kya explore karna chahte ho.',
    'Write three sentences about what you want to explore.',
  ),
];
const growthSteps = <Words>[
  ('Apna ek project kholo.', 'Open one of your projects.'),
  (
    'README mein setup ka ek unclear step dhoondo.',
    'Find one unclear setup step in the README.',
  ),
  (
    'Us step ko dobara likho aur khud instructions try karo.',
    'Rewrite the step and try the instructions yourself.',
  ),
];
const manualSteps = <Words>[
  (
    'Asli listing kholo aur location aur eligibility check karo.',
    'Open the original listing and check location and eligibility.',
  ),
  (
    'Deadline aur required documents note karo.',
    'Note the deadline and required documents.',
  ),
  (
    'Application ke liye apna pehla action likho.',
    'Write down your first application action.',
  ),
];

String dayAt(DateTime now) => now
    .toUtc()
    .add(const Duration(hours: 5))
    .toIso8601String()
    .substring(0, 10);

class Mission {
  Mission(
    this.id,
    this.day, {
    this.title = '',
    this.url = '',
    this.state = 'planned',
    this.step = 0,
    this.note = '',
    this.campus = '',
    this.subject = '',
    this.deadline = '',
    this.suggestedDeadline = '',
    this.deadlineEvidence = '',
  });
  final String id;
  String day, title, url, state, note;
  String campus, subject, deadline;
  String suggestedDeadline, deadlineEvidence;
  int step;
  bool get active => state == 'planned' || state == 'running';
  bool get demo => id == 'demo0' || id == 'demo1';
  List<Words> get steps => campus.isNotEmpty
      ? [
          (
            'Email mein action aur deadline dobara dekh lo.',
            'Check the requested action and deadline in the email.',
          ),
          (title, title),
          (
            'Kaam hone ki tasdeeq karo aur zaroori note save kar lo.',
            'Confirm you finished the action and save any note you need.',
          ),
        ]
      : id == 'demo0'
      ? cvSteps
      : id == 'demo1'
      ? researchSteps
      : id == 'growth'
      ? growthSteps
      : manualSteps;
  Words get label => title.isNotEmpty
      ? (title, title)
      : demo
      ? opportunities[id == 'demo0' ? 0 : 1].$2
      : ('Project README behtar karo', 'Improve your project README');
  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'title': title,
    'url': url,
    'state': state,
    'step': step,
    'note': note,
    if (campus.isNotEmpty) 'campus': campus,
    if (subject.isNotEmpty) 'subject': subject,
    if (deadline.isNotEmpty) 'deadline': deadline,
    if (suggestedDeadline.isNotEmpty) 'suggestedDeadline': suggestedDeadline,
    if (deadlineEvidence.isNotEmpty) 'deadlineEvidence': deadlineEvidence,
  };
  factory Mission.read(Map m) => Mission(
    m['id'],
    m['day'],
    title: m['title'],
    url: m['url'],
    state: m['state'],
    step: m['step'],
    note: m['note'],
    campus: m['campus'] ?? '',
    subject: m['subject'] ?? '',
    deadline: m['deadline'] ?? '',
    suggestedDeadline: m['suggestedDeadline'] ?? '',
    deadlineEvidence: m['deadlineEvidence'] ?? '',
  );
}

class Plan {
  bool english = false;
  String examUntil = '';
  final missions = <Mission>[];
  bool exam(String today) => examUntil.compareTo(today) >= 0;
  List<Mission> today(String day) {
    final available = missions
        .where(
          (m) =>
              m.active &&
              m.day.compareTo(day) <= 0 &&
              (!exam(day) || m.id != 'growth'),
        )
        .toList();
    final tomorrow = DateTime.parse(
      '${day}T00:00:00Z',
    ).add(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final urgent =
        available
            .where(
              (m) =>
                  m.campus.isNotEmpty &&
                  m.deadline.isNotEmpty &&
                  m.deadline.compareTo(tomorrow) <= 0,
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return [
      ...urgent,
      ...available.where((m) => !urgent.contains(m)),
    ].take(exam(day) ? 1 : 3).toList();
  }

  Mission? find(String id) => missions.where((m) => m.id == id).firstOrNull;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'english': english,
    'examUntil': examUntil,
    'missions': missions.map((m) => m.toJson()).toList(),
  };
  factory Plan.read(Map map) {
    if (map['version'] != 1) throw const FormatException('Unknown version');
    return Plan()
      ..english = map['english']
      ..examUntil = map['examUntil']
      ..missions.addAll((map['missions'] as List).map((m) => Mission.read(m)));
  }
  Plan();
}
