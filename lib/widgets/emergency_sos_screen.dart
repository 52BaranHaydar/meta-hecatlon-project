import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

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
  bool _isWhistlePlaying = true;
  String? _soundError;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..repeat(reverse: true);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    unawaited(_startWhistle());
  }

  Future<void> _startWhistle() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1);
      await _audioPlayer.play(BytesSource(_createWhistleWave()));
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
          _soundError = 'Sesli düdük başlatılamadı: $error';
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
        setState(() => _soundError = 'Düdük durdurulamadı: $error');
      }
    }
  }

  Uint8List _createWhistleWave() {
    const sampleRate = 22050;
    const durationSeconds = 1.8;
    final sampleCount = (sampleRate * durationSeconds).round();
    final dataSize = sampleCount * 2;
    final wave = ByteData(44 + dataSize);

    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        wave.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeAscii(0, 'RIFF');
    wave.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    wave.setUint32(16, 16, Endian.little);
    wave.setUint16(20, 1, Endian.little);
    wave.setUint16(22, 1, Endian.little);
    wave.setUint32(24, sampleRate, Endian.little);
    wave.setUint32(28, sampleRate * 2, Endian.little);
    wave.setUint16(32, 2, Endian.little);
    wave.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    wave.setUint32(40, dataSize, Endian.little);

    for (var index = 0; index < sampleCount; index++) {
      final time = index / sampleRate;
      final pulsePosition = time % 0.9;
      var envelope = 0.0;
      if (pulsePosition < 0.68) {
        envelope = min(1, pulsePosition / 0.025) *
            min(1, (0.68 - pulsePosition) / 0.025);
      }
      final frequency = 1950 + 250 * sin(2 * pi * 5 * time);
      final sample = (sin(2 * pi * frequency * time) * envelope * 28000)
          .round()
          .clamp(-32768, 32767)
          .toInt();
      wave.setInt16(44 + index * 2, sample, Endian.little);
    }
    return wave.buffer.asUint8List();
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
          final isWhite = _flashController.value >= 0.5;
          final foreground = isWhite ? Colors.black : Colors.white;
          return ColoredBox(
            color: isWhite ? Colors.white : const Color(0xFFD50000),
            child: SafeArea(
              child: SizedBox.expand(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                        _isWhistlePlaying ? 'DÜDÜĞÜ DURDUR' : 'DÜDÜĞÜ ÇAL',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_soundError != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _soundError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: foreground, fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Yanıp sönen ışığa hassasiyetiniz varsa ekran flaşörünü kapatın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: foreground, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      child: const Text(
                        'SOS FLAŞÖRÜNÜ KAPAT',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
