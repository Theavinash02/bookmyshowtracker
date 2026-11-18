# Contributing to BMS Tracker

Thanks for helping! Bug reports, theater-matching fixes, UI ideas and code
are all welcome. Please be kind and constructive in issues and reviews.

## Ways to help

- **Report a bug.** Use the
  [bug report form](https://github.com/Theavinash02/bookmyshowtracker/issues/new?template=bug_report.yml).
  Always paste the **Background report** (home screen → *Background report*).
  It shows exactly what the tracker saw.
- **My city or theater doesn't work.** Use the
  [city / theater form](https://github.com/Theavinash02/bookmyshowtracker/issues/new?template=city_or_theater.yml)
  with the BookMyShow link and the theater's exact name in BookMyShow.
- **BookMyShow changed its website.** This is the most common way the app
  breaks. A report with the Background report and the link you tracked is
  very useful.
- **Suggest a feature** with the
  [feature request form](https://github.com/Theavinash02/bookmyshowtracker/issues/new?template=feature_request.yml).
- **Send code.** See below.

## Development setup

You need:

- Flutter SDK **3.50 or newer** (stable channel)
- Java **21**
- An Android phone or emulator (Android only; there is no iOS build)

```sh
git clone https://github.com/Theavinash02/bookmyshowtracker.git
cd bookmyshowtracker
flutter pub get
flutter analyze
flutter test
flutter run            # on a connected phone or emulator
```

Local release builds (`flutter build apk --release`) are signed with your
debug key, which is fine for testing.

## How the code is organised

| File | What it does |
|---|---|
| `lib/main.dart` | App start and the home screen: tracking on/off, "Check now", movie list |
| `lib/ui/` | The other screens and shared widgets: `movie_page.dart`, `theaters_page.dart`, `settings_page.dart`, `report_page.dart`, `widgets.dart` (status card, movie card, date chips) and `theme.dart` (colours, light/dark) |
| `lib/background.dart` | Foreground service that runs a check every *N* seconds and rings alarms |
| `lib/checker.dart` | Pure logic: parse BookMyShow links, build show-time URLs, find theaters and dates in a page, decide what is "open". Most of the tests cover this file. |
| `lib/web_fetcher.dart` | Hidden in-app browser (`flutter_inappwebview`) that loads BookMyShow pages like a real user |
| `lib/notifications.dart` | Alarm and "watching" notifications, opening BookMyShow on tap |
| `lib/models.dart` | `Movie`, `Theater`, `TrackerConfig` and their JSON form |
| `lib/storage.dart` | Saved settings, alarm log and last status (`shared_preferences`) |
| `test/checker_test.dart` | Unit tests, mostly with saved snippets of real BookMyShow pages |
| `third_party/flutter_inappwebview_android` | Patched plugin copy (Android Gradle Plugin 9 fix). Avoid changing it unless needed. |

Keep page-parsing logic in `checker.dart` as pure functions, so it can be
tested without a phone. When you fix a parsing bug, add a test with a short
snippet of the real page that broke.

## Pull requests

1. Fork the repo and create a branch from `main`.
2. Keep each PR focused on one fix or feature.
3. Run `flutter analyze` and `flutter test`. CI runs both and must pass.
4. If you change the UI, add before/after screenshots to the PR.
5. If you change how the app is used, update `README.md` too.
6. Fill in the PR template.

CI builds an APK for every branch, so you can download it from the run's
**Artifacts** and try it on your phone.

## Releases (maintainers)

Every merge to `main` publishes a GitHub release with `bms-tracker.apk`.
The version number doesn't change by itself: raise `version:` in
`pubspec.yaml` (both parts, e.g. `0.4.0+21` → `0.4.1+22`) when the change is
user-visible.

Release APKs are signed with the project's permanent key, so updates install
over the old app. CI reads it from these repository secrets (*Settings →
Secrets and variables → Actions*):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The PKCS#12 keystore, base64-encoded on one line |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

A build of `main` fails if these are missing, so a release is never signed
with a throwaway key. Never commit the keystore. Keep a private backup,
because a lost key means every user has to reinstall the app once.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
