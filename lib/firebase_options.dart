// PLACEHOLDER — not real Firebase config.
//
// Replace this file by running `flutterfire configure` once a Firebase project
// exists. The stub values below let the app *compile and run analyze/test in CI*
// without leaking real keys. They are intentionally non-functional; Firebase
// initialization is guarded in main.dart so the app does not hard-crash with
// these placeholders during local UI development.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart'
    show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _stub;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _stub;
      default:
        return _stub;
    }
  }

  static const FirebaseOptions _stub = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'calistrack-placeholder',
    storageBucket: 'calistrack-placeholder.appspot.com',
  );
}
