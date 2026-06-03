import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';

/// Localization wiring shared by both MaterialApp variants — our hand-rolled
/// [AppStrings] plus the Flutter global delegates so Material/Cupertino widgets
/// (date/time pickers, etc.) speak Turkish too.
const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Root application widget. Dark-first Material 3.
///
/// While the first auth state is still resolving we show a splash instead of
/// the router, so a signed-out (or not-yet-restored) user never flashes a
/// protected screen before being redirected to `/login`. Once auth has
/// resolved (data *or* error), the gated [goRouterProvider] takes over.
class CalisTrackApp extends ConsumerWidget {
  const CalisTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    if (auth.isLoading) {
      return MaterialApp(
        title: 'CalisTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const _SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'CalisTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}

/// Branded splash shown while the first auth state resolves — a logo + wordmark
/// instead of a bare spinner, so the cold start looks intentional.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'CalisTrack',
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context).appTagline,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
