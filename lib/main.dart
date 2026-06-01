import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init is best-effort: with the committed placeholder config it may
  // throw, which is fine for local UI work and CI. Real config (via
  // `flutterfire configure`) makes this succeed. We never crash the app on it.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase init skipped/failed (expected with placeholder): $e');
    debugPrintStack(stackTrace: st);
  }

  runApp(const ProviderScope(child: CalisTrackApp()));
}
