import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not supported');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDFhfPxogmPZxA8sj9vtaUj2jXmXSt-5eE',
    appId: '1:467132775931:android:3b60b6e9882e3dbcab5f5e',
    messagingSenderId: '467132775931',
    projectId: 'medichine-29fff',
    storageBucket: 'medichine-29fff.firebasestorage.app',
  );
}