/// Google Gemini API Configuration
///
/// To get a free API Key:
/// 1. Go to https://aistudio.google.com/app/apikey
/// 2. Sign in with mobdev2026chn@gmail.com
/// 3. Click "Create API Key" and paste it below inside `defaultKey`.
class GeminiConfig {
  static const String _defaultKey = ''; // Set GEMINI_API_KEY env var or paste your AIzaSy... key here (never commit real keys)

  static String get apiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) return envKey;
    return _defaultKey;
  }
}
