import 'package:flutter/widgets.dart';

/// Lightweight, hand-rolled localizations (EN + TR). A plain delegate — no
/// codegen — so it stays `dart format` / `flutter analyze` clean and fully under
/// our control. Turkish is the launch beachhead; English is the fallback for any
/// missing key. Expand the tables (and getters) as more of the UI is localized.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  Map<String, String> get _t => _tables[locale.languageCode] ?? _en;
  String _s(String key) => _t[key] ?? _en[key]!;

  // Bottom navigation.
  String get navToday => _s('navToday');
  String get navPrograms => _s('navPrograms');
  String get navProgress => _s('navProgress');
  String get navSkills => _s('navSkills');
  String get navProfile => _s('navProfile');

  // Splash.
  String get appTagline => _s('appTagline');

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(Locale('en'));

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('tr')];

  static const Map<String, String> _en = {
    'navToday': 'Today',
    'navPrograms': 'Programs',
    'navProgress': 'Progress',
    'navSkills': 'Skills',
    'navProfile': 'Profile',
    'appTagline': 'Master bodyweight strength',
  };

  static const Map<String, String> _tr = {
    'navToday': 'Bugün',
    'navPrograms': 'Programlar',
    'navProgress': 'İlerleme',
    'navSkills': 'Beceriler',
    'navProfile': 'Profil',
    'appTagline': 'Vücut ağırlığı gücünde ustalaş',
  };

  static const Map<String, Map<String, String>> _tables = {
    'en': _en,
    'tr': _tr,
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      );

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
