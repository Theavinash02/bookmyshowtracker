import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'checker.dart';
import 'models.dart';
import 'notifications.dart';
import 'storage.dart';
import 'web_fetcher.dart';

final service = FlutterBackgroundService();

Future<void> configureBackgroundService() async {
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: serviceChannelId,
      initialNotificationTitle: 'BMS Tracker',
      initialNotificationContent: 'Starting…',
      foregroundServiceNotificationId: serviceNotificationId,
      foregroundServiceTypes: [AndroidForegroundType.specialUse],
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

Future<void> startTracking() async {
  await Storage.setRunning(true);
  if (!await service.isRunning()) {
    await service.startService();
  } else {
    service.invoke('checkNow');
  }
}

Future<void> stopTracking() async {
  await Storage.setRunning(false);
  if (await service.isRunning()) service.invoke('stop');
}

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
    ':${t.second.toString().padLeft(2, '0')}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

@pragma('vm:entry-point')
Future<void> onServiceStart(ServiceInstance svc) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Started on boot but the user had switched tracking off.
  if (!await Storage.isRunning()) {
    await svc.stopSelf();
    return;
  }

  await initNotifications();

  var stopped = false;
  var wake = Completer<void>();
  void wakeUp() {
    if (!wake.isCompleted) wake.complete();
  }

  svc.on('stop').listen((_) async {
    stopped = true;
    wakeUp();
    await svc.stopSelf();
  });
  svc.on('checkNow').listen((_) => wakeUp());

  final rnd = Random();
  while (!stopped) {
    // New completer before the cycle, so a "checkNow" (e.g. config edited)
    // that arrives mid-cycle triggers an immediate re-check afterwards.
    wake = Completer<void>();
    TrackerConfig? cfg;
    try {
      cfg = await Storage.loadConfig();
      final loader = PageLoader();
      try {
        await runOneCycle(svc, loader.load, cfg);
      } finally {
        await loader.close();
      }
    } catch (e) {
      await _setForeground(svc, 'BMS Tracker – error', 'Will retry: $e');
    }
    if (stopped) break;
    final base = max(30, cfg?.intervalSeconds ?? 60);
    final delay = Duration(seconds: base + rnd.nextInt(10));
    await Future.any([Future<void>.delayed(delay), wake.future]);
  }
}

Future<void> _setForeground(ServiceInstance svc, String title, String body) async {
  if (svc is AndroidServiceInstance) {
    await svc.setForegroundNotificationInfo(title: title, content: body);
  }
}

/// Discovered language/format versions per movie id, refreshed hourly.
final _versionCache = <String, (DateTime, List<MovieVersion>)>{};

Future<List<MovieVersion>> _versionsFor(PageFetch fetch, Movie m) async {
  if (!m.allVersions) return [MovieVersion(m.eventCode, m.slug)];
  final c = _versionCache[m.id];
  if (c != null && DateTime.now().difference(c.$1) < const Duration(hours: 1)) {
    return c.$2;
  }
  final v = await discoverVersions(fetch, m);
  _versionCache[m.id] = (DateTime.now(), v);
  return v;
}

/// One-line status per date: OPEN if any version is open.
String summarize(List<DateCheck> results, List<DateTime> dates) =>
    dates.map((d) {
      final rs = results.where((r) => r.date == d).toList();
      final open = rs.where((r) => r.outcome == Outcome.open).toList();
      if (open.isNotEmpty) {
        final names = {for (final r in open) ...r.matchedTheaters.map((t) => t.name)};
        return '${shortDate(d)}: OPEN${names.isEmpty ? '' : ' @ ${names.join(', ')}'}';
      }
      if (rs.any((r) => r.outcome == Outcome.blocked)) return '${shortDate(d)}: blocked';
      if (rs.isNotEmpty && rs.every((r) => r.outcome == Outcome.error)) {
        return '${shortDate(d)}: error';
      }
      return '${shortDate(d)}: not yet';
    }).join(' · ');

/// One pass over all enabled movies. Fires alarms for new openings.
Future<void> runOneCycle(
    ServiceInstance svc, PageFetch fetch, TrackerConfig cfg) async {
  final movies = cfg.movies.where((m) => m.enabled).toList();
  final now = DateTime.now();
  if (movies.isEmpty) {
    await _setForeground(svc, 'BMS Tracker', 'No movies enabled – add one in the app');
    return;
  }

  final alerted = await Storage.alertedKeys();
  final newKeys = <String>[];
  final lines = <String>[];
  var anyOpen = false;
  var anyBlocked = false;
  final watchAll = cfg.alertAnyTheater || cfg.selectedTheaters.isEmpty;

  for (final movie in movies) {
    final versions = await _versionsFor(fetch, movie);
    final results = await checkMovie(
        fetch: fetch, config: cfg, movie: movie, versions: versions);
    final open = results.where((r) => r.outcome == Outcome.open).toList();
    anyBlocked |= results.any((r) => r.outcome == Outcome.blocked);

    // Selected theaters that now have shows, with their dates.
    final theaterDates = <String, List<DateTime>>{};
    final theaterNames = <String, String>{};
    for (final r in open) {
      for (final t in r.matchedTheaters) {
        theaterDates.putIfAbsent(t.id, () => []).add(r.date);
        theaterNames[t.id] = t.name;
      }
    }
    final freshTheaters = theaterDates.keys
        .where((id) => !alerted.contains('${movie.id}|$id'))
        .toList();

    if (freshTheaters.isNotEmpty) {
      final parts = freshTheaters.map((id) =>
          '${theaterNames[id]} (${theaterDates[id]!.map(shortDate).join(', ')})');
      await showTicketsOpenAlarm(
        title: '🎟️ ${movie.title} (${movie.city}): BOOKING OPEN!',
        body: 'Open now at ${parts.join('; ')}. Tap to open BookMyShow.',
        url: open.first.url,
      );
      newKeys.addAll(freshTheaters.map((id) => '${movie.id}|$id'));
    } else if (open.isNotEmpty &&
        watchAll &&
        !alerted.contains('${movie.id}|*')) {
      await showTicketsOpenAlarm(
        title: '🎟️ ${movie.title}: booking opened (${movie.city})',
        body: 'Shows are listed for ${open.map((r) => shortDate(r.date)).join(', ')}'
            '${cfg.selectedTheaters.isEmpty ? '' : ' (your selected theaters not seen yet – still watching them)'}.'
            ' Tap to open BookMyShow.',
        url: open.first.url,
      );
      newKeys.add('${movie.id}|*');
    }

    anyOpen |= open.isNotEmpty;
    final summary = summarize(results, movie.dates);
    final vCount = versions.length > 1 ? ' (${versions.length} versions)' : '';
    lines.add('${movie.title} [${movie.city}]$vCount – $summary');
  }

  if (newKeys.isNotEmpty) await Storage.addAlertedKeys(newKeys);

  await Storage.saveStatus({
    'time': now.millisecondsSinceEpoch,
    'lines': lines,
    'open': anyOpen,
    'blocked': anyBlocked,
  });
  svc.invoke('status');

  await _setForeground(
    svc,
    anyOpen
        ? 'BMS Tracker – BOOKING OPEN'
        : anyBlocked
            ? 'BMS Tracker – BookMyShow blocking, retrying'
            : 'BMS Tracker – watching',
    'Checked ${_hm(now)} · ${lines.join(' | ')}',
  );
}
