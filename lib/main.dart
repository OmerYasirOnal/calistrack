import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
    // Offline-first: Firestore's local cache serves reads and queues writes
    // when offline (a separate Hive mirror would be redundant for this data —
    // see docs/specs/2026-06-02-m6-polish-design.md). Set generously + on.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e, st) {
    debugPrint('Firebase init skipped/failed (expected with placeholder): $e');
    debugPrintStack(stackTrace: st);
  }

  runApp(const ProviderScope(child: CalisTrackApp()));
}
