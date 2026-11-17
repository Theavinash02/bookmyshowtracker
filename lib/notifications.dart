import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

/// Notification channel for the always-on "tracking" notification.
const serviceChannelId = 'tracker_service';

/// Notification channel for the loud "tickets open" alarm.
const alarmChannelId = 'tickets_open_alarm_v1';

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
  await android?.createNotificationChannel(AndroidNotificationChannel(
    alarmChannelId,
    'Tickets open ALARM',
    description: 'Loud alarm when ticket booking opens',
    importance: Importance.max,
    playSound: true,
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
    fullScreenIntent: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
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
