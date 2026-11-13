typedef Words = (String, String);

class GrowthWorkflow {
  const GrowthWorkflow(this.label, this.steps, this.template);
  final Words label, template;
  final List<Words> steps;
}

const growthWorkflows = <String, GrowthWorkflow>{
  'readme': GrowthWorkflow(
    ('GitHub: README test karo', 'GitHub: Test your README'),
    growthSteps,
    (
      'Project:\nSetup ka masla:\nNayi instruction:\nKhud test karne ka nateeja:',
      'Project:\nSetup problem:\nRevised instruction:\nResult of testing it yourself:',
    ),
  ),
  'contribution': GrowthWorkflow(
    ('GitHub: Contribution tayyar karo', 'GitHub: Prepare a contribution'),
    [
      (
        'Repository ki CONTRIBUTING file aur issue parho. Scope aur maintainer ki requirements note karo.',
        'Read the repository CONTRIBUTING file and issue. Note the scope and maintainer requirements.',
      ),
      (
        'Apni local branch mein chhoti change karo. Asal test command aur uska nateeja draft mein likho; jo test nahi hua woh bhi batao.',
        'Make a small change on your local branch. Record the actual test command and result, including anything untested.',
      ),
      (
        'Diff mein secrets aur unrelated changes check karo. PR draft mein problem, change aur test evidence likho. Publish karne ka faisla alag se karo.',
        'Review the diff for secrets and unrelated changes. Draft the PR problem, change and test evidence. Decide separately whether to publish.',
      ),
    ],
    (
      'Repository / issue:\nProblem:\nMeri change:\nTests aur nateeje:\nAbhi kya verify nahi hua:',
      'Repository / issue:\nProblem:\nMy change:\nTests and results:\nNot yet verified:',
    ),
  ),
  'profile': GrowthWorkflow(
    ('LinkedIn: Profile draft banao', 'LinkedIn: Draft your profile'),
    [
      (
        'Apni current education, target role aur ek asal project ka saboot likho. Sirf woh skills chuno jo explain kar sakte ho.',
        'Note your current education, target role and evidence from one real project. Choose skills you can explain.',
      ),
      (
        'Headline mein apna current role aur focus likho. About mein kya banaya, tumhara hissa aur kya seekha likho.',
        'Draft a headline with your current role and focus. In About, describe what you built, your contribution and what you learned.',
      ),
      (
        'Har claim aur link check karo. Banaye hue numbers, experience ya private details hatao. Final draft ko khud review karo.',
        'Check each claim and link. Remove invented metrics, experience and private details. Review the final draft yourself.',
      ),
    ],
    (
      'Headline:\nAbout:\nAsal project aur mera hissa:\nSaboot / public link:\nAgla learning goal:',
      'Headline:\nAbout:\nReal project and my contribution:\nEvidence / public link:\nNext learning goal:',
    ),
  ),
  'post': GrowthWorkflow(
    ('LinkedIn: Project post likho', 'LinkedIn: Draft a project post'),
    [
      (
        'Ek asal project milestone chuno. Problem, tumhara apna kaam aur dikhane layak result note karo.',
        'Choose a real project milestone. Note the problem, your own work and a result you can demonstrate.',
      ),
      (
        'Chhota post likho: kya banaya, ek mushkil, kya seekha aur public demo ya repo link agar available ho.',
        'Draft a short post: what you built, one challenge, what you learned, and a public demo or repository link if available.',
      ),
      (
        'Facts aur link check karo. Team ko credit do aur private data hatao. Ye local draft hai; publish khud review karne ke baad karo.',
        'Check facts and links. Credit collaborators and remove private data. This is a local draft; publish only after your own review.',
      ),
    ],
    (
      'Kya banaya:\nMera hissa:\nEk mushkil aur seekh:\nAsal result:\nPublic link / credits:',
      'What I built:\nMy contribution:\nOne challenge and lesson:\nActual result:\nPublic link / credits:',
    ),
  ),
};

const applicationStages = <String, Words>{
  'saved': ('Save ki hui', 'Saved'),
  'preparing': ('Tayyari jaari', 'Preparing'),
  'applied': ('Apply kar diya', 'Applied'),
  'interview': ('Interview', 'Interview'),
  'offer': ('Offer mila', 'Offer'),
  'closed': ('Band / ab nahi karna', 'Closed'),
};

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

