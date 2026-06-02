import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/ad_config.dart';
import 'ad_service.dart';

/// Used on `dart:io` targets. Ads only actually run on Android/iOS; on the test
/// VM / desktop [isSupported] is false so every method is a graceful no-op (no
/// plugin calls), which is why widget tests need no override.
AdService createAdService(Ref ref) => MobileAdService(ref);

class MobileAdService implements AdService {
  MobileAdService(this._ref);

  final Ref _ref;
  int _finishedSessions = 0;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> initialize() async {
    if (!isSupported) return;
    // 1. iOS App Tracking Transparency prompt (no-op on Android / if already
    //    decided). Owner must finalise the Info.plist copy + verify on-device.
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
    // 2. GDPR/UMP consent (Google User Messaging Platform, bundled in
    //    google_mobile_ads). Gathers consent / shows the form where the user's
    //    region requires it, before any ad loads. Owner configures the consent
    //    form in the AdMob console + verifies on-device.
    await _gatherConsent();
    // 3. Now safe to initialize the ads SDK.
    await MobileAds.instance.initialize();
  }

  /// Requests a consent-info update and shows the consent form if required.
  /// Always completes (proceeding non-personalized on failure) and is
  /// time-boxed so a slow/blocked consent flow never hangs app startup.
  Future<void> _gatherConsent() {
    final completer = Completer<void>();
    void done() {
      if (!completer.isCompleted) completer.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => unawaited(
        ConsentForm.loadAndShowConsentFormIfRequired((_) => done()),
      ),
      (_) => done(),
    );
    return completer.future
        .timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  @override
  Widget banner() =>
      isSupported ? const _BannerAdView() : const SizedBox.shrink();

  @override
  Future<void> maybeShowInterstitial() async {
    if (!isSupported) return;
    _finishedSessions++;
    final cfg = await _ref.read(adConfigProvider.future);
    final due = shouldShowInterstitial(
      _finishedSessions,
      cfg.interstitialEverySessions,
    );
    if (!due) return;
    await InterstitialAd.load(
      adUnitId: cfg.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, _) => ad.dispose(),
          );
          ad.show();
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }
}

/// Loads a single adaptive banner and renders it once ready (empty until then).
class _BannerAdView extends ConsumerStatefulWidget {
  const _BannerAdView();

  @override
  ConsumerState<_BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends ConsumerState<_BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await ref.read(adConfigProvider.future);
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: cfg.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
