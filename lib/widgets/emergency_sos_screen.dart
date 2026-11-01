import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isWhistlePlaying = false;
  bool _isFlashEnabled = false;
  String? _soundError;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(_startWhistle());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showFlashSafetyNotice());
    });
  }

  Future<void> _showFlashSafetyNotice() async {
    final enableFlash = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Yanıp sönen ışık uyarısı'),
          content: const Text(
            'Epilepsi nöbeti geçiren veya yanıp sönen ışığa hassasiyeti olan '
            'kişiler ekran flaşörünü kullanmamalıdır. Işığı kapalı tutabilir '
            'veya daha sonra açabilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('IŞIĞI KAPALI TUT'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('IŞIĞI AÇ'),
            ),
          ],
        ),
      ),
    );

    if (mounted) _setFlashEnabled(enableFlash ?? false);
  }

  void _setFlashEnabled(bool enabled) {
    setState(() => _isFlashEnabled = enabled);
    if (enabled) {
      _flashController.repeat(reverse: true);
    } else {
      _flashController
        ..stop()
        ..value = 0;
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

  @override
  void dispose() {
    _flashController.dispose();
    unawaited(_audioPlayer.dispose());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _flashController,
        builder: (context, _) {
          final isWhite = _isFlashEnabled && _flashController.value >= 0.5;
          final foreground = isWhite ? Colors.black : Colors.white;
          return ColoredBox(
            color: _isFlashEnabled && isWhite
                ? Colors.white
                : const Color(0xFFD50000),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sos_rounded, size: 96, color: foreground),
                      const SizedBox(height: 16),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'YARDIM BEKLIYORUM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => _setFlashEnabled(!_isFlashEnabled),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: foreground,
                          side: BorderSide(color: foreground, width: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(
                          _isFlashEnabled
                              ? Icons.flash_off_rounded
                              : Icons.flash_on_rounded,
                        ),
                        label: Text(
                          _isFlashEnabled ? 'IŞIĞI KAPAT' : 'IŞIĞI AÇ',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isWhistlePlaying
                            ? _stopWhistle
                            : _startWhistle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: foreground,
                          side: BorderSide(color: foreground, width: 2),
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
                      if (_soundError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _soundError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: foreground, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Yanıp sönen ışığa hassasiyetiniz varsa flaşörü kapalı tutun.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: foreground, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        style: FilledButton.styleFrom(
                          backgroundColor: foreground,
                          foregroundColor: isWhite
                              ? const Color(0xFFD50000)
                              : Colors.black,
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
        },
      ),
    );
  }
}
