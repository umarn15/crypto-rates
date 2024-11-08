import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto_rates/firebase_options.dart';
import 'package:crypto_rates/models/theme_data.dart';
import 'package:crypto_rates/screens/crypto_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/notification_helper.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

late SharedPreferences prefs;

void main () async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  @override
  void initState() {
    super.initState();

    FirebaseMessaging.instance.getToken().then((String? token) async {
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationHelper.handleRemoteMessage(message);
    });
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
