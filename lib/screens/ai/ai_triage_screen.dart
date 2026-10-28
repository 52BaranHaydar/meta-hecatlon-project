import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ai_triage_model.dart';
import '../../widgets/emergency_112_button.dart';

class AiTriageScreen extends StatefulWidget {
  const AiTriageScreen({super.key});

  @override
  State<AiTriageScreen> createState() => _AiTriageScreenState();
}

class _AiTriageScreenState extends State<AiTriageScreen> {
  final TextEditingController _reportController = TextEditingController();
  bool _isAnalyzing = false;
  bool _isListening = false;
  AiTriageResult? _activeResult;

  @override
  void initState() {
    super.initState();
    _activeResult = AiTriageResult.sampleScenarios.first;
    _reportController.text = _activeResult!.rawText;
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _runAiClassification(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
    });

    // Simulate Meta Llama 3 API inference
    await Future.delayed(const Duration(milliseconds: 900));

    final lower = text.toLowerCase();
    AiTriageResult result;

    if (lower.contains('enkaz') || lower.contains('ses') || lower.contains('çök') || lower.contains('altında') || lower.contains('gaz')) {
      result = AiTriageResult(
        id: 'AI-TR-${DateTime.now().millisecondsSinceEpoch % 1000}',
        rawText: text,
        category: 'ENKAZ & ARAMA KURTARMA',
        urgency: UrgencyLevel.critical,
        confidenceScore: 0.99,
        recommendedAction: 'Acil Arama Kurtarma timi ve dinleme ekibi tahsis edildi. Enkaz üstünde titreşim yaratılmamalı, doğalgaz vanaları kapatılmalıdır.',
        requiredResources: ['Ses Dinleme Ekipmanı', 'K9 Kurtarma Köpeği', 'Hidrolik Kaldırıcı', 'Termal Kamera'],
        shouldTrigger112: true,
        etaWindow: 'Altın İlk 4 Saat İçinde Acil Müdahale',
        timestamp: DateTime.now(),
      );
    } else if (lower.contains('hasta') || lower.contains('ilaç') || lower.contains('kan') || lower.contains('yaralı') || lower.contains('kalp')) {
      result = AiTriageResult(
        id: 'AI-TR-${DateTime.now().millisecondsSinceEpoch % 1000}',
        rawText: text,
        category: 'SAĞLIK & TRAVMA',
        urgency: UrgencyLevel.high,
        confidenceScore: 0.95,
        recommendedAction: 'Sahra hastanesine acil vaka kaydı düşürüldü. Hastanın solunum yolu açık tutulmalı, kanama varsa temiz bezle baskı uygulanmalıdır.',
        requiredResources: ['İlk Yardım Çantası', 'Ambulans Nakli', 'Temel Medikal İlaçlar'],
        shouldTrigger112: true,
        etaWindow: 'Maksimum 25 Dakika',
        timestamp: DateTime.now(),
      );
    } else {
      result = AiTriageResult(
        id: 'AI-TR-${DateTime.now().millisecondsSinceEpoch % 1000}',
        rawText: text,
        category: 'LOJİSTİK & TEMEL İHTİYAÇ',
        urgency: UrgencyLevel.medium,
        confidenceScore: 0.88,
        recommendedAction: 'İhtiyaç kriz masası stok modülüne yazıldı. En yakın dağıtım noktasından malzeme transferi planlandı.',
        requiredResources: ['İçme Suyu', 'Gıda Paketi', 'Isınma / Battaniye'],
        shouldTrigger112: false,
        etaWindow: '2-4 Saat Aralığında Teslimat',
        timestamp: DateTime.now(),
      );
    }

    if (mounted) {
      setState(() {
        _activeResult = result;
        _isAnalyzing = false;
      });
    }
  }

  void _simulateVoiceInput() {
    setState(() {
      _isListening = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ses dinleniyor... Meta AI konuşmayı metne aktarıyor (Whisper / Speech-to-Text)'),
        backgroundColor: AppColors.primaryBlue,
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isListening = false;
          _reportController.text = 'Apartmanın alt katında bir kişi sıkışmış durumda, lütfen acil vinç ve sağlık ekibi gönderin!';
        });
        _runAiClassification(_reportController.text);
      }
    });
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.psychology_rounded, color: AppColors.primaryBlue, size: 26),
                          SizedBox(width: 8),
                          Text(
                            'Meta AI Triage İstasyonu',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Meta Llama 3 ile Anlık Afet İhbar & Aciliyet Analizi',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const Emergency112Button(compact: true),
                ],
              ),
              const SizedBox(height: 24),

              // Interactive Input Card (Spacious, airy)
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
                    const Text(
                      'İhbar veya Yardım Mesajınızı Girin',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Durumu doğal bir dille yazabilir veya sesli olarak anlatabilirsiniz. Yapay zeka aciliyeti ve gerekli ekipleri otomatik belirler.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Quick Scenario Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildScenarioChip('🏚️ Enkaz & Çökme', AiTriageResult.sampleScenarios[0].rawText),
                        _buildScenarioChip('🩸 Kalp & İlaç Acil', AiTriageResult.sampleScenarios[1].rawText),
                        _buildScenarioChip('💧 Su & Bebek Maması', AiTriageResult.sampleScenarios[2].rawText),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Text Area
                    TextField(
                      controller: _reportController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'Örn: 4. katta yangın çıktı ve 2 yaşlı insan tahliye edilemiyor...',
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
                        // Voice Button
                        OutlinedButton.icon(
                          onPressed: _simulateVoiceInput,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            side: BorderSide(
                              color: _isListening ? AppColors.emergencyRed : AppColors.primaryBlue,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: Icon(
                            _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: _isListening ? AppColors.emergencyRed : AppColors.primaryBlue,
                            size: 20,
                          ),
                          label: Text(
                            _isListening ? 'Dinleniyor...' : 'Sesli İhbar',
                            style: TextStyle(
                              color: _isListening ? AppColors.emergencyRed : AppColors.primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Analyze Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAnalyzing
                                ? null
                                : () => _runAiClassification(_reportController.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: _isAnalyzing
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.auto_awesome_rounded, size: 20),
                            label: Text(
                              _isAnalyzing ? 'Analiz Ediliyor...' : 'Meta AI ile Sınıflandır',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // AI Diagnostic Output Card (Airy, prominent)
              if (_activeResult != null) ...[
                const Text(
                  'Meta Llama 3 Triage Sonuç Raporu',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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

  Widget _buildScenarioChip(String label, String text) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
        border: Border.all(color: urgency.color.withValues(alpha: 0.35), width: 1.5),
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
          // Urgency Header & Model Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: urgency.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(urgency.icon, size: 16, color: urgency.color),
                    const SizedBox(width: 6),
                    Text(
                      '${urgency.title} ACİLİYET (%${(result.confidenceScore * 100).round()})',
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Meta Llama 3',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category
          Text(
            result.category,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),

          // Recommended Action Box
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
                  children: const [
                    Icon(Icons.shield_outlined, size: 16, color: AppColors.primaryBlue),
                    SizedBox(width: 6),
                    Text(
                      'Yapay Zeka Müdahale & Güvenlik Direktifi:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.recommendedAction,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Required Resources (Lojistik & Kurtarma Talebi)
          const Text(
            'Sevk Edilmesi Gereken Ekipman & Kaynaklar:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: result.requiredResources.map((res) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(res, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Dispatch status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    result.etaWindow,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (result.shouldTrigger112)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '112 Dispatch Aktif',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emergencyRed),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
