import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/document_provider.dart';

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key});

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final _ctrl = TextEditingController();
  String _filter = 'All';

  static const _filters = ['All', 'PDF', 'EPUB', 'DOCX', 'TXT', 'Audio'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applyFilter(String filter) {
    setState(() => _filter = filter);
    context.read<DocumentProvider>().filterByType(filter == 'All' ? null : filter.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Search field — takes remaining space
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: (v) {
                setState(() {});
                context.read<DocumentProvider>().searchDocuments(v);
              },
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() {});
                          context.read<DocumentProvider>().searchDocuments('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Filter dropdown
          PopupMenuButton<String>(
            onSelected: _applyFilter,
            itemBuilder: (_) => _filters
                .map((f) => PopupMenuItem(
                      value: f,
                      child: Row(
                        children: [
                          Icon(_filterIcon(f), size: 16,
                              color: _filter == f ? cs.primary : cs.onSurface),
                          const SizedBox(width: 8),
                          Text(f,
                              style: TextStyle(
                                fontWeight: _filter == f
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _filter == f ? cs.primary : null,
                              )),
                        ],
                      ),
                    ))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _filter != 'All'
                      ? cs.primary
                      : cs.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(12),
                color: _filter != 'All'
                    ? cs.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_filterIcon(_filter), size: 16,
                      color: _filter != 'All' ? cs.primary : cs.onSurface),
                  const SizedBox(width: 4),
                  Text(
                    _filter,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _filter != 'All' ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 18,
                      color: _filter != 'All' ? cs.primary : cs.onSurface),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _filterIcon(String filter) {
    switch (filter) {
      case 'PDF': return Icons.picture_as_pdf_outlined;
      case 'EPUB': return Icons.book_outlined;
      case 'DOCX': return Icons.description_outlined;
      case 'TXT': return Icons.text_snippet_outlined;
      case 'Audio': return Icons.mic_outlined;
      default: return Icons.filter_list;
    }
  }
}
