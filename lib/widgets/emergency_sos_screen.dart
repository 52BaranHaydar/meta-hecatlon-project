import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart';

import '../services/auth_service.dart';
import '../services/safety_circle_service.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _morseTimer;
  List<_MorseStep> _morsePattern = const [];
  int _morseStepIndex = 0;
  bool _isWhistlePlaying = false;
  bool _isTorchEnabled = false;
  bool _isVoiceCommandDetected = false;
  String? _soundError;
  String? _torchError;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(_startWhistle());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showFlashSafetyNotice());
    });
  }

  Future<void> _showFlashSafetyNotice() async {
    final enableTorch = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Fener ve titreşim uyarısı'),
          content: const Text(
            'SOS mors flaşı yanıp sönen arka kamera ışığını kullanır. '
            'Epilepsi nöbeti geçiren veya ışığa hassasiyeti olan kişiler '
            'feneri açmamalıdır. Dilerseniz yalnızca ses ve titreşim '
            'uyarısını kullanabilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('FENERİ KAPALI TUT'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('SOS FENERİNİ AÇ'),
            ),
          ],
        ),
      ),
    );

    if (mounted && enableTorch == true) {
      await _setTorchEnabled(true);
    }
  }

  List<_MorseStep> _createSosMorsePattern() {
    const dot = Duration(milliseconds: 180);
    const dash = Duration(milliseconds: 540);
    const pulseGap = Duration(milliseconds: 180);
    const letterGap = Duration(milliseconds: 720);
    const wordGap = Duration(milliseconds: 1400);
    const letters = ['...', '---', '...'];
    final pattern = <_MorseStep>[];

    for (final letter in letters) {
      for (var index = 0; index < letter.length; index++) {
        pattern.add(
          _MorseStep(
            lightOn: true,
            duration: letter[index] == '.' ? dot : dash,
          ),
        );
        pattern.add(
          _MorseStep(
            lightOn: false,
            duration: index == letter.length - 1 ? letterGap : pulseGap,
          ),
        );
      }
    }
    pattern.add(const _MorseStep(lightOn: false, duration: wordGap));
    return pattern;
  }

  Future<void> _setTorchEnabled(bool enabled) async {
    _morseTimer?.cancel();
    if (!enabled) {
      try {
        await TorchLight.disableTorch();
        if (mounted) {
          setState(() {
            _isTorchEnabled = false;
            _torchError = null;
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() => _torchError = 'Fener kapatılamadı: $error');
        }
      }
      return;
    }

    try {
      if (!await TorchLight.isTorchAvailable()) {
        throw StateError('Bu cihazda kamera feneri bulunamadı.');
      }
      if (!mounted) return;
      setState(() {
        _isTorchEnabled = true;
        _torchError = null;
        _morsePattern = _createSosMorsePattern();
        _morseStepIndex = 0;
      });
      await _playNextMorseStep();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isTorchEnabled = false;
        _torchError = 'SOS feneri başlatılamadı: $error';
      });
      try {
        await TorchLight.disableTorch();
      } catch (disableError) {
        debugPrint('SOS flashlight cleanup failed: $disableError');
      }
    }
  }

  Future<void> _playNextMorseStep() async {
    if (!mounted || !_isTorchEnabled || _morsePattern.isEmpty) return;
    final step = _morsePattern[_morseStepIndex];
    try {
      if (step.lightOn) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isTorchEnabled = false;
          _torchError = 'SOS flaş/titreşim döngüsü durdu: $error';
        });
      }
      return;
    }
    if (step.lightOn) {
      try {
        await HapticFeedback.selectionClick();
      } catch (error) {
        if (mounted) {
          setState(() => _torchError = 'Titreşim uyarısı başlatılamadı: $error');
        }
      }
    }

    _morseStepIndex = (_morseStepIndex + 1) % _morsePattern.length;
    _morseTimer = Timer(step.duration, () {
      unawaited(_playNextMorseStep());
    });
  }

  Future<void> _simulateVoiceCommand() async {
    setState(() => _isVoiceCommandDetected = true);
    String? vibrationError;
    unawaited(_publishHelpStatus());
    try {
      await HapticFeedback.vibrate();
    } catch (error) {
      vibrationError = 'Titreşim uyarısı başlatılamadı: $error';
    }
    await _setTorchEnabled(true);
    if (mounted && vibrationError != null) {
      setState(() => _torchError = vibrationError);
    }
  }

  Future<void> _publishHelpStatus() async {
    final user = AuthService().currentUser;
    if (user == null) {
      if (mounted) {
        setState(
          () => _statusMessage =
              'Yardım durumu canlı paylaşılmadı; kullanıcı oturumu yok.',
        );
      }
      return;
    }

    try {
      final recipientCount = await SafetyCircleService(user.uid).publishStatus(
        userId: user.uid,
        status: SafetyStatus.helpRequested,
      );
      if (mounted) {
        setState(
          () => _statusMessage = recipientCount == 0
              ? 'Yardım durumu kaydedilmedi: henüz daveti kabul eden yakın yok.'
              : 'Yardım durumu $recipientCount yakınla paylaşıldı.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _statusMessage = 'Canlı yardım bildirimi başarısız: $error');
      }
    }
  }

  Future<void> _startWhistle() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1);
      await _audioPlayer.play(AssetSource('emergency_siren.mp3'));
      if (mounted) {
        setState(() {
          _isWhistlePlaying = true;
          _soundError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isWhistlePlaying = false;
          _soundError = 'Siren sesi başlatılamadı: $error';
        });
      }
    }
  }

  Future<void> _stopWhistle() async {
    try {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isWhistlePlaying = false);
    } catch (error) {
      if (mounted) {
        setState(() => _soundError = 'Siren sesi durdurulamadı: $error');
      }
    }
  }

  Future<void> _disableTorchOnDispose() async {
    _morseTimer?.cancel();
    try {
      await TorchLight.disableTorch();
    } catch (error) {
      debugPrint('SOS flashlight cleanup failed: $error');
    }
  }

  @override
  void dispose() {
    _morseTimer?.cancel();
    unawaited(_disableTorchOnDispose());
    unawaited(_audioPlayer.dispose());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD50000),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sos_rounded, size: 96, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'YARDIM BEKLİYORUM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _setTorchEnabled(!_isTorchEnabled),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  icon: Icon(
                    _isTorchEnabled
                        ? Icons.flash_off_rounded
                        : Icons.flash_on_rounded,
                  ),
                  label: Text(
                    _isTorchEnabled ? 'SOS FENERİNİ KAPAT' : 'SOS FENERİNİ AÇ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isVoiceCommandDetected
                      ? null
                      : _simulateVoiceCommand,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(
                    _isVoiceCommandDetected
                        ? 'KOMUT ALGILANDI (SİMÜLASYON)'
                        : '“YARDIM İSTİYORUM” KOMUTUNU SİMÜLE ET',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isWhistlePlaying ? _stopWhistle : _startWhistle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  icon: Icon(
                    _isWhistlePlaying
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                  ),
                  label: Text(
                    _isWhistlePlaying ? 'SİRENİ DURDUR' : 'SİRENİ ÇAL',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_soundError != null ||
                    _torchError != null ||
                    _statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    [
                      _soundError,
                      _torchError,
                      _statusMessage,
                    ].whereType<String>().join('\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Sesli komut gerçek konuşma tanıma değildir; düğme simülasyonu '
                  'başlatır. SOS flaşında arka kamera feneri ve titreşim kullanılır. '
                  'Flaş hassasiyetiniz varsa feneri kapalı tutun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).popUntil((route) => route.isFirst),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFD50000),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text(
                    'ANA EKRANA DÖN',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MorseStep {
  final bool lightOn;
  final Duration duration;

  const _MorseStep({required this.lightOn, required this.duration});
}
