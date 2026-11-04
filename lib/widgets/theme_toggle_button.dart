import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final isDarkMode = ThemeService.instance.themeMode == ThemeMode.dark;
        final label = isDarkMode
            ? context.t('Light mode', 'Açık mod')
            : context.t('Dark mode', 'Koyu mod');

        return Semantics(
          button: true,
          label: label,
          child: FilledButton.icon(
            onPressed: ThemeService.instance.toggleThemeMode,
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 18,
            ),
            label: Text(label),
            style: FilledButton.styleFrom(
              elevation: 4,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: const StadiumBorder(),
            ),
          ),
        );
      },
    );
  }
}
