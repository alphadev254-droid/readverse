import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/highlight_provider.dart';
import '../../models/document_model.dart';
import '../../utils/formatters.dart';
import '../../utils/extensions.dart';

class DocumentDetailsScreen extends StatefulWidget {
  final String docId;
  const DocumentDetailsScreen({super.key, required this.docId});

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().loadBookmarks(widget.docId);
      context.read<HighlightProvider>().loadHighlights(widget.docId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<DocumentProvider>().getDocumentById(widget.docId);
    if (doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document Details')),
        body: const Center(child: Text('Document not found')),
      );
    }

    final cs = context.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Cover / App Bar ──
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            actions: [
              Consumer<FavoritesProvider>(
                builder: (_, favs, __) => IconButton(
                  icon: Icon(
                    favs.isFavorite(doc.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: favs.isFavorite(doc.id) ? Colors.red : null,
                  ),
                  onPressed: () {
                    favs.toggleFavorite(doc.id);
                    context.showSnackBar(
                      favs.isFavorite(doc.id)
                          ? 'Added to favorites'
                          : 'Removed from favorites',
                      isSuccess: true,
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCover(doc, cs),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title + type badge ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              doc.name,
                              style: context.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _TypeBadge(doc: doc),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        doc.formattedSize,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Progress bar ──
                if (doc.totalPages > 0) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProgressSection(doc: doc),
                  ),
                ],

                // ── Action buttons ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _ActionButtons(doc: doc),
                ),

                // ── Stats row ──
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Consumer2<BookmarkProvider, HighlightProvider>(
                    builder: (_, bookmarks, highlights, __) => Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.bookmark_outline,
                            label: 'Bookmarks',
                            value: '${bookmarks.bookmarks.length}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.highlight,
                            label: 'Highlights',
                            value: '${highlights.highlights.length}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.edit_note,
                            label: 'Notes',
                            value:
                                '${highlights.highlights.where((h) => h.note != null).length}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Info rows ──
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _InfoSection(doc: doc),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(DocumentModel doc, ColorScheme cs) {
    if (doc.thumbnailPath != null &&
        File(doc.thumbnailPath!).existsSync()) {
      return Image.file(File(doc.thumbnailPath!), fit: BoxFit.cover);
    }
    return Container(
      color: cs.primaryContainer,
      child: Center(
        child: Icon(
          _docIcon(doc),
          size: 72,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }

  IconData _docIcon(DocumentModel doc) {
    if (doc.isPdf) return Icons.picture_as_pdf_outlined;
    if (doc.isEpub) return Icons.book_outlined;
    if (doc.isDocx) return Icons.description_outlined;
    if (doc.isTextBased) return Icons.text_snippet_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type badge
// ─────────────────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final DocumentModel doc;
  const _TypeBadge({required this.doc});

  Color get _color {
    if (doc.isPdf) return Colors.red;
    if (doc.isEpub) return Colors.blue;
    if (doc.isDocx) return Colors.indigo;
    if (doc.isMd) return Colors.teal;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        doc.type.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress section
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressSection extends StatelessWidget {
  final DocumentModel doc;
  const _ProgressSection({required this.doc});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reading Progress',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              '${doc.progressPercent}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: doc.readingProgress,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          doc.totalPages > 0
              ? 'Page ${doc.lastPage} of ${doc.totalPages}'
              : 'Not started',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action buttons
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final DocumentModel doc;
  const _ActionButtons({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Continue / Start reading
        FilledButton.icon(
          onPressed: () => context.push('/reader/${doc.id}'),
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: Text(
            doc.lastPage > 0 ? 'Continue Reading' : 'Start Reading',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Library toggle
            Expanded(
              child: Consumer<LibraryProvider>(
                builder: (_, lib, __) {
                  final inLib = lib.isInLibrary(doc.id);
                  return OutlinedButton.icon(
                    onPressed: () {
                      lib.toggleLibrary(doc.id);
                      context.showSnackBar(
                        inLib ? 'Removed from library' : 'Added to library',
                        isSuccess: true,
                      );
                    },
                    icon: Icon(
                      inLib
                          ? Icons.bookmark_remove_outlined
                          : Icons.bookmark_add_outlined,
                      size: 18,
                    ),
                    label: Text(inLib ? 'In Library' : 'Add to Library'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            // Delete
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, doc),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, DocumentModel doc) {
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

// ─────────────────────────────────────────────────────────────────────────────
// Stat card — uses theme colors only, no hardcoded colors
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: cs.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info section — clean rows with dividers
// ─────────────────────────────────────────────────────────────────────────────
class _InfoSection extends StatelessWidget {
  final DocumentModel doc;
  const _InfoSection({required this.doc});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    final rows = <_InfoRowData>[
      _InfoRowData(Icons.calendar_today_outlined, 'Date Added',
          Formatters.date(doc.uploadDate)),
      if (doc.lastOpened != null)
        _InfoRowData(Icons.access_time_outlined, 'Last Opened',
            Formatters.timeAgo(doc.lastOpened!)),
      if (doc.totalPages > 0)
        _InfoRowData(
            Icons.pages_outlined, 'Total Pages', '${doc.totalPages}'),
      _InfoRowData(Icons.timer_outlined, 'Reading Time',
          Formatters.readingTime(doc.totalReadingSeconds)),
      _InfoRowData(Icons.storage_outlined, 'File Size', doc.formattedSize),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(row.icon,
                        size: 18,
                        color: cs.primary),
                    const SizedBox(width: 12),
                    Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      row.value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                Divider(
                  height: 1,
                  indent: 46,
                  color: cs.outline.withValues(alpha: 0.1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRowData {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRowData(this.icon, this.label, this.value);
}
