import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/reader_provider.dart';
import '../../models/bookmark_model.dart';
import '../../utils/formatters.dart';
import '../../utils/extensions.dart';
import '../../config/app_colors.dart';

class BookmarksPanel extends StatefulWidget {
  final String docId;
  const BookmarksPanel({super.key, required this.docId});

  @override
  State<BookmarksPanel> createState() => _BookmarksPanelState();
}

class _BookmarksPanelState extends State<BookmarksPanel> {
  String _sortMode = 'Recent';

  void _sort(String mode) {
    _sortMode = mode;
    final provider = context.read<BookmarkProvider>();
    switch (mode) {
      case 'Page': provider.sortByPage(); break;
      case 'Title': provider.sortByTitle(); break;
      default: provider.sortByRecent(); break;
    }
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int selectedColor = AppColors.bookmarkRed.value;
    final reader = context.read<ReaderProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Bookmark'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: 'Title', hintText: 'Page ${reader.currentPage}'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: AppColors.bookmarkColors.map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color.value),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color.value
                              ? Border.all(color: Colors.black, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                context.read<BookmarkProvider>().addBookmark(
                      docId: widget.docId,
                      page: reader.currentPage,
                      title: titleCtrl.text.isEmpty ? 'Page ${reader.currentPage}' : titleCtrl.text,
                      note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                      colorValue: selectedColor,
                    );
                Navigator.pop(ctx);
                context.showSnackBar('Bookmark added', isSuccess: true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

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
                const Icon(Icons.bookmark, size: 20),
                const SizedBox(width: 8),
                const Text('Bookmarks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                // Sort menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  onSelected: _sort,
                  itemBuilder: (_) => ['Recent', 'Page', 'Title']
                      .map((s) => PopupMenuItem(value: s, child: Text(s)))
                      .toList(),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<BookmarkProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.bookmarks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border, size: 48, color: cs.onSurface.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('No bookmarks yet', style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showAddDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Bookmark'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: provider.bookmarks.length,
                  itemBuilder: (_, i) => _BookmarkItem(
                    bookmark: provider.bookmarks[i],
                    onTap: () {
                      context.read<ReaderProvider>().setPage(provider.bookmarks[i].page);
                      Navigator.pop(context);
                    },
                    onDelete: () => provider.deleteBookmark(provider.bookmarks[i].id),
                    onEdit: () => _showEditDialog(provider.bookmarks[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BookmarkModel bookmark) {
    final titleCtrl = TextEditingController(text: bookmark.title);
    final noteCtrl = TextEditingController(text: bookmark.note ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<BookmarkProvider>().editBookmark(
                    bookmark.id,
                    title: titleCtrl.text,
                    note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _BookmarkItem extends StatelessWidget {
  final BookmarkModel bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BookmarkItem({
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Dismissible(
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        onLongPress: onEdit,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(bookmark.colorValue),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${bookmark.page}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        title: Text(bookmark.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bookmark.note != null)
              Text(bookmark.note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
            Text(Formatters.timeAgo(bookmark.createdAt), style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
          ],
        ),
        trailing: IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
      ),
    );
  }
}
