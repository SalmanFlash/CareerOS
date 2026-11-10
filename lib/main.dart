import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'plan.dart';
import 'discovery.dart';

@JS('fetch')
external JSPromise<_Response> fetchBoard(JSString url, JSObject options);
@JS('AbortSignal.timeout')
external JSObject requestTimeout(int milliseconds);
extension type _Response(JSObject _) implements JSObject {
  external bool get ok;
  external JSPromise<JSString> text();
}

@JS('localStorage.getItem')
external JSString? readStore(JSString key);
@JS('localStorage.setItem')
external void writeStore(JSString key, JSString value);
@JS('window.open')
external void openSource(JSString url, JSString target, JSString features);

const ink = Color(0xff080611),
    surface = Color(0xff171024),
    lilac = Color(0xffb996ff);
void main() => runApp(
  MaterialApp(
    title: 'CareerOS',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lilac,
        brightness: Brightness.dark,
      ).copyWith(surface: surface, primary: lilac),
    ),
    home: const Desk(),
  ),
);

class Desk extends StatefulWidget {
  const Desk({super.key});
  @override
  State<Desk> createState() => _DeskState();
}

class _DeskState extends State<Desk> {
  Plan plan = Plan();
  int tab = 0;
  final feed = <String, BoardSnapshot>{};
  final failedBoards = <String>{};
  bool searching = false, pkOnly = false;
  String query = '';
  int limit = 5;
  DateTime? lastAttempt;
  bool saved = true, unreadable = false;
  late String today;
  Timer? clock;
  String? focus;
  Map<String, dynamic>? gmail;
  bool gmailLoading = false, gmailOffline = false;
  String t(String ur, String en) => plan.english ? en : ur;
  String word(Words pair) => t(pair.$1, pair.$2);
  @override
  void initState() {
    super.initState();
    today = dayAt(DateTime.now());
    try {
      final raw = readStore('careeros.boards.v1'.toJS)?.toDart;
      if (raw != null) {
        final cached = jsonDecode(raw) as Map;
        for (final key in boards.keys) {
          if (cached[key] is Map)
            feed[key] = BoardSnapshot.fromJson(cached[key]);
        }
      }
    } catch (_) {
      /* A fresh search replaces unusable cached public data. */
    }
    try {
      final raw = readStore('careeros.v1'.toJS)?.toDart;
      if (raw != null) plan = Plan.read(jsonDecode(raw));
    } catch (_) {
      saved = false;
      unreadable = true;
    }
    clock = Timer.periodic(const Duration(seconds: 30), (_) {
      final date = dayAt(DateTime.now());
      if (date != today) setState(() => today = date);
      refreshGmail();
    });
    refreshGmail();
  }

  @override
  void dispose() {
    clock?.cancel();
    searchInput.dispose();
    super.dispose();
  }

