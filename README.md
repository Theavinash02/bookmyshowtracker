# BMS Tracker

**Get an alarm on your phone the moment BookMyShow opens bookings for a movie at
the theaters you want, on the dates you want.**

You add a movie, tick your theaters and pick your dates. The app then checks
BookMyShow about once a minute in the background. As soon as one of your
theaters has shows on one of your dates, your phone rings like an alarm clock.
Tap the notification and you go straight to that BookMyShow page to book.

- Works for **any movie**, in every **language and format** (2D, 3D, IMAX,
  MS-Infinity…). You don't have to choose one.
- Alarms only for **your theaters** and **your dates**. Shows anywhere else
  don't wake you up.
- Rings with your **alarm ringtone**, even on silent, until you dismiss it.
- Keeps working with the screen off, and starts again after the phone restarts.

> Android only. Made for Trichy (Tiruchirappalli) and works for other
> BookMyShow cities too.

---

## 1. Install

1. On your Android phone, open this link. It always downloads the newest
   version:
   **<https://github.com/Theavinash02/bookmyshowtracker/releases/latest/download/bms-tracker.apk>**
2. Open the downloaded **bms-tracker.apk** and tap **Install**. If Android
   asks, allow **"Install unknown apps"** for your browser.

**To update later,** open the same link again and install over the old app.
Your movies and theaters are kept.

## 2. Allow what the app needs

The first time you turn tracking on, the app asks for these. Say **Allow** to
all of them:

| Permission | Why |
|---|---|
| **Notifications** | To show the alarm |
| **Ignore battery optimisation** | So Android doesn't stop the checks when the screen is off |

Also turn up your phone's **alarm volume**. The alarm uses the alarm volume,
not the ringtone or media volume.

## 3. Add a movie

1. Open the **BookMyShow** app or website and choose your city (for Trichy,
   choose **Trichy**).
2. Open the movie and copy its link:
   - **App:** tap **Share**, then **Copy link**.
   - **Website:** copy the address from the address bar.

   The link must contain a code like `ET00439706`. Either the movie page or
   the "Book tickets" page works, for example
   `https://in.bookmyshow.com/movies/trichy/avengers-doomsday/ET00439706`.
3. In BMS Tracker, tap **+ Movie** and paste the link. The title and city fill
   in by themselves.
4. Set the **Show date** and **Days to watch**. For example, set 17 Dec and
   2 days to watch 17 and 18 Dec.
5. Tap **Save**.

You don't need to add each language separately. The app finds all
languages and formats of the movie by itself.

## 4. Pick your theaters

Under **Theaters**, tick the cinemas you want. Common Trichy cinemas are listed
already.

- **Missing a theater?** Tap **Add theater** and enter its name and a word from
  its BookMyShow name, for example `Thiruverumbur`. You can give several
  spellings separated by `|`, for example `Thiruverumbur|Tiruverumbur`.
- **Want BookMyShow's exact list?** Tap **Load from BookMyShow**, paste the link
  of any movie currently running in your city, and tick the theaters you want.
- **No theater ticked** means any theater counts.

## 5. Turn tracking on

Turn on the **switch at the top right**. A small **"BMS Tracker – watching…"**
notification appears and stays while tracking is on. Leave it there.

Then tap **Test alarm** to hear what the alarm sounds like.

That's it. You can close the app.

---

## When the alarm rings

- The phone rings with your alarm ringtone, and a notification says
  **"BOOKING OPEN!"** with the theater, date and language/format.
- The alarm only rings. It **doesn't open anything** by itself.
- **Tap the notification** to open that BookMyShow page and book.
- Each theater rings **once per movie**. To hear it again, go to **Settings**,
  tap **Reset alerts**, then **Save**.

## The home screen

| Item | What it shows |
|---|---|
| **Status card** | When the last check ran, how long it took, and for each movie and date: **OPEN @ your theater**, **not at your theaters yet**, or **not yet** |
| **Check now** | Runs a check right away and shows the details. If one of your theaters has shows that haven't rung yet, it rings too. |
| **Background report** | Exactly what the background tracker saw on its last check: each language/format and date, the theaters with shows, and ✔ or ✖ for each of your theaters |
| **Test alarm** | Plays the alarm, so you can check the sound and volume |
| **Recent alarms** | The alarms that have rung, with times |

## Settings

| Setting | What it does |
|---|---|
| **Check every … seconds** | How often to check (30–300 s, default 60) |
| **Also alarm when booking opens at other theaters** | Off by default. Turn it on to also get one alarm when the movie opens at any theater. |
| **Default BookMyShow city** | Used only when a movie link has no city in it |
| **Reset alerts** | Lets theaters that already rang ring again |

---

## Tips and troubleshooting

**Keep the app running in the background.** Samsung, Xiaomi/Redmi, Oppo,
Vivo, Realme and OnePlus phones often stop background apps. Do this:

- Settings → Apps → **BMS Tracker** → Battery → **Unrestricted** (or "No restrictions").
- Turn on **Autostart** if your phone has it.
- Don't swipe away the "watching" notification.

If the home screen says **"⚠ No check for a while"**, the phone paused the
tracker. Fix the settings above, then turn tracking off and on.

**"BookMyShow HAS shows on another date"**: BookMyShow has shows, but not on
the date you set. Tap the movie and change its date.

**Movie shows at a theater in the BookMyShow app but not in the tracker**:
check the city. BookMyShow has two cities for Trichy: **"Trichy"**
(`/movies/trichy/…`, with all cinemas) and **"Tiruchirappalli"** (only a few).
Use a link with `trichy`. You can add the same movie twice, once with each
link, to watch both.

**BLOCKED**: BookMyShow refused the request. Switch between Wi-Fi and mobile
data and try **Check now** again.

**No sound**: tap **Test alarm**. If it's silent, turn up the alarm volume
and check that notifications for BMS Tracker are allowed.

---

## How it works

The app checks each movie's BookMyShow "Book tickets" page for every date you
chose, using a hidden browser inside the app. That's why it works with
BookMyShow's bot protection. It finds the movie's other languages and formats
by pressing "Book tickets" on the movie page, the way you would. A date counts
as open only if BookMyShow lists shows **on that exact date**. A theater counts
only if BookMyShow lists it **with shows**.

## Build it yourself

Requires the Flutter SDK (3.50 or newer) and Java 21.

```
flutter pub get
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Every
merge to `main` also builds the APK and publishes it as a new GitHub release.
