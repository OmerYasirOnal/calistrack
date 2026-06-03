import 'package:calistrack/features/billing/data/pricing.dart';
import 'package:calistrack/features/billing/presentation/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _pricing = Pricing(
  proBenefits: ['AI-generated programs', 'No ads'],
  plans: [
    PricingPlan(
      id: 'annual',
      title: 'Annual',
      priceUsd: r'$29.99',
      priceTry: '₺299',
      period: 'per year',
      highlighted: true,
      badge: 'Save 58%',
    ),
    PricingPlan(
      id: 'monthly',
      title: 'Monthly',
      priceUsd: r'$5.99',
      priceTry: '₺59',
      period: 'per month',
    ),
  ],
);

Widget _app() => ProviderScope(
      overrides: [
        pricingProvider.overrideWith((ref) async => _pricing),
      ],
      child: const MaterialApp(
        home: PaywallScreen(reason: 'AI program generation is a Pro feature.'),
      ),
    );

void main() {
  testWidgets('renders benefits, plans, prices, and the reason', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('AI program generation is a Pro feature.'), findsOneWidget);
    expect(find.text('AI-generated programs'), findsOneWidget);
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text(r'$29.99'), findsOneWidget);
    expect(find.text('Save 58%'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('choosing a plan and confirming the demo unlock flips to Pro',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annual'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock (demo)'), findsOneWidget);

    await tester.tap(find.text('Unlock (demo)'));
    await tester.pumpAndSettle();

    // Paywall is the root route, so it rebuilds into the Pro state in place.
    expect(find.text("You're Pro 🎉"), findsOneWidget);
    expect(find.text('Switch back to Free (demo)'), findsOneWidget);
  });
}
