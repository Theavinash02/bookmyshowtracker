import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'background.dart';
import 'checker.dart';
import 'models.dart';
import 'notifications.dart';
import 'storage.dart';
import 'web_fetcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications(handleTaps: true);
  await configureBackgroundService();
  // App launched by tapping the alarm while it was closed.
  final launch = await notifications.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp ?? false) {
    unawaited(openBookMyShow(launch!.notificationResponse?.payload));
  }
  runApp(const TrackerApp());
}

const bmsRed = Color(0xFFE7394D);

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMS Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: bmsRed, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: bmsRed,
          brightness: Brightness.dark,
          useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  TrackerConfig? cfg;
  bool running = false;
  Map<String, dynamic>? status;
  StreamSubscription? _statusSub;
  bool testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _statusSub = service.on('status').listen((_) => _loadStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final c = await Storage.loadConfig();
    final r = await Storage.isRunning() && await service.isRunning();
    final s = await Storage.lastStatus();
    if (!mounted) return;
    setState(() {
      cfg = c;
      running = r;
      status = s;
    });
  }

  Future<void> _loadStatus() async {
    final s = await Storage.lastStatus();
    if (mounted) setState(() => status = s);
  }

  Future<void> _save(TrackerConfig c) async {
    setState(() => cfg = c);
    await Storage.saveConfig(c);
    if (running) service.invoke('checkNow');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  /// True when the last check is much older than one interval plus the
  /// time a check takes, i.e. the background tracker probably stopped.
  bool _isStale(DateTime last, int? tookSeconds, TrackerConfig c) {
    final expected = c.intervalSeconds + (tookSeconds ?? 60) + 10;
    return DateTime.now().difference(last).inSeconds > expected * 3 + 120;
  }

  // ---------------------------------------------------------------- tracking

  Future<void> _toggle(bool on) async {
    if (on) {
      final c = cfg!;
      if (c.movies.where((m) => m.enabled).isEmpty) {
        _snack('Add a movie first');
        return;
      }
      await _askPermissions();
      await startTracking();
    } else {
      await stopTracking();
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _load();
  }

  Future<void> _askPermissions() async {
    final android = notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestFullScreenIntentPermission();
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> _testNow() async {
    final c = cfg!;
    final movies = c.movies.where((m) => m.enabled).toList();
    if (movies.isEmpty) {
      _snack('Add a movie first');
      return;
    }
    setState(() => testing = true);
    final loader = PageLoader();
    final report = <Widget>[];
    final started = DateTime.now();
    try {
      for (final m in movies) {
        final versions = await discoverVersions(loader.load, m, click: loader.click);
        final res = await checkMovie(
            fetch: loader.load, config: c, movie: m, versions: versions);
        report.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
              '${m.title} · ${m.city}\n'
              '${m.allVersions ? 'Versions found: ${versions.length} (${versions.map((v) => v.eventCode).join(', ')})' : 'This version only'}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ));
        for (final r in res) {
          final label = switch (r.outcome) {
            Outcome.open => 'OPEN',
            Outcome.notOpen => 'Not open yet',
            Outcome.blocked => 'BLOCKED',
            Outcome.error => 'ERROR',
          };
          report.add(ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${r.label.isNotEmpty ? '${r.label} · ' : r.version.isEmpty ? '' : '${r.version} · '}${shortDate(r.date)} – $label'
                '${r.matchedTheaters.isEmpty ? '' : '\nYour theaters: ${r.matchedTheaters.map((t) => t.name).join(', ')}'}'),
            subtitle: SelectableText('${r.detail}\n${r.debug}'),
            onTap: () => openBookMyShow(r.url),
          ));
        }
      }
    } catch (e) {
      report.add(Text('Check failed: $e', style: const TextStyle(color: Colors.red)));
    } finally {
      await loader.close();
      if (mounted) setState(() => testing = false);
    }
    if (!mounted) return;
    final took = DateTime.now().difference(started).inSeconds;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Check result (no alarm) · ${took}s'),
        content: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: report)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- movies

  Future<void> _addMovie() async {
    final m = await showDialog<Movie>(
        context: context, builder: (_) => MovieDialog(city: cfg!.city));
    if (m == null) return;
    final c = cfg!;
    final existed = c.movies.any((x) => x.id == m.id);
    final list = [...c.movies.where((x) => x.id != m.id), m];
    await _save(c.copyWith(movies: list));
    if (existed) _snack('${m.title} in ${m.city} was already added – updated it.');
  }

  Future<void> _editMovie(Movie m) async {
    final edited = await showDialog<Movie>(
        context: context,
        builder: (_) => MovieDialog(city: cfg!.city, existing: m));
    if (edited == null) return;
    await _save(cfg!.copyWith(
        movies: cfg!.movies.map((x) => x.id == m.id ? edited : x).toList()));
  }

  // ---------------------------------------------------------------- theaters

  Future<void> _editTheater([Theater? t]) async {
    final res = await showDialog<Theater>(
        context: context, builder: (_) => TheaterDialog(existing: t));
    if (res == null) return;
    final list = [...cfg!.theaters];
    final i = t == null ? -1 : list.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      list[i] = res;
    } else if (!list.any((x) => x.id == res.id)) {
      list.add(res);
    }
    await _save(cfg!.copyWith(theaters: list));
  }

  Future<void> _deleteTheater(Theater t) async {
    await _save(cfg!.copyWith(
        theaters: cfg!.theaters.where((x) => x.id != t.id).toList()));
  }

  Future<void> _loadTheatersFromBms() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load theaters from BookMyShow'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Paste the BookMyShow link of ANY movie that is running in '
              'Trichy today (movie page or "Book tickets" page).'),
          TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'BookMyShow link')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Load')),
        ],
      ),
    );
    if (url == null || extractUrl(url) == null) return;
    final link = extractUrl(url)!;
    // A plain movie page lists no theaters: open its show-times
    // ("Book tickets") page for today, then the next two days.
    final candidates = <String>[];
    final parsed = parseMovieUrl(link, city: cfg!.city);
    if (link.toLowerCase().contains('buytickets') || parsed == null) {
      candidates.add(link);
    } else {
      final today = DateTime.now();
      final m = Movie(
          title: '',
          url: link,
          eventCode: parsed.eventCode,
          slug: parsed.slug,
          city: parsed.city ?? cfg!.city,
          startDate: today);
      for (var i = 0; i < 3; i++) {
        candidates.add(buildShowtimesUrl(cfg!.showtimesTemplate, m,
            DateTime(today.year, today.month, today.day + i)));
      }
    }
    setState(() => testing = true);
    _snack('Loading theaters from BookMyShow…');
    final loader = PageLoader();
    List<String> names = [];
    String? err;
    try {
      for (final c in candidates) {
        final page = await loader.load(c);
        names = extractVenueNames(page.body);
        if (names.isNotEmpty) break;
        err = 'No theater names found.\n${describePage(page)}';
      }
    } catch (e) {
      err = '$e';
    } finally {
      await loader.close();
    }
    if (!mounted) return;
    setState(() => testing = false);
    if (names.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Could not load theaters'),
          content: SingleChildScrollView(
              child: SelectableText('${err ?? ''}\n\n'
                  'Add theaters manually with "Add theater" instead.')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );
      return;
    }
    final existing = cfg!.theaters.map((t) => normalize(t.name)).toSet();
    final picked = await showDialog<List<String>>(
        context: context,
        builder: (_) => PickNamesDialog(
            names: names.where((n) => !existing.contains(normalize(n))).toList()));
    if (picked == null || picked.isEmpty) return;
    final list = [
      ...cfg!.theaters,
      for (final n in picked) Theater(name: n, keyword: n, selected: true),
    ];
    await _save(cfg!.copyWith(theaters: list));
  }

  // ---------------------------------------------------------------- settings

  Future<void> _settings() async {
    final res = await showDialog<TrackerConfig>(
        context: context, builder: (_) => SettingsDialog(cfg: cfg!));
    if (res != null) await _save(res);
  }

  @override
  Widget build(BuildContext context) {
    final c = cfg;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final st = status;
    final stTime = st == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(st['time'] as int);
    return Scaffold(
      appBar: AppBar(
        title: const Text('BMS Tracker · Trichy'),
        actions: [
          IconButton(onPressed: _settings, icon: const Icon(Icons.settings)),
          Switch(value: running, onChanged: _toggle),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMovie,
        icon: const Icon(Icons.add),
        label: const Text('Movie'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          children: [
            Card(
              color: running
                  ? (st?['open'] == true
                      ? Colors.green.withValues(alpha: 0.25)
                      : null)
                  : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        running
                            ? 'Tracking ON – every ~${c.intervalSeconds}s'
                            : 'Tracking OFF – turn on the switch above',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (stTime != null) ...[
                      const SizedBox(height: 4),
                      Text('Last check: ${TimeOfDay.fromDateTime(stTime).format(context)}'
                          ' (${shortDate(stTime)})'
                          '${st!['took'] == null ? '' : ' · took ${st['took']}s'}'),
                      if (running && _isStale(stTime, st['took'] as int?, c))
                        const Text(
                            '⚠ No check for a while: the phone may have paused the '
                            'tracker. Set Battery → BMS Tracker → Unrestricted, keep '
                            'the "watching" notification, then switch tracking off and on.',
                            style: TextStyle(color: Colors.red)),
                      for (final l in (st['lines'] as List)) Text('• $l'),
                      if (st['blocked'] == true)
                        const Text(
                            '⚠ BookMyShow refused some requests. If this keeps '
                            'happening, switch Wi-Fi/mobile data or raise the interval.',
                            style: TextStyle(color: Colors.orange)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: testing ? null : _testNow,
                        icon: testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search),
                        label: const Text('Check now'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _askPermissions();
                          await showTicketsOpenAlarm(
                              title: '🎟️ Test alarm',
                              body: 'This is how the alert will look and sound.',
                              url: 'https://in.bookmyshow.com/explore/movies-${c.city}');
                        },
                        icon: const Icon(Icons.alarm),
                        label: const Text('Test alarm'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const _Header('Movies'),
            if (c.movies.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                    'Tap "+ Movie" and paste the BookMyShow link of the movie '
                    '(e.g. Avengers: Doomsday). In the BookMyShow app: open the '
                    'movie → Share → Copy link.'),
              ),
            for (final m in c.movies)
              Card(
                child: ListTile(
                  title: Text(m.title),
                  subtitle: Text('${m.city} · ${m.eventCode}${m.allVersions ? ' + all versions' : ''} · ${m.dates.map(shortDate).join(', ')}'),
                  onTap: () => _editMovie(m),
                  leading: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _save(c.copyWith(
                        movies: c.movies.where((x) => x.id != m.id).toList())),
                  ),
                  trailing: Switch(
                    value: m.enabled,
                    onChanged: (v) => _save(c.copyWith(
                        movies: c.movies
                            .map((x) => x.id == m.id ? x.copyWith(enabled: v) : x)
                            .toList())),
                  ),
                ),
              ),
            _Header('Theaters (${c.selectedTheaters.length} selected)'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                c.selectedTheaters.isEmpty
                    ? 'No theater selected: you will be alerted when booking opens anywhere in ${c.city}.'
                    : c.alertAnyTheater
                        ? 'Alarm for your theaters, plus one alarm when booking opens anywhere in ${c.city}.'
                        : 'Alarm only for the selected theaters.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final t in c.theaters)
              CheckboxListTile(
                value: t.selected,
                title: Text(t.name),
                subtitle: Text('matches "${t.keyword}"'),
                onChanged: (v) => _save(c.copyWith(
                    theaters: c.theaters
                        .map((x) => x.id == t.id ? x.copyWith(selected: v) : x)
                        .toList())),
                secondary: PopupMenuButton<String>(
                  onSelected: (a) =>
                      a == 'edit' ? _editTheater(t) : _deleteTheater(t),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                  onPressed: () => _editTheater(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add theater')),
              TextButton.icon(
                  onPressed: _loadTheatersFromBms,
                  icon: const Icon(Icons.download),
                  label: const Text('Load from BookMyShow')),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

// ------------------------------------------------------------------ dialogs

class MovieDialog extends StatefulWidget {
  const MovieDialog({super.key, required this.city, this.existing});
  final String city;
  final Movie? existing;
  @override
  State<MovieDialog> createState() => _MovieDialogState();
}

class _MovieDialogState extends State<MovieDialog> {
  late final url = TextEditingController(text: widget.existing?.url ?? '');
  late final title = TextEditingController(text: widget.existing?.title ?? '');
  late DateTime start = widget.existing?.startDate ?? _defaultStart();
  late int days = widget.existing?.days ?? 3;
  late bool allVersions = widget.existing?.allVersions ?? true;
  late final city = TextEditingController(text: widget.existing?.city ?? widget.city);
  String? error;

  static DateTime _defaultStart() {
    // Avengers: Doomsday India release (17 Dec 2026, per BookMyShow). Editable.
    final release = DateTime(2026, 12, 17);
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    return release.isBefore(t) ? t : release;
  }

  void _urlChanged(String v) {
    final p = parseMovieUrl(v, city: city.text.trim());
    if (p != null && title.text.trim().isEmpty) title.text = p.suggestedTitle;
    if (p?.city != null) city.text = p!.city!;
    setState(() => error = null);
  }

  void _submit() {
    final p = parseMovieUrl(url.text, city: city.text.trim());
    final c = city.text.trim().toLowerCase();
    if (p == null) {
      setState(() => error =
          'Link must contain the movie code (ET00…). Copy it from the movie page on BookMyShow.');
      return;
    }
    Navigator.pop(
      context,
      Movie(
        title: title.text.trim().isEmpty ? p.suggestedTitle : title.text.trim(),
        url: p.url,
        eventCode: p.eventCode,
        slug: p.slug,
        city: c.isEmpty ? (p.city ?? widget.city) : c,
        allVersions: allVersions,
        startDate: start,
        days: days,
        enabled: widget.existing?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add movie' : 'Edit movie'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: url,
            onChanged: _urlChanged,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'BookMyShow movie link',
              hintText:
                  'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/ET00…',
              errorText: error,
              errorMaxLines: 3,
              helperText:
                  'Each language/format (Tamil, English, 3D…) has its own code on '
                  'BookMyShow. Add one entry per version you would watch: on '
                  'in.bookmyshow.com pick the language, open the show-times page '
                  'and copy its link (…/buytickets/ET00…/date).',
              helperMaxLines: 6,
            ),
          ),
          TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title')),
          TextField(
              controller: city,
              decoration: const InputDecoration(
                  labelText: 'BookMyShow city',
                  helperText:
                      'Filled from the link. Add the same movie again with another '
                      'city (e.g. trichy and tiruchirappalli) to watch both.',
                  helperMaxLines: 3)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('First show date to watch'),
            subtitle: Text('${shortDate(start)} ${start.year}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: start,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => start = d);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: allVersions,
            onChanged: (v) => setState(() => allVersions = v),
            title: const Text('Watch all languages & formats'),
            subtitle: const Text(
                'Also checks the other versions (Tamil, Hindi, 3D, IMAX…) listed '
                'on this movie\'s BookMyShow page.'),
          ),
          Row(children: [
            const Expanded(child: Text('Days to watch')),
            IconButton(
                onPressed: days > 1 ? () => setState(() => days--) : null,
                icon: const Icon(Icons.remove)),
            Text('$days'),
            IconButton(
                onPressed: days < 7 ? () => setState(() => days++) : null,
                icon: const Icon(Icons.add)),
          ]),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class TheaterDialog extends StatefulWidget {
  const TheaterDialog({super.key, this.existing});
  final Theater? existing;
  @override
  State<TheaterDialog> createState() => _TheaterDialogState();
}

class _TheaterDialogState extends State<TheaterDialog> {
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final kw = TextEditingController(text: widget.existing?.keyword ?? '');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add theater' : 'Edit theater'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name')),
        TextField(
            controller: kw,
            decoration: const InputDecoration(
                labelText: 'Match keyword',
                helperText:
                    'A distinctive word from the theater name as shown on '
                    'BookMyShow. Several spellings: Thiruverumbur|Tiruverumbur',
                helperMaxLines: 2)),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final n = name.text.trim();
            final k = kw.text.trim().isEmpty ? n : kw.text.trim();
            if (n.isEmpty || normalize(k).isEmpty) return;
            Navigator.pop(
                context,
                Theater(
                    name: n,
                    keyword: k,
                    selected: widget.existing?.selected ?? true));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class PickNamesDialog extends StatefulWidget {
  const PickNamesDialog({super.key, required this.names});
  final List<String> names;
  @override
  State<PickNamesDialog> createState() => _PickNamesDialogState();
}

class _PickNamesDialogState extends State<PickNamesDialog> {
  final picked = <String>{};
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.names.length} new theaters found'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: [
          for (final n in widget.names)
            CheckboxListTile(
              value: picked.contains(n),
              title: Text(n),
              onChanged: (v) =>
                  setState(() => v == true ? picked.add(n) : picked.remove(n)),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, picked.toList()),
            child: const Text('Add selected')),
      ],
    );
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.cfg});
  final TrackerConfig cfg;
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double interval = widget.cfg.intervalSeconds.toDouble();
  late bool any = widget.cfg.alertAnyTheater;
  late final city = TextEditingController(text: widget.cfg.city);
  late final template =
      TextEditingController(text: widget.cfg.showtimesTemplate);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Check every ${interval.round()} seconds'),
          Slider(
              min: 30,
              max: 300,
              divisions: 27,
              value: interval,
              onChanged: (v) => setState(() => interval = v)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: any,
            onChanged: (v) => setState(() => any = v),
            title: const Text('Also alarm when booking opens at any theater'),
          ),
          TextField(
              controller: city,
              decoration: const InputDecoration(
                  labelText: 'Default BookMyShow city',
                  helperText: 'Used when a movie link has no city. Each movie keeps the city from its own link.',
                  helperMaxLines: 2)),
          TextField(
              controller: template,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Show-times URL pattern (advanced)',
                  helperText: '{city} {slug} {event} {date}')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () async {
                  await Storage.clearAlerted();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Alerts reset – you will be alarmed again.')));
                  }
                },
                child: const Text('Reset alerts')),
            OutlinedButton(
                onPressed: () => template.text = defaultShowtimesTemplate,
                child: const Text('Default pattern')),
          ]),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.cfg.copyWith(
              intervalSeconds: interval.round(),
              alertAnyTheater: any,
              city: city.text.trim().isEmpty
                  ? defaultCity
                  : city.text.trim().toLowerCase(),
              showtimesTemplate: template.text.trim().isEmpty
                  ? defaultShowtimesTemplate
                  : template.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
