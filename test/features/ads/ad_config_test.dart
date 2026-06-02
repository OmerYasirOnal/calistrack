import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Guards the AdMob config asset's shape so the AdService (T31) can rely on it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ad_config.json has test + prod unit ids and a positive pacing cap',
      () async {
    final raw = await rootBundle.loadString('assets/data/ad_config.json');
    final cfg = json.decode(raw) as Map<String, dynamic>;

    for (final env in ['test', 'prod']) {
      final block = cfg[env] as Map<String, dynamic>;
      for (final platform in ['android', 'ios']) {
        final ids = block[platform] as Map<String, dynamic>;
        expect(ids['banner'], isA<String>());
        expect((ids['banner'] as String), isNotEmpty);
        expect(ids['interstitial'], isA<String>());
        expect((ids['interstitial'] as String), isNotEmpty);
      }
    }

    // The interstitial frequency cap lives in config (no magic numbers in code).
    expect(cfg['interstitialEverySessions'], isA<int>());
    expect(cfg['interstitialEverySessions'] as int, greaterThan(0));
  });
}
