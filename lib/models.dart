import 'dart:convert';

import 'checker.dart' show defaultShowtimesTemplate;

/// BookMyShow has two cities for Trichy: "tiruchirappalli" lists only a few
/// cinemas, "trichy" (what the BookMyShow app uses) lists them all.
const defaultCity = 'trichy';

/// A movie being tracked on BookMyShow.
class Movie {
  Movie({
    required this.title,
    required this.url,
    required this.eventCode,
    required this.slug,
    required this.startDate,
    this.days = 3,
    this.enabled = true,
  });

  /// Display title, e.g. "Avengers: Doomsday".
  final String title;

  /// The URL the user pasted / shared from BookMyShow.
  final String url;

  /// BookMyShow event code, e.g. "ET00123456".
  final String eventCode;

  /// URL slug, e.g. "avengers-doomsday".
  final String slug;

  /// First show date to check (local date, time ignored).
  final DateTime startDate;

  /// Number of consecutive days to check starting at [startDate].
  final int days;

  final bool enabled;

  String get id => eventCode;

  List<DateTime> get dates => List.generate(
        days,
        (i) => DateTime(startDate.year, startDate.month, startDate.day + i),
      );

  Movie copyWith({
    String? title,
    DateTime? startDate,
    int? days,
    bool? enabled,
  }) =>
      Movie(
        title: title ?? this.title,
        url: url,
        eventCode: eventCode,
        slug: slug,
        startDate: startDate ?? this.startDate,
        days: days ?? this.days,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'url': url,
        'eventCode': eventCode,
        'slug': slug,
        'startDate': startDate.millisecondsSinceEpoch,
        'days': days,
        'enabled': enabled,
      };

  factory Movie.fromMap(Map<String, dynamic> m) => Movie(
        title: m['title'] as String,
        url: m['url'] as String,
        eventCode: m['eventCode'] as String,
        slug: m['slug'] as String,
        startDate: DateTime.fromMillisecondsSinceEpoch(m['startDate'] as int),
        days: (m['days'] as int?) ?? 3,
        enabled: (m['enabled'] as bool?) ?? true,
      );
}

/// A cinema the user may want to track.
class Theater {
  Theater({required this.name, required this.keyword, this.selected = false});

  /// Display name.
  final String name;

  /// Text that must appear (case-insensitive) in the BookMyShow
  /// show-times page for this theater to count as "booking open".
  final String keyword;

  final bool selected;

  String get id => keyword.toLowerCase();

  Theater copyWith({String? name, String? keyword, bool? selected}) => Theater(
        name: name ?? this.name,
        keyword: keyword ?? this.keyword,
        selected: selected ?? this.selected,
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'keyword': keyword, 'selected': selected};

  factory Theater.fromMap(Map<String, dynamic> m) => Theater(
        name: m['name'] as String,
        keyword: m['keyword'] as String,
        selected: (m['selected'] as bool?) ?? false,
      );
}

/// Everything the user configured.
class TrackerConfig {
  TrackerConfig({
    required this.city,
    required this.movies,
    required this.theaters,
    this.intervalSeconds = 60,
    this.alertAnyTheater = true,
    this.showtimesTemplate = defaultShowtimesTemplate,
  });

  /// BookMyShow city slug, e.g. "trichy".
  final String city;
  final List<Movie> movies;
  final List<Theater> theaters;
  final int intervalSeconds;

  /// Also alert when booking opens anywhere in the city
  /// (not only at the selected theaters).
  final bool alertAnyTheater;

  /// URL pattern of the BookMyShow show-times page (see checker.dart).
  final String showtimesTemplate;

  List<Theater> get selectedTheaters =>
      theaters.where((t) => t.selected).toList();

  TrackerConfig copyWith({
    String? city,
    List<Movie>? movies,
    List<Theater>? theaters,
    int? intervalSeconds,
    bool? alertAnyTheater,
    String? showtimesTemplate,
  }) =>
      TrackerConfig(
        city: city ?? this.city,
        movies: movies ?? this.movies,
        theaters: theaters ?? this.theaters,
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        alertAnyTheater: alertAnyTheater ?? this.alertAnyTheater,
        showtimesTemplate: showtimesTemplate ?? this.showtimesTemplate,
      );

  String toJson() => jsonEncode({
        'city': city,
        'movies': movies.map((m) => m.toMap()).toList(),
        'theaters': theaters.map((t) => t.toMap()).toList(),
        'intervalSeconds': intervalSeconds,
        'alertAnyTheater': alertAnyTheater,
        'showtimesTemplate': showtimesTemplate,
      });

  factory TrackerConfig.fromJson(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return TrackerConfig(
      city: (m['city'] as String?) ?? defaultCity,
      movies: ((m['movies'] as List?) ?? [])
          .map((e) => Movie.fromMap(e as Map<String, dynamic>))
          .toList(),
      theaters: ((m['theaters'] as List?) ?? [])
          .map((e) => Theater.fromMap(e as Map<String, dynamic>))
          .toList(),
      intervalSeconds: (m['intervalSeconds'] as int?) ?? 60,
      alertAnyTheater: (m['alertAnyTheater'] as bool?) ?? true,
      showtimesTemplate:
          (m['showtimesTemplate'] as String?) ?? defaultShowtimesTemplate,
    );
  }
}
