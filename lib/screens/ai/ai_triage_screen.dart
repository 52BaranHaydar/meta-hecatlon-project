import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import '../../constants/app_colors.dart';
import '../../constants/meta_ai_config.dart';
import '../../models/ai_triage_model.dart';
import '../../services/auth_service.dart';
import '../../services/crisis_data_service.dart';
import '../../services/language_service.dart';
import '../../services/location_service.dart';
import '../../services/safety_circle_service.dart';
import '../../services/safety_sms_service.dart';
import '../../widgets/emergency_112_button.dart';

class AiTriageScreen extends StatefulWidget {
  const AiTriageScreen({super.key});

  @override
  State<AiTriageScreen> createState() => _AiTriageScreenState();
}

class _AiTriageScreenState extends State<AiTriageScreen> {
  final TextEditingController _reportController = TextEditingController();
  final TextEditingController _locationController = TextEditingController(
    text: 'Şehitkamil, Osmangazi Mah. No: 18',
  );
  final CrisisDataService _crisisService = CrisisDataService();

  bool _isAnalyzing = false;
  bool _isListening = false;
  bool _submittedToAdmin = false;
  AiTriageResult? _activeResult;
  List<SafetySmsDraft> _pendingSmsDrafts = [];

  @override
  void initState() {
    super.initState();
    _activeResult = _crisisService.reports.first;
    final english = LanguageService.instance.isEnglish;
    _locationController.text = english
        ? 'Central Şehitkamil, Gaziantep'
        : 'Şehitkamil, Osmangazi Mah. No: 18';
    _reportController.text = english
        ? 'There is a building collapse and people may be trapped inside.'
        : _activeResult!.rawText;
    _loadPendingSmsDrafts();
  }

