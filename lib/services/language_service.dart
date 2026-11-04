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
    final next = _currentLanguage == AppLanguage.en
        ? AppLanguage.tr
        : AppLanguage.en;
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

  String areaCategoryTitle(String title) => switch (title) {
    'Toplanma Alanı' => t('Assembly Area', title),
    'Çadır Kent' => t('Tent City', title),
    'Sahra Hastanesi / İlk Yardım' => t('Field Hospital / First Aid', title),
    'Aşevi & Su Dağıtım' => t('Soup Kitchen & Water Distribution', title),
    _ => title,
  };

  String areaName(String name) => switch (name) {
    'Atatürk Parkı Güvenli Toplanma Alanı' => t(
      'Atatürk Park Safe Assembly Area',
      name,
    ),
    'Kamil Ocak 1 Nolu Çadır Kent' => t('Kamil Ocak Tent City No. 1', name),
    'Kızılay Aşevi ve Temel İhtiyaç Noktası' => t(
      'Red Crescent Soup Kitchen and Essential Supplies Point',
      name,
    ),
    'Sahra Acil Müdahale ve İlk Yardım Merkezi' => t(
      'Field Emergency Response and First Aid Center',
      name,
    ),
    'Masal Parkı 2. Toplanma Bölgesi' => t(
      'Masal Park Assembly Area No. 2',
      name,
    ),
    _ => name,
  };

  String areaAddress(String address) => switch (address) {
    'Şehitkamil, Osmangazi Mah. Park İçi' => t(
      'Şehitkamil, Osmangazi Neighborhood, inside the park',
      address,
    ),
    'Kamil Ocak Spor Kompleksi Çevresi' => t(
      'Around Kamil Ocak Sports Complex',
      address,
    ),
    'Mithatpaşa Meydanı Dağıtım Merkezi' => t(
      'Mithatpaşa Square Distribution Center',
      address,
    ),
    'İstasyon Caddesi Sağlık Çadırı' => t(
      'Health tent on İstasyon Street',
      address,
    ),
    'Sarıgüllük Mah. Masal Parkı İçi' => t(
      'Sarıgüllük Neighborhood, inside Masal Park',
      address,
    ),
    'Şehitkamil Merkez Bölgesi' => t('Central Şehitkamil', address),
    _ => address,
  };

  String areaService(String service) => switch (service) {
    'Temiz Su' => t('Clean Water', service),
    'Aydınlatma' => t('Lighting', service),
    'İlk Yardım Çadırı' => t('First Aid Tent', service),
    'Mobil Tuvalet' => t('Portable Toilets', service),
    'Şarj İstasyonu' => t('Charging Station', service),
    'Isınma' => t('Heating', service),
    'Barınma Çadırları' => t('Shelter Tents', service),
    'Gıda Dağıtımı' => t('Food Distribution', service),
    'Psikososyal Destek' => t('Psychosocial Support', service),
    'Sıcak Çorba' => t('Hot Soup', service),
    'Ekmek Dağıtımı' => t('Bread Distribution', service),
    'Konserve & Su' => t('Canned Food & Water', service),
    'Bebek Bezi & Hijyen' => t('Diapers & Hygiene Supplies', service),
    'Temel İlaçlar' => t('Essential Medicines', service),
    'Doktor & Hemşire' => t('Doctors & Nurses', service),
    'Pansuman' => t('Dressing Supplies', service),
    'Ambulans İrtibat' => t('Ambulance Coordination', service),
    'Geniş Açık Alan' => t('Large Open Area', service),
    'Jeneratör' => t('Generator', service),
    'İçme Suyu Deposu' => t('Drinking Water Tank', service),
    'Helikopter Pisti' => t('Helipad', service),
    'Güvenli Alan' => t('Safe Area', service),
    _ => service,
  };

  String stockItemName(String item) => switch (item) {
    'İçme Suyu' => t('Drinking Water', item),
    'Battaniye' => t('Blankets', item),
    'Bebek Maması' => t('Infant Formula', item),
    'Isıtıcı' => t('Heaters', item),
    'Kuru Gıda' => t('Dry Food', item),
    'Sıcak Yemek' => t('Hot Meals', item),
    'Hijyen Seti' => t('Hygiene Kits', item),
    'Ağrı Kesici & Antibiyotik' => t('Painkillers & Antibiotics', item),
    'Serum' => t('IV Fluids', item),
    'İlk Yardım Çantası' => t('First Aid Kits', item),
    'Çadır' => t('Tents', item),
    _ => item,
  };

  String stockQuantity(String quantity) {
    if (!isEnglish) return quantity;
    return quantity
        .replaceAll('Şişe', 'bottles')
        .replaceAll('Adet', 'items')
        .replaceAll('Kutu', 'boxes')
        .replaceAll('Koli', 'cartons')
        .replaceAll('Paket', 'packages')
        .replaceAll('Boş', 'available')
        .replaceAll('Günlük', 'daily')
        .replaceAll('Porsiyon', 'portions')
        .replaceAll('L Depo', 'L tank')
        .replaceAll('Bol', 'plenty')
        .replaceAll('Mevcut', 'available')
        .replaceAll('Depo', 'tank');
  }
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
              color: (activeColor ?? Theme.of(context).primaryColor).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (activeColor ?? Theme.of(context).primaryColor)
                    .withValues(alpha: 0.35),
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
