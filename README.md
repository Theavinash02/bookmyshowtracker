# BMS Tracker for Trichy

An Android app that checks BookMyShow every minute and **sounds a loud alarm**
on your phone when ticket booking opens for your movie (for example
*Avengers: Doomsday*) at the Tiruchirappalli theaters you pick.

The idea comes from [albinpk/bookmyshow-tracker](https://github.com/albinpk/bookmyshow-tracker),
which checks every 15 minutes and only looks at the whole city. This app adds:

- **Theater selection.** Tick the Trichy cinemas you care about. You can also load the real list from BookMyShow or add your own.
- **Checks every 30–300 seconds** (60 s by default). It runs as a foreground service, not Android's 15-minute WorkManager.
- **An alarm-style alert.** It uses the alarm sound stream, so it rings even when the phone is on silent. It keeps ringing until you dismiss it and shows on the lock screen. Tap it to open BookMyShow.
- **A "Check now" button.** It shows exactly what the app sees for each date, so you can confirm the checker works before tickets open.
- **Restart after reboot.** Tracking comes back on automatically after the phone restarts.

## Install

1. Open the **Releases** page of this repository (tag `latest`) on your phone. Or go to **Actions → Build APK → latest run → Artifacts**.
2. Download `bms-tracker.apk` and install it. When Android asks, allow "Install unknown apps" for your browser.

## Set up (takes 2 minutes, do it today)

1. **Add the movie.** In the BookMyShow app or website, open *Avengers: Doomsday* with Tiruchirappalli as the city. Tap **Share → Copy link**. In BMS Tracker, tap **+ Movie** and paste the link. It must contain the code `ET00…`.
2. **Pick the dates.** Set the first show date (18 Dec 2026 by default) and how many days to watch (1–7).
3. **Tick your theaters.** If a name in the list is wrong, use **Load from BookMyShow**: paste the "Book tickets" link of *any movie running in Trichy today* and pick theaters from the real list. You can also edit the match keyword yourself.
4. Turn on the **switch at the top right**. Allow notifications, and allow the app to **ignore battery optimisation**. This is important.
5. Tap **Test alarm** to hear the alert.

### Check that the checker works (strongly recommended)

Add a movie that is **already running in Trichy** with today's date, then tap
**Check now**. It should say **OPEN** and list your theaters. If it does,
the checker is working. Delete that movie afterwards (or switch it off).

If it says **BLOCKED**, BookMyShow is refusing the request. Try mobile data
instead of Wi-Fi.

If it says *Redirected away* even for a running movie, BookMyShow has
changed its link format. Open the movie's "Book tickets" page in a browser,
look at the link, and update **Settings → Show-times URL pattern**. The
pattern can use these placeholders: `{city} {slug} {event} {date}`.

## Keep it alive

- Leave the "BMS Tracker – watching" notification in place. That notification is the background service.
- Some phones (Xiaomi/Redmi, Oppo, Vivo, Realme, OnePlus, Samsung) kill background apps. Set **Battery → BMS Tracker → No restrictions / Allow background activity**, and turn on **Autostart** if your phone has it. For more, see <https://dontkillmyapp.com>.
- Keep the phone on the internet.

## How it works

For each date it fetches
`https://in.bookmyshow.com/movies/{city}/{slug}/buytickets/{event}/{YYYYMMDD}`.

- If BookMyShow redirects away from the show-times page, or the page has no show times, booking is not open.
- If show times are present, booking is open. The app then looks for your theater keywords on the page. A keyword only matches at the start of a word, so "Sona" matches "Sona Mina" but not "personal".

Each theater raises the alarm once per movie. **Settings → Reset alerts**
makes it ring again.

## Build it yourself

You need the Flutter SDK (3.50 or newer):

```
flutter pub get
flutter test
flutter build apk --release
```
