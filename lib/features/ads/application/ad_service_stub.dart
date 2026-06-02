import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_service.dart';

/// Used on web / any non-`dart:io` target. Never touches the ads SDK.
AdService createAdService(Ref ref) => const NoOpAdService();

class NoOpAdService implements AdService {
  const NoOpAdService();

  @override
  bool get isSupported => false;

  @override
  Future<void> initialize() async {}

  @override
  Widget banner() => const SizedBox.shrink();

  @override
  Future<void> maybeShowInterstitial() async {}
}
