import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';

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
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'CalisTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
