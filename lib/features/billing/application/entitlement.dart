import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the in-app demo unlock is permitted. TRUE only in debug builds or
/// when the build is explicitly flagged a demo (`--dart-define=CALISTRACK_DEMO=true`,
/// which the web/PWA preview build passes). In a real RELEASE build this is
/// FALSE, so the "Unlock (demo)" path cannot bypass billing — Pro then comes
/// only from a verified store purchase (the owner's RevenueCat step).
const demoUnlockAllowed = kDebugMode || bool.fromEnvironment('CALISTRACK_DEMO');

/// Where a Pro entitlement came from. `proStore` is the real path (a verified
/// store purchase via RevenueCat); `proDemo` is the in-app demo unlock used by
/// the web/PWA preview so reviewers can see the Pro experience without billing.
enum EntitlementSource { free, proDemo, proStore }

/// The user's current entitlement. Defaults to free so nothing is ever
/// accidentally unlocked. `adsRemoved` is derived from `isPro` (removing ads is
/// bundled into Pro) but kept as its own getter so a standalone "remove ads"
/// product could set it independently later.
class Entitlement {
  const Entitlement({
    this.isPro = false,
    this.source = EntitlementSource.free,
  });

  final bool isPro;
  final EntitlementSource source;

  bool get adsRemoved => isPro;

  Entitlement copyWith({bool? isPro, EntitlementSource? source}) => Entitlement(
        isPro: isPro ?? this.isPro,
        source: source ?? this.source,
      );
}

/// Owns the active [Entitlement]. This is the single seam between the app and
/// billing: the real implementation will set [state] from a RevenueCat customer
/// info listener (an owner step — needs store accounts + product IDs). Until
/// then it stays free, and [unlockProDemo]/[lock] drive the demo toggle so the
/// $0 web/PWA build can showcase both the free and Pro experiences.
class EntitlementController extends Notifier<Entitlement> {
  @override
  Entitlement build() => const Entitlement();

  /// Demo-only: grant Pro without a purchase (web/PWA showcase). A no-op unless
  /// [demoUnlockAllowed], so it can never bypass billing in a release build.
  void unlockProDemo() {
    if (!demoUnlockAllowed) return;
    state = const Entitlement(isPro: true, source: EntitlementSource.proDemo);
  }

  /// Demo-only: drop back to free.
  void lock() => state = const Entitlement();
}

final entitlementProvider =
    NotifierProvider<EntitlementController, Entitlement>(
  EntitlementController.new,
);

/// Whether ad surfaces should render/serve — false for Pro users. UI consults
/// this so "remove ads" is a single flip and tests can override it.
final adsEnabledProvider = Provider<bool>(
  (ref) => !ref.watch(entitlementProvider).adsRemoved,
);
