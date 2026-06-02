import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Web (and any non-io target) gets the no-op implementation; mobile/desktop/the
// test VM get the google_mobile_ads-backed one. This is what keeps the web
// build (lib/preview.dart) free of the ads SDK, which doesn't support web.
import 'ad_service_stub.dart' if (dart.library.io) 'ad_service_io.dart';

/// Whether an interstitial should run after [finishedSessions] completed
/// sessions, capped to one every [everyN]. Pure → unit-tested.
bool shouldShowInterstitial(int finishedSessions, int everyN) =>
    everyN > 0 && finishedSessions > 0 && finishedSessions % everyN == 0;

/// Shows ads on supported platforms (Android/iOS) and is a safe no-op
/// everywhere else (web, desktop, tests), so the rest of the app never depends
/// on the SDK being present or initialized.
abstract interface class AdService {
  bool get isSupported;

  /// Initialize the ads SDK (no-op when unsupported). Best-effort.
  Future<void> initialize();

  /// A banner widget, or an empty box when ads aren't supported/loaded.
  Widget banner();

  /// Count a finished session and, if the pacing cap is hit, show an
  /// interstitial. No-op when unsupported.
  Future<void> maybeShowInterstitial();
}

/// The active [AdService] — real on mobile, no-op elsewhere. Overridable in
/// tests.
final adServiceProvider = Provider<AdService>(createAdService);
