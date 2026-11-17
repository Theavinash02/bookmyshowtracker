import 'models.dart';

/// Starter list of Tiruchirappalli (Trichy) cinemas.
///
/// `keyword` is matched (case-insensitive, punctuation ignored) against the
/// BookMyShow show-times page, so keep it short and distinctive. If a
/// theater's BookMyShow name differs, edit it in the app or use
/// "Load theaters from BookMyShow".
List<Theater> defaultTrichyTheaters() => [
      Theater(
          name: 'LA Cinemas: Thiruverumbur',
          keyword: 'Thiruverumbur|Tiruverumbur|Thiruverambur|Thiruvarumbur'),
      Theater(name: 'Megastar Cinemas', keyword: 'Megastar'),
      Theater(name: 'LA Cinemas - Maris Complex', keyword: 'Maris'),
      Theater(name: 'Sona Mina Cinemas', keyword: 'Sona'),
      Theater(name: 'Rambha / Ramba Theatre', keyword: 'Ramb'),
      Theater(name: 'Kalaiarangam', keyword: 'Kalaiarangam'),
      Theater(name: 'Urvasi Theatre', keyword: 'Urvasi'),
    ];
