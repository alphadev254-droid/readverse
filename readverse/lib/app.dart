import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/document_provider.dart';
import 'providers/library_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/reader_provider.dart';
import 'providers/bookmark_provider.dart';
import 'providers/highlight_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/read_aloud_provider.dart';
import 'providers/recording_provider.dart';
import 'config/app_theme.dart';
import 'routes/app_router.dart';

class ReadVerseApp extends StatefulWidget {
  const ReadVerseApp({super.key});

  @override
  State<ReadVerseApp> createState() => _ReadVerseAppState();
}

class _ReadVerseAppState extends State<ReadVerseApp> {
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ReaderProvider()),
        ChangeNotifierProvider(create: (_) => ReadAloudProvider()),
        // RecordingProvider shares the TTS engine from ReadAloudProvider
        ChangeNotifierProxyProvider<ReadAloudProvider, RecordingProvider>(
          create: (_) => RecordingProvider(),
          update: (_, readAloud, recording) {
            recording!.setTts(readAloud.tts);
            return recording;
          },
        ),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => HighlightProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final router = createRouter(_authProvider);
          return MaterialApp.router(
            title: 'ReadVerse',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(themeProvider.accentColor),
            darkTheme: AppTheme.darkTheme(themeProvider.accentColor),
            themeMode: themeProvider.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
