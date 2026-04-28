import 'dart:io';
import 'package:flutter/material.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:provider/provider.dart';
import '../models/document_model.dart';
import '../providers/reader_provider.dart';
import '../screens/reader/pdf_reader_controller.dart';

class DocxReader extends StatefulWidget {
  final DocumentModel document;
  final PdfReaderController readerController;

  const DocxReader({
    super.key,
    required this.document,
    required this.readerController,
  });

  @override
  State<DocxReader> createState() => _DocxReaderState();
}

class _DocxReaderState extends State<DocxReader> {
  late final Future<List<Widget>> _renderFuture;
  final ScrollController _scrollController = ScrollController();
  bool _showHighlightBanner = true;
  bool _pageInfoSet = false;
  bool _isNavigating = false;
  int _totalPages = 1;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();

    widget.readerController.onNavigateToHighlight = (id, page) {};
    widget.readerController.onDeleteHighlight = (id) async {};
    widget.readerController.onPageChanged = _scrollToPage;
    widget.readerController.onScrollFraction = _scrollToFraction;

    _renderFuture =
        DocxExtractor().renderLayout(File(widget.document.filePath));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pageInfoSet) {
      _pageInfoSet = true;
      final bytes = widget.document.fileSizeBytes;
      _totalPages = ((bytes / 2) / 3000).ceil().clamp(1, 9999);
      
      // Defer provider calls to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rp = context.read<ReaderProvider>();
        rp.setTotalPages(_totalPages);
        rp.setPage(1);
        // Register so PageSlider.onChanged drives us instantly
        rp.registerSliderDragCallback(_scrollToFraction);
      });
    }
  }

  @override
  void dispose() {
    context.read<ReaderProvider>().unregisterSliderDragCallback();
    _scrollController.dispose();
    super.dispose();
  }

  // Called by scroll notifications — updates page and slider on page changes only
  void _onScrollUpdate() {
    if (_isNavigating) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    
    // Calculate current page based on scroll position
    final scrollFraction = (_scrollController.offset / max).clamp(0.0, 1.0);
    final newPage = (scrollFraction * _totalPages).ceil().clamp(1, _totalPages);
    
    // Only update if page changed
    if (newPage != _currentPage) {
      _currentPage = newPage;
      if (mounted) {
        context.read<ReaderProvider>().setPage(_currentPage);
        // Use page midpoint for slider position
        final sliderFraction = ((_currentPage - 0.5) / _totalPages).clamp(0.0, 1.0);
        context.read<ReaderProvider>().setScrollFraction(sliderFraction);
      }
    }
  }

  // Called by onPageChanged callback (next/prev buttons)
  // Called by onScrollFraction callback (slider drag)
  Future<void> _scrollToPage(int targetPage) async {
    if (!_scrollController.hasClients) return;
    final page = targetPage.clamp(1, _totalPages);
    _currentPage = page;
    _isNavigating = true;

    final max = _scrollController.position.maxScrollExtent;
    final fraction = _totalPages > 1 ? (page - 1) / (_totalPages - 1) : 0.0;
    final target = (fraction * max).clamp(0.0, max);

    _scrollController.jumpTo(target);
    
    // Release navigation lock
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _isNavigating = false;
    });
  }

  // Called by slider drag — converts fraction to page and scrolls
  void _scrollToFraction(double fraction) {
    if (!_scrollController.hasClients) return;
    _isNavigating = true;
    
    // Convert fraction to target page
    final targetPage = ((fraction * _totalPages) + 0.5).floor().clamp(1, _totalPages);
    _currentPage = targetPage;
    
    final max = _scrollController.position.maxScrollExtent;
    final pageFraction = _totalPages > 1 ? (targetPage - 1) / (_totalPages - 1) : 0.0;
    final target = (pageFraction * max).clamp(0.0, max);
    
    _scrollController.jumpTo(target);
    
    // Release navigation lock
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return ColoredBox(
      color: bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Document content ──
          FutureBuilder<List<Widget>>(
            future: _renderFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Loading Word document...',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: cs.error),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to render document.\n'
                          '${snapshot.error ?? "Unknown error"}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ColoredBox(
                color: bgColor,
                child: DefaultTextStyle(
                  style:
                      TextStyle(color: textColor, fontSize: 16, height: 1.6),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Only update on scroll updates, not on start/end
                      if (notification is ScrollUpdateNotification) {
                        _onScrollUpdate();
                      }
                      return false; // don't absorb — let scroll continue
                    },
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        16, 
                        MediaQuery.of(context).padding.top + 80, // Status bar + top bar height
                        16, 
                        120
                      ),
                      children: snapshot.requireData
                          .map((w) => DefaultTextStyle.merge(
                                style: TextStyle(color: textColor),
                                child: w,
                              ))
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── "Highlighting not available" banner ──
          if (_showHighlightBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: cs.secondaryContainer,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: cs.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Highlighting not available for Word documents',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSecondaryContainer),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 16, color: cs.onSecondaryContainer),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                        onPressed: () =>
                            setState(() => _showHighlightBanner = false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}