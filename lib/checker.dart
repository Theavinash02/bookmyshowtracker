import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Default BookMyShow show-times page. Placeholders:
/// {city} {slug} {event} {date} (date = YYYYMMDD).
const defaultShowtimesTemplate =
    'https://in.bookmyshow.com/movies/{city}/{slug}/buytickets/{event}/{date}';

const _userAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

final _eventCodeRe = RegExp(r'ET\d{6,}', caseSensitive: false);
final _urlRe = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
final _showTimeRe = RegExp(r'\b\d{1,2}:\d{2}\s?[AP]\.?M\b', caseSensitive: false);

/// Result of parsing a BookMyShow movie link.
class ParsedMovieUrl {
  ParsedMovieUrl(this.url, this.eventCode, this.slug, [this.city]);
  final String url;
  final String eventCode;
  final String slug;

  /// City slug from the link ("trichy" in /movies/trichy/...), if present.
  final String? city;

  String get suggestedTitle => slug
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Pulls the first URL out of shared text such as
/// "Check out Avengers: Doomsday on BookMyShow https://...".
String? extractUrl(String text) => _urlRe.firstMatch(text.trim())?.group(0);

/// Parses links like
///  https://in.bookmyshow.com/movies/tiruchirappalli/avengers-doomsday/ET00123456
///  https://in.bookmyshow.com/tiruchirappalli/movies/avengers-doomsday/ET00123456
///  https://in.bookmyshow.com/movies/tiruchirappalli/avengers-doomsday/buytickets/ET00123456/20261218
///  https://in.bookmyshow.com/buytickets/avengers-doomsday-tiruchirappalli/movie-tric-ET00123456-MT/20261218
ParsedMovieUrl? parseMovieUrl(String input, {String city = ''}) {
  final url = extractUrl(input) ?? input.trim();
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  for (var i = 0; i < segs.length; i++) {
    final m = _eventCodeRe.firstMatch(segs[i]);
    if (m == null) continue;
    final event = m.group(0)!.toUpperCase();
    var j = i - 1;
    if (j >= 0 && segs[j].toLowerCase() == 'buytickets') j--;
    if (j < 0) return null;
    var slug = segs[j].toLowerCase();
    // Old "buytickets/<slug>-<city>/movie-..." format.
    if (segs[i].toUpperCase() != event &&
        city.isNotEmpty &&
        slug.endsWith('-${city.toLowerCase()}')) {
      slug = slug.substring(0, slug.length - city.length - 1);
    }
    return ParsedMovieUrl(url, event, slug, _cityFromSegments(segs));
  }
  return null;
}

/// `/movies/CITY/...` (current) or `/CITY/movies/...` (older links).
String? _cityFromSegments(List<String> segs) {
  final i = segs.indexWhere((s) => s.toLowerCase() == 'movies');
  if (i == 0 && segs.length > 2) return segs[1].toLowerCase();
  if (i == 1) return segs[0].toLowerCase();
  return null;
}

String formatBmsDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

String buildShowtimesUrl(String template, Movie movie, DateTime date) =>
    template
        .replaceAll('{city}', movie.city)
        .replaceAll('{slug}', movie.slug)
        .replaceAll('{event}', movie.eventCode)
        .replaceAll('{date}', formatBmsDate(date));

/// Lowercase, keep only letters/digits, single spaces.
String normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// True if [keyword] occurs in [normalizedBody] starting at a word
/// boundary ("Sona" matches "Sona Mina" but not "personal").
/// Several spellings can be given separated by "|", e.g.
/// "Thiruverumbur|Tiruverumbur".
bool keywordMatches(String normalizedBody, String keyword) {
  for (final alt in keyword.split('|')) {
    final k = normalize(alt);
    if (k.isEmpty) continue;
    if (RegExp('(^| )${RegExp.escape(k)}').hasMatch(normalizedBody)) {
      return true;
    }
  }
  return false;
}

enum Outcome { notOpen, open, blocked, error }

class FetchedPage {
  FetchedPage(this.status, this.finalUrl, this.body);
  final int status;
  final Uri finalUrl;
  final String body;
}

class DateCheck {
  DateCheck({
    required this.date,
    required this.url,
    required this.outcome,
    this.matchedTheaters = const [],
    this.detail = '',
    this.debug = '',
  });
  final DateTime date;
  final String url;
  final Outcome outcome;

