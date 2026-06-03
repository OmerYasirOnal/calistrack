import 'package:calistrack/core/l10n/app_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppStrings', () {
    test('English values match the existing UI copy', () {
      const en = AppStrings(Locale('en'));
      expect(en.navToday, 'Today');
      expect(en.navSkills, 'Skills');
      expect(en.appTagline, 'Master bodyweight strength');
    });

    test('Turkish localizes the nav + tagline', () {
      const tr = AppStrings(Locale('tr'));
      expect(tr.navToday, 'Bugün');
      expect(tr.navProgress, 'İlerleme');
      expect(tr.navProfile, 'Profil');
      expect(tr.appTagline, 'Vücut ağırlığı gücünde ustalaş');
    });

    test('falls back to English for an unsupported locale', () {
      const fr = AppStrings(Locale('fr'));
      expect(fr.navToday, 'Today');
    });

    test('delegate supports en + tr and loads the right table', () async {
      expect(AppStrings.delegate.isSupported(const Locale('tr')), isTrue);
      expect(AppStrings.delegate.isSupported(const Locale('de')), isFalse);
      final loaded = await AppStrings.delegate.load(const Locale('tr'));
      expect(loaded.navToday, 'Bugün');
    });
  });
}
