class MetaAiConfig {
  static const String apiKey = String.fromEnvironment(
    'META_API_KEY',
    defaultValue: 'LLM_28824693343848975_VTvZbn3AH0-JxbKFc415zujrBzo',
  );

  static const String defaultModel = 'Meta-Llama-3-70B-Instruct';

  static bool get hasValidKey => apiKey.trim().isNotEmpty;

  static String get maskedKey {
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 6)}...${apiKey.substring(apiKey.length - 4)}';
  }
}

