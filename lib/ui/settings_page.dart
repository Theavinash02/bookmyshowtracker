import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../checker.dart' show defaultShowtimesTemplate;
import '../models.dart';
import '../storage.dart';

const repoUrl = 'https://github.com/Theavinash02/bookmyshowtracker';
const sponsorUrl = 'https://github.com/sponsors/Theavinash02';

/// Full-screen settings. Pops with the new [TrackerConfig] on Save.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.cfg, required this.onTestAlarm});
  final TrackerConfig cfg;
  final VoidCallback onTestAlarm;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late double interval = widget.cfg.intervalSeconds.toDouble();
  late bool any = widget.cfg.alertAnyTheater;
  late final city = TextEditingController(text: widget.cfg.city);
  late final template =
      TextEditingController(text: widget.cfg.showtimesTemplate);

  @override
  void dispose() {
    city.dispose();
    template.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(
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
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
              child: Text(title,
                  style: text.titleSmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w700)),
            ),
            Card(child: Column(children: children)),
          ],
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          section('Checking', [
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Check every'),
              trailing: Text('${interval.round()} s',
                  style: text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Slider(
                  min: 30,
                  max: 300,
                  divisions: 27,
                  value: interval,
                  label: '${interval.round()} s',
                  onChanged: (v) => setState(() => interval = v)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                  'Shorter is faster to notice, but checking too often can '
                  'get you blocked by BookMyShow. 60 s is a good default.',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ]),
          section('Alarms', [
            SwitchListTile(
              secondary: const Icon(Icons.public),
              value: any,
              onChanged: (v) => setState(() => any = v),
              title: const Text('Also alarm for other theaters'),
              subtitle: const Text(
                  'One extra alarm when booking opens at any theater, not just '
                  'yours.'),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('Test alarm'),
              subtitle: const Text('Hear the sound and check the volume'),
              onTap: widget.onTestAlarm,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset alerts'),
              subtitle: const Text(
                  'Theaters that already rang will ring again'),
              onTap: () async {
                await Storage.clearAlerted();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Alerts reset. You will be alarmed again.')));
                }
              },
            ),
          ]),
          section('City', [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: city,
                decoration: const InputDecoration(
                  labelText: 'Default BookMyShow city',
                  prefixIcon: Icon(Icons.location_city_outlined),
                  helperText: 'Used only when a movie link has no city. Each '
                      'movie keeps the city from its own link.',
                  helperMaxLines: 2,
                ),
              ),
            ),
          ]),
          section('Advanced', [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: template,
                maxLines: 3,
                style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'Show-times URL pattern',
                  helperText: 'Placeholders: {city} {slug} {event} {date}',
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton(
                    onPressed: () => template.text = defaultShowtimesTemplate,
                    child: const Text('Restore default')),
              ),
            ),
          ]),
          section('About', [
            ListTile(
              leading: Icon(Icons.favorite, color: scheme.primary),
              title: const Text('Support this project'),
              subtitle: const Text('Sponsor on GitHub. The app stays free.'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => launchUrl(Uri.parse(sponsorUrl),
                  mode: LaunchMode.externalApplication),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Source code on GitHub'),
              subtitle: const Text('Free and open source (MIT)'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => launchUrl(Uri.parse(repoUrl),
                  mode: LaunchMode.externalApplication),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Report a problem'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => launchUrl(Uri.parse('$repoUrl/issues/new/choose'),
                  mode: LaunchMode.externalApplication),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                  'BMS Tracker is not affiliated with BookMyShow. It only reads '
                  'public show-time pages and never books tickets for you.',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ]),
        ],
      ),
    );
  }
}
