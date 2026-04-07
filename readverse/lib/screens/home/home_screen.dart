import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/file_service.dart';
import '../../utils/extensions.dart';
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
    return Consumer2<DocumentProvider, LibraryProvider>(
      builder: (_, docProvider, libProvider, __) {
        final docs =
            libProvider.getLibraryDocuments(docProvider.allDocuments);
        return DocumentGrid(
          documents: docs,
          isLoading: docProvider.isLoading,
          emptyTitle: 'Library is Empty',
          emptySubtitle: 'Add documents to your library for quick access',
          onRefresh: docProvider.loadDocuments,
        );
      },
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<DocumentProvider, FavoritesProvider>(
      builder: (_, docProvider, favProvider, __) {
        final docs =
            favProvider.getFavoriteDocuments(docProvider.allDocuments);
        return DocumentGrid(
          documents: docs,
          isLoading: docProvider.isLoading,
          emptyTitle: 'No Favorites Yet',
          emptySubtitle:
              'Tap the heart icon on any document to add it here',
          onRefresh: docProvider.loadDocuments,
        );
      },
    );
  }
}
