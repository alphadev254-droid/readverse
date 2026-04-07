import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../models/document_model.dart';
import '../../utils/extensions.dart';
import '../home/widgets/document_grid.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _sortBy = 'Date Added';
  String _filterBy = 'All';

  List<DocumentModel> _getSorted(List<DocumentModel> docs) {
    var sorted = List<DocumentModel>.from(docs);
    if (_filterBy == 'PDF') sorted = sorted.where((d) => d.isPdf).toList();
    if (_filterBy == 'EPUB') sorted = sorted.where((d) => d.isEpub).toList();
    switch (_sortBy) {
      case 'Name': sorted.sort((a, b) => a.name.compareTo(b.name)); break;
      case 'Last Read': sorted.sort((a, b) => (b.lastOpened ?? DateTime(0)).compareTo(a.lastOpened ?? DateTime(0))); break;
      default: sorted.sort((a, b) => b.uploadDate.compareTo(a.uploadDate)); break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Consumer2<DocumentProvider, FavoritesProvider>(
      builder: (_, docProvider, favProvider, __) {
        final allFavs = favProvider.getFavoriteDocuments(docProvider.allDocuments);
        final docs = _getSorted(allFavs);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Favorites'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (_) => ['Date Added', 'Name', 'Last Read']
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Stats card
              if (allFavs.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primaryContainer.withOpacity(0.5), cs.secondaryContainer.withOpacity(0.5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickStat(label: 'Total Favorites', value: '${allFavs.length}', icon: Icons.favorite),
                      _QuickStat(
                        label: 'Most Read',
                        value: allFavs.isNotEmpty
                            ? allFavs.reduce((a, b) => a.totalReadingSeconds > b.totalReadingSeconds ? a : b).name.truncate(10)
                            : '-',
                        icon: Icons.local_fire_department,
                      ),
                    ],
                  ),
                ),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: ['All', 'PDF', 'EPUB'].map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: _filterBy == f,
                      onSelected: (_) => setState(() => _filterBy = f),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DocumentGrid(
                  documents: docs,
                  isLoading: docProvider.isLoading,
                  emptyTitle: 'No Favorites Yet',
                  emptySubtitle: 'Tap the heart icon on any document to add it here',
                  onRefresh: docProvider.loadDocuments,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _QuickStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      children: [
        Icon(icon, color: cs.primary, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
      ],
    );
  }
}
