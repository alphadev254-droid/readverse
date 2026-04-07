import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../models/document_model.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/document_provider.dart';
import '../../../utils/extensions.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  const DocumentCard({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Card(
      child: InkWell(
        onTap: () => context.push('/reader/${document.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCover(context, cs)),
            _buildInfo(context, cs),
          ],
        ),
      ),
    );
  }

  // ── Cover ──────────────────────────────────────────────────────────────
  Widget _buildCover(BuildContext context, ColorScheme cs) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnail(cs),
        // Type chip — top right
        Positioned(
          top: 8,
          right: 8,
          child: _TypeChip(document: document),
        ),
        // Favorite — top left
        Positioned(
          top: 8,
          left: 8,
          child: _FavoriteButton(document: document),
        ),
      ],
    );
  }

  Widget _buildThumbnail(ColorScheme cs) {
    if (document.thumbnailPath != null &&
        File(document.thumbnailPath!).existsSync()) {
      return Image.file(File(document.thumbnailPath!), fit: BoxFit.cover);
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.secondaryContainer],
        ),
      ),
      child: Center(
        child: Icon(_docIcon(), size: 44, color: cs.primary),
      ),
    );
  }

  IconData _docIcon() {
    if (document.isPdf) return Icons.picture_as_pdf_outlined;
    if (document.isDocx) return Icons.description_outlined;
    if (document.isTextBased) return Icons.text_snippet_outlined;
    return Icons.book_outlined;
  }

  // ── Info ───────────────────────────────────────────────────────────────
  Widget _buildInfo(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            document.name,
            style: context.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Page indicator
          if (document.totalPages > 0)
            Text(
              'Page ${document.lastPage} of ${document.totalPages}',
              style: context.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          const SizedBox(height: 6),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: document.readingProgress,
                    minHeight: 4,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${document.progressPercent}%',
                style: context.textTheme.bodySmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Action row: library | details | delete ──
          Row(
            children: [
              // Library bookmark toggle
              _LibraryButton(document: document),
              const Spacer(),
              // Details button
              _IconActionButton(
                icon: Icons.info_outline,
                tooltip: 'Details',
                onTap: () =>
                    context.push('/document-details/${document.id}'),
              ),
              const SizedBox(width: 4),
              // Delete button
              _IconActionButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                color: cs.error,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content:
            Text('Are you sure you want to delete "${document.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DocumentProvider>().deleteDocument(document.id);
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
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final DocumentModel document;
  const _TypeChip({required this.document});

  Color get _color {
    if (document.isPdf) return Colors.red;
    if (document.isEpub) return Colors.blue;
    if (document.isDocx) return Colors.indigo;
    if (document.isMd) return Colors.teal;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        document.type.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final DocumentModel document;
  const _FavoriteButton({required this.document});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (_, favs, __) {
        final isFav = favs.isFavorite(document.id);
        return GestureDetector(
          onTap: () => favs.toggleFavorite(document.id),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: isFav ? Colors.red : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class _LibraryButton extends StatelessWidget {
  final DocumentModel document;
  const _LibraryButton({required this.document});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Consumer<LibraryProvider>(
      builder: (_, lib, __) {
        final inLib = lib.isInLibrary(document.id);
        return GestureDetector(
          onTap: () => lib.toggleLibrary(document.id),
          child: Icon(
            inLib ? Icons.bookmark : Icons.bookmark_border,
            size: 20,
            color: inLib
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.35),
          ),
        );
      },
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 19,
            color: color ?? cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