  Future<void> _loadPendingSmsDrafts() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      final drafts = await SafetySmsService.loadQueue(user.uid);
      if (mounted) setState(() => _pendingSmsDrafts = drafts);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Could not load pending SMS queue: $error',
              'Bekleyen SMS kuyruğu yüklenemedi: $error',
            ),
          ),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _runAiClassification(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _submittedToAdmin = false;
    });

    bool hasInternet;
    try {
      hasInternet = await InternetConnection().hasInternetAccess;
    } catch (error) {
      final queued = await _tryQueueOfflineReport(text);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? context.t(
                    'Could not verify the connection; the report was saved to the SMS queue. Error: $error',
                    'Bağlantı doğrulanamadı; ihbar SMS kuyruğuna kaydedildi. Hata: $error',
                  )
                : context.t(
                    'Could not verify the connection and the report could not be added to the SMS queue. Error: $error',
                    'Bağlantı doğrulanamadı ve ihbar SMS kuyruğuna eklenemedi. Hata: $error',
                  ),
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (!hasInternet) {
      final queued = await _tryQueueOfflineReport(text);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? context.t(
                    'No internet connection. The report was added to the SMS queue but has not been sent.',
                    'İnternet yok. İhbar SMS kuyruğuna kaydedildi; henüz gönderilmedi.',
                  )
                : context.t(
                    'No internet connection and the report could not be added to the SMS queue.',
                    'İnternet yok ve ihbar SMS kuyruğuna eklenemedi.',
                  ),
          ),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }

    final result = await _crisisService.classifyAndSubmitReport(
      text,
      location: _locationController.text,
      english: LanguageService.instance.isEnglish,
    );

    if (mounted) {
      setState(() {
        _activeResult = result;
        _isAnalyzing = false;
        _submittedToAdmin = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Report (${result.id} • ${_localizedUrgency(result.urgency.title)}) sent live to the Crisis Center and Firebase!',
              'İhbar (${result.id} • ${result.urgency.title}) Kriz Masası ekranına ve Firebase\'e canlı olarak iletildi!',
            ),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool> _tryQueueOfflineReport(String text) async {
    try {
      await _queueOfflineReport(text);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'Could not save to the SMS queue: $error',
                'SMS kuyruğuna kaydedilemedi: $error',
              ),
            ),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _queueOfflineReport(String text) async {
    final user = AuthService().currentUser;
    if (user == null) throw StateError('Oturum açmış kullanıcı bulunamadı.');

    SafetyStatusReport? report;
    var location = _locationController.text.trim();
    try {
      final currentLocation = await LocationService.getCurrentLocation();
      report = SafetyStatusReport(
        reportedAt: DateTime.now(),
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
      );
    } catch (error) {
      location = '$location (GPS alınamadı: $error)';
    }

    final draft = await SafetySmsService.queueEmergencyMessage(
      userId: user.uid,
      message: SafetySmsService.composeEmergencyMessage(
        citizenName: user.name,
        reportText: text,
        location: location,
        report: report,
      ),
    );
    if (mounted) {
      setState(() => _pendingSmsDrafts = [draft, ..._pendingSmsDrafts]);
    }
  }

  Future<void> _openPendingSms(SafetySmsDraft draft) async {
    try {
      final launched = await SafetySmsService.openQueuedDraft(draft);
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'Could not open the SMS app; the draft remains queued.',
                'SMS uygulaması açılamadı; taslak kuyrukta tutuluyor.',
              ),
            ),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'The SMS app is open. Select a recipient and tap Send.',
              'SMS uygulaması açıldı. Alıcıyı seçip Gönder’e basmanız gerekir.',
            ),
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Could not open SMS draft: $error',
              'SMS taslağı açılamadı: $error',
            ),
          ),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  Future<void> _removePendingSms(SafetySmsDraft draft) async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      await SafetySmsService.removeFromQueue(
        userId: user.uid,
        draftId: draft.id,
      );
      if (mounted) {
        setState(
          () =>
              _pendingSmsDrafts.removeWhere((queued) => queued.id == draft.id),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Could not update SMS queue: $error',
              'SMS kuyruğu güncellenemedi: $error',
            ),
          ),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  void _simulateVoiceInput() {
    setState(() {
      _isListening = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'Voice command simulation: detecting “I need help”…',
            'Ses komutu simülasyonu: “Yardım İstiyorum” algılanıyor…',
          ),
        ),
        backgroundColor: AppColors.primaryBlue,
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        setState(() {
          _isListening = false;
          _reportController.text = context.t(
            'I need help. I am trapped under rubble; send an emergency team to my location.',
            'Yardım istiyorum. Enkaz altında mahsur kaldım, konumuma acil ekip gönderin.',
          );
        });
        await _vibrateForVoiceCommand();
        _runAiClassification(_reportController.text);
      }
    });
  }

  Future<void> _vibrateForVoiceCommand() async {
    try {
      await HapticFeedback.vibrate();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'Could not start vibration alert: $error',
              'Titreşim uyarısı başlatılamadı: $error',
            ),
          ),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Title & 112
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              color: AppColors.primaryBlue,
                              size: 26,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                context.t(
                                  'Meta AI Triage Station',
                                  'Meta AI Triage İstasyonu',
                                ),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.t(
                            'Live disaster report triage & transmission with Meta Llama 3 (${MetaAiConfig.maskedKey})',
                            'Meta Llama 3 (${MetaAiConfig.maskedKey}) ile Anlık Afet İhbar & Canlı Aktarım',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Emergency112Button(compact: true),
                ],
              ),
              const SizedBox(height: 20),

              // Interactive Input Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        'Enter a Report or Request for Help',
                        'İhbar veya Yardım Mesajınızı Girin',
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(
                        'Your report is triaged by Meta Llama 3 and sent directly to the Admin Crisis Center live feed.',
                        'Gönderdiğiniz ihbar Meta Llama 3 tarafından aciliyetine göre sınıflandırılır ve doğrudan Admin Kriz Masası canlı akışına düşer.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick Scenario Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildScenarioChip(
                          context.t(
                            '🏚️ Rubble & Collapse',
                            '🏚️ Enkaz & Çökme',
                          ),
                          _sampleScenarioText(0),
                        ),
                        _buildScenarioChip(
                          context.t(
                            '🩸 Heart & Medication Emergency',
                            '🩸 Kalp & İlaç Acil',
                          ),
                          _sampleScenarioText(1),
                        ),
                        _buildScenarioChip(
                          context.t(
                            '💧 Water & Infant Formula',
                            '💧 Su & Bebek Maması',
                          ),
                          _sampleScenarioText(2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Location Input
                    TextField(
                      controller: _locationController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: context.t(
                          'Location / Street Address',
                          'Konum / Açık Adres',
                        ),
                        prefixIcon: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.emergencyRed,
                          size: 18,
                        ),
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Text Area
                    TextField(
                      controller: _reportController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                      decoration: InputDecoration(
                        hintText: context.t(
                          'Example: There is a fire on the 4th floor and two elderly people cannot evacuate...',
                          'Örn: 4. katta yangın çıktı ve 2 yaşlı insan tahliye edilemiyor...',
                        ),
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Voice & Analyze Buttons
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _simulateVoiceInput,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            side: BorderSide(
                              color: _isListening
                                  ? AppColors.emergencyRed
                                  : AppColors.primaryBlue,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            _isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: _isListening
                                ? AppColors.emergencyRed
                                : AppColors.primaryBlue,
                            size: 20,
                          ),
                          label: Text(
                            _isListening
                                ? context.t('Listening...', 'Dinleniyor...')
                                : context.t('Voice Report', 'Sesli İhbar'),
                            style: TextStyle(
                              color: _isListening
                                  ? AppColors.emergencyRed
                                  : AppColors.primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAnalyzing
                                ? null
                                : () => _runAiClassification(
                                    _reportController.text,
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isAnalyzing
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_and_archive_rounded,
                                    size: 19,
                                  ),
                            label: Text(
                              _isAnalyzing
                                  ? context.t(
                                      'Analyzing...',
                                      'Analiz Ediliyor...',
                                    )
                                  : context.t(
                                      'Classify & Send to Crisis Center',
                                      'Sınıflandır & Kriz Masasına İlet',
                                    ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              if (_pendingSmsDrafts.isNotEmpty) ...[
                Card(
                  color: const Color(0xFFFFF8E1),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(
                            'Offline SMS Queue (${_pendingSmsDrafts.length})',
                            'Çevrimdışı SMS kuyruğu (${_pendingSmsDrafts.length})',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          SafetySmsService.emergencySmsTarget.isEmpty
                              ? context.t(
                                  'The 112/AFAD SMS recipient is not configured. Select a recipient in the SMS app and tap Send.',
                                  '112/AFAD SMS hedefi yapılandırılmadı. Taslak alıcı olmadan açılır; mesajı göndermek için alıcı seçip Gönder’e basın.',
                                )
                              : context.t(
                                  'The SMS draft has not been sent. Tap Send in your SMS app to send it.',
                                  'SMS taslağı henüz gönderilmedi. Göndermek için SMS uygulamasında Gönder’e basın.',
                                ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        ..._pendingSmsDrafts.map(
                          (draft) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.sms_outlined,
                              color: AppColors.warning,
                            ),
                            title: Text(
                              draft.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              draft.createdAt.toLocal().toString(),
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: context.t(
                                    'Open SMS draft',
                                    'SMS taslağını aç',
                                  ),
                                  onPressed: () => _openPendingSms(draft),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                ),
                                IconButton(
                                  tooltip: context.t(
                                    'Mark as sent',
                                    'Gönderildi olarak işaretle',
                                  ),
                                  onPressed: () => _removePendingSms(draft),
                                  icon: const Icon(Icons.check_circle_outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // AI Diagnostic Output Card
              if (_activeResult != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.t(
                        'Meta Llama 3 Triage Report',
                        'Meta Llama 3 Triage Sonuç Raporu',
                      ),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_submittedToAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_done_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              context.t(
                                'Sent to Crisis Center',
                                'Kriz Masasına İletildi',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAiResultCard(_activeResult!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _sampleScenarioText(int index) {
    if (!LanguageService.instance.isEnglish) {
      return AiTriageResult.sampleScenarios[index].rawText;
    }
    return switch (index) {
      0 =>
        'A building has collapsed and a family is calling for help inside. There is also a smell of gas.',
      1 =>
        'Our 72-year-old grandfather has heart disease and needs urgent medication and oxygen.',
      _ =>
        'The tent camp has run out of clean drinking water and urgently needs formula for 40 babies.',
    };
  }

  String _localizedUrgency(String title) => switch (title) {
    'KRİTİK' => context.t('CRITICAL', title),
    'YÜKSEK' => context.t('HIGH', title),
    'ORTA' => context.t('MEDIUM', title),
    'DÜŞÜK' => context.t('LOW', title),
    _ => title,
  };

  String _localizedTriageCategory(String category) => switch (category) {
    'ENKAZ & ARAMA KURTARMA' => context.t(
      'RUBBLE & SEARCH AND RESCUE',
      category,
    ),
    'SAĞLIK & MEDİKAL' => context.t('HEALTH & MEDICAL', category),
    'SU & TEMEL YAŞAM' => context.t('WATER & ESSENTIALS', category),
    'GENEL İHBAR' => context.t('GENERAL REPORT', category),
    _ => category,
  };

  String _localizedTriageLocation(String location) => switch (location) {
    'Şehitkamil, Osmangazi Mah. No: 18' => context.t(
      'Şehitkamil, Osmangazi Neighborhood, No. 18',
      location,
    ),
    'Şehitkamil, Osmangazi Mah. No: 14' => context.t(
      'Şehitkamil, Osmangazi Neighborhood, No. 14',
      location,
    ),
    'İstasyon Cad. Sahra Bölgesi B Blok' => context.t(
      'İstasyon Street, Field Hospital Area, Block B',
      location,
    ),
    'Atatürk Parkı 2. Çadır Alanı' => context.t(
      'Atatürk Park Tent Area No. 2',
      location,
    ),
    _ => location,
  };

  String _localizedRecommendedAction(String action) => switch (action) {
    'Acil Arama Kurtarma (AKUT/AFAD) ve Doğalgaz Acil Ekibi ivedilikle yönlendirilmeli. Gaz patlaması riski nedeniyle ateş yakılmamalı.' =>
      context.t(
        'Dispatch search-and-rescue (AKUT/AFAD) and the natural gas emergency team immediately. Do not use flames due to the risk of a gas explosion.',
        action,
      ),
    'En yakın Sahra Hastanesi mobil sağlık timi yönlendirildi. Hastayı sakin ve yarı oturur pozisyonda tutunuz.' =>
      context.t(
        'The nearest field hospital mobile medical team has been dispatched. Keep the patient calm and semi-seated.',
        action,
      ),
    'En yakın yardım konvoyuna (Adana Lojistik sevkiyatı) rota güncellenerek 200 koli su ve bebek maması sevk emri verildi.' =>
      context.t(
        'The nearest aid convoy has been rerouted and ordered to deliver 200 cartons of water and infant formula.',
        action,
      ),
    _ => action,
  };

  String _localizedResource(String resource) => switch (resource) {
    'Ses Dinleme Cihazı' => context.t('Acoustic Listening Device', resource),
    'K9 Kurtarma Köpeği' => context.t('K9 Search-and-Rescue Dog', resource),
    'Gaz Dedektörü' => context.t('Gas Detector', resource),
    'Hidrolik Kesici' => context.t('Hydraulic Cutter', resource),
    'Taşınabilir Oksijen' => context.t('Portable Oxygen', resource),
    'Acil Kardiyo İlaçları' => context.t(
      'Emergency Cardiac Medication',
      resource,
    ),
    'Mobil Sağlık Ekibi' => context.t('Mobile Medical Team', resource),
    '0.5L İçme Suyu' => context.t('0.5 L Drinking Water', resource),
    'Bebek Maması (0-12 Ay)' => context.t(
      'Infant Formula (0–12 months)',
      resource,
    ),
    'Hijyen Kiti' => context.t('Hygiene Kit', resource),
    _ => resource,
  };

  String _localizedEta(String eta) => switch (eta) {
    'Altın İlk 4 Saat İçinde Müdahale Şart' => context.t(
      'Response required within the critical first 4 hours',
      eta,
    ),
    'Maksimum 30 Dakika' => context.t('Within 30 minutes', eta),
    '2-4 Saat İçinde İkmal' => context.t('Resupply within 2–4 hours', eta),
    _ => eta,
  };

  Widget _buildScenarioChip(String label, String text) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: const BorderSide(color: AppColors.border),
      onPressed: () {
        _reportController.text = text;
        _runAiClassification(text);
      },
    );
  }

  Widget _buildAiResultCard(AiTriageResult result) {
    final urgency = result.urgency;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: urgency.color.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: urgency.color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: urgency.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(urgency.icon, size: 16, color: urgency.color),
                    const SizedBox(width: 6),
                    Text(
                      '${_localizedUrgency(urgency.title)} ${context.t('URGENCY', 'ACİLİYET')} (%${(result.confidenceScore * 100).round()})',
                      style: TextStyle(
                        color: urgency.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.id,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _localizedTriageCategory(result.category),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.pin_drop_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _localizedTriageLocation(result.location),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    SizedBox(width: 6),
                    Text(
                      context.t(
                        'AI Response & Safety Instructions:',
                        'Yapay Zeka Müdahale & Güvenlik Direktifi:',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _localizedRecommendedAction(result.recommendedAction),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t(
              'Required Equipment & Resources:',
              'Sevk Edilmesi Gereken Ekipman & Kaynaklar:',
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: result.requiredResources.map((res) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _localizedResource(res),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _localizedEta(result.etaWindow),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.shouldTrigger112)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.t('112 Dispatch Active', '112 Dispatch Aktif'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emergencyRed,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