  /// Selected theaters whose name appeared on an open show-times page.
  final List<Theater> matchedTheaters;
  final String detail;

  /// Diagnostics shown by "Check now" (page size, times, cinemas seen).
  final String debug;

  DateCheck withDebug(String d) => DateCheck(
      date: date,
      url: url,
      outcome: outcome,
      matchedTheaters: matchedTheaters,
      detail: detail,
      debug: d);
}

/// Human-readable summary of what a fetched page contained.
String describePage(FetchedPage p) {
  final times = _showTimeRe.allMatches(p.body).length;
  final venues = extractVenueNames(p.body);
  final title =
      RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false)
              .firstMatch(p.body)
              ?.group(1)
              ?.trim() ??
          '';
  return 'HTTP ${p.status} · ${p.body.length} chars · $times show times\n'
      'Page title: $title\n'
      'Landed on: ${p.finalUrl}\n'
      'Cinemas seen (${venues.length}): '
      '${venues.isEmpty ? '-' : venues.take(15).join(' | ')}';
}

/// True for Cloudflare / bot-protection interstitial pages.
bool looksLikeChallenge(String html) {
  final head = html.length > 6000 ? html.substring(0, 6000) : html;
  final l = head.toLowerCase();
  return l.contains('just a moment') ||
      l.contains('cf-chl') ||
      l.contains('challenge-platform') ||
      l.contains('attention required') ||
      l.contains('verify you are human');
}

bool _looksBlocked(FetchedPage p) =>
    p.status == 403 ||
    p.status == 429 ||
    p.status == 503 ||
    looksLikeChallenge(p.body);

/// Decides, from a fetched show-times page, whether booking is open
/// and at which of [theaters]. Pure function, unit-tested.
DateCheck analyzePage({
  required FetchedPage page,
  required Movie movie,
  required DateTime date,
  required String requestedUrl,
  required List<Theater> theaters,
}) {
  if (_looksBlocked(page)) {
    return DateCheck(
      date: date,
      url: requestedUrl,
      outcome: Outcome.blocked,
      detail: 'BookMyShow blocked the request (HTTP ${page.status}).',
    );
  }
  if (page.status == 404) {
    return DateCheck(
        date: date,
        url: requestedUrl,
        outcome: Outcome.notOpen,
        detail: 'No show-times page yet (HTTP 404).');
  }
  if (page.status >= 400) {
    return DateCheck(
        date: date,
        url: requestedUrl,
        outcome: Outcome.error,
        detail: 'HTTP ${page.status}');
  }
  final finalUrl = page.finalUrl.toString();
  final onShowtimesPage = finalUrl.toLowerCase().contains('buytickets') &&
      finalUrl.toUpperCase().contains(movie.eventCode.toUpperCase());
  if (!onShowtimesPage) {
    return DateCheck(
        date: date,
        url: requestedUrl,
        outcome: Outcome.notOpen,
        detail: 'Redirected away from show-times (to $finalUrl).');
  }
  final hasShowTimes = _showTimeRe.hasMatch(page.body);
  if (!hasShowTimes) {
    return DateCheck(
        date: date,
        url: requestedUrl,
        outcome: Outcome.notOpen,
        detail: 'Show-times page has no show times yet.');
  }
  // BookMyShow sends you to another date (often today) when the requested
  // date has no shows yet: that is NOT open for the requested date.
  final landedDate = RegExp(r'/(\d{8})(?:[/?#]|$)').firstMatch(finalUrl)?.group(1);
  if (landedDate != null && landedDate != formatBmsDate(date)) {
    return DateCheck(
        date: date,
        url: requestedUrl,
        outcome: Outcome.notOpen,
        detail: 'No shows for this date yet (BookMyShow showed $landedDate instead).');
  }
  final body = normalize(page.body);
  final matched = theaters.where((t) => keywordMatches(body, t.keyword)).toList();
  final missing = theaters.where((t) => !matched.contains(t)).map((t) => t.name);
  return DateCheck(
    date: date,
    url: finalUrl,
    outcome: Outcome.open,
    matchedTheaters: matched,
    detail: 'Shows found.'
        '${missing.isEmpty ? '' : ' Not on page yet: ${missing.join(', ')}.'}',
  );
}

