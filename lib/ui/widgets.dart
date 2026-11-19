import 'package:material_ui/material_ui.dart';

import '../background.dart' show shortDate;
import '../models.dart';
import 'theme.dart';

/// What the big card at the top of the home screen shows.
enum TrackerState { off, watching, open, paused, error }

/// Big, colour-coded status card with the start/stop button.
class StatusHero extends StatelessWidget {
  const StatusHero({
    super.key,
    required this.state,
    required this.title,
    required this.subtitle,
    required this.running,
    required this.onToggle,
    this.details = const [],
  });

  final TrackerState state;
  final String title;
  final String subtitle;
  final bool running;
  final VoidCallback onToggle;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sc = StatusColors(context);
    final (IconData icon, Color bg, Color fg) = switch (state) {
      TrackerState.off => (
          Icons.notifications_off_outlined,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
      TrackerState.watching => (
          Icons.radar,
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      TrackerState.open => (
          Icons.celebration_outlined,
          sc.successContainer,
          sc.success
        ),
      TrackerState.paused => (
          Icons.pause_circle_outline,
          sc.warningContainer,
          sc.warning
        ),
      TrackerState.error => (
          Icons.error_outline,
          scheme.errorContainer,
          scheme.onErrorContainer
        ),
    };
    final text = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: fg, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: text.titleLarge
                          ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: text.bodyMedium
                          ?.copyWith(color: fg.withValues(alpha: 0.85))),
                ],
              ),
            ),
          ]),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final d in details)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(d,
                    style: text.bodySmall
                        ?.copyWith(color: fg.withValues(alpha: 0.9))),
              ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: running
                ? OutlinedButton.icon(
                    onPressed: onToggle,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fg,
                      side: BorderSide(color: fg.withValues(alpha: 0.4)),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop tracking'),
                  )
                : FilledButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start tracking'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A small coloured warning or info strip.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.warning = true,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final sc = StatusColors(context);
    final scheme = Theme.of(context).colorScheme;
    final bg = warning ? sc.warningContainer : scheme.surfaceContainerHigh;
    final fg = warning ? sc.warning : scheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: fg, height: 1.35))),
      ]),
    );
  }
}

/// Round icon button with a label underneath, for the quick-action row.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              SizedBox(
                height: 24,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Icon(icon,
                        color: onTap == null
                            ? scheme.onSurface.withValues(alpha: 0.38)
                            : scheme.primary),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ?trailing,
        ]),
      );
}

/// A date with its booking state, e.g. "17 Dec · Open".
class DateChip extends StatelessWidget {
  const DateChip({super.key, required this.label, required this.state});
  final String label;

  /// `open`, `elsewhere`, `blocked`, `error`, `waiting` or null (unknown).
  final String? state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sc = StatusColors(context);
    final (Color bg, Color fg, IconData? icon, String? word) = switch (state) {
      'open' => (sc.successContainer, sc.success, Icons.check_circle, 'Open'),
      'elsewhere' => (
          sc.warningContainer,
          sc.warning,
          Icons.info_outline,
          'Other theaters'
        ),
      'blocked' || 'error' => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
          state == 'blocked' ? 'Blocked' : 'Error'
        ),
      'waiting' => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.schedule,
          'Not yet'
        ),
      _ => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          null,
          null
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
        ],
        Text(word == null ? label : '$label · $word',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// One tracked movie with its dates and on/off switch.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.states,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final Movie movie;

  /// Date state by date milliseconds (see [DateChip.state]); may be empty.
  final Map<String, String> states;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: movie.enabled ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.local_movies_outlined,
                        color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(movie.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(cityName(movie.city),
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  Switch(value: movie.enabled, onChanged: onToggle),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (a) => a == 'edit' ? onTap() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'))),
                      PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete'))),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final d in movie.dates)
                    DateChip(
                      label: shortDate(d),
                      state: movie.enabled
                          ? states['${d.millisecondsSinceEpoch}']
                          : null,
                    ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First-run guide shown while no movie is added.
class GettingStarted extends StatelessWidget {
  const GettingStarted({super.key, required this.onAddMovie});
  final VoidCallback onAddMovie;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget step(int n, String title, String body) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primary,
              child: Text('$n',
                  style: text.labelLarge?.copyWith(
                      color: scheme.onPrimary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(body,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
            ),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Get started in 3 steps',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          step(1, 'Add a movie',
              'In BookMyShow, open the movie → Share → Copy link, and paste it here.'),
          step(2, 'Pick your theaters',
              'Load your city\'s theaters from BookMyShow and tick the ones you want.'),
          step(3, 'Start tracking',
              'Your phone rings like an alarm the moment booking opens.'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAddMovie,
              icon: const Icon(Icons.add),
              label: const Text('Add your first movie'),
            ),
          ),
        ]),
      ),
    );
  }
}

String _cap(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');

/// "chennai" -> "Chennai", "navi-mumbai" -> "Navi mumbai".
String cityName(String slug) => _cap(slug);
