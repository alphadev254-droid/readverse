import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/highlight_provider.dart';
import '../../providers/read_aloud_provider.dart';
import '../../providers/streaming_tts_provider.dart';
import '../../providers/recording_provider.dart';
import '../../models/document_model.dart';
import '../../utils/extensions.dart';
import '../../utils/doc_text_extractor.dart';
import '../../services/online_tts_service.dart';
import '../../widgets/read_aloud_bar.dart';
import '../../widgets/online_tts_bar.dart';
import '../../widgets/tts_mode_selector.dart';
import '../../widgets/online_voice_picker.dart';
import '../bookmarks/bookmarks_panel.dart';
import '../highlights/highlights_panel.dart';
import 'pdf_reader_controller.dart';
import '../../readers/document_reader_router.dart';
import 'widgets/reader_controls.dart';

class ReaderScreen extends StatefulWidget {
  final String docId;
  const ReaderScreen({super.key, required this.docId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  DocumentModel? _document;
  bool _loading = true;
  final PdfReaderController _pdfReaderController = PdfReaderController();
  // Captured once when scaffold is alive — never looked up across async gaps
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final doc = context.read<DocumentProvider>().getDocumentById(widget.docId);
    if (doc == null) {
      if (mounted) {
        context.showSnackBar('Document not found', isError: true);
        context.go('/home');
      }
      return;
    }
    _document = doc;
    if (!mounted) return;
    
    // Check if there's active playback for a different document
    final ttsProvider = context.read<ReadAloudProvider>();
    if (ttsProvider.isActive && ttsProvider.docId != doc.id) {
      // Stop playback of different document
      await ttsProvider.stop();
      await ttsProvider.clearPlaybackState();
    }
    
    // Check if there's active online TTS for a different document
    final streamingTtsProvider = context.read<StreamingTtsProvider>();
    if (streamingTtsProvider.isActive && streamingTtsProvider.docId != doc.id) {
      // Stop online TTS of different document
      await streamingTtsProvider.stop();
    }
    
    await context.read<ReaderProvider>().openDocument(doc);
    if (!mounted) return;
    await context.read<BookmarkProvider>().loadBookmarks(doc.id);
    if (!mounted) return;
    await context.read<HighlightProvider>().loadHighlights(doc.id);
    if (!mounted) return;
    // Extract text and load into ReadAloudProvider
    try {
      final text = await DocTextExtractor.extract(doc.filePath);
      if (!mounted) return;
      await context.read<ReadAloudProvider>().loadText(doc.id, text, docTitle: doc.name);
      
      // Load saved playback state if exists
      if (!mounted) return;
      await context.read<ReadAloudProvider>().loadPlaybackState();
    } catch (e) {
      debugPrint('[ReaderScreen] Text extraction failed: $e');
      if (mounted) {
        context.showSnackBar('Failed to extract text for audio features', isError: true);
      }
    }
    if (!mounted) return;
    // Capture messenger once — safe to use in all async callbacks
    _messenger = ScaffoldMessenger.of(context);
    // Wire synthesis-complete callback to show save dialog
    context.read<RecordingProvider>().onSynthesisComplete = () {
      if (mounted) _showSaveRecordingDialog();
    };
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _messenger = null;
    context.read<ReaderProvider>().closeDocument();
    context.read<RecordingProvider>().onSynthesisComplete = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BookmarksPanel(docId: widget.docId),
    );
  }