/// GETs [url] following redirects and reports the final URL.
Future<FetchedPage> fetchPage(http.Client client, String url) async {
  var uri = Uri.parse(url);
  // Follow redirects manually so we always know the final URL.
  for (var hop = 0; hop < 8; hop++) {
    final req = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll({
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-IN,en;q=0.9',
      });
    final res = await client.send(req).timeout(const Duration(seconds: 25));
    final loc = res.headers['location'];
    if (res.statusCode >= 300 && res.statusCode < 400 && loc != null) {
      await res.stream.drain<void>();
      uri = uri.resolve(loc);
      continue;
    }
    final body = await res.stream.bytesToString().timeout(
          const Duration(seconds: 25),
        );
    return FetchedPage(res.statusCode, uri, body);
  }
  throw Exception('Too many redirects');
}

/// Loads a page and reports its final URL (after redirects).
typedef PageFetch = Future<FetchedPage> Function(String url);

/// Checks every configured date of [movie].
Future<List<DateCheck>> checkMovie({
  required PageFetch fetch,
  required TrackerConfig config,
  required Movie movie,
}) async {
  final results = <DateCheck>[];
  for (final date in movie.dates) {
    final url = buildShowtimesUrl(
        config.showtimesTemplate, movie, date);
    try {
      final page = await fetch(url);
      results.add(analyzePage(
        page: page,
        movie: movie,
        date: date,
        requestedUrl: url,
        theaters: config.selectedTheaters,
      ).withDebug(describePage(page)));
    } catch (e) {
      results.add(DateCheck(
          date: date, url: url, outcome: Outcome.error, detail: '$e'));
    }
  }
  return results;
}

/// Best-effort: list cinema names BookMyShow mentions in a page
/// (e.g. the show-times page of a movie that is currently running).
List<String> extractVenueNames(String html) {
  final re = RegExp(
      r'"(?:venueName|VenueName|venue_name)"\s*:\s*"((?:[^"\\]|\\.){2,120})"');
  final names = <String>{};
  for (final m in re.allMatches(html)) {
    final raw = m.group(1)!;
    String name;
    try {
      name = jsonDecode('"$raw"') as String; // unescape \uXXXX, \" etc.
    } catch (_) {
      name = raw;
    }
    names.add(name.trim());
  }
  names.addAll(_venueNamesFromText(html));
  final list = names.toList()..sort();
  return list;
}

/// Fallback for the rendered page text: a cinema name is a line such as
/// "LA Cinemas: Thiruverumbur" followed within a few lines by show times.
List<String> _venueNamesFromText(String html) {
  final i = html.indexOf('<!--TEXT-->');
  final text = i >= 0 ? html.substring(i + 11) : html;
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final out = <String>{};
  for (var j = 0; j < lines.length; j++) {
    final l = lines[j];
    if (l.length < 6 || l.length > 120 || _showTimeRe.hasMatch(l)) continue;
    if (!l.contains(':') || l.contains('<')) continue;
    final ahead = lines.skip(j + 1).take(8);
    if (ahead.any((x) => _showTimeRe.hasMatch(x))) out.add(l);
  }
  return out.toList();
}
