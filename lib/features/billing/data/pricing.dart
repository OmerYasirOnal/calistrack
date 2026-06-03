import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One purchasable Pro plan, as configured in `assets/data/pricing.json`.
class PricingPlan {
  const PricingPlan({
    required this.id,
    required this.title,
    required this.priceUsd,
    required this.priceTry,
    required this.period,
    this.subtitle = '',
    this.highlighted = false,
    this.badge,
  });

  final String id; // 'annual' | 'monthly' | 'lifetime' — maps to a store product
  final String title;
  final String priceUsd;
  final String priceTry;
  final String period;
  final String subtitle;
  final bool highlighted;
  final String? badge;

  factory PricingPlan.fromJson(Map<String, dynamic> j) => PricingPlan(
        id: j['id'] as String,
        title: j['title'] as String,
        priceUsd: j['priceUsd'] as String,
        priceTry: j['priceTry'] as String,
        period: j['period'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        highlighted: j['highlighted'] as bool? ?? false,
        badge: j['badge'] as String?,
      );
}

/// Pro plans + the benefit bullets shown on the paywall.
class Pricing {
  const Pricing({required this.plans, required this.proBenefits});

  final List<PricingPlan> plans;
  final List<String> proBenefits;

  factory Pricing.fromMap(Map<String, dynamic> map) => Pricing(
        proBenefits: (map['proBenefits'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        plans: (map['plans'] as List? ?? const [])
            .map((e) => PricingPlan.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

final pricingProvider = FutureProvider<Pricing>((ref) async {
  final raw = await rootBundle.loadString('assets/data/pricing.json');
  return Pricing.fromMap(json.decode(raw) as Map<String, dynamic>);
});
