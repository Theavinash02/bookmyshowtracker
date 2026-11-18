import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../background.dart' show shortDate;
import '../checker.dart';
import '../models.dart';

/// Full-screen form to add or edit a movie. Pops with the [Movie].
class MoviePage extends StatefulWidget {
  const MoviePage({super.key, required this.city, this.existing});
  final String city;
  final Movie? existing;

  @override
  State<MoviePage> createState() => _MoviePageState();
}

class _MoviePageState extends State<MoviePage> {
  late final url = TextEditingController(text: widget.existing?.url ?? '');
  late final title = TextEditingController(text: widget.existing?.title ?? '');
  late final city =
      TextEditingController(text: widget.existing?.city ?? widget.city);
  late DateTime start = widget.existing?.startDate ?? _today();
  late int days = widget.existing?.days ?? 1;
  String? error;

  static DateTime _today() {
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void dispose() {
    url.dispose();
    title.dispose();
    city.dispose();
    super.dispose();
  }

  void _urlChanged(String v) {
    final p = parseMovieUrl(v, city: city.text.trim());
    if (p != null && title.text.trim().isEmpty) title.text = p.suggestedTitle;
    if (p?.city != null) city.text = p!.city!;
    setState(() => error = null);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim();
    if (t == null || t.isEmpty) return;
    url.text = t;
    _urlChanged(t);
  }

  void _submit() {
    final p = parseMovieUrl(url.text, city: city.text.trim());
    final c = city.text.trim().toLowerCase();
    if (p == null) {
      setState(() => error =
          'The link must contain the movie code (ET00…). Copy it from the '
          'movie page on BookMyShow.');
      return;
    }
    if (c.isEmpty && p.city == null && widget.city.isEmpty) {
      setState(() => error =
          'Enter your BookMyShow city below (the word after /movies/ in a '
          'BookMyShow link, e.g. "chennai").');
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
        allVersions: true, // every language & format is always checked
        startDate: start,
        days: days,
        enabled: widget.existing?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dates = List.generate(
        days, (i) => DateTime(start.year, start.month, start.day + i));
    Widget label(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(s,
              style: text.titleSmall?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w700)),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add movie' : 'Edit movie'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          label('BookMyShow link'),
          TextField(
            controller: url,
            onChanged: _urlChanged,
            minLines: 1,
            maxLines: 3,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://in.bookmyshow.com/movies/<city>/<movie>/ET00…',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                tooltip: 'Paste',
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
              ),
              errorText: error,
              errorMaxLines: 3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
                'In BookMyShow: open the movie → Share → Copy link. The movie '
                'page and the "Book tickets" page both work. Every language '
                'and format is checked automatically.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          label('Details'),
          TextField(
            controller: title,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(Icons.movie_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: city,
            decoration: const InputDecoration(
              labelText: 'BookMyShow city',
              prefixIcon: Icon(Icons.location_city_outlined),
              helperText: 'Filled from the link. Some places have two '
                  'BookMyShow cities; add the movie once for each.',
              helperMaxLines: 2,
            ),
          ),
          label('Dates to watch'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('First show date'),
                subtitle: Text('${shortDate(start)} ${start.year}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => start = d);
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Number of days'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton.filledTonal(
                      onPressed:
                          days > 1 ? () => setState(() => days--) : null,
                      icon: const Icon(Icons.remove)),
                  SizedBox(
                    width: 32,
                    child: Text('$days',
                        textAlign: TextAlign.center,
                        style: text.titleMedium),
                  ),
                  IconButton.filledTonal(
                      onPressed:
                          days < 7 ? () => setState(() => days++) : null,
                      icon: const Icon(Icons.add)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in dates)
                Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text(shortDate(d)),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: Text(widget.existing == null ? 'Save movie' : 'Save changes'),
          ),
        ),
      ),
    );
  }
}
