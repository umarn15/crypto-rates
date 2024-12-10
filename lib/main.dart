import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto_rates/firebase_options.dart';
import 'package:crypto_rates/models/theme_data.dart';
import 'package:crypto_rates/screens/crypto_list_screen.dart';
import 'package:crypto_rates/services/firebase_manager.dart';
import 'package:crypto_rates/widgets/home_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'models/notification_helper.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await CryptoHomeWidget.updatePriceData();
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

Future<void> initializeApp() async {
  try {
    await HomeWidget.setAppGroupId('group.com.example.crypto_rates');
    HomeWidget.registerInteractivityCallback(backgroundCallback);
    await CryptoHomeWidget.initPlatformState();

    // Reduced initial update frequency
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      "cryptoUpdate",
      "updateWidget",
      frequency: Duration(minutes: 30), // Increased to 30 minutes
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true // Only update when battery isn't low
      ),
      backoffPolicy: BackoffPolicy.exponential, // Add exponential backoff
    );

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationHelper.init();
  } catch (e) {
    print('Initialization error: $e');
  }
}

void updateWidgetFromApp() async {
  await CryptoHomeWidget.updatePriceData();
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

late SharedPreferences prefs;

void main () async {
  WidgetsFlutterBinding.ensureInitialized();

  await CryptoHomeWidget.updatePriceData();

  await FirebaseManager().initializeFirebase();

 await initializeApp();

  await NotificationHelper.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  prefs = await SharedPreferences.getInstance();

  runApp(MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _fcmInitialized = false;

  Future<void> setupFCM() async {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      print('FCM Token: $token');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
        print('Token saved to Firestore');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
      print('FCM Token refreshed: $token');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
        print('Refreshed token saved to Firestore');
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      print('Message notification: ${message.notification?.title}');
      print('Message notification: ${message.notification?.body}');
      NotificationHelper.handleRemoteMessage(message);
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeWithRetry();
    setupFCM();
  }

  Future<void> _initializeWithRetry() async {
    if (!_fcmInitialized) {
      try {
        await setupFCM();
        _fcmInitialized = true;
      } catch (e) {
        print('FCM initialization failed: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: CryptoListScreen(),
    );
  }
}

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'handleRefresh') {
    await CryptoHomeWidget.handleRefresh();
  }
}