import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recording_provider.dart';
import '../../services/file_service.dart';
import '../../utils/extensions.dart';
import '../../widgets/global_mini_player.dart';
import '../../widgets/online_tts_bar.dart';
import '../recordings/recordings_screen.dart';
import 'widgets/document_grid.dart';
import 'widgets/search_bar_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    // 4 tabs: All Documents | My Library | Favorites | Recordings
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<DocumentProvider>().loadDocuments(),
      context.read<LibraryProvider>().loadLibrary(),
      context.read<FavoritesProvider>().loadFavorites(),
    ]);
  }

  Future<void> _importDocument() async {
    setState(() => _isImporting = true);
    try {
      final file = await FileService.pickDocument();
      if (file == null) return;
      if (!mounted) return;
      final doc = await context
          .read<DocumentProvider>()
          .addDocument(file.path!, file.name);
      if (!mounted) return;
      if (doc != null) {
        context.showSnackBar('"${doc.name}" imported successfully',
            isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
            e.toString().replaceAll('Exception: ', ''),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    // Hide import FAB on Recordings tab
    final showFab = _tabController.index != 3;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('ReadVerse',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          _buildAvatarButton(context),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}), // refresh FAB visibility
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'All Documents'),
            Tab(text: 'My Library'),
            Tab(text: 'Favorites'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, size: 14),
                  SizedBox(width: 4),
                  Text('Recordings'),
                ],
              ),
            ),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Global mini-players (show when TTS is active)
          const GlobalMiniPlayer(),
          const OnlineTtsBar(isGlobal: true),
          
          // Hide search bar on Recordings tab
          if (_tabController.index != 3) ...[
            const HomeSearchBar(),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AllDocumentsTab(onImport: _importDocument),
                const _LibraryTab(),
                const _FavoritesTab(),
                const RecordingsScreen(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _isImporting ? null : _importDocument,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add),
              label: Text(_isImporting ? 'Importing...' : 'Import'),
            )
          : null,
    );
  }

  Widget _buildAvatarButton(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initials = user?.name.isNotEmpty == true
        ? user!.name.substring(0, 1).toUpperCase()
        : 'U';
    return GestureDetector(
      onTap: () => context.push('/settings'),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: context.colorScheme.primaryContainer,
        child: Text(initials,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.colorScheme.onPrimaryContainer)),
      ),
    );
  }
}

class _AllDocumentsTab extends StatelessWidget {
  final VoidCallback onImport;
  const _AllDocumentsTab({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (_, provider, __) => DocumentGrid(
        documents: provider.allDocuments,
        isLoading: provider.isLoading,
        emptyTitle: 'No Documents Yet',
        emptySubtitle: 'Import your first PDF or EPUB to start reading',
        onAddDocument: onImport,
        onRefresh: provider.loadDocuments,
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer3<DocumentProvider, LibraryProvider, RecordingProvider>(
      builder: (_, docProvider, libProvider, recProvider, __) {
        final docs = libProvider.getLibraryDocuments(docProvider.allDocuments);
        final recs = recProvider.recordings
            .where((r) => recProvider.isInLibrary(r.id))
            .toList();

        return Column(
          children: [
            if (recs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recordings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              ...recs.map((r) => _RecordingMiniCard(recording: r, provider: recProvider, isLibrary: true)),
              const Divider(height: 16),
            ],
            Expanded(
              child: docs.isEmpty
                  ? (recs.isEmpty
                      ? DocumentGrid(
                          documents: const [],
                          isLoading: docProvider.isLoading,
                          emptyTitle: 'Library is Empty',
                          emptySubtitle: 'Add documents or recordings to your library for quick access',
                          onRefresh: docProvider.loadDocuments,
                        )
                      : const SizedBox.shrink())
                  : DocumentGrid(
                      documents: docs,
                      isLoading: docProvider.isLoading,
                      emptyTitle: 'Library is Empty',
                      emptySubtitle: 'Add documents or recordings to your library for quick access',
                      onRefresh: docProvider.loadDocuments,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer3<DocumentProvider, FavoritesProvider, RecordingProvider>(
      builder: (_, docProvider, favProvider, recProvider, __) {
        final docs = favProvider.getFavoriteDocuments(docProvider.allDocuments);
        final recs = recProvider.recordings
            .where((r) => recProvider.isFavorite(r.id))
            .toList();

        return Column(
          children: [
            if (recs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recordings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              ...recs.map((r) => _RecordingMiniCard(recording: r, provider: recProvider)),
              const Divider(height: 16),
            ],
            Expanded(
              child: docs.isEmpty
                  ? (recs.isEmpty
                      ? DocumentGrid(
                          documents: const [],
                          isLoading: docProvider.isLoading,
                          emptyTitle: 'No Favorites Yet',
                          emptySubtitle: 'Tap the heart icon on any document or recording to add it here',
                          onRefresh: docProvider.loadDocuments,
                        )
                      : const SizedBox.shrink())
                  : DocumentGrid(
                      documents: docs,
                      isLoading: docProvider.isLoading,
                      emptyTitle: 'No Favorites Yet',
                      emptySubtitle: 'Tap the heart icon on any document or recording to add it here',
                      onRefresh: docProvider.loadDocuments,
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact recording card for Favourites/Library tabs
class _RecordingMiniCard extends StatelessWidget {
  final dynamic recording;
  final RecordingProvider provider;
  /// If true, shows "remove from library" icon; if false, shows "unfavourite"
  final bool isLibrary;
  const _RecordingMiniCard({
    required this.recording,
    required this.provider,
    this.isLibrary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final isActive = provider.activeRecordingId == recording.id;
    final isPlaying = isActive && provider.state == RecordingState.playing;
    final isPaused = isActive && provider.state == RecordingState.playerPaused;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isActive ? cs.primary : cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.graphic_eq : Icons.mic,
                    size: 18,
                    color: isActive ? cs.onPrimary : cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recording.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        '${recording.formattedDuration}  •  ${recording.formattedSize}',
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                // Unfavourite / remove from library
                IconButton(
                  icon: Icon(
                    isLibrary ? Icons.bookmark_remove_outlined : Icons.favorite,
                    size: 20,
                    color: isLibrary ? cs.onSurface.withValues(alpha: 0.5) : Colors.red,
                  ),
                  onPressed: () => isLibrary
                      ? provider.toggleLibrary(recording.id)
                      : provider.toggleFavorite(recording.id),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),

            // Progress bar when active
            if (isActive) ...[
              const SizedBox(height: 8),
              StreamBuilder<Duration>(
                stream: provider.positionStream,
                builder: (_, posSnap) => StreamBuilder<Duration?>(
                  stream: provider.durationStream,
                  builder: (_, durSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final dur = durSnap.data ?? Duration.zero;
                    final frac = dur.inMilliseconds > 0
                        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0;
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: cs.primary,
                            inactiveTrackColor: cs.surfaceContainerHighest,
                            thumbColor: cs.primary,
                          ),
                          child: Slider(
                            value: frac,
                            onChanged: dur.inMilliseconds > 0
                                ? (v) => provider.seekTo(Duration(milliseconds: (v * dur.inMilliseconds).round()))
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Text(_fmt(pos), style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
                              const Spacer(),
                              Text(_fmt(dur), style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],

            // Controls
            const SizedBox(height: 6),
            Row(
              children: [
                // Play/Pause/Resume
                FilledButton.icon(
                  onPressed: () {
                    if (isPlaying) {
                      provider.pausePlayback();
                    } else if (isPaused) {
                      provider.resumePlayback();
                    } else {
                      provider.playRecording(recording);
                    }
                  },
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 16,
                  ),
                  label: Text(isPlaying ? 'Pause' : isPaused ? 'Resume' : 'Play'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: provider.stopPlayback,
                    icon: const Icon(Icons.stop_rounded, size: 16),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Speed chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                          final sel = (provider.playbackSpeed - s).abs() < 0.01;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: GestureDetector(
                              onTap: () => provider.setPlaybackSpeed(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: sel ? cs.primary : cs.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${s}x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: sel ? cs.onPrimary : cs.primary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