  void _showHighlights() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HighlightsPanel(
        docId: widget.docId,
        pdfReaderController: _pdfReaderController,
      ),
    );
  }

  void _showGenerateAudioDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _GenerateAudioDialog(docId: widget.docId),
    );
  }

  Future<void> _showTtsModeSelector(BuildContext context, ReadAloudProvider tts) async {
    await TtsModeSelector.show(
      context,
      onOfflineSelected: () async {
        // Stop online TTS if active
        final streamingTts = context.read<StreamingTtsProvider>();
        if (streamingTts.isActive) {
          await streamingTts.stop();
        }
        
        // Use existing offline TTS (device TTS)
        tts.play();
      },
      onOnlineSelected: () async {
        // Stop offline TTS if active
        if (tts.isActive) {
          await tts.stop();
        }
        
        // Show voice picker for online TTS
        final selectedVoice = await OnlineVoicePicker.show(context);
        
        if (selectedVoice != null && context.mounted) {
          // Initialize online TTS
          final streamingTts = context.read<StreamingTtsProvider>();
          final doc = _document;
          
          if (doc == null) return;
          
          // Extract full text
          String fullText = '';
          try {
            if (doc.isPdf) {
              fullText = await DocTextExtractor.extract(doc.filePath);
            } else if (doc.isDocx) {
              fullText = await DocTextExtractor.extract(doc.filePath);
            } else if (doc.isTxt || doc.isMd) {
              fullText = await File(doc.filePath).readAsString();
            } else if (doc.isEpub) {
              // TODO: Extract EPUB text
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('EPUB not yet supported for online TTS')),
                );
              }
              return;
            }
            
            if (fullText.isEmpty) {
              throw Exception('No text found in document');
            }
            
            // Initialize and start streaming TTS
            await streamingTts.initialize(
              docId: doc.id,
              docTitle: doc.name,
              fullText: fullText,
              voiceId: selectedVoice.id,
              speed: 1.0,
            );
            
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to start online TTS: $e')),
              );
            }
          }
        }
      },
    );
  }

  void _showSaveRecordingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _SaveRecordingDialog(messenger: _messenger),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _document == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final doc = _document!;

    return Consumer<ReaderProvider>(
      builder: (_, reader, __) {
        if (reader.immersiveMode) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Document viewer ──
              Positioned.fill(
                child: DocumentReaderRouter(
                  document: doc,
                  readerController: _pdfReaderController,
                ),
              ),

              // Forward page changes from slider/buttons to text-based readers
              // PDF handles this internally; txt/md/docx need the callback.
              if (!doc.isPdf)
                _PageChangeForwarder(
                  controller: _pdfReaderController,
                ),

              // ── 2. Single-tap detector to SHOW controls ──
              // HitTestBehavior.translucent means:
              //   - onTap fires for single taps
              //   - scroll/pan/drag events still pass through to SfPdfViewer
              if (!reader.showControls)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: reader.toggleControls,
                    child: const SizedBox.expand(),
                  ),
                ),

              // ── 3. Top bar (hidden via IgnorePointer when controls off) ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !reader.showControls,
                  child: AnimatedOpacity(
                    opacity: reader.showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _TopBar(
                      doc: doc,
                      reader: reader,
                      onBack: () => context.pop(),
                    ),
                  ),
                ),
              ),

              // ── 4. Bottom: ReadAloudBar + OnlineTtsBar + ReaderControls ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ReadAloudBar(),
                    const OnlineTtsBar(),
                    ReaderControls(pageText: doc.name),
                  ],
                ),
              ),

              // ── 4b. Synthesis progress overlay ──
              Consumer<RecordingProvider>(
                builder: (_, rec, __) {
                  if (!rec.isSynthesizing) return const SizedBox.shrink();
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _SynthesisProgressBanner(rec: rec),
                  );
                },
              ),

              // ── 5. Side FABs (hidden when controls off) ──
              Positioned(
                right: 12,
                bottom: 230,
                child: IgnorePointer(
                  ignoring: !reader.showControls,
                  child: AnimatedOpacity(
                    opacity: reader.showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FabButton(
                          icon: Icons.bookmark_outline,
                          tooltip: 'Bookmarks',
                          onTap: _showBookmarks,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 8),
                        // Generate Audio FAB — disabled while synthesizing
                        Consumer2<ReadAloudProvider, RecordingProvider>(
                          builder: (_, tts, rec, __) => _FabButton(
                            icon: Icons.audio_file_outlined,
                            tooltip: rec.isSynthesizing
                                ? 'Generating audio...'
                                : 'Generate Audio',
                            onTap: rec.isSynthesizing
                                ? () {}
                                : _showGenerateAudioDialog,
                            color: rec.isSynthesizing
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.primaryContainer,
                            iconColor: rec.isSynthesizing
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                                : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Read aloud FAB
                        Consumer<ReadAloudProvider>(
                          builder: (_, tts, __) => _FabButton(
                            icon: tts.isActive
                                ? Icons.record_voice_over
                                : Icons.record_voice_over_outlined,
                            tooltip: tts.isActive ? 'Stop Reading' : 'Read Aloud',
                            onTap: () async {
                              if (tts.state == ReadAloudState.idle) {
                                // Show mode selector
                                await _showTtsModeSelector(context, tts);
                              } else {
                                tts.stop();
                              }
                            },
                            color: tts.isActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.primaryContainer,
                            iconColor: tts.isActive
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Hide highlight FAB for DOCX — not supported
                        if (!doc.isDocx) ...[
                          _FabButton(
                            icon: Icons.highlight,
                            tooltip: 'Highlights',
                            onTap: _showHighlights,
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            iconColor: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(height: 8),
                        ],
                        _FabButton(
                          icon: reader.immersiveMode
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          tooltip: reader.immersiveMode
                              ? 'Exit Immersive'
                              : 'Immersive Mode',
                          onTap: reader.toggleImmersiveMode,
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          iconColor: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 6. Always-visible mini restore button (bottom-left) ──
              // Only shown when controls are hidden so user can always
              // bring the UI back without needing to know about tap-to-show.
              if (!reader.showControls)
                Positioned(
                  bottom: 24,
                  left: 16,
                  child: _RestoreButton(onTap: reader.toggleControls),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Always-visible restore button shown when controls are hidden
// ─────────────────────────────────────────────────────────────────────────────
class _RestoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RestoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Show controls',
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Show UI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final DocumentModel doc;
  final ReaderProvider reader;
  final VoidCallback onBack;

  const _TopBar({
    required this.doc,
    required this.reader,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface.withValues(alpha: 0.97),
            cs.surface.withValues(alpha: 0.0),
          ],
          stops: const [0.65, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                doc.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _BookmarkToggleButton(
                docId: doc.id, currentPage: reader.currentPage),
            _FavoriteToggleButton(docId: doc.id),
            _ReaderMenuButton(doc: doc),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB button
// ─────────────────────────────────────────────────────────────────────────────
class _FabButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  const _FabButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookmark toggle
// ─────────────────────────────────────────────────────────────────────────────
class _BookmarkToggleButton extends StatelessWidget {
  final String docId;
  final int currentPage;
  const _BookmarkToggleButton(
      {required this.docId, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarkProvider>(
      builder: (_, bookmarks, __) {
        final hasBookmark =
            bookmarks.bookmarks.any((b) => b.page == currentPage);
        return IconButton(
          icon: Icon(hasBookmark ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () {
            if (hasBookmark) {
              final b = bookmarks.bookmarks
                  .firstWhere((b) => b.page == currentPage);
              bookmarks.deleteBookmark(b.id);
              context.showSnackBar('Bookmark removed');
            } else {
              _showAddDialog(context);
            }
          },
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddBookmarkDialog(docId: docId, currentPage: currentPage),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Favorite toggle
// ─────────────────────────────────────────────────────────────────────────────
class _FavoriteToggleButton extends StatelessWidget {
  final String docId;
  const _FavoriteToggleButton({required this.docId});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (_, favs, __) {
        final isFav = favs.isFavorite(docId);
        return IconButton(
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.red : null,
          ),
          onPressed: () {
            favs.toggleFavorite(docId);
            context.showSnackBar(
              isFav ? 'Removed from favorites' : 'Added to favorites',
              isSuccess: !isFav,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Three-dot menu
// ─────────────────────────────────────────────────────────────────────────────
class _ReaderMenuButton extends StatelessWidget {
  final DocumentModel doc;
  const _ReaderMenuButton({required this.doc});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'library':
            context.read<LibraryProvider>().toggleLibrary(doc.id);
            context.showSnackBar(
              context.read<LibraryProvider>().isInLibrary(doc.id)
                  ? 'Added to library'
                  : 'Removed from library',
              isSuccess: true,
            );
            break;
          case 'details':
            context.push('/document-details/${doc.id}');
            break;
          case 'delete':
            _confirmDelete(context);
            break;
        }
      },
      itemBuilder: (ctx) {
        final lib = ctx.read<LibraryProvider>();
        return [
          PopupMenuItem(
            value: 'library',
            child: Row(children: [
              Icon(
                lib.isInLibrary(doc.id)
                    ? Icons.bookmark_remove
                    : Icons.bookmark_add_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(lib.isInLibrary(doc.id)
                  ? 'Remove from Library'
                  : 'Add to Library'),
            ]),
          ),
          const PopupMenuItem(
            value: 'details',
            child: Row(children: [
              Icon(Icons.info_outline, size: 18),
              SizedBox(width: 8),
              Text('Document Info'),
            ]),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ]),
          ),
        ];
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DocumentProvider>().deleteDocument(doc.id);
              context.go('/home');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Forwards page changes from the slider/buttons to text-based readers.
// Only fires when the page change came from a button/slider (setPage),
// NOT from scroll-driven updates (setScrollFraction).
// This prevents the forwarder from fighting the scroll with animateTo().
class _PageChangeForwarder extends StatefulWidget {
  final PdfReaderController controller;
  const _PageChangeForwarder({required this.controller});

  @override
  State<_PageChangeForwarder> createState() => _PageChangeForwarderState();
}

class _PageChangeForwarderState extends State<_PageChangeForwarder> {
  int _lastPage = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch lastSetPage (only updated by setPage, not setScrollFraction)
    final page = context.watch<ReaderProvider>().lastSetPage;
    if (_lastPage != 0 && page != _lastPage) {
      _lastPage = page;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.jumpToPage(page);
      });
    } else {
      _lastPage = page;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// Synthesis progress banner — shown at top while generating audio
// ─────────────────────────────────────────────────────────────────────────────
class _SynthesisProgressBanner extends StatelessWidget {
  final RecordingProvider rec;
  const _SynthesisProgressBanner({required this.rec});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Generating audio — ${rec.synthesizedCount} / ${rec.totalSentences > 0 ? rec.totalSentences : '?'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: rec.cancelSynthesis,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    foregroundColor: cs.error,
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rec.synthesisProgress,
                minHeight: 4,
                backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generate Audio Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _GenerateAudioDialog extends StatefulWidget {
  final String docId;
  const _GenerateAudioDialog({required this.docId});

  @override
  State<_GenerateAudioDialog> createState() => _GenerateAudioDialogState();
}

class _GenerateAudioDialogState extends State<_GenerateAudioDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Offline state
  String _rangeOption = 'all';
  final _fromPageController = TextEditingController();
  final _toPageController = TextEditingController();
  int _fromPage = 1;
  int _toPage = 1;
  String? _errorText;

  // Online state
  String _selectedVoiceId = 'en_US-lessac-high';
  String _selectedQuality = 'high';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {})); // rebuild on tab switch
    final reader = context.read<ReaderProvider>();
    _fromPage = reader.currentPage;
    _toPage = reader.totalPages;
    _fromPageController.text = '$_fromPage';
    _toPageController.text = '$_toPage';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fromPageController.dispose();
    _toPageController.dispose();
    super.dispose();
  }

  void _generateOffline() {
    final tts = context.read<ReadAloudProvider>();
    final rec = context.read<RecordingProvider>();
    final reader = context.read<ReaderProvider>();
    final totalPages = reader.totalPages;
    final currentPage = reader.currentPage;

    if (tts.sentences.isEmpty) {
      setState(() => _errorText = 'No text available to generate audio');
      return;
    }

    if (_rangeOption == 'custom') {
      if (_fromPage < 1 || _fromPage > totalPages) {
        setState(() => _errorText = 'From page must be between 1 and $totalPages');
        return;
      }
      if (_toPage < 1 || _toPage > totalPages) {
        setState(() => _errorText = 'To page must be between 1 and $totalPages');
        return;
      }
      if (_fromPage > _toPage) {
        setState(() => _errorText = 'From page cannot be greater than To page');
        return;
      }
    }

    Navigator.pop(context);
    tts.stop();

    List<String> sentences;
    if (_rangeOption == 'all') {
      sentences = tts.sentences;
    } else if (_rangeOption == 'current') {
      final fraction = totalPages > 1 ? (currentPage - 1) / (totalPages - 1) : 0.0;
      final startIdx = (fraction * tts.sentences.length).floor();
      sentences = tts.sentences.sublist(startIdx);
    } else {
      final f1 = totalPages > 1 ? ((_fromPage - 1) / (totalPages - 1)) : 0.0;
      final f2 = totalPages > 1 ? ((_toPage - 1) / (totalPages - 1)) : 1.0;
      final s1 = (f1 * tts.sentences.length).floor().clamp(0, tts.sentences.length);
      final s2 = (f2 * tts.sentences.length).ceil().clamp(s1, tts.sentences.length);
      sentences = tts.sentences.sublist(s1, s2);
    }

    if (sentences.isEmpty) {
      context.showSnackBar('No text in selected range', isError: true);
      return;
    }

    rec.startSynthesis(sentences, tts.speed, 'en-US');
  }

  Future<void> _generateOnline() async {
    final doc = context.read<DocumentProvider>().getDocumentById(widget.docId);
    if (doc == null) return;

    Navigator.pop(context);

    String fullText = '';
    try {
      fullText = await DocTextExtractor.extract(doc.filePath);
    } catch (e) {
      if (mounted) context.showSnackBar('Failed to extract text: $e', isError: true);
      return;
    }

    if (fullText.isEmpty) {
      if (mounted) context.showSnackBar('No text found in document', isError: true);
      return;
    }

    if (!mounted) return;

    final rec = context.read<RecordingProvider>();
    final ttsService = OnlineTtsService();

    final isHealthy = await ttsService.checkHealth();
    if (!isHealthy) {
      if (mounted) context.showSnackBar('Online TTS server not available', isError: true);
      return;
    }

    await rec.startOnlineSynthesis(
      text: fullText,
      voiceId: _selectedVoiceId,
      baseUrl: ttsService.baseUrl,
      speed: 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reader = context.read<ReaderProvider>();
    final totalPages = reader.totalPages;
    final voices = PiperVoices.voices.where((v) => v.quality == _selectedQuality).toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      contentPadding: const EdgeInsets.all(20),
      titlePadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Generate Audio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Offline'), Tab(text: 'Online')],
              labelColor: Colors.purple,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.purple,
              dividerColor: Colors.transparent,
            ),

            const SizedBox(height: 12),

            // Tab content
            SizedBox(
              height: 260,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Offline tab ──
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select page range:', style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        RadioListTile<String>(
                          title: const Text('All pages'),
                          value: 'all',
                          groupValue: _rangeOption,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() { _rangeOption = v!; _errorText = null; }),
                        ),
                        RadioListTile<String>(
                          title: const Text('Current page onward'),
                          value: 'current',
                          groupValue: _rangeOption,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() { _rangeOption = v!; _errorText = null; }),
                        ),
                        RadioListTile<String>(
                          title: const Text('Custom range'),
                          value: 'custom',
                          groupValue: _rangeOption,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() { _rangeOption = v!; _errorText = null; }),
                        ),
                        if (_rangeOption == 'custom') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _fromPageController,
                                  decoration: InputDecoration(
                                    labelText: 'From page',
                                    isDense: true,
                                    helperText: '1-$totalPages',
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    _fromPage = int.tryParse(v) ?? _fromPage;
                                    setState(() => _errorText = null);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _toPageController,
                                  decoration: InputDecoration(
                                    labelText: 'To page',
                                    isDense: true,
                                    helperText: '1-$totalPages',
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    _toPage = int.tryParse(v) ?? _toPage;
                                    setState(() => _errorText = null);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Online tab ──
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quality filter chips
                      Row(
                        children: [
                          for (final q in [
                            ('high', 'High', Icons.star),
                            ('medium', 'Medium', Icons.speed),
                            ('low', 'Low', Icons.flash_on),
                          ])
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: q.$1 != 'low' ? 6 : 0),
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedQuality = q.$1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _selectedQuality == q.$1
                                          ? Colors.purple.withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _selectedQuality == q.$1 ? Colors.purple : Colors.grey.shade300,
                                        width: _selectedQuality == q.$1 ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(q.$3, size: 14,
                                          color: _selectedQuality == q.$1 ? Colors.purple : Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(q.$2,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _selectedQuality == q.$1 ? FontWeight.bold : FontWeight.normal,
                                            color: _selectedQuality == q.$1 ? Colors.purple : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: voices.length,
                          itemBuilder: (context, index) {
                            final voice = voices[index];
                            final isSelected = _selectedVoiceId == voice.id;
                            return InkWell(
                              onTap: () => setState(() => _selectedVoiceId = voice.id),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.purple.withValues(alpha: 0.1) : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? Colors.purple : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      voice.gender == 'Male' ? Icons.man : Icons.woman,
                                      color: voice.gender == 'Male' ? Colors.blue : Colors.pink,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(voice.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          Text(voice.language, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: Colors.purple, size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _tabController.index == 0 ? _generateOffline : _generateOnline,
          style: FilledButton.styleFrom(
            backgroundColor: _tabController.index == 1 ? Colors.purple : null,
          ),
          child: Text(_tabController.index == 1 ? 'Generate & Save' : 'Generate'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Save Recording Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _SaveRecordingDialog extends StatefulWidget {
  final ScaffoldMessengerState? messenger;
  const _SaveRecordingDialog({required this.messenger});

  @override
  State<_SaveRecordingDialog> createState() => _SaveRecordingDialogState();
}

class _SaveRecordingDialogState extends State<_SaveRecordingDialog> {
  late final TextEditingController _nameController;
  late final RecordingProvider _recordingProvider;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _nameController = TextEditingController(
      text: 'Audio ${now.day}/${now.month}/${now.year}',
    );
    // Capture provider reference in initState
    _recordingProvider = context.read<RecordingProvider>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveRecording() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final recording = await _recordingProvider.saveRecording(_nameController.text);
      if (!mounted) return;
      
      Navigator.pop(context);
      
      if (widget.messenger != null) {
        widget.messenger!.showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(
                recording != null
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(recording != null
                  ? 'Saved to Recordings'
                  : 'Failed to save'),
            ]),
            backgroundColor: recording != null ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      }
    } catch (e) {
      debugPrint('[SaveRecordingDialog] Error: $e');
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.messenger != null) {
        widget.messenger!.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Error: ${e.toString()}'),
            ]),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Audio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Audio generation complete! Enter a name:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
            enabled: !_isSaving,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context);
                  _recordingProvider.cancelSynthesis();
                },
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveRecording,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Bookmark Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _AddBookmarkDialog extends StatefulWidget {
  final String docId;
  final int currentPage;
  const _AddBookmarkDialog({required this.docId, required this.currentPage});

  @override
  State<_AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<_AddBookmarkDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Page ${widget.currentPage}');
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Bookmark'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            context.read<BookmarkProvider>().addBookmark(
                  docId: widget.docId,
                  page: widget.currentPage,
                  title: _titleController.text.isEmpty
                      ? 'Page ${widget.currentPage}'
                      : _titleController.text,
                  note: _noteController.text.isEmpty
                      ? null
                      : _noteController.text,
                );
            Navigator.pop(context);
            context.showSnackBar('Bookmark added', isSuccess: true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}