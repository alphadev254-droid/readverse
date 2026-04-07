import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/library_provider.dart';
import '../../models/document_model.dart';
import '../../utils/extensions.dart';
import '../../utils/formatters.dart';
import '../home/widgets/document_card.dart';

class LibraryManagementScreen extends StatefulWidget {
  const LibraryManagementScreen({super.key});

  @override
  State<LibraryManagementScreen> createState() => _LibraryManagementScreenState();
}

class _LibraryManagementScreenState extends State<LibraryManagementScreen> {
  bool _isGridView = true;
  String _sortBy = 'Date Added';
  String _filterBy = 'All';
  bool _multiSelect = false;
  final Set<String> _selectedIds = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DocumentModel> _getFilteredDocs(List<DocumentModel> docs) {
    var filtered = docs;
    // Filter by type
    if (_filterBy == 'PDF') filtered = filtered.where((d) => d.isPdf).toList();
    if (_filterBy == 'EPUB') filtered = filtered.where((d) => d.isEpub).toList();
    // Search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((d) => d.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    // Sort
    switch (_sortBy) {
      case 'Name': filtered.sort((a, b) => a.name.compareTo(b.name)); break;
      case 'Last Read': filtered.sort((a, b) => (b.lastOpened ?? DateTime(0)).compareTo(a.lastOpened ?? DateTime(0))); break;
      case 'File Size': filtered.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes)); break;
      default: filtered.sort((a, b) => b.uploadDate.compareTo(a.uploadDate)); break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Consumer2<DocumentProvider, LibraryProvider>(
      builder: (_, docProvider, libProvider, __) {
        final allDocs = libProvider.getLibraryDocuments(docProvider.allDocuments);
        final docs = _getFilteredDocs(allDocs);

        return Scaffold(
          appBar: AppBar(
            title: _multiSelect
                ? Text('${_selectedIds.length} selected')
                : const Text('My Library'),
            actions: _multiSelect
                ? _buildMultiSelectActions(context, libProvider)
                : _buildNormalActions(),
          ),
          body: Column(
            children: [
              _buildStatsCard(context, allDocs),
              _buildSearchAndFilters(context),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.library_books_outlined, size: 64, color: cs.onSurface.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('No documents in library', style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
                          ],
                        ),
                      )
                    : _isGridView
                        ? _buildGrid(context, docs, libProvider)
                        : _buildList(context, docs, libProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildNormalActions() => [
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: () => setState(() => _isGridView = !_isGridView),
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          onPressed: () => setState(() => _multiSelect = true),
        ),
      ];

  List<Widget> _buildMultiSelectActions(BuildContext context, LibraryProvider lib) => [
        TextButton(
          onPressed: () {
            for (final id in _selectedIds) lib.removeFromLibrary(id);
            setState(() { _selectedIds.clear(); _multiSelect = false; });
            context.showSnackBar('Removed from library', isSuccess: true);
          },
          child: const Text('Remove'),
        ),
        TextButton(
          onPressed: () => setState(() { _selectedIds.clear(); _multiSelect = false; }),
          child: const Text('Cancel'),
        ),
      ];

  Widget _buildStatsCard(BuildContext context, List<DocumentModel> docs) {
    final cs = context.colorScheme;
    final totalTime = docs.fold<int>(0, (sum, d) => sum + d.totalReadingSeconds);
    final completed = docs.where((d) => d.readingProgress >= 0.99).length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Total', value: '${docs.length}', icon: Icons.library_books),
          _StatItem(label: 'Read Time', value: Formatters.readingTime(totalTime), icon: Icons.timer),
          _StatItem(label: 'Completed', value: '$completed', icon: Icons.check_circle_outline),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search library...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Sort
              PopupMenuButton<String>(
                child: Chip(label: Row(mainAxisSize: MainAxisSize.min, children: [Text(_sortBy), const Icon(Icons.arrow_drop_down, size: 18)])),
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (_) => ['Date Added', 'Name', 'Last Read', 'File Size']
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
              ),
              const SizedBox(width: 8),
              // Filter
              ...['All', 'PDF', 'EPUB'].map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _filterBy == f,
                  onSelected: (_) => setState(() => _filterBy = f),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, List<DocumentModel> docs, LibraryProvider lib) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        return _multiSelect
            ? Stack(
                children: [
                  DocumentCard(document: doc),
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (_selectedIds.contains(doc.id)) _selectedIds.remove(doc.id);
                        else _selectedIds.add(doc.id);
                      }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedIds.contains(doc.id) ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: _selectedIds.contains(doc.id) ? Border.all(color: Colors.blue, width: 2) : null,
                        ),
                        child: _selectedIds.contains(doc.id)
                            ? const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.check_circle, color: Colors.blue)))
                            : null,
                      ),
                    ),
                  ),
                ],
              )
            : DocumentCard(document: doc);
      },
    );
  }

  Widget _buildList(BuildContext context, List<DocumentModel> docs, LibraryProvider lib) {
    final cs = context.colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(doc.isPdf ? Icons.picture_as_pdf_outlined : Icons.book_outlined, color: cs.primary),
            ),
            title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${doc.progressPercent}% • ${doc.formattedSize}', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
            trailing: _multiSelect
                ? Checkbox(
                    value: _selectedIds.contains(doc.id),
                    onChanged: (_) => setState(() {
                      if (_selectedIds.contains(doc.id)) _selectedIds.remove(doc.id);
                      else _selectedIds.add(doc.id);
                    }),
                  )
                : IconButton(
                    icon: const Icon(Icons.bookmark_remove_outlined, size: 20),
                    onPressed: () => lib.removeFromLibrary(doc.id),
                  ),
            onTap: _multiSelect
                ? () => setState(() {
                    if (_selectedIds.contains(doc.id)) _selectedIds.remove(doc.id);
                    else _selectedIds.add(doc.id);
                  })
                : () => context.push('/reader/${doc.id}'),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      children: [
        Icon(icon, color: cs.primary, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
      ],
    );
  }
}
