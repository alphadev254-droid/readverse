import 'package:flutter/material.dart';
import '../../../models/document_model.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import 'document_card.dart';

class DocumentGrid extends StatelessWidget {
  final List<DocumentModel> documents;
  final bool isLoading;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback? onAddDocument;
  final Future<void> Function() onRefresh;

  const DocumentGrid({
    super.key,
    required this.documents,
    required this.isLoading,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    this.onAddDocument,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const ShimmerGrid();

    if (documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: EmptyState(
              title: emptyTitle,
              subtitle: emptySubtitle,
              icon: Icons.library_books_outlined,
              actionLabel: onAddDocument != null ? 'Import Document' : null,
              onAction: onAddDocument,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: documents.length,
        itemBuilder: (_, i) => DocumentCard(document: documents[i]),
      ),
    );
  }
}
