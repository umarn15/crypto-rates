import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class FirebaseManager {
  static final FirebaseManager _singleton = FirebaseManager._internal();

  factory FirebaseManager() {
    return _singleton;
  }

  FirebaseManager._internal();

  Future<void> initializeFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }
}