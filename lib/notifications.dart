import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

/// Notification channel for the always-on "tracking" notification.
const serviceChannelId = 'tracker_service';

/// Notification channel for the loud "tickets open" alarm.
/// (v2: uses the phone's alarm ringtone. Channel sounds can't be changed
/// after creation, hence a new id.)
const alarmChannelId = 'tickets_open_alarm_v2';
const _oldAlarmChannelIds = ['tickets_open_alarm_v1'];

/// The phone's own alarm ringtone (falls back to the default sound if unset).
const _alarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');

const serviceNotificationId = 888;

final notifications = FlutterLocalNotificationsPlugin();

Future<void> openBookMyShow(String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('launch failed: $e');
  }
}

/// Initialise the plugin and create channels. Safe to call in any isolate.
Future<void> initNotifications({bool handleTaps = false}) async {
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse:
        handleTaps ? (r) => openBookMyShow(r.payload) : null,
  );
  final android = notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    serviceChannelId,
    'Tracking status',
    description: 'Shown while the tracker is checking BookMyShow',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  ));
  for (final old in _oldAlarmChannelIds) {
    await android?.deleteNotificationChannel(channelId: old);
  }
  await android?.createNotificationChannel(AndroidNotificationChannel(
    alarmChannelId,
    'Tickets open ALARM',
    description: 'Loud alarm when ticket booking opens',
    importance: Importance.max,
    playSound: true,
    sound: _alarmSound,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    bypassDnd: true,
  ));
}

int _alarmId = 1000;

/// Loud, repeating alarm. Sound keeps ringing until the user taps/dismisses
/// it (FLAG_INSISTENT). Tapping opens BookMyShow.
Future<void> showTicketsOpenAlarm({
  required String title,
  required String body,
  required String url,
}) async {
  final details = AndroidNotificationDetails(
    alarmChannelId,
    'Tickets open ALARM',
    channelDescription: 'Loud alarm when ticket booking opens',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    // No full-screen intent: the alarm only rings (heads-up + insistent
    // sound). BookMyShow opens only when the user taps the notification.
    fullScreenIntent: false,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: _alarmSound,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
    visibility: NotificationVisibility.public,
    ticker: title,
    styleInformation: BigTextStyleInformation(body),
    // 4 = Notification.FLAG_INSISTENT: repeat sound until dismissed.
    additionalFlags: Int32List.fromList([4]),
    autoCancel: true,
  );
  await notifications.show(
    id: _alarmId++,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: details),
    payload: url,
  );
}
