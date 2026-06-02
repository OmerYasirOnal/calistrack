import 'package:calistrack/features/ads/application/ad_service.dart';
import 'package:calistrack/features/ads/application/ad_service_stub.dart';
import 'package:calistrack/features/ads/data/ad_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowInterstitial', () {
    test('fires every Nth finished session, never at 0', () {
      expect(shouldShowInterstitial(0, 3), isFalse);
      expect(shouldShowInterstitial(1, 3), isFalse);
      expect(shouldShowInterstitial(2, 3), isFalse);
      expect(shouldShowInterstitial(3, 3), isTrue);
      expect(shouldShowInterstitial(4, 3), isFalse);
      expect(shouldShowInterstitial(6, 3), isTrue);
    });

    test('is disabled when the cap is non-positive', () {
      expect(shouldShowInterstitial(3, 0), isFalse);
      expect(shouldShowInterstitial(3, -1), isFalse);
    });
  });

  group('AdConfig.fromMap', () {
    final Map<String, dynamic> map = {
      'test': {
        'android': {'banner': 'a-test-b', 'interstitial': 'a-test-i'},
        'ios': {'banner': 'i-test-b', 'interstitial': 'i-test-i'},
      },
      'prod': {
        'android': {'banner': 'a-prod-b', 'interstitial': 'a-prod-i'},
        'ios': {'banner': 'i-prod-b', 'interstitial': 'i-prod-i'},
      },
      'interstitialEverySessions': 5,
    };

    test('selects the env + platform block and the cap', () {
      final android = AdConfig.fromMap(map, env: 'test', platform: 'android');
      expect(android.bannerUnitId, 'a-test-b');
      expect(android.interstitialUnitId, 'a-test-i');
      expect(android.interstitialEverySessions, 5);

      final iosProd = AdConfig.fromMap(map, env: 'prod', platform: 'ios');
      expect(iosProd.bannerUnitId, 'i-prod-b');
      expect(iosProd.interstitialUnitId, 'i-prod-i');
    });

    test('defaults the cap to 3 when missing or non-positive', () {
      final c = AdConfig.fromMap(
        {...map, 'interstitialEverySessions': 0},
        env: 'test',
        platform: 'ios',
      );
      expect(c.interstitialEverySessions, 3);
    });
  });

  group('NoOpAdService', () {
    test('is unsupported and every method is a safe no-op', () async {
      const service = NoOpAdService();
      expect(service.isSupported, isFalse);
      await service.initialize();
      await service.maybeShowInterstitial();
      expect(service.banner(), isA<SizedBox>());
    });
  });
}
