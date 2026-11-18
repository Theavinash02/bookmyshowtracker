import 'package:material_ui/material_ui.dart';

import 'widgets.dart';

/// Full-screen, scrollable report: a header banner and a list of cards.
class ReportPage extends StatelessWidget {
  const ReportPage({
    super.key,
    required this.title,
    required this.intro,
    required this.sections,
    this.highlight = false,
  });

  final String title;
  final String intro;

  /// Shows [intro] as a green "alarm rang" style banner instead of info.
  final bool highlight;
  final List<Widget> sections;

  /// Report made of plain text blocks, e.g. the background tracker's.
  factory ReportPage.text({
    required String title,
    required String intro,
    required List<String> blocks,
  }) =>
      ReportPage(
        title: title,
        intro: intro,
        sections: [
          for (final b in blocks)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(b, style: const TextStyle(height: 1.4)),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          InfoBanner(
            warning: false,
            icon: highlight
                ? Icons.notifications_active
                : Icons.info_outline,
            text: intro,
          ),
          for (final s in sections) ...[const SizedBox(height: 12), s],
        ],
      ),
    );
  }
}
