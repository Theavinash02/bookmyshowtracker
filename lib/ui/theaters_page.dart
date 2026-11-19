import 'package:material_ui/material_ui.dart';

import '../checker.dart';
import '../models.dart';
import '../web_fetcher.dart';
import 'theme.dart';
import 'widgets.dart';

/// Full-screen list of theaters with search, select and load from
/// BookMyShow. Every change is saved through [onChanged] right away.
class TheatersPage extends StatefulWidget {
  const TheatersPage({
    super.key,
    required this.cfg,
    required this.onChanged,
    this.autoLoadFrom,
  });

  final TrackerConfig cfg;
  final Future<void> Function(TrackerConfig) onChanged;

  /// Movie link to load the city's theaters from as soon as the page opens.
  final String? autoLoadFrom;

  @override
  State<TheatersPage> createState() => _TheatersPageState();
}

class _TheatersPageState extends State<TheatersPage> {
  late TrackerConfig cfg = widget.cfg;
  String query = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final link = widget.autoLoadFrom;
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(link));
    }
  }

  Future<void> _save(TrackerConfig c) async {
    setState(() => cfg = c);
    await widget.onChanged(c);
  }

  Future<void> _setSelected(bool Function(Theater) which, bool v) => _save(
      cfg.copyWith(
          theaters: cfg.theaters
              .map((t) => which(t) ? t.copyWith(selected: v) : t)
              .toList()));

  Future<void> _edit([Theater? t]) async {
    final res = await showDialog<Theater>(
        context: context, builder: (_) => TheaterDialog(existing: t));
    if (res == null) return;
    final list = [...cfg.theaters];
    final i = t == null ? -1 : list.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      list[i] = res;
    } else if (!list.any((x) => x.id == res.id)) {
      list.add(res);
    }
    await _save(cfg.copyWith(theaters: list));
  }

  Future<void> _delete(Theater t) async {
    final before = cfg;
    await _save(cfg.copyWith(
        theaters: cfg.theaters.where((x) => x.id != t.id).toList()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Deleted ${t.name}'),
      action: SnackBarAction(label: 'Undo', onPressed: () => _save(before)),
    ));
  }

  Future<void> _load([String? link]) async {
    link ??= await _askLink();
    if (link == null || !mounted) return;
    setState(() => loading = true);
    final (names, err) = await fetchTheaterNames(link, cfg);
    if (!mounted) return;
    setState(() => loading = false);
    if (names.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.wifi_off),
          title: const Text('Could not load theaters'),
          content: SingleChildScrollView(
              child: SelectableText('${err ?? ''}\n\n'
                  'Try again in a minute, or add theaters by hand with "+".')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );
      return;
    }
    final existing = cfg.theaters.map((t) => normalize(t.name)).toSet();
    final fresh = names.where((n) => !existing.contains(normalize(n))).toList();
    if (fresh.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All theaters from BookMyShow are already listed.')));
      return;
    }
    final picked = await Navigator.push<List<String>>(context,
        MaterialPageRoute(builder: (_) => PickTheatersPage(names: fresh)));
    if (picked == null || picked.isEmpty) return;
    await _save(cfg.copyWith(theaters: [
      ...cfg.theaters,
      for (final n in picked) Theater(name: n, keyword: n, selected: true),
    ]));
  }

  Future<String?> _askLink() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load theaters from BookMyShow'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Paste the BookMyShow link of any movie running in your '
              'city today (movie page or "Book tickets" page).'),
          const SizedBox(height: 12),
          TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'BookMyShow link', prefixIcon: Icon(Icons.link))),
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
    return url == null ? null : extractUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final q = normalize(query);
    final shown = cfg.theaters
        .where((t) => q.isEmpty || normalize(t.name).contains(q))
        .toList();
    final selected = cfg.selectedTheaters.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theaters'),
        actions: [
          IconButton(
              tooltip: 'Add theater by hand',
              onPressed: () => _edit(),
              icon: const Icon(Icons.add)),
          if (cfg.theaters.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (a) => _setSelected(
                  (t) => shown.contains(t), a == 'all'),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'all', child: Text('Select all shown')),
                PopupMenuItem(value: 'none', child: Text('Clear all shown')),
              ],
            ),
        ],
        bottom: loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator())
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : () => _load(),
        icon: const Icon(Icons.download),
        label: Text(loading ? 'Loading…' : 'Load from BookMyShow'),
      ),
      body: cfg.theaters.isEmpty
          ? _Empty(loading: loading)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: searchDecoration(context, 'Search theaters'),
                ),
                const SizedBox(height: 12),
                InfoBanner(
                  warning: false,
                  icon: Icons.notifications_active_outlined,
                  text: selected == 0
                      ? 'No theater ticked: the alarm rings when booking opens '
                          'at any theater.'
                      : cfg.alertAnyTheater
                          ? '$selected ticked. Alarm for these, plus one alarm '
                              'when booking opens anywhere else.'
                          : '$selected ticked. The alarm rings only when one of '
                              'these has shows on your dates.',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(children: [
                    for (final (i, t) in shown.indexed) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 56, endIndent: 16),
                      CheckboxListTile(
                        value: t.selected,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(t.name),
                        subtitle: t.keyword == t.name
                            ? null
                            : Text('Matches "${t.keyword}"',
                                style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                        onChanged: (v) =>
                            _setSelected((x) => x.id == t.id, v ?? false),
                        secondary: PopupMenuButton<String>(
                          onSelected: (a) =>
                              a == 'edit' ? _edit(t) : _delete(t),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    ],
                    if (shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No theater matches your search.'),
                      ),
                  ]),
                ),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: scheme.primaryContainer,
            child: Icon(Icons.theaters_outlined,
                size: 40, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text(loading ? 'Loading theaters…' : 'No theaters yet',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Tap "Load from BookMyShow" to get your city\'s theaters, or "+" '
            'to add one by hand. With no theater, the alarm rings for any '
            'theater.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}

/// Loads theater names from the show-times page behind [link]: the page
/// itself if it is a "Book tickets" link, else today and the next two days.
Future<(List<String>, String?)> fetchTheaterNames(
    String link, TrackerConfig cfg) async {
  final candidates = <String>[];
  final parsed = parseMovieUrl(link, city: cfg.city);
  if (link.toLowerCase().contains('buytickets') || parsed == null) {
    candidates.add(link);
  } else {
    final today = DateTime.now();
    final m = Movie(
        title: '',
        url: link,
        eventCode: parsed.eventCode,
        slug: parsed.slug,
        city: parsed.city ?? cfg.city,
        startDate: today);
    for (var i = 0; i < 3; i++) {
      candidates.add(buildShowtimesUrl(cfg.showtimesTemplate, m,
          DateTime(today.year, today.month, today.day + i)));
    }
  }
  final loader = PageLoader();
  String? err;
  try {
    for (final c in candidates) {
      final page = await loader.load(c);
      final names = extractVenueNames(page.body);
      if (names.isNotEmpty) return (names, null);
      err = 'No theater names found.\n${describePage(page)}';
    }
  } catch (e) {
    err = '$e';
  } finally {
    await loader.close();
  }
  return (const <String>[], err);
}

/// Pick which of the theaters found on BookMyShow to add.
class PickTheatersPage extends StatefulWidget {
  const PickTheatersPage({super.key, required this.names});
  final List<String> names;

  @override
  State<PickTheatersPage> createState() => _PickTheatersPageState();
}

class _PickTheatersPageState extends State<PickTheatersPage> {
  final picked = <String>{};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final q = normalize(query);
    final shown = widget.names
        .where((n) => q.isEmpty || normalize(n).contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.names.length} theaters found'),
        actions: [
          TextButton(
            onPressed: () => setState(() => shown.every(picked.contains)
                ? picked.removeAll(shown)
                : picked.addAll(shown)),
            child: Text(shown.isNotEmpty && shown.every(picked.contains)
                ? 'Clear'
                : 'Select all'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: searchDecoration(context, 'Search theaters'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              for (final (i, n) in shown.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 56, endIndent: 16),
                CheckboxListTile(
                  value: picked.contains(n),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(n),
                  onChanged: (v) => setState(
                      () => v == true ? picked.add(n) : picked.remove(n)),
                ),
              ],
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: picked.isEmpty
                ? null
                : () => Navigator.pop(context, picked.toList()),
            icon: const Icon(Icons.check),
            label: Text(picked.isEmpty
                ? 'Tick the theaters you want'
                : 'Add ${picked.length} theater${picked.length == 1 ? '' : 's'}'),
          ),
        ),
      ),
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
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              autofocus: widget.existing == null,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(
              controller: kw,
              decoration: const InputDecoration(
                  labelText: 'Match keyword',
                  helperText:
                      'A distinctive word from the theater\'s BookMyShow name. '
                      'Several spellings: Thiruverumbur|Tiruverumbur',
                  helperMaxLines: 3)),
        ]),
      ),
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
