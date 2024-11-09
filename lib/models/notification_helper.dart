import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  static const mainNotificationChannelID = 'offrir_app';

  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Request notification permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        // Handle notification tap
        if (details.payload != null) {
          // Navigate to relevant screen
        }
      },
    );

    // Set up foreground notification presentation
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> handleRemoteMessage(RemoteMessage message) async {
    print('Handling remote message: ${message.messageId}');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.toMap()}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    try {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation;
      AndroidFlutterLocalNotificationsPlugin().createNotificationChannel(
        AndroidNotificationChannel(
          'price_alerts_channel',
          'Price Alerts',
          description: 'Notifications for cryptocurrency price alerts',
          importance: Importance.high,
        ),
      );

      if (notification != null) {
        print('Showing local notification');
        await _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'price_alerts_channel',
              'Price Alerts',
              channelDescription: 'Notifications for cryptocurrency price alerts',
              importance: Importance.high,
              priority: Priority.high,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );
        print('Local notification shown successfully');
      }
    } catch (e) {
      print('Error showing notification: $e');
    }
  }


  static Future<NotificationDetails?> getMainNotificationDetails(
      Map<String, dynamic> payload) async {
    late AndroidNotificationDetails androidNotificationDetails;
    DarwinNotificationDetails iosNotificationDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    androidNotificationDetails = AndroidNotificationDetails(
      mainNotificationChannelID,
      "313 Notification Channel",
      channelDescription: "Main Notification Channel",
      importance: Importance.max,
      priority: Priority.high,
    );

    return NotificationDetails(
        android: androidNotificationDetails, iOS: iosNotificationDetails);
  }
}