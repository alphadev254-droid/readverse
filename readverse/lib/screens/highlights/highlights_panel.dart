import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/highlight_provider.dart';
import '../../models/highlight_model.dart';
import '../../utils/formatters.dart';
import '../../utils/extensions.dart';
import '../reader/pdf_reader_controller.dart';

class HighlightsPanel extends StatelessWidget {
  final String docId;
  /// Null for EPUB documents (no PdfReader involved).
  final PdfReaderController? pdfReaderController;

  const HighlightsPanel({
    super.key,
    required this.docId,
    this.pdfReaderController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.highlight, size: 20),
                const SizedBox(width: 8),
                const Text('Highlights',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Consumer<HighlightProvider>(
                  builder: (_, provider, __) => IconButton(
                    icon: const Icon(Icons.ios_share_outlined),
                    tooltip: 'Export',
                    onPressed: provider.highlights.isEmpty
                        ? null
                        : () {
                            provider.exportAsText(docId);
                            context.showSnackBar(
                              'Highlights exported (${provider.highlights.length} items)',
                              isSuccess: true,
                            );
                          },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<HighlightProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.highlights.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.highlight_outlined,
                            size: 48,
                            color: cs.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('No highlights yet',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        const SizedBox(height: 4),
                        Text('Long-press text in the PDF to highlight',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    cs.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: provider.highlights.length,
                  itemBuilder: (_, i) {
                    final highlight = provider.highlights[i];
                    return _HighlightItem(
                      highlight: highlight,
                      onTap: () {
                        // Close sheet first, then navigate after dismiss animation
                        Navigator.pop(context);
                        Future.delayed(const Duration(milliseconds: 200), () {
                          pdfReaderController?.navigateTo(
                              highlight.id, highlight.page);
                        });
                      },
                      onDelete: () async {
                        // Remove from viewer + storage via PdfReaderController
                        if (pdfReaderController != null) {
                          await pdfReaderController!.delete(highlight.id);
                        } else {
                          // EPUB or no controller — just remove from storage
                          await provider.deleteHighlight(highlight.id);
                        }
                      },
                      onEditNote: () =>
                          _showEditNoteDialog(context, highlight, provider),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNoteDialog(
      BuildContext context, HighlightModel highlight, HighlightProvider provider) {
    final noteCtrl = TextEditingController(text: highlight.note ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(labelText: 'Note'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              provider.editHighlight(highlight.id,
                  note: noteCtrl.text.isEmpty ? null : noteCtrl.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _HighlightItem extends StatelessWidget {
  final HighlightModel highlight;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEditNote;

  const _HighlightItem({
    required this.highlight,
    required this.onTap,
    required this.onDelete,
    required this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final color = Color(highlight.colorValue);
    return Dismissible(
      key: Key(highlight.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color bar
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Highlighted text preview
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        highlight.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (highlight.note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        highlight.note!,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Page ${highlight.page}',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.6)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.timeAgo(highlight.createdAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, size: 18),
                onPressed: onEditNote,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
