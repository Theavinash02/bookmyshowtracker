import 'package:bms_tracker/background.dart' show describeForReport, summarize;
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
          return ClickResult(
              FetchedPage(200, Uri.parse(after), '<html>Avengers: Doomsday - (Tamil)</html>'),
              clicked: true);
        },
      );
      expect(clickedUrl, 'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/ET00439706');
      expect(v.map((e) => '${e.eventCode}/${e.slug}'),
          ['ET00439706/avengers-doomsday', 'ET00526312/avengers-doomsday']);
    });

    test('no Book tickets button yet: falls back to the page, then just itself', () async {
      final v = await discoverVersions(
          (url) async => FetchedPage(200, Uri.parse(url), 'Mark interested'), eng,
          click: (url, text) async =>
              ClickResult(FetchedPage(200, Uri.parse(url), 'Mark interested'), clicked: false));
      expect(v.single.eventCode, 'ET00439706');
    });

    test('etCodes with several versions', () {
      final v = extractVersions('', eng,
          landedUrl: 'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/buytickets/ET00526312/20261217?etCodes=ET00526312,ET00526314,ET00526313&refEventCode=ET00526312');
      expect(v.map((e) => e.eventCode), ['ET00439706', 'ET00526312', 'ET00526314', 'ET00526313']);
    });

    test('movie page retried with the plain movie name if the link name fails', () async {
      final tried = <String>[];
      final v = await discoverVersions((url) async {
        tried.add(url);
        return url.contains('avengers-doomsday-english')
            ? FetchedPage(404, Uri.parse(url), 'not found')
            : FetchedPage(200, Uri.parse(url),
                '<a href="/movies/trichy/avengers-doomsday/buytickets/ET00526312/20261217">');
      }, eng);
      expect(tried, [
        'https://in.bookmyshow.com/movies/trichy/avengers-doomsday-english/ET00439706',
        'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/ET00439706',
      ]);
      expect(v.map((e) => e.eventCode), ['ET00439706', 'ET00526312']);
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
      expect(empty.detail, contains('showed 17 Nov instead'));
      // Shows exist, just on another date: say so plainly.
      final other = run(200, showUrl.replaceAll('20261218', '20261217'),
          '<html></html>\n<!--TEXT-->\nMegastar Cinemas\n08:00 AM');
      expect(other.outcome, Outcome.notOpen);
      expect(other.detail, contains('HAS shows on 17 Dec'));
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

  group('visible theater list only', () {
    const url =
        'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/buytickets/ET00526312/20261217';
    final m = Movie(
        title: 't', url: url, eventCode: 'ET00526312', slug: 'avengers-doomsday',
        city: 'trichy', startDate: DateTime(2026, 12, 17));
    final thiru = Theater(name: 'LA Cinema: Thiruverumbur', keyword: 'Thiruverumbur', selected: true);
    final mega = Theater(name: 'Megastar', keyword: 'Megastar', selected: true);

    DateCheck check(String body) => analyzePage(
        page: FetchedPage(200, Uri.parse(url), body),
        movie: m,
        date: DateTime(2026, 12, 17),
        requestedUrl: url,
        theaters: [thiru, mega]);

    test('footer and hidden data do not count as a theater listing', () {
      const body = '<html><script>{"venueName":"LA Cinema: Thiruverumbur"}</script></html>'
          '\n<!--TEXT-->\nMegastar Cinemas: Premium Large Format\n08:00 AM\n'
          'Unable to find what you are looking for?\nCinemas in Trichy: LA Cinema: Thiruverumbur';
      final r = check(body);
      expect(r.outcome, Outcome.open);
      expect(r.matchedTheaters.map((t) => t.name), ['Megastar']);
      expect(r.detail, contains('Not on page yet: LA Cinema: Thiruverumbur'));
    });

    test('show times only in the footer = not open', () {
      const body = '<html></html>\n<!--TEXT-->\nNo shows\n'
          'Unable to find what you are looking for?\nCustomer care 10:00 AM';
      expect(check(body).outcome, Outcome.notOpen);
    });

    test('pages without rendered text (HTTP fallback) are used whole', () {
      expect(visibleListText('Megastar 08:00 AM'), 'Megastar 08:00 AM');
    });
  });

  group('background: list not drawn, read downloaded data', () {
    const url =
        'https://in.bookmyshow.com/movies/trichy/avengers-doomsday/buytickets/ET00526312/20261217';
    final m = Movie(
        title: 't', url: url, eventCode: 'ET00526312', slug: 'avengers-doomsday',
        city: 'trichy', startDate: DateTime(2026, 12, 17));
    final mega = Theater(name: 'Megastar Cinemas', keyword: 'Megastar', selected: true);
    final thiru = Theater(name: 'LA Cinema: Thiruverumbur', keyword: 'Thiruverumbur', selected: true);

    DateCheck check(String body) => analyzePage(
        page: FetchedPage(200, Uri.parse(url), body),
        movie: m,
        date: DateTime(2026, 12, 17),
        requestedUrl: url,
        theaters: [mega, thiru]);

    // What the hidden browser returns with no screen: page text has no list,
    // but the captured show-time data has it.
    const undrawn = '<html><title>Avengers: Doomsday Movie Showtimes in Trichy</title></html>'
        '\n<!--TEXT-->\nAvengers: Doomsday\nUnable to find what you are looking for?'
        '\n<!--DATA-->\n{"eventCode":"ET00526312","venues":[{"venueName":"Megastar Cinemas: Premium Large Format ATMOS LASER","shows":[{"sessionId":"123","showTime":"08:00 AM"}]}]}';

    test('Megastar is found from data and the alarm can ring', () {
      final r = check(undrawn);
      expect(r.outcome, Outcome.open);
      expect(r.matchedTheaters.map((t) => t.name), ['Megastar Cinemas']);
      expect(r.detail, contains('from page data'));
    });

    test('a cinema mentioned in the data but not listed with shows does not match', () {
      // Real case: data listed only Megastar as a venue, but also mentioned
      // LA Cinema: Thiruverumbur elsewhere (e.g. a list of the city's cinemas).
      const body = '<html></html>\n<!--TEXT-->\nloading'
          '\n<!--DATA-->\n{"eventCode":"ET00526312","venues":[{"venueName":"Megastar Cinemas: Premium Large Format ATMOS LASER",'
          '"shows":[{"sessionId":"1","showTime":"08:00 AM"}]}],'
          '"cityCinemas":["LA Cinema: Thiruverumbur","LA Cinema: Maris, Trichy"]}';
      final r = check(body);
      expect(r.outcome, Outcome.open);
      expect(r.matchedTheaters.map((t) => t.name), ['Megastar Cinemas']);
      expect(r.detail, contains('Not on page yet: LA Cinema: Thiruverumbur'));
    });

    test('data about another movie is ignored', () {
      const other = '<html></html>\n<!--TEXT-->\nnothing'
          '\n<!--DATA-->\n{"eventCode":"ET00999999","venueName":"Megastar","showTime":"08:00 AM"}';
      expect(check(other).outcome, Outcome.notOpen);
    });

    test('data without shows = not open', () {
      const none = '<html></html>\n<!--TEXT-->\nnothing'
          '\n<!--DATA-->\n{"eventCode":"ET00526312","venues":[]}';
      expect(check(none).outcome, Outcome.notOpen);
    });

    test('embedded page data (script tags) also counts', () {
      const embedded = '<html><script id="__NEXT_DATA__">{"eventCode":"ET00526312",'
          '"venueName":"Megastar Cinemas","sessionId":"1"}</script></html>\n<!--TEXT-->\nloading';
      expect(check(embedded).matchedTheaters.single.name, 'Megastar Cinemas');
    });

    test('drawn list is preferred when present', () {
      const drawn = '<html></html>\n<!--TEXT-->\nMegastar Cinemas\n08:00 AM\n'
          'Unable to find what you are looking for?'
          '\n<!--DATA-->\n{"eventCode":"ET00526312","venueName":"LA Cinema: Thiruverumbur","sessionId":"9"}';
      final r = check(drawn);
      expect(r.matchedTheaters.map((t) => t.name), ['Megastar Cinemas']);
      expect(r.detail, contains('from screen'));
    });
  });

  group('background report details', () {
    const drawn = '<html><title>Avengers: Doomsday Movie Showtimes in Trichy</title></html>'
        '\n<!--TEXT-->\nTamil - MS-Infinity Vsn 3d\nMegastar Cinemas: Premium Large Format ATMOS LASER\n'
        'Cancellation available\n08:00 AM\n11:50 AM\nUnable to find what you are looking for?';
    const undrawn = '<html></html>\n<!--TEXT-->\nloading'
        '\n<!--DATA-->\n{"eventCode":"ET00526312","language":"Tamil","dimension":"MS-Infinity Vsn 3d",'
        '"venueName":"Megastar Cinemas: Premium Large Format ATMOS LASER","sessionId":"1","showTime":"08:00 AM"}';

    test('language/format from the page or its data', () {
      expect(versionFormat(drawn, 'ET00526312'), 'Tamil · MS-Infinity Vsn 3d');
      expect(versionFormat(undrawn, 'ET00526312'), 'Tamil · MS-Infinity Vsn 3d');
      expect(versionFormat('<html></html>', 'ET00526312'), '');
    });

    test('theaters with shows and show count, drawn or not', () {
      expect(theatersWithShows(drawn, 'ET00526312'),
          ['Megastar Cinemas: Premium Large Format ATMOS LASER']);
      expect(theatersWithShows(undrawn, 'ET00526312'),
          ['Megastar Cinemas: Premium Large Format ATMOS LASER']);
      expect(showTimeCount(drawn, 'ET00526312'), 2);
      expect(showTimeCount(undrawn, 'ET00526312'), 1);
    });

    test('report lists theaters and marks the selected ones', () {
      final mega = Theater(name: 'Megastar Cinemas', keyword: 'Megastar', selected: true);
      final thiru = Theater(name: 'LA Cinema: Thiruverumbur', keyword: 'Thiruverumbur', selected: true);
      final m = Movie(title: 'Avengers', url: 'u', eventCode: 'ET00439706',
          slug: 'avengers-doomsday', city: 'trichy', startDate: DateTime(2026, 12, 17));
      final r = DateCheck(
          date: DateTime(2026, 12, 17),
          url: 'u',
          outcome: Outcome.open,
          matchedTheaters: [mega],
          version: 'ET00526312',
          label: 'Avengers: Doomsday',
          format: 'Tamil · MS-Infinity Vsn 3d',
          venues: const ['Megastar Cinemas: Premium Large Format ATMOS LASER'],
          showCount: 5);
      final text = describeForReport(m, 2, [r],
          TrackerConfig(city: 'trichy', movies: [m], theaters: [mega, thiru]));
      expect(text, contains('Avengers: Doomsday · Tamil · MS-Infinity Vsn 3d · 17 Dec — ✅ OPEN at your theater'));
      expect(text, contains('✔ Megastar Cinemas · ✖ LA Cinema: Thiruverumbur'));
      expect(text, isNot(contains('Also showing at')));
    });

    test('only other theaters showing = not at your theaters yet', () {
      final thiru = Theater(name: 'LA Cinema: Thiruverumbur', keyword: 'Thiruverumbur', selected: true);
      final m = Movie(title: 'Avengers', url: 'u', eventCode: 'ET00439706',
          slug: 'avengers-doomsday', city: 'trichy', startDate: DateTime(2026, 12, 17));
      final r = DateCheck(
          date: DateTime(2026, 12, 17),
          url: 'u',
          outcome: Outcome.open,
          version: 'ET00526312',
          label: 'Avengers: Doomsday',
          format: 'Tamil · MS-Infinity Vsn 3d',
          venues: const ['Megastar Cinemas: Premium Large Format ATMOS LASER'],
          showCount: 18);
      final cfg = TrackerConfig(city: 'trichy', movies: [m], theaters: [thiru]);
      final text = describeForReport(m, 2, [r], cfg);
      expect(text, contains('17 Dec — not at your theaters yet'));
      expect(text, contains('✖ LA Cinema: Thiruverumbur'));
      expect(text, contains('(Showing only at: Megastar Cinemas'));
      expect(text, isNot(contains('✅')));
      expect(isOpenForUser(r, cfg.selectedTheaters), isFalse);
      expect(summarize([r], [DateTime(2026, 12, 17)], cfg.selectedTheaters),
          '17 Dec: not at your theaters yet');
      // With no theater selected, any theater counts.
      expect(isOpenForUser(r, const []), isTrue);
      expect(summarize([r], [DateTime(2026, 12, 17)]), '17 Dec: OPEN');
    });
  });

  test('versionLabel', () {
    expect(versionLabel('<title>Avengers: Doomsday - (Tamil) Movie Showtimes in Trichy &amp; Online Ticket Booking</title>'),
        'Avengers: Doomsday - (Tamil)');
    expect(versionLabel('<title>Scene Showtimes</title>'), 'Scene');
    expect(versionLabel('<html></html>'), '');
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
