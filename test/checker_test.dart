import 'package:bms_tracker/checker.dart';
import 'package:bms_tracker/models.dart';
import 'package:flutter_test/flutter_test.dart';

Movie movie() => Movie(
      title: 'Avengers Doomsday',
      url: 'x',
      eventCode: 'ET00123456',
      slug: 'avengers-doomsday',
      city: 'tiruchirappalli',
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

  group('per-movie city', () {
    test('city is read from the link', () {
      expect(parseMovieUrl('https://in.bookmyshow.com/movies/trichy/avengers-doomsday-english/ET00439706')!.city, 'trichy');
      expect(parseMovieUrl('https://in.bookmyshow.com/movies/tiruchirappalli/avengers-doomsday-english/ET00439706')!.city, 'tiruchirappalli');
      expect(parseMovieUrl('https://in.bookmyshow.com/trichy/movies/x/ET00439706')!.city, 'trichy');
      expect(parseMovieUrl('https://in.bookmyshow.com/buytickets/x-trichy/movie-tric-ET00439706-MT/20261217')!.city, isNull);
    });
    test('same movie in two cities = two entries with their own URLs', () {
      final a = movie().copyWith(city: 'trichy');
      final b = movie().copyWith(city: 'tiruchirappalli');
      expect(a.id == b.id, isFalse);
      expect(buildShowtimesUrl(defaultShowtimesTemplate, a, DateTime(2026, 12, 17)),
          contains('/movies/trichy/'));
      expect(buildShowtimesUrl(defaultShowtimesTemplate, b, DateTime(2026, 12, 17)),
          contains('/movies/tiruchirappalli/'));
    });
    test('old saved movies get the global city', () {
      final json = '{"city":"trichy","movies":[{"title":"t","url":"u","eventCode":"ET1","slug":"s","startDate":0}],"theaters":[]}';
      expect(TrackerConfig.fromJson(json).movies.single.city, 'trichy');
    });
  });

  test('Avengers Tamil MS-Infinity link from the user round-trips', () {
    const link =
        'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/buytickets/ET00526312/20261217';
    final p = parseMovieUrl(link)!;
    expect([p.eventCode, p.slug, p.city], ['ET00526312', 'avengers-doomsday', 'trichy']);
    final m = movie().copyWith(city: p.city);
    final rebuilt = Movie(
        title: 't', url: link, eventCode: p.eventCode, slug: p.slug,
        city: p.city!, startDate: DateTime(2026, 12, 17));
    expect(buildShowtimesUrl(defaultShowtimesTemplate, rebuilt, DateTime(2026, 12, 17)), link);
    expect(m.city, 'trichy');
    final r = analyzePage(
        page: FetchedPage(200, Uri.parse(link),
            'Megastar Cinemas: Premium Large Format ATMOS LASER 08:00 AM 11:50 AM'),
        movie: rebuilt,
        date: DateTime(2026, 12, 17),
        requestedUrl: link,
        theaters: [Theater(name: 'Megastar', keyword: 'Megastar', selected: true)]);
    expect(r.outcome, Outcome.open);
    expect(r.matchedTheaters.single.name, 'Megastar');
  });

  group('all languages & formats', () {
    final eng = Movie(
        title: 'Avengers',
        url: 'u',
        eventCode: 'ET00439706',
        slug: 'avengers-doomsday-english',
        city: 'trichy',
        startDate: DateTime(2026, 12, 17),
        days: 1);

    test('baseMovieName strips language/format words', () {
      expect(baseMovieName('avengers-doomsday-english'), 'avengers doomsday');
      expect(baseMovieName('avengers-doomsday-tamil-3d'), 'avengers doomsday');
      expect(baseMovieName('scene-tamil'), 'scene');
      expect(baseMovieName('english'), 'english');
    });

    test('extractVersions finds sibling versions, skips other movies', () {
      const html = '<a href="/movies/trichy/avengers-doomsday/buytickets/ET00526312/20261217">'
          '<a href="/movies/trichy/avengers-doomsday-hindi/ET00439999">'
          '<a href="/movies/trichy/some-other-film/ET00111111">'
          '{"eventCode":"ET00422222"}';
      final v = extractVersions(html, eng);
      expect(v.map((e) => e.eventCode),
          ['ET00439706', 'ET00526312', 'ET00439999', 'ET00422222']);
      expect(v[1].slug, 'avengers-doomsday');
      expect(v[2].slug, 'avengers-doomsday-hindi');
    });

    test('checkMovie checks each version; other-movie pages are ignored', () async {
      final cfg = TrackerConfig(city: 'trichy', movies: [eng], theaters: [
        Theater(name: 'Megastar', keyword: 'Megastar', selected: true)
      ]);
      Future<FetchedPage> fetch(String url) async {
        if (url.contains('ET00526312')) {
          return FetchedPage(200, Uri.parse(url),
              '<title>Avengers: Doomsday Movie Showtimes in Trichy</title> Megastar 08:00 AM');
        }
        if (url.contains('ET00422222')) {
          return FetchedPage(200, Uri.parse(url),
              '<title>Some Other Film Showtimes</title> Megastar 09:00 AM');
        }
        // English: not open yet, BookMyShow shows today instead.
        return FetchedPage(200, Uri.parse(url.replaceAll('20261217', '20261117')), '');
      }
      final res = await checkMovie(fetch: fetch, config: cfg, movie: eng, versions: const [
        MovieVersion('ET00439706', 'avengers-doomsday-english'),
        MovieVersion('ET00526312', 'avengers-doomsday'),
        MovieVersion('ET00422222', 'avengers-doomsday-english'),
      ]);
      final byV = {for (final r in res) r.version: r};
      expect(byV['ET00439706']!.outcome, Outcome.notOpen);
      expect(byV['ET00526312']!.outcome, Outcome.open);
      expect(byV['ET00526312']!.matchedTheaters.single.name, 'Megastar');
      expect(byV['ET00422222']!.outcome, Outcome.notOpen);
      expect(byV['ET00422222']!.detail, contains('different movie'));
    });

    test('pressing Book tickets: the landed URL gives the open version', () async {
      final parent = eng.copyWith(slug: 'avengers-doomsday');
      const after =
          'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/buytickets/ET00526312/20261217?etCodes=ET00526312&language=tamil&refEventCode=ET00526312';
      String? clickedUrl;
      final v = await discoverVersions(
        (url) async => FetchedPage(200, Uri.parse(url), ''),
        parent,
        click: (url, text) async {
          clickedUrl = url;
          expect(text, 'Book tickets');
          return FetchedPage(200, Uri.parse(after), '<html>Avengers: Doomsday - (Tamil)</html>');
        },
      );
      expect(clickedUrl, 'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/ET00439706');
      expect(v.map((e) => '${e.eventCode}/${e.slug}'),
          ['ET00439706/avengers-doomsday', 'ET00526312/avengers-doomsday']);
    });

    test('no Book tickets button yet: falls back to the page, then just itself', () async {
      final v = await discoverVersions(
          (url) async => FetchedPage(200, Uri.parse(url), 'Mark interested'), eng,
          click: (url, text) async => null);
      expect(v.single.eventCode, 'ET00439706');
    });

    test('etCodes with several versions', () {
      final v = extractVersions('', eng,
          landedUrl: 'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/buytickets/ET00526312/20261217?etCodes=ET00526312,ET00526314,ET00526313&refEventCode=ET00526312');
      expect(v.map((e) => e.eventCode), ['ET00439706', 'ET00526312', 'ET00526314', 'ET00526313']);
    });

    test('allVersions defaults to true, including old saved movies', () {
      final json = '{"movies":[{"title":"t","url":"u","eventCode":"ET1","slug":"s","startDate":0}],"theaters":[]}';
      expect(TrackerConfig.fromJson(json).movies.single.allVersions, isTrue);
    });
  });

  test('buildShowtimesUrl', () {
    expect(
        buildShowtimesUrl(
            defaultShowtimesTemplate, movie(), DateTime(2026, 12, 18)),
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
      final empty = run(200, showUrl.replaceAll('20261218', '20261117'), 'nothing');
      expect(empty.detail, contains('showed 17/11 instead'));
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
    expect(c2.movies.single.city, 'tiruchirappalli');
    expect(c2.movies.single.dates.last, DateTime(2026, 12, 20));
    expect(c2.selectedTheaters.length, 3);
    expect(c2.showtimesTemplate, defaultShowtimesTemplate);
  });
}
