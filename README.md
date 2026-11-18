# 🎟️ BMS Tracker

**Never miss a first-day-first-show again.** BMS Tracker rings an alarm on
your Android phone the moment BookMyShow opens bookings for a movie at the
theaters you want, on the dates you want.

[![Build APK](https://github.com/Theavinash02/bookmyshowtracker/actions/workflows/build-apk.yml/badge.svg)](https://github.com/Theavinash02/bookmyshowtracker/actions/workflows/build-apk.yml)
[![Latest release](https://img.shields.io/github/v/release/Theavinash02/bookmyshowtracker?label=download)](https://github.com/Theavinash02/bookmyshowtracker/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

<!-- Screenshots: added after the UI redesign. -->

## Features

- **Any movie, any city.** Works wherever BookMyShow sells tickets.
- **Every language and format** (2D, 3D, IMAX, 4DX…) is checked
  automatically. You add the movie once.
- **Only your theaters, only your dates.** Shows anywhere else don't wake
  you up.
- **Rings like an alarm clock**, even on silent, until you dismiss it.
- **Runs in the background** with the screen off, and starts again after the
  phone restarts.
- **Tap the alarm to book.** It opens that BookMyShow page directly.

> **Android only.** BMS Tracker is an independent, open-source project. It is
> not affiliated with, endorsed by or connected to BookMyShow (Bigtree
> Entertainment). See [Disclaimer](#disclaimer).

---

## Quick start

### 1. Install

On your Android phone, open this link. It always downloads the newest version:

**<https://github.com/Theavinash02/bookmyshowtracker/releases/latest/download/bms-tracker.apk>**

Open **bms-tracker.apk** and tap **Install**. If Android asks, allow
**"Install unknown apps"** for your browser.

**To update later,** open the same link again and install over the old app.
Your movies and theaters are kept.

> **Coming from version 0.3 or older?** Version 0.4 has a new app ID and a
> permanent signing key. Uninstall the old **BMS Tracker** once, then install
> the new one and add your movies again. After that, updates install normally.

### 2. Add a movie

1. In the **BookMyShow** app or website, choose your city and open the movie.
2. Copy its link. In the **app**, tap **Share → Copy link**. On the
   **website**, copy the address bar.
   The link must contain a code like `ET00439706`, for example
   `https://in.bookmyshow.com/movies/<city>/<movie>/ET00439706`.
3. In BMS Tracker, tap **+ Movie** and paste the link. The title and city fill
   in by themselves.
4. Pick the **show date** and **how many days** to watch. For example,
   17 Dec and 2 days watches 17 and 18 Dec.
5. Tap **Save**.

### 3. Pick your theaters

After your first movie, the app offers to **load your city's theaters from
BookMyShow**. Tick the ones you want.

- **Later:** tap the **Theaters** card, then **Load from BookMyShow**, and paste
  the link of any movie currently running in your city.
- **Missing a theater?** On the Theaters page, tap **+**. Enter its name and a word from
  its BookMyShow name. You can list several spellings separated by `|`, for
  example `Thiruverumbur|Tiruverumbur`.
- **No theater ticked** means any theater in the city counts.

### 4. Turn tracking on

Tap **Start tracking** on the big status card and **Allow** what it asks for:

| Permission | Why |
|---|---|
| **Notifications** | To show the alarm |
| **Ignore battery optimisation** | So Android doesn't stop the checks when the screen is off |

A small **"BMS Tracker – watching…"** notification stays while tracking is on.
Tap **Test alarm** to hear it, and turn up your **alarm volume**. The alarm
uses the alarm volume, not the ringtone or media volume.

That's it. You can close the app.

---

## Using the app

### When the alarm rings

- The notification says **"BOOKING OPEN!"** with the theater, date and
  language/format.
- **Tap it** to open the BookMyShow page and book. The alarm never opens
  anything by itself.
- Each theater rings **once per movie**. To hear it again, go to
  **Settings → Reset alerts**.

### Home screen

| Item | What it shows |
|---|---|
| **Status card** | Whether tracking is **off**, **watching**, **booking open!**, **paused by your phone** or hit an **error**, with the last check time and the Start/Stop button |
| **Check now** | Runs a check right away and shows the details. If one of your theaters has shows that haven't rung yet, it rings too. |
| **Report** | Exactly what the background tracker saw: each language/format and date, the theaters with shows, and ✔/✖ for your theaters |
| **Test alarm** | Plays the alarm, so you can check the sound and volume |
| **Movie cards** | One chip per date: **Open** (at your theaters), **Other theaters** (open, but not at yours yet), **Not yet**, or **Blocked** |
| **Theaters** | How many theaters are ticked. Tap to search, tick, add or load theaters. |
| **Recent alarms** | The alarms that have rung, with times |

### Settings

| Setting | What it does |
|---|---|
| **Check every** | How often to check (30–300 s, default 60) |
| **Also alarm for other theaters** | Off by default. Turn it on to also get one alarm when the movie opens at any theater. |
| **Test alarm** / **Reset alerts** | Hear the alarm; let theaters that already rang ring again |
| **Default BookMyShow city** | Used only when a movie link has no city in it |
| **About** | Source code, report a problem |

Tap **Save** at the top right to keep your changes.

---

## Troubleshooting

**The tracker stops when the screen is off.** Samsung, Xiaomi/Redmi, Oppo,
Vivo, Realme and OnePlus phones often stop background apps:

- Settings → Apps → **BMS Tracker** → Battery → **Unrestricted**.
- Turn on **Autostart** if your phone has it.
- Don't swipe away the "watching" notification.

If the home screen says **"⚠ No check for a while"**, the phone paused the
tracker. Fix the settings above, then turn tracking off and on.

**"Shows on another date" warning.** BookMyShow has shows, but not on the
date you set. Tap the movie and change its date.

**A theater shows in BookMyShow but not in the tracker.** Check the city in the
movie's link. Some places have two BookMyShow cities, for example a short name
and a full name. One of them may list fewer cinemas. Use the city the
BookMyShow app shows, or add the movie once for each city.

**BLOCKED.** BookMyShow refused the request. Switch between Wi-Fi and mobile
data and try **Check now** again, or raise the check interval.

**No sound.** Tap **Test alarm**. If it's silent, turn up the alarm volume and
check that notifications for BMS Tracker are allowed.

**"App not installed" when updating.** You have a version older than 0.4.
Uninstall it once, then install the new one.

Still stuck? [Open an issue](https://github.com/Theavinash02/bookmyshowtracker/issues/new/choose)
and paste the **Background report**.

---

## How it works

The app opens each movie's BookMyShow "Book tickets" page for every date you
chose, in a hidden browser inside the app, the same way you would. That's why
it works with BookMyShow's bot protection. It finds the movie's other
languages and formats by pressing "Book tickets" on the movie page. A date
counts as open only if BookMyShow lists shows **on that exact date**. A theater
counts only if BookMyShow lists it **with shows**.

## Contributing

Contributions are welcome: bug reports, theater-matching fixes, UI ideas and
code. Read **[CONTRIBUTING.md](CONTRIBUTING.md)** for how to build the app, how
the code is organised and how to send a pull request.

- 🐞 [Report a bug](https://github.com/Theavinash02/bookmyshowtracker/issues/new?template=bug_report.yml)
- 💡 [Suggest a feature](https://github.com/Theavinash02/bookmyshowtracker/issues/new?template=feature_request.yml)
- 🏙️ [My city or theater doesn't work](https://github.com/Theavinash02/bookmyshowtracker/issues/new?template=city_or_theater.yml)

## Build it yourself

Requires the Flutter SDK (3.50 or newer) and Java 21.

```sh
flutter pub get
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. A new
GitHub release is published whenever a merge to `main` raises the version in
`pubspec.yaml` (see [CONTRIBUTING.md](CONTRIBUTING.md#releases-maintainers)).

## Disclaimer

BMS Tracker is an unofficial personal tool. It is not affiliated with,
endorsed by or connected to BookMyShow or Bigtree Entertainment Pvt. Ltd.
"BookMyShow" is a trademark of its owner. The app only reads public show-time
pages, at the interval you choose, and never books, buys or resells tickets.
Use it responsibly, keep the check interval reasonable, and follow
BookMyShow's terms of use. You use it at your own risk.

## License

[MIT](LICENSE). Bundles a patched copy of
[flutter_inappwebview_android](third_party/flutter_inappwebview_android)
(Apache-2.0).
