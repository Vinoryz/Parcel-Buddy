import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

/// Central service for all local push notifications via awesome_notifications.
class NotificationService {
  static const _channelKey = 'parcel_channel';

  /// Stream to broadcast notification tap events
  static final StreamController<Map<String, String?>> actionStream = StreamController<Map<String, String?>>.broadcast();

  /// Call once in main() before runApp().
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // uses the default app launcher icon
      [
        NotificationChannel(
          channelKey: _channelKey,
          channelName: 'Package Notifications',
          channelDescription: 'Alerts when your package arrives at the lobby.',
          defaultColor: Colors.indigo,
          ledColor: Colors.indigo,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
    );

    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    if (receivedAction.payload != null) {
      actionStream.add(receivedAction.payload!);
    }
  }

  /// Request permission — call once after the app is fully loaded.
  static Future<void> requestPermission() async {
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  /// Show a notification banner (works in foreground & background).
  static Future<void> showPackageArrived({
    required String title,
    required String body,
    required Map<String, String> payload,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        channelKey: _channelKey,
        title: title,
        body: body,
        payload: payload,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
      ),
    );
  }
}
