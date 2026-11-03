class MetaAiConfig {
  static const String apiKey = String.fromEnvironment(
    'META_API_KEY',
    defaultValue: 'LLM_1420775716376133_sxB1vXIF74rVhTvo68O9F9faXpE',
  );

  static const String defaultModel = 'Meta-Llama-3-70B-Instruct';

  static bool get hasValidKey => apiKey.trim().isNotEmpty;

  static String get maskedKey {
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 6)}...${apiKey.substring(apiKey.length - 4)}';
  }
}

