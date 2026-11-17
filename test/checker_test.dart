import 'package:bms_tracker/checker.dart';
import 'package:bms_tracker/models.dart';
import 'package:flutter_test/flutter_test.dart';

Movie movie() => Movie(
      title: 'Avengers Doomsday',
      url: 'x',
      eventCode: 'ET00123456',
      slug: 'avengers-doomsday',
      startDate: DateTime(2026, 12, 18),
      days: 3,
    );

final theaters = [
  Theater(name: 'Sona Mina', keyword: 'Sona', selected: true),
  Theater(name: 'Rambha', keyword: 'Ramb', selected: true),
  Theater(name: 'Maris', keyword: 'Maris', selected: true),
];

const showUrl =
    'https://in.bookmyshow.com/movies/tiruchirappalli/avengers-doomsday/buytickets/ET00123456/20261218';

DateCheck run(int status, String finalUrl, String body) => analyzePage(
      page: FetchedPage(status, Uri.parse(finalUrl), body),
      movie: movie(),
      date: DateTime(2026, 12, 18),
      requestedUrl: showUrl,
      theaters: theaters,
    );

void main() {
  group('parseMovieUrl', () {
    test('new movie page format', () {
      final p = parseMovieUrl(
          'https://in.bookmyshow.com/movies/tiruchirappalli/avengers-doomsday/ET00123456');
      expect(p!.eventCode, 'ET00123456');
      expect(p.slug, 'avengers-doomsday');
      expect(p.suggestedTitle, 'Avengers Doomsday');
    });
    test('old format + share text', () {
      final p = parseMovieUrl(
          'Check out Avengers on BookMyShow https://in.bookmyshow.com/tiruchirappalli/movies/avengers-doomsday/ET00123456 now');
      expect(p!.eventCode, 'ET00123456');
      expect(p.slug, 'avengers-doomsday');
    });
    test('new buytickets format', () {
      final p = parseMovieUrl(showUrl);
      expect(p!.slug, 'avengers-doomsday');
      expect(p.eventCode, 'ET00123456');
    });
    test('old buytickets format', () {
      final p = parseMovieUrl(
          'https://in.bookmyshow.com/buytickets/avengers-doomsday-tiruchirappalli/movie-tric-ET00123456-MT/20261218',
          city: 'tiruchirappalli');
      expect(p!.slug, 'avengers-doomsday');
      expect(p.eventCode, 'ET00123456');
    });
    test('no event code', () {
      expect(parseMovieUrl('https://in.bookmyshow.com/explore/home'), isNull);
      expect(parseMovieUrl('hello'), isNull);
    });
  });

  test('buildShowtimesUrl', () {
    expect(
        buildShowtimesUrl(defaultShowtimesTemplate, 'tiruchirappalli', movie(),
            DateTime(2026, 12, 18)),
        showUrl);
  });

  group('analyzePage', () {
    test('open with selected theaters', () {
      final r = run(200, showUrl,
          '<div>Sona Mina Cinemas 4K</div><div>Rambha Theatre</div><span>10:30 AM</span>');
      expect(r.outcome, Outcome.open);
      expect(r.matchedTheaters.map((t) => t.keyword), ['Sona', 'Ramb']);
    });
    test('keyword must start a word ("personal" is not "Sona")', () {
      final r = run(200, showUrl, 'personalised picks <b>07:15 PM</b>');
      expect(r.outcome, Outcome.open);
      expect(r.matchedTheaters, isEmpty);
    });
    test('redirected to movie page = not open', () {
      final r = run(
          200,
          'https://in.bookmyshow.com/movies/tiruchirappalli/avengers-doomsday/ET00123456',
          'Sona Mina 10:30 AM');
      expect(r.outcome, Outcome.notOpen);
    });
    test('redirected to another date = not open', () {
      final r = run(200, showUrl.replaceAll('20261218', '20261117'),
          'Sona Mina 10:30 AM');
      expect(r.outcome, Outcome.notOpen);
    });
    test('showtimes page without times = not open', () {
      final r = run(200, showUrl, 'Sona Mina, no shows available');
      expect(r.outcome, Outcome.notOpen);
    });
    test('404 = not open', () {
      expect(run(404, showUrl, '').outcome, Outcome.notOpen);
    });
    test('blocked', () {
      expect(run(403, showUrl, '').outcome, Outcome.blocked);
      expect(run(200, showUrl, '<title>Just a moment...</title>').outcome,
          Outcome.blocked);
    });
  });

  test('keyword alternatives', () {
    expect(keywordMatches(normalize('LA Cinemas: Tiruverumbur'),
        'Thiruverumbur|Tiruverumbur'), isTrue);
    expect(keywordMatches(normalize('LA Cinemas: Maris'),
        'Thiruverumbur|Tiruverumbur'), isFalse);
  });

  test('extractVenueNames from rendered text', () {
    const page = '<html></html>\n<!--TEXT-->\nMegastar Cinemas: Premium Large Format\n'
        '1.1 km (In Trichy) | Cancellation available\n08:00 AM\nDolbyAtmos\n'
        'LA Cinemas: Thiruverumbur\n11:50 AM\nUnable to find: what you want';
    expect(extractVenueNames(page),
        ['LA Cinemas: Thiruverumbur', 'Megastar Cinemas: Premium Large Format']);
  });

  test('real BookMyShow names match the starter keywords', () {
    final body = normalize('LA Cinema: Thiruverumbur 06:25 PM LA CINEMA: MARIS, TRICHY '
        'STAR CINEMAS A/C RGB LASER: TRICHY LA Cinema: Sona Mina, Trichy');
    for (final k in ['Thiruverumbur|Tiruverumbur', 'Maris', 'Star Cinemas', 'Sona']) {
      expect(keywordMatches(body, k), isTrue, reason: k);
    }
    expect(keywordMatches(normalize('Megastar Cinemas'), 'Star Cinemas'), isFalse);
  });

  test('extractVenueNames', () {
    expect(
        extractVenueNames(
            '{"venueName":"Sona Mina: Trichy"},{"VenueName":"LA Cinemas \\u0026 Co"},{"venueName":"Sona Mina: Trichy"}'),
        ['LA Cinemas & Co', 'Sona Mina: Trichy']);
  });

  test('config json roundtrip', () {
    final c = TrackerConfig(
        city: 'tiruchirappalli', movies: [movie()], theaters: theaters);
    final c2 = TrackerConfig.fromJson(c.toJson());
    expect(c2.movies.single.eventCode, 'ET00123456');
    expect(c2.movies.single.dates.last, DateTime(2026, 12, 20));
    expect(c2.selectedTheaters.length, 3);
    expect(c2.showtimesTemplate, defaultShowtimesTemplate);
  });
}
