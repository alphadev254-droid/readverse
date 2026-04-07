class AppConstants {
  AppConstants._();

  static const appName = 'ReadVerse';
  static const appVersion = '1.0.0';
  static const baseUrl = 'https://api.readverse.com/v1';

  // Hive box names
  static const documentsBox = 'documents_box';
  static const libraryBox = 'library_box';
  static const favoritesBox = 'favorites_box';
  static const bookmarksBox = 'bookmarks_box';
  static const highlightsBox = 'highlights_box';
  static const settingsBox = 'settings_box';

  // SharedPreferences keys
  static const authTokenKey = 'auth_token';
  static const userDataKey = 'user_data';
  static const themeModeKey = 'theme_mode';
  static const accentColorKey = 'accent_color';
  static const fontSizeKey = 'font_size';
  static const fontFamilyKey = 'font_family';
  static const lineHeightKey = 'line_height';
  static const readingBgKey = 'reading_bg';
  static const ttsSpeedKey = 'tts_speed';
  static const ttsVoiceKey = 'tts_voice';

  // File constraints
  static const maxFileSizeMB = 50;
  static const allowedExtensions = ['pdf', 'epub', 'docx', 'txt', 'md'];

  // Reading
  static const autoSaveIntervalSeconds = 5;
  static const defaultFontSize = 16.0;
  static const minFontSize = 12.0;
  static const maxFontSize = 32.0;
  static const defaultTtsSpeed = 1.0;
  static const minTtsSpeed = 0.5;
  static const maxTtsSpeed = 2.0;

  static const ttsLanguages = [
    'en-US',
    'es-ES',
    'fr-FR',
    'de-DE',
    'it-IT',
    'pt-BR',
    'ja-JP',
    'zh-CN',
    'ar-SA',
    'hi-IN',
  ];

  static const ttsLanguageNames = {
    'en-US': 'English (US)',
    'es-ES': 'Spanish',
    'fr-FR': 'French',
    'de-DE': 'German',
    'it-IT': 'Italian',
    'pt-BR': 'Portuguese',
    'ja-JP': 'Japanese',
    'zh-CN': 'Chinese',
    'ar-SA': 'Arabic',
    'hi-IN': 'Hindi',
  };
}
