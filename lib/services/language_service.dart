import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  en('English', '🇬🇧 EN'),
  tr('Türkçe', '🇹🇷 TR');

  final String title;
  final String badge;
  const AppLanguage(this.title, this.badge);
}

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal() {
    _loadSavedLanguage();
  }

  static LanguageService get instance => _instance;

  static const String _prefKey = 'selected_app_language';
  AppLanguage _currentLanguage = AppLanguage.en;

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isEnglish => _currentLanguage == AppLanguage.en;
  bool get isTurkish => _currentLanguage == AppLanguage.tr;

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'tr') {
        _currentLanguage = AppLanguage.tr;
        notifyListeners();
      } else if (saved == 'en') {
        _currentLanguage = AppLanguage.en;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang.name);
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    final next = _currentLanguage == AppLanguage.en ? AppLanguage.tr : AppLanguage.en;
    await setLanguage(next);
  }

  /// Returns English or Turkish text based on current language
  String text(String en, String tr) {
    return _currentLanguage == AppLanguage.en ? en : tr;
  }
}

/// Convenience extension on BuildContext
extension LocalizationExtension on BuildContext {
  String t(String en, String tr) => LanguageService.instance.text(en, tr);
  bool get isEnglish => LanguageService.instance.isEnglish;
  bool get isTurkish => LanguageService.instance.isTurkish;
}

/// Reusable Language Toggle Pill for AppBars and Headers
class LanguageToggleButton extends StatelessWidget {
  final bool compact;
  final Color? activeColor;

  const LanguageToggleButton({
    super.key,
    this.compact = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final current = LanguageService.instance.currentLanguage;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => LanguageService.instance.toggleLanguage(),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: (activeColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (activeColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current == AppLanguage.en ? '🇬🇧' : '🇹🇷',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 4),
                Text(
                  current == AppLanguage.en ? 'EN' : 'TR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: activeColor ?? Theme.of(context).primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 13,
                  color: activeColor ?? Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