  void change(VoidCallback action) => setState(() {
    action();
    if (unreadable) return;
    try {
      writeStore('careeros.v1'.toJS, jsonEncode(plan.toJson()).toJS);
      saved = true;
    } catch (_) {
      saved = false;
    }
  });
  void go(int i) => setState(() {
    focus = null;
    tab = i;
  });
  void add(Mission m) {
    change(() {
      if (plan.find(m.id) == null) plan.missions.add(m);
      tab = 0;
      focus = null;
    });
    if (!plan.today(today).contains(m))
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Mission Progress mein save hai.', 'Mission saved in Progress.'),
          ),
        ),
      );
  }

  List<String> get tabs => [
    t('Aaj', 'Today'),
    t('Mauqay', 'Opportunities'),
    t('Taraqqi', 'Growth'),
    'Progress',
  ];
  static const icons = [
    Icons.wb_sunny_outlined,
    Icons.explore_outlined,
    Icons.eco_outlined,
    Icons.insights_outlined,
  ];
  Widget eyebrow(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: lilac,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      fontSize: 12,
    ),
  );
  Widget heading(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
  );
  Widget panel(List<Widget> items, {bool accent = false}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: accent ? const Color(0xff25163a) : surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: accent ? const Color(0xff64478a) : const Color(0xff342a43),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: items,
    ),
  );
  Widget button(String label, VoidCallback onTap) =>
      FilledButton(onPressed: onTap, child: Text(label));
  Widget link(String label, VoidCallback onTap) =>
      TextButton(onPressed: onTap, child: Text(label));
  Widget titleText(String s) => Text(
    s,
    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 21),
  );
  String stateName(Mission m) => switch (m.state) {
    'done' => t('Mukammal', 'Completed'),
    'skipped' => t('Skip kiya', 'Skipped'),
    'running' => t('Jaari hai', 'In progress'),
    _ =>
      m.day.compareTo(today) > 0
          ? t('Baad ke liye', 'Postponed')
          : t('Tayyar', 'Planned'),
  };
  Widget get brand => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.layers_rounded, color: lilac),
      const SizedBox(width: 9),
      Text(
        'CareerOS',
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final active = plan.find(focus ?? '');
    final content = active != null
        ? guide(active)
        : switch (tab) {
            0 => daily(),
            1 => opps(),
            2 => growth(),
            3 => progress(),
            _ => settings(),
          };
    return Scaffold(
      appBar: AppBar(
        title: brand,
        backgroundColor: ink,
        actions: [
          IconButton(
            tooltip: t('Settings aur zabaan', 'Settings and language'),
            icon: const Icon(Icons.tune),
            onPressed: () => go(4),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  for (var i = 0; i < 4; i++)
                    ListTile(
                      selected: tab == i,
                      leading: Icon(icons[i]),
                      title: Text(tabs[i]),
                      onTap: () => go(i),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  key: ValueKey(focus ?? tab),
                  padding: EdgeInsets.all(wide ? 32 : 18),
                  children: [
                    if (!saved)
                      panel([
                        Text(
                          t(
                            'Data save nahi ho saka. Is session ki tabdeeliyan refresh par kho sakti hain.',
                            'Storage is unavailable. Session changes may be lost on refresh.',
                          ),
                        ),
                      ]),
                    ...content,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab < 4 ? tab : 0,
              onDestinationSelected: go,
              destinations: [
                for (var i = 0; i < 4; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: tabs[i]),
              ],
            ),
    );
  }

  List<Widget> daily() {
    final list = plan.today(today);
    return [
      eyebrow('PKT  /  ' + today),
      const SizedBox(height: 8),
      heading(t('Aaj ka focus', 'Today’s focus')),
      const SizedBox(height: 18),
      if (plan.exam(today))
        panel([
          eyebrow('Exam Mode'),
          Text(
            t(
              'Aaj sirf ek mission. Growth tasks pause hain.',
              'One mission today. Growth tasks are paused.',
            ),
          ),
        ]),
      ...gmailCards(),
      if (list.isEmpty)
        panel([
          eyebrow(t('Agla kaam', 'Next action')),
          titleText(t('Apna pehla kaam chuno', 'Choose your next task')),
          Text(
            t(
              'Apni listing lao ya demo ke saath pehla step try karo.',
              'Bring your own listing or try the first step with a demo.',
            ),
          ),
          button(t('Mauqay dekho', 'Explore opportunities'), () => go(1)),
        ], accent: true),
      for (final (i, m) in list.indexed)
        panel([
          eyebrow(
            (m.demo ? 'DEMO   /   ' : '') +
                (i == 0
                    ? t('Agla kaam', 'Next action')
                    : t('Aaj ka mission', 'Today’s mission')),
          ),
          titleText(word(m.label)),
          if (m.campus.isNotEmpty) universitySource(m),
          Text((m.campus.isEmpty ? '15 min   ·   ' : '') + stateName(m)),
          Wrap(
            spacing: 6,
            children: [
              button(
                t('Mere saath karo', 'Do it with me'),
                () => change(() {
                  m.state = 'running';
                  focus = m.id;
                }),
              ),
              link(
                t('Kal karo', 'Postpone'),
                () => change(() {
                  m.day = dayAt(DateTime.now().add(const Duration(days: 1)));
                  m.state = 'planned';
                }),
              ),
              link(
                t('Skip karo', 'Skip'),
                () => change(() => m.state = 'skipped'),
              ),
            ],
          ),
        ], accent: i == 0),
      ExpansionTile(
        title: Text(
          t(
            'Notice khud add karo (optional)',
            'Add a notice manually (optional)',
          ),
        ),
        children: [
          panel([
            eyebrow('FAST'),
            titleText(
              t(
                'University ki email se kaam save karo',
                'Save an action from university email',
              ),
            ),
            Text(
              t(
                'Email ka subject aur apna agla kaam likho. Agar deadline di hai toh woh bhi save karo.',
                'Enter the subject and the action you need to take. Add the deadline if the notice gives one.',
              ),
            ),
            link(
              t('FAST notice add karo', 'Add FAST notice'),
              () => universityNotice(),
            ),
          ]),
        ],
      ),
      Text(
        t('Is device par save hota hai.', 'Saved on this device.'),
        style: const TextStyle(color: Colors.white60),
      ),
    ];
  }

  List<Widget> opps() => [
    eyebrow(t('Talash', 'Discover')),
    const SizedBox(height: 8),
    heading(tabs[1]),
    const SizedBox(height: 18),
    ...discoveryCards(),
    panel([
      titleText(t('Apna mauqa add karo', 'Bring your own opportunity')),
      Text(
        t(
          'Asli listing ka link save karo. Pehla mission eligibility check karna hoga.',
          'Save an original listing. Your first mission is to verify eligibility.',
        ),
      ),
      button(t('Listing add karo', 'Add listing'), () => edit()),
    ], accent: true),
    for (final (i, o) in opportunities.indexed)
      panel([
        eyebrow('Demo'),
        titleText(word(o.$1)),
        Text(
          t(
            'Practice listing • eligibility aur deadline maloom nahi.',
            'Practice listing • eligibility and deadline unknown.',
          ),
        ),
        Text(word(o.$2)),
        if (plan.find('demo' + i.toString()) == null)
          button(
            t('Mission banao', 'Create mission'),
            () => add(Mission('demo' + i.toString(), today)),
          )
        else
          link(t('Progress dekho', 'View progress'), () => go(3)),
      ]),
  ];
  Future<void> refreshBoards() async {
    if (searching) return;
    final now = DateTime.now().toUtc();
    if (lastAttempt != null &&
        now.difference(lastAttempt!) < const Duration(minutes: 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Dobara check karne se pehle ek minute ruk jao.',
              'Wait one minute before checking again.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      searching = true;
      lastAttempt = now;
    });
    final errors = <String>{};
    await Future.wait(
      boards.keys.map((key) async {
        try {
          final options =
              {
                    'signal': requestTimeout(12000),
                    'credentials': 'omit',
                    'cache': 'no-store',
                    'referrerPolicy': 'no-referrer',
                  }.jsify()
                  as JSObject;
          final response = await fetchBoard(
            'https://boards-api.greenhouse.io/v1/boards/$key/jobs'.toJS,
            options,
          ).toDart;
          if (!response.ok) throw const FormatException('Board unavailable');
          final json = jsonDecode((await response.text().toDart).toDart);
          final listings = parseBoard(key, json);
          feed[key] = BoardSnapshot(DateTime.now().toUtc(), listings);
        } catch (_) {
          errors.add(key);
        }
      }),
    );
    try {
      writeStore(
        'careeros.boards.v1'.toJS,
        jsonEncode(feed.map((k, v) => MapEntry(k, v.toJson()))).toJS,
      );
    } catch (_) {
      /* In-memory results remain usable. */
    }
    if (mounted)
      setState(() {
        searching = false;
        failedBoards
          ..clear()
          ..addAll(errors);
        limit = 5;
      });
  }

  List<Widget> discoveryCards() {
    final now = DateTime.now().toUtc();
    final matches = <Listing>[
      for (final snapshot in feed.values)
        if (now.difference(snapshot.checked) < const Duration(days: 7))
          for (final job in snapshot.listings)
            if ((!pkOnly || job.pakistan) &&
                ('${job.title} ${job.location} ${boards[job.source]}')
                    .toLowerCase()
                    .contains(query.trim().toLowerCase()))
              job,
    ];
    int rank(Listing job) => job.pakistan
        ? 0
        : job.broadLocation
        ? 1
        : 2;
    matches.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return [
      panel([
        eyebrow(t('Official career boards', 'Official career boards')),
        titleText(t('CS internships dhoondo', 'Find CS internships')),
        Text(boards.values.join('  ·  ')),
        FilledButton.icon(
          onPressed: searching ? null : refreshBoards,
          icon: const Icon(Icons.search),
          label: Text(
            searching
                ? t('Check ho raha hai…', 'Checking…')
                : t('Abhi check karo', 'Check now'),
          ),
        ),
        if (failedBoards.isNotEmpty)
          Text(
            t('In boards ka naya data nahi mil saka: ', 'Could not refresh: ') +
                failedBoards.map((k) => boards[k]).join(', '),
          ),
        if (feed.isNotEmpty) ...[
          TextField(
            onChanged: (v) => setState(() {
              query = v;
              limit = 5;
            }),
            controller: searchInput,
            decoration: InputDecoration(
              labelText: t(
                'Role, company ya jagah',
                'Role, company or location',
              ),
              prefixIcon: const Icon(Icons.manage_search),
            ),
          ),
          FilterChip(
            label: Text(
              t('Sirf Pakistan locations', 'Pakistan locations only'),
            ),
            selected: pkOnly,
            onSelected: (v) => setState(() {
              pkOnly = v;
              limit = 5;
            }),
          ),
          Text(
            t('Matches: ', 'Matches: ') +
                matches.length.toString() +
                '   ·   ' +
                t('Aakhri check (PKT): ', 'Last check (PKT): ') +
                pkt(
                  feed.values
                      .map((s) => s.checked)
                      .reduce((a, b) => a.isAfter(b) ? a : b),
                ),
          ),
          if (matches.isEmpty)
            Text(
              t(
                'In boards aur filters se koi current match nahi mila.',
                'No current matches on these boards with these filters.',
              ),
            ),
        ],
      ], accent: true),
      for (final job in matches.take(limit)) listingCard(job, now),
      if (matches.length > limit)
        link(
          t('Aur results dekho', 'Show more results'),
          () => setState(() => limit += 5),
        ),
    ];
  }

  final searchInput = TextEditingController();
  String pkt(DateTime utc) => utc
      .toUtc()
      .add(const Duration(hours: 5))
      .toIso8601String()
      .substring(0, 16)
      .replaceFirst('T', ' ');
  Widget listingCard(Listing job, DateTime now) {
    final board = feed[job.source]!;
    final saved = plan.missions.any((m) => m.id == job.id || m.url == job.url);
    final old = board.stale(now) || failedBoards.contains(job.source);
    return panel([
      eyebrow(boards[job.source]!),
      titleText(job.title),
      Text(
        job.location.isEmpty
            ? t('Location maloom nahi', 'Location unspecified')
            : job.location,
      ),
      Text(
        job.pakistan
            ? t(
                'Employer ne Pakistan ki location di hai. Degree aur doosri shartein listing mein check karo.',
                'The employer lists a Pakistan location. Check degree and other requirements in the listing.',
              )
            : t(
                'Pakistan se apply karne ki ijazat confirm nahi hai. Location aur work authorization listing mein check karo.',
                'Eligibility from Pakistan is unconfirmed. Check location and work authorization in the listing.',
              ),
      ),
      Text(
        t('Deadline: maloom nahi', 'Deadline: unknown') +
            '   ·   ' +
            (old
                ? t('Purana result', 'Cached result')
                : t('Check kiya', 'Checked')) +
            ' ' +
            pkt(board.checked) +
            ' PKT',
      ),
      Wrap(
        spacing: 6,
        children: [
          link(
            t('Asli listing kholo', 'Open original listing'),
            () => openSource(
              job.url.toJS,
              '_blank'.toJS,
              'noopener,noreferrer'.toJS,
            ),
          ),
          if (saved)
            link(t('Progress dekho', 'View progress'), () => go(3))
          else if (!old)
            button(
              t('Mission banao', 'Create mission'),
              () => add(Mission(job.id, today, title: job.title, url: job.url)),
            ),
        ],
      ),
    ]);
  }

  List<Widget> growth() => [
    eyebrow('GitHub'),
    const SizedBox(height: 8),
    heading(tabs[2]),
    const SizedBox(height: 18),
    panel([
      titleText(t('README ko test karo', 'Test your README')),
      Text(
        t(
          'Kya koi naya developer tumhari instructions se project chala sakta hai? Ek step khud try karo.',
          'Could a new developer run your project from your instructions? Try one step yourself.',
        ),
      ),
      if (plan.find('growth') == null)
        button(
          t('Mission banao', 'Create mission'),
          () => add(Mission('growth', today)),
        )
      else
        link(t('Progress dekho', 'View progress'), () => go(3)),
    ], accent: true),
  ];
  List<Widget> guide(Mission m) => [
    Align(
      alignment: Alignment.centerLeft,
      child: link(t('Wapas', 'Back'), () => go(0)),
    ),
    eyebrow((m.demo ? 'DEMO   /   ' : '') + t('Focus mode', 'Focus mode')),
    heading(word(m.label)),
    if (m.campus.isNotEmpty) universitySource(m),
    if (m.suggestedDeadline.isNotEmpty && m.deadline != m.suggestedDeadline)
      panel([
        Text(
          t(
            'Email se mumkin deadline mili hai. Asli email dekh kar tasdeeq karo.',
            'A possible deadline was found in the email. Confirm it against the original message.',
          ),
        ),
        Text(m.suggestedDeadline),
        Text(m.deadlineEvidence),
        button(
          t('Tareekh confirm karo', 'Confirm date'),
          () => change(() => m.deadline = m.suggestedDeadline),
        ),
      ]),
    const SizedBox(height: 18),
    panel([
      eyebrow(t('Step', 'Step') + ' ${m.step + 1} / ${m.steps.length}'),
      LinearProgressIndicator(value: m.step / m.steps.length),
      titleText(word(m.steps[m.step])),
      if (m.url.isNotEmpty)
        link(
          m.campus.isEmpty
              ? t('Asli listing kholo', 'Open original listing')
              : t('Asli email kholo', 'Open original email'),
          () =>
              openSource(m.url.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS),
        ),
      TextFormField(
        key: ValueKey(m.id),
        initialValue: m.note,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: t('Mere notes', 'My notes'),
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => change(() => m.note = v),
      ),
      Wrap(
        spacing: 8,
        children: [
          button(
            m.step == m.steps.length - 1
                ? t('Complete mark karo', 'Mark complete')
                : t('Step ho gaya', 'Finish step'),
            () => change(() {
              if (m.step < m.steps.length - 1) {
                m.step++;
              } else {
                m.state = 'done';
                focus = null;
                tab = 3;
              }
            }),
          ),
          link(
            t('Pause karo', 'Pause'),
            () => change(() {
              m.state = 'planned';
              focus = null;
            }),
          ),
        ],
      ),
    ], accent: true),
  ];
  List<Widget> progress() => [
    eyebrow(t('Mera record', 'My record')),
    const SizedBox(height: 8),
    heading('Progress'),
    const SizedBox(height: 18),
    panel([
      eyebrow(t('Mukammal missions', 'Completed missions')),
      heading(
        '${plan.missions.where((m) => m.state == 'done' && !m.demo).length}',
      ),
      Text(
        t(
          'Demo missions alag record hote hain.',
          'Practice missions are recorded separately.',
        ),
      ),
    ], accent: true),
    if (plan.missions.isEmpty)
      Text(
        t(
          'Pehla mission banane par yahan nazar aayega.',
          'Your first mission will appear here.',
        ),
      ),
    for (final m in plan.missions.reversed)
      panel([
        eyebrow((m.demo ? 'DEMO   /   ' : '') + stateName(m)),
        titleText(word(m.label)),
        if (m.campus.isNotEmpty) universitySource(m),
        Text(m.day + '   ·   PKT'),
        if (m.note.isNotEmpty) Text(m.note),
        Wrap(
          children: [
            if (m.campus.isNotEmpty)
              link(t('Notice badlo', 'Edit notice'), () => universityNotice(m))
            else
              link(t('Naam badlo', 'Rename'), () => edit(m)),
            if (m.state == 'skipped' || m.day.compareTo(today) > 0)
              link(
                t('Aaj ke liye rakho', 'Plan for today'),
                () => change(() {
                  m.day = today;
                  m.state = 'planned';
                  tab = 0;
                }),
              ),
          ],
        ),
      ]),
  ];
  Future<void> refreshGmail() async {
    if (gmailLoading) return;
    gmailLoading = true;
    try {
      final options =
          {
                'headers': {'X-CareerOS': '1'},
                'cache': 'no-store',
                'signal': requestTimeout(10000),
              }.jsify()
              as JSObject;
      final response = await fetchBoard('/api/gmail'.toJS, options).toDart;
      if (!response.ok) throw const FormatException();
      final data =
          jsonDecode((await response.text().toDart).toDart)
              as Map<String, dynamic>;
      if (mounted)
        setState(() {
          gmail = data;
          gmailOffline = false;
        });
    } catch (_) {
      if (mounted) setState(() => gmailOffline = true);
    } finally {
      gmailLoading = false;
    }
  }

  String gmailState(String value) => switch (value) {
    'connected' => t('Connected', 'Connected'),
    'reconnect_required' => t(
      'Dobara Google sign-in karo',
      'Google sign-in needed',
    ),
    'sync_failed' => t('Aakhri scan fail hua', 'Last scan failed'),
    'partial' => t(
      'Purani emails ka scan jaari hai',
      'Catching up on older emails',
    ),
    _ => t('Connect karna baqi hai', 'Not connected'),
  };
  void openGmailSetup() => openSource(
    ('http://127.0.0.1:4173/gmail/setup?lang=' + (plan.english ? 'en' : 'ur'))
        .toJS,
    '_blank'.toJS,
    'noopener,noreferrer'.toJS,
  );
  List<Widget> gmailSettings() => [
    panel([
      eyebrow('FAST Gmail'),
      Text(
        t(
          'Independent email sync har 15 minute. Laptop aur CareerOS service chalni chahiye.',
          'Independent email sync every 15 minutes. Keep this laptop and the CareerOS service running.',
        ),
      ),
      if (gmailOffline)
        Text(
          t(
            'Local Gmail service se rabta nahi ho saka. CareerOS launcher dobara kholo.',
            'Cannot reach the local Gmail service. Restart the CareerOS launcher.',
          ),
        ),
      if (gmail?['storageError'] == true)
        Text(
          t(
            'Encrypted storage nahi khul saka. Sync ruka hua hai.',
            'Encrypted storage is unavailable. Sync is paused.',
          ),
        ),
      if (gmail?['scanning'] == true)
        Text(t('Email check ho rahi hai…', 'Checking email…')),
      for (final account in (gmail?['accounts'] as List? ?? []))
        Text(
          'FAST ${account['campus']} · ${gmailState(account['status'])}' +
              (account['email'] == '' ? '' : '\n${account['email']}') +
              (account['lastSuccess'] == ''
                  ? ''
                  : '\n' +
                        t('Aakhri check ', 'Last checked ') +
                        pkt(DateTime.parse(account['lastSuccess'])) +
                        ' PKT'),
        ),
      button(t('Gmail setup kholo', 'Open Gmail setup'), openGmailSetup),
    ]),
  ];
  List<Widget> gmailCards() {
    if (gmail == null || gmail?['ready'] != true)
      return [
        panel([
          eyebrow('FAST Gmail'),
          Text(
            t(
              'Google connect karne ke baad university updates yahan khud aayengi.',
              'University updates will appear here automatically after you connect Google.',
            ),
          ),
          link(t('Gmail connect karo', 'Connect Gmail'), openGmailSetup),
        ]),
      ];
    final source = (gmail?['notices'] as List? ?? []);
    final fingerprints = <String>{}, threads = <String>{};
    final notices = <Map>[];
    for (final item in source.whereType<Map>()) {
      final thread = '${item['campus']}/${item['threadId']}';
      if (threads.contains(thread) ||
          fingerprints.contains(item['fingerprint']))
        continue;
      threads.add(thread);
      fingerprints.add(item['fingerprint']);
      notices.add(item);
    }
    return [
      ExpansionTile(
        initiallyExpanded: notices.isNotEmpty,
        title: Text(t('FAST ki automatic updates', 'Automatic FAST updates')),
        subtitle: Text(
          gmailOffline
              ? t(
                  'Service offline · purana data',
                  'Service offline · cached data',
                )
              : t(
                  '${notices.length} notices · har 15 min sync',
                  '${notices.length} notices · sync every 15 min',
                ),
        ),
        children: [
          if (notices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                t(
                  'Settings mein campus connection aur last scan dekho.',
                  'Check the campus connection and last scan in Settings.',
                ),
              ),
            ),
          for (final notice in notices.take(20))
            panel([
              eyebrow('FAST ${notice['campus']}'),
              titleText(notice['subject']),
              Text(notice['excerpt']),
              Text(pkt(DateTime.parse(notice['received'])) + ' PKT'),
              if (notice['deadline'] != '')
                Text(
                  t(
                        'Mumkin deadline (verify karo) ',
                        'Possible deadline (verify) ',
                      ) +
                      notice['deadline'],
                ),
              Wrap(
                children: [
                  link(
                    t('Asli email kholo', 'Open original email'),
                    () => openSource(
                      (notice['url'] as String).toJS,
                      '_blank'.toJS,
                      'noopener,noreferrer'.toJS,
                    ),
                  ),
                  if (plan.find(notice['id']) == null)
                    button(t('Mere saath karo', 'Do it with me'), () {
                      final m = Mission(
                        notice['id'],
                        today,
                        title: notice['subject'],
                        subject: notice['subject'],
                        campus: notice['campus'],
                        url: notice['url'],
                        suggestedDeadline: notice['deadline'],
                        deadlineEvidence: notice['deadlineEvidence'],
                        note: notice['excerpt'],
                      );
                      add(m);
                      change(() {
                        m.state = 'running';
                        focus = m.id;
                      });
                    })
                  else
                    link(t('Progress dekho', 'View progress'), () => go(3)),
                ],
              ),
            ]),
        ],
      ),
    ];
  }

  Widget universitySource(Mission m) => Text(
    'FAST ${m.campus}   ·   ${m.subject}\n' +
        (m.deadline.isEmpty
            ? t('Deadline confirm nahi hai', 'Deadline not confirmed')
            : 'Deadline: ${m.deadline} (PKT)'),
  );

  Future<void> universityNotice([Mission? previous]) async {
    final form = GlobalKey<FormState>();
    var campus = previous?.campus ?? 'Karachi',
        subject = previous?.subject ?? '',
        action = previous?.title ?? '',
        due = previous?.deadline ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          scrollable: true,
          title: Text(t('FAST ka notice', 'FAST notice')),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Kaunsi campus email?', 'Which campus inbox?')),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Karachi', label: Text('Karachi')),
                    ButtonSegment(value: 'Lahore', label: Text('Lahore')),
                  ],
                  selected: {campus},
                  onSelectionChanged: (v) => update(() => campus = v.first),
                ),
                TextFormField(
                  initialValue: subject,
                  decoration: InputDecoration(
                    labelText: t('Email ka subject', 'Email subject'),
                  ),
                  onChanged: (v) => subject = v.trim(),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? t('Subject likho', 'Enter the subject')
                      : null,
                ),
                TextFormField(
                  initialValue: action,
                  decoration: InputDecoration(
                    labelText: t('Kya karna hai?', 'Required action'),
                  ),
                  onChanged: (v) => action = v.trim(),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? t('Kaam likho', 'Enter the action')
                      : null,
                ),
                TextFormField(
                  initialValue: due,
                  decoration: InputDecoration(
                    labelText: t(
                      'Deadline (agar di hai)',
                      'Deadline (optional)',
                    ),
                    helperText: 'YYYY-MM-DD · PKT',
                  ),
                  onChanged: (v) => due = v.trim(),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    final date = DateTime.tryParse('${value}T00:00:00Z');
                    if (date == null ||
                        date.toIso8601String().split('T').first != value)
                      return t(
                        'Sahi tareekh YYYY-MM-DD mein likho',
                        'Enter a valid date as YYYY-MM-DD',
                      );
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            link(t('Wapas', 'Cancel'), () => Navigator.pop(ctx, false)),
            button(t('Save karo', 'Save'), () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            }),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final duplicate = plan.missions.any(
      (m) =>
          m != previous &&
          m.campus == campus &&
          m.subject.toLowerCase() == subject.toLowerCase() &&
          m.title.toLowerCase() == action.toLowerCase() &&
          m.deadline == due,
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Ye notice pehle se Progress mein hai.',
              'This notice is already in Progress.',
            ),
          ),
        ),
      );
      return;
    }
    if (previous != null) {
      change(() {
        previous.campus = campus;
        previous.subject = subject;
        previous.title = action;
        previous.deadline = due;
      });
      return;
    }
    add(
      Mission(
        'fast-${DateTime.now().microsecondsSinceEpoch}',
        today,
        title: action,
        campus: campus,
        subject: subject,
        deadline: due,
      ),
    );
  }

  List<Widget> settings() => [
    eyebrow('CareerOS'),
    heading('Settings'),
    const SizedBox(height: 18),
    ...gmailSettings(),
    panel([
      titleText(t('Zabaan', 'Language')),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Roman Urdu')),
          ButtonSegment(value: true, label: Text('English')),
        ],
        selected: {plan.english},
        onSelectionChanged: (v) => change(() => plan.english = v.first),
      ),
    ]),
    panel([
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Exam Mode'),
        subtitle: Text(
          t(
            'Saat din ke liye workload kam karo.',
            'Reduce workload for seven days.',
          ),
        ),
        value: plan.exam(today),
        onChanged: (v) => change(
          () => plan.examUntil = v
              ? dayAt(DateTime.now().add(const Duration(days: 6)))
              : '',
        ),
      ),
      if (plan.exam(today))
        Text(t('Aakhri din: ', 'Last day: ') + plan.examUntil),
    ]),
    panel([
      titleText(t('Is device ka workspace', 'Device workspace')),
      Text(
        t(
          'Missions aur notes is browser mein save hain. Gmail ki connection details is laptop par Windows encryption se mehfooz hain.',
          'Missions and notes are saved in this browser. Gmail credentials are protected by Windows encryption on this laptop.',
        ),
      ),
    ]),
  ];

  Future<void> edit([Mission? m]) async {
    final form = GlobalKey<FormState>();
    String name = m == null ? '' : word(m.label), url = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          m == null
              ? t('Listing add karo', 'Add listing')
              : t('Naam badlo', 'Rename mission'),
        ),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                autofocus: true,
                decoration: InputDecoration(labelText: t('Naam', 'Title')),
                onChanged: (v) => name = v.trim(),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? t('Naam likho', 'Enter a title')
                    : null,
              ),
              if (m == null)
                TextFormField(
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: t(
                      'Asli listing ka HTTPS link',
                      'Original HTTPS listing URL',
                    ),
                  ),
                  onChanged: (v) => url = v.trim(),
                  validator: (v) {
                    final u = Uri.tryParse((v ?? '').trim());
                    return u != null &&
                            u.scheme == 'https' &&
                            u.host.isNotEmpty &&
                            u.userInfo.isEmpty
                        ? null
                        : t('HTTPS link likho', 'Enter an HTTPS URL');
                  },
                ),
            ],
          ),
        ),
        actions: [
          link(t('Wapas', 'Cancel'), () => Navigator.pop(ctx, false)),
          button(t('Save karo', 'Save'), () {
            if (form.currentState!.validate()) Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (m != null) {
      change(() => m.title = name);
      return;
    }
    final existing = plan.missions.where((x) => x.url == url).firstOrNull;
    if (existing != null) {
      go(3);
      return;
    }
    add(
      Mission(
        'listing-${DateTime.now().microsecondsSinceEpoch}',
        today,
        title: name,
        url: url,
      ),
    );
  }
}
