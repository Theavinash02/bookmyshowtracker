import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'background.dart';
import 'checker.dart';
import 'models.dart';
import 'notifications.dart';
import 'storage.dart';
import 'ui/movie_page.dart';
import 'ui/report_page.dart';
import 'ui/settings_page.dart';
import 'ui/theaters_page.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';
import 'web_fetcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications(handleTaps: true);
  await configureBackgroundService();
  // App launched by the user tapping the alarm while it was closed: open the
  // BookMyShow page of that alarm. (Alarms never open anything by themselves.)
  final launch = await notifications.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp ?? false) {
    unawaited(openBookMyShow(launch!.notificationResponse?.payload));
  }
  runApp(const TrackerApp());
}

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMS Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
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
  List<(DateTime, String)> alarms = [];
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
    final a = await Storage.alarmLog();
    if (!mounted) return;
    setState(() {
      cfg = c;
      running = r;
      status = s;
      alarms = a;
    });
  }

  Future<void> _loadStatus() async {
    final s = await Storage.lastStatus();
    final a = await Storage.alarmLog();
    if (mounted) {
      setState(() {
        status = s;
        alarms = a;
      });
    }
  }

  Future<void> _save(TrackerConfig c) async {
    setState(() => cfg = c);
    await Storage.saveConfig(c);
    if (running) service.invoke('checkNow');
  }

  void _snack(String msg, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), action: action));

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
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> _testAlarm() async {
    await _askPermissions();
    final city = cfg!.city;
    await showTicketsOpenAlarm(
        title: '🎟️ Test alarm',
        body: 'This is how the alert will look and sound.',
        url: city.isEmpty
            ? 'https://in.bookmyshow.com/'
            : 'https://in.bookmyshow.com/explore/movies-$city');
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
    final sections = <Widget>[];
    final started = DateTime.now();
    final alerted = await Storage.alertedKeys();
    final ringing = <String>[];
    try {
      for (final m in movies) {
        final versions = await discoverVersions(loader.load, m, click: loader.click);
        final res = await checkMovie(
            fetch: loader.load, config: c, movie: m, versions: versions);
        // Ring for selected theaters that haven't rung yet (shared memory
        // with the background tracker, so nothing rings twice).
        final fresh = <String, Theater>{};
        final dates = <String, Set<DateTime>>{};
        String? url;
        for (final r in res.where((r) => r.outcome == Outcome.open)) {
          for (final t in r.matchedTheaters) {
            final key = '${m.id}|${t.id}';
            if (alerted.contains(key)) continue;
            fresh[key] = t;
            dates.putIfAbsent(key, () => {}).add(r.date);
            url ??= r.url;
          }
        }
        if (fresh.isNotEmpty) {
          final parts = fresh.entries.map((e) =>
              '${e.value.name} (${dates[e.key]!.map(shortDate).join(', ')})');
          await showTicketsOpenAlarm(
            title: '🎟️ ${m.title} (${m.city}): BOOKING OPEN!',
            body: 'Open now at ${parts.join('; ')}. Tap to open BookMyShow.',
            url: url!,
          );
          await Storage.addAlertedKeys(fresh.keys);
          await Storage.logAlarm('${m.title} (${m.city}): ${parts.join('; ')} [Check now]');
          ringing.addAll(fresh.values.map((t) => t.name));
        }
        sections.add(_CheckResultCard(
            movie: m,
            versions: versions.map((v) => v.eventCode).toList(),
            results: res,
            cfg: c,
            alerted: alerted));
      }
    } catch (e) {
      sections.add(InfoBanner(icon: Icons.error_outline, text: 'Check failed: $e'));
    } finally {
      await loader.close();
      if (mounted) setState(() => testing = false);
    }
    if (!mounted) return;
    final took = DateTime.now().difference(started).inSeconds;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPage(
          title: 'Check result · ${took}s',
          highlight: ringing.isNotEmpty,
          intro: ringing.isEmpty
              ? 'Each theater rings once per movie. To ring again, use '
                  'Settings → Reset alerts. Tap a date to open it in BookMyShow.'
              : '🔔 Alarm rang for: ${ringing.join(', ')}',
          sections: sections,
        ),
      ),
    );
  }

  void _openBackgroundReport(List report) => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ReportPage.text(
            title: 'Background report',
            intro: 'This is exactly what the tracker that rings the alarm saw '
                'on its last check. Long-press to copy it into a bug report.',
            blocks: report.cast<String>(),
          ),
        ),
      );

  // ---------------------------------------------------------------- movies

  Future<void> _addMovie() async {
    final m = await Navigator.push<Movie>(context,
        MaterialPageRoute(builder: (_) => MoviePage(city: cfg!.city)));
    if (m == null) return;
    final c = cfg!;
    final existed = c.movies.any((x) => x.id == m.id);
    final list = [...c.movies.where((x) => x.id != m.id), m];
    await _save(c.copyWith(movies: list));
    if (existed) _snack('${m.title} in ${m.city} was already added. Updated it.');
    if (cfg!.city.isEmpty) await _save(cfg!.copyWith(city: m.city));
    if (!mounted) return;
    if (cfg!.theaters.isEmpty) {
      final load = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.theaters_outlined),
          title: const Text('Pick your theaters?'),
          content: Text('Load the list of ${cityName(m.city)} theaters from '
              'BookMyShow and tick the ones you want. Without any ticked '
              'theater, the alarm rings when booking opens anywhere in the city.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Later')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Load theaters')),
          ],
        ),
      );
      if (load == true) await _openTheaters(autoLoadFrom: m.url);
    }
  }

  Future<void> _editMovie(Movie m) async {
    final edited = await Navigator.push<Movie>(
        context,
        MaterialPageRoute(
            builder: (_) => MoviePage(city: cfg!.city, existing: m)));
    if (edited == null) return;
    await _save(cfg!.copyWith(
        movies: cfg!.movies.map((x) => x.id == m.id ? edited : x).toList()));
  }

  Future<void> _deleteMovie(Movie m) async {
    final before = cfg!;
    await _save(before.copyWith(
        movies: before.movies.where((x) => x.id != m.id).toList()));
    if (!mounted) return;
    _snack('Deleted ${m.title}',
        action: SnackBarAction(label: 'Undo', onPressed: () => _save(before)));
  }

  // ---------------------------------------------------------------- pages

  Future<void> _openTheaters({String? autoLoadFrom}) => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => TheatersPage(
              cfg: cfg!, onChanged: _save, autoLoadFrom: autoLoadFrom),
        ),
      );

  Future<void> _settings() async {
    final res = await Navigator.push<TrackerConfig>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                SettingsPage(cfg: cfg!, onTestAlarm: _testAlarm)));
    if (res != null) await _save(res);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final c = cfg;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final st = status;
    final stTime = st?['time'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(st!['time'] as int);
    final errTime = st?['errorTime'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(st!['errorTime'] as int);
    final showError = st?['error'] != null &&
        errTime != null &&
        (stTime == null || !errTime.isBefore(stTime));
    final stale = running && stTime != null && _isStale(stTime, st?['took'] as int?, c);
    final states = <String, Map<String, String>>{
      for (final e in ((st?['states'] as Map?) ?? {}).entries)
        '${e.key}': {
          for (final d in (e.value as Map).entries) '${d.key}': '${d.value}'
        },
    };
    final warnings = <String>[
      for (final l in ((st?['lines'] as List?) ?? const []))
        if ('$l'.contains('⚠')) '$l',
    ];
    final enabled = c.movies.where((m) => m.enabled).length;
    String hm(DateTime t) => TimeOfDay.fromDateTime(t).format(context);
    final lastCheck = stTime == null
        ? 'First check starting…'
        : 'Last check ${hm(stTime)}'
            '${st?['took'] == null ? '' : ' · took ${st!['took']}s'}';

    final (TrackerState state, String title, String subtitle) = !running
        ? (
            TrackerState.off,
            'Tracking is off',
            c.movies.isEmpty
                ? 'Add a movie, then start tracking.'
                : 'Start tracking to get an alarm when booking opens.'
          )
        : showError
            ? (
                TrackerState.error,
                'Check failed',
                'At ${hm(errTime)}: ${st!['error']}. Retrying automatically.'
              )
            : stale
                ? (
                    TrackerState.paused,
                    'Paused by your phone',
                    'No check since ${hm(stTime)}. Set Battery → BMS Tracker → '
                        'Unrestricted, then stop and start tracking.'
                  )
                : st?['open'] == true
                    ? (
                        TrackerState.open,
                        'Booking open!',
                        'At your theater. Tap the alarm notification to book. '
                            '$lastCheck'
                      )
                    : (
                        TrackerState.watching,
                        'Watching $enabled movie${enabled == 1 ? '' : 's'}',
                        'Every ~${c.intervalSeconds}s · $lastCheck'
                      );

    final selected = c.selectedTheaters;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.confirmation_number_outlined,
                size: 18, color: scheme.onPrimary),
          ),
          const SizedBox(width: 10),
          const Text('BMS Tracker'),
        ]),
        actions: [
          IconButton(
              tooltip: 'Settings',
              onPressed: _settings,
              icon: const Icon(Icons.settings_outlined)),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: c.movies.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addMovie,
              icon: const Icon(Icons.add),
              label: const Text('Add movie'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
          children: [
            StatusHero(
              state: state,
              title: title,
              subtitle: subtitle,
              running: running,
              onToggle: () => _toggle(!running),
            ),
            if (running && st?['blocked'] == true) ...[
              const SizedBox(height: 10),
              const InfoBanner(
                  icon: Icons.block,
                  text: 'BookMyShow refused some requests. If this keeps '
                      'happening, switch between Wi-Fi and mobile data or '
                      'raise the check interval in Settings.'),
            ],
            for (final w in warnings) ...[
              const SizedBox(height: 10),
              InfoBanner(icon: Icons.event_busy, text: w),
            ],
            const SizedBox(height: 12),
            Row(children: [
              QuickAction(
                  icon: Icons.search,
                  label: 'Check now',
                  busy: testing,
                  onTap: c.movies.isEmpty ? null : _testNow),
              const SizedBox(width: 10),
              QuickAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'Report',
                  onTap: st?['report'] == null
                      ? null
                      : () => _openBackgroundReport(st!['report'] as List)),
              const SizedBox(width: 10),
              QuickAction(
                  icon: Icons.alarm, label: 'Test alarm', onTap: _testAlarm),
            ]),
            SectionHeader(
              c.movies.isEmpty ? 'Movies' : 'Movies · ${c.movies.length}',
            ),
            if (c.movies.isEmpty)
              GettingStarted(onAddMovie: _addMovie)
            else
              for (final m in c.movies) ...[
                MovieCard(
                  movie: m,
                  states: states[m.id] ?? const {},
                  onTap: () => _editMovie(m),
                  onDelete: () => _deleteMovie(m),
                  onToggle: (v) => _save(c.copyWith(
                      movies: c.movies
                          .map((x) => x.id == m.id ? x.copyWith(enabled: v) : x)
                          .toList())),
                ),
                const SizedBox(height: 10),
              ],
            const SectionHeader('Theaters'),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                leading: CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(Icons.theaters_outlined,
                      color: scheme.onSecondaryContainer),
                ),
                title: Text(
                    c.theaters.isEmpty
                        ? 'No theaters yet'
                        : selected.isEmpty
                            ? 'Any theater'
                            : '${selected.length} of ${c.theaters.length} selected',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  c.theaters.isEmpty
                      ? 'Load your city\'s theaters from BookMyShow'
                      : selected.isEmpty
                          ? 'No theater ticked: the alarm rings for any theater'
                          : selected.map((t) => t.name).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTheaters(),
              ),
            ),
            if (alarms.isNotEmpty) ...[
              const SectionHeader('Recent alarms'),
              Card(
                child: Column(children: [
                  for (final (i, a) in alarms.take(5).indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 56, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.notifications_active_outlined,
                          color: scheme.primary),
                      title: Text(a.$2, style: text.bodyMedium),
                      subtitle: Text('${hm(a.$1)} · ${shortDate(a.$1)}'),
                    ),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One movie's "Check now" result: a row per language/format and date.
class _CheckResultCard extends StatelessWidget {
  const _CheckResultCard({
    required this.movie,
    required this.versions,
    required this.results,
    required this.cfg,
    required this.alerted,
  });

  final Movie movie;
  final List<String> versions;
  final List<DateCheck> results;
  final TrackerConfig cfg;
  final Set<String> alerted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('${movie.title} · ${cityName(movie.city)}',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
              'Languages/formats found: ${versions.length} (${versions.join(', ')})',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        for (final r in results) ...[
          const Divider(height: 1),
          ListTile(
            onTap: () => openBookMyShow(r.url),
            title: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DateChip(
                    label: shortDate(r.date),
                    state: switch (r.outcome) {
                      Outcome.open when !isOpenForUser(r, cfg.selectedTheaters) =>
                        'elsewhere',
                      Outcome.open => 'open',
                      Outcome.notOpen => 'waiting',
                      Outcome.blocked => 'blocked',
                      Outcome.error => 'error',
                    },
                  ),
                  Text(
                      [
                        if (r.label.isNotEmpty) r.label else if (r.version.isNotEmpty) r.version,
                        if (r.format.isNotEmpty) r.format,
                      ].join(' · '),
                      style: text.bodyMedium),
                ]),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText([
                if (r.venues.isNotEmpty)
                  'Theaters with shows: ${r.venues.join(' | ')}',
                if (r.matchedTheaters.isNotEmpty)
                  'Your theaters: ${r.matchedTheaters.map((t) => '${t.name} (${alerted.contains('${movie.id}|${t.id}') ? 'alarm already rang earlier' : 'alarm ringing now'})').join(', ')}',
                r.detail,
                if (r.debug.isNotEmpty) r.debug,
              ].join('\n')),
            ),
          ),
        ],
      ]),
    );
  }
}