bool validDay(String value, {bool optional = false}) {
  if (value.isEmpty) return optional;
  if (!RegExp(r'^20\d{2}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final date = DateTime.tryParse('${value}T00:00:00Z');
  return date != null && date.toIso8601String().substring(0, 10) == value;
}

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
    this.noticeFingerprint = '',
    this.applicationStage = '',
    this.followUp = '',
    this.applicationNote = '',
    this.applicationUpdated = '',
    this.appliedOn = '',
    this.workflow = '',
  });
  final String id;
  String day, title, url, state, note;
  String campus, subject, deadline;
  String suggestedDeadline, deadlineEvidence;
  String noticeFingerprint;
  final String workflow;
  String get workflowKey =>
      id == 'growth' && workflow.isEmpty ? 'readme' : workflow;
  bool get isGrowth => workflowKey.isNotEmpty;
  String applicationStage,
      followUp,
      applicationNote,
      applicationUpdated,
      appliedOn;
  bool get canTrackApplication =>
      !demo && campus.isEmpty && url.isNotEmpty && !isGrowth;
  bool get tracked => applicationStage.isNotEmpty;
  void recordApplication(
    String stage,
    String date,
    String nextDate,
    String note,
  ) {
    if (!canTrackApplication ||
        !applicationStages.containsKey(stage) ||
        !validDay(date) ||
        (stage != 'closed' && !validDay(nextDate, optional: true)) ||
        note.length > 8192)
      throw const FormatException();
    applicationStage = stage;
    applicationUpdated = date;
    if (stage == 'applied' && appliedOn.isEmpty) appliedOn = date;
    followUp = stage == 'closed' ? '' : nextDate;
    applicationNote = note;
  }

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
      : isGrowth
      ? growthWorkflows[workflowKey]!.steps
      : manualSteps;
  Words get label => title.isNotEmpty
      ? (title, title)
      : isGrowth
      ? growthWorkflows[workflowKey]!.label
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
    if (workflow.isNotEmpty) 'workflow': workflow,
    if (campus.isNotEmpty) 'campus': campus,
    if (subject.isNotEmpty) 'subject': subject,
    if (deadline.isNotEmpty) 'deadline': deadline,
    if (suggestedDeadline.isNotEmpty) 'suggestedDeadline': suggestedDeadline,
    if (deadlineEvidence.isNotEmpty) 'deadlineEvidence': deadlineEvidence,
    if (noticeFingerprint.isNotEmpty) 'noticeFingerprint': noticeFingerprint,
    if (applicationStage.isNotEmpty) 'applicationStage': applicationStage,
    if (followUp.isNotEmpty) 'followUp': followUp,
    if (applicationNote.isNotEmpty) 'applicationNote': applicationNote,
    if (applicationUpdated.isNotEmpty) 'applicationUpdated': applicationUpdated,
    if (appliedOn.isNotEmpty) 'appliedOn': appliedOn,
  };
  factory Mission.read(Map m) => Mission(
    m['id'],
    m['day'],
    title: m['title'],
    url: m['url'],
    state: m['state'],
    step: m['step'],
    note: m['note'],
    workflow: m['workflow'] ?? '',
    campus: m['campus'] ?? '',
    subject: m['subject'] ?? '',
    deadline: m['deadline'] ?? '',
    suggestedDeadline: m['suggestedDeadline'] ?? '',
    deadlineEvidence: m['deadlineEvidence'] ?? '',
    noticeFingerprint: m['noticeFingerprint'] ?? '',
    applicationStage: m['applicationStage'] ?? '',
    followUp: m['followUp'] ?? '',
    applicationNote: m['applicationNote'] ?? '',
    applicationUpdated: m['applicationUpdated'] ?? '',
    appliedOn: m['appliedOn'] ?? '',
  );
}

class Plan {
  bool english = false;
  String examUntil = '';
  final missions = <Mission>[];
  List<Mission> followUps(String day) =>
      missions
          .where(
            (m) =>
                m.canTrackApplication &&
                m.tracked &&
                m.applicationStage != 'closed' &&
                m.followUp.isNotEmpty &&
                m.followUp.compareTo(day) <= 0,
          )
          .toList()
        ..sort((a, b) => a.followUp.compareTo(b.followUp));
  Mission? noticeMission(String id, String fingerprint) => missions
      .where(
        (m) =>
            m.id == id ||
            (fingerprint.isNotEmpty && m.noticeFingerprint == fingerprint),
      )
      .firstOrNull;
  bool exam(String today) => examUntil.compareTo(today) >= 0;
  List<Mission> today(String day) {
    final available = missions
        .where(
          (m) =>
              m.active &&
              m.day.compareTo(day) <= 0 &&
              (!exam(day) || !m.isGrowth),
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
