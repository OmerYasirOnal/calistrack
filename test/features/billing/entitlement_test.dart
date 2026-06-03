import 'package:calistrack/features/billing/application/entitlement.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entitlement', () {
    test('defaults to free — not Pro, ads enabled', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final e = c.read(entitlementProvider);
      expect(e.isPro, isFalse);
      expect(e.adsRemoved, isFalse);
      expect(e.source, EntitlementSource.free);
      expect(c.read(adsEnabledProvider), isTrue);
    });

    test('demo unlock is allowed under test (debug) so the showcase works', () {
      // In a real release build this const is false (no --dart-define), which is
      // what stops the demo unlock from bypassing billing in production.
      expect(demoUnlockAllowed, isTrue);
    });

    test('demo unlock grants Pro and removes ads, then lock reverts', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(entitlementProvider.notifier);

      ctrl.unlockProDemo();
      expect(c.read(entitlementProvider).isPro, isTrue);
      expect(c.read(entitlementProvider).source, EntitlementSource.proDemo);
      expect(c.read(entitlementProvider).adsRemoved, isTrue);
      expect(c.read(adsEnabledProvider), isFalse);

      ctrl.lock();
      expect(c.read(entitlementProvider).isPro, isFalse);
      expect(c.read(adsEnabledProvider), isTrue);
    });
  });
}
