import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AdMob unit ids + pacing resolved for the current build (test vs prod) and
/// platform (android vs ios), loaded from `assets/data/ad_config.json`.
class AdConfig {
  const AdConfig({
    required this.bannerUnitId,
    required this.interstitialUnitId,
    required this.interstitialEverySessions,
  });

  final String bannerUnitId;
  final String interstitialUnitId;

  /// Show at most one interstitial per this many finished sessions.
  final int interstitialEverySessions;

  /// Pure selection of the [env] ('test'|'prod') + [platform] ('android'|'ios')
  /// block from the decoded ad_config.json — kept pure so it's unit-testable.
  factory AdConfig.fromMap(
    Map<String, dynamic> map, {
    required String env,
    required String platform,
  }) {
    final ids = (map[env] as Map)[platform] as Map;
    final cap = map['interstitialEverySessions'];
    return AdConfig(
      bannerUnitId: ids['banner'] as String,
      interstitialUnitId: ids['interstitial'] as String,
      interstitialEverySessions: cap is int && cap > 0 ? cap : 3,
    );
  }
}

/// `android` / `ios` for the running platform — `defaultTargetPlatform` is safe
/// on web and in tests (no `dart:io`), defaulting to android otherwise.
String adPlatformKey() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

final adConfigProvider = FutureProvider<AdConfig>((ref) async {
  final raw = await rootBundle.loadString('assets/data/ad_config.json');
  final map = json.decode(raw) as Map<String, dynamic>;
  return AdConfig.fromMap(
    map,
    // Debug/profile builds use the safe sample units; release uses the real
    // (owner-provided) ones.
    env: kReleaseMode ? 'prod' : 'test',
    platform: adPlatformKey(),
  );
});
