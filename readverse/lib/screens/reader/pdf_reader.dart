import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../models/document_model.dart';
import '../../providers/highlight_provider.dart';
import '../../providers/reader_provider.dart';
import '../../widgets/highlight_bar.dart';
import 'pdf_reader_controller.dart';

class PdfReader extends StatefulWidget {
  final DocumentModel document;
  final PdfReaderController readerController;
  const PdfReader({
    super.key,
    required this.document,
    required this.readerController,
  });

  @override
  State<PdfReader> createState() => _PdfReaderState();
}

class _PdfReaderState extends State<PdfReader> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _controller;

  Uint8List? _pdfBytes;
  bool _firstLoad = true;
  int _currentPage = 1;
  double _totalContentHeight = 0.0;
  bool _totalHeightCalculated = false;
  bool _isSliderDragging = false;
  Timer? _scrollDebounce;

  OverlayEntry? _overlayEntry;
  String _selectedText = '';
  List<PdfTextLine> _selectedLines = [];
  bool _saving = false;
  bool _overlayInserting = false;
  Timer? _selectionDebounce;

  // Maps HighlightModel.id -> live Annotation inside the viewer.
  // Populated at add-time; rebuilt on every onDocumentLoaded.
  final Map<String, Annotation> _annotationRegistry = {};

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _currentPage = widget.document.lastPage > 0 ? widget.document.lastPage : 1;
    widget.readerController.onNavigateToHighlight = _navigateToHighlight;
    widget.readerController.onDeleteHighlight = _deleteHighlight;
    // Wire page-changed callback for next/prev buttons via _PageChangeForwarder
    widget.readerController.onPageChanged = (page) {
      _controller.jumpToPage(page);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateSliderFromScroll);
    _scrollDebounce?.cancel();
    context.read<ReaderProvider>().unregisterSliderDragCallback();
    _selectionDebounce?.cancel();
    _closeOverlay();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    final bytes = await File(widget.document.filePath).readAsBytes();
    if (!mounted) return;
    setState(() {
      _pdfBytes = bytes;
      _firstLoad = false;
    });
  }

  // Navigate: page is stored as PdfTextLine.pageNumber (1-based).
  // Do NOT call selectAnnotation/deselectAnnotation — they trigger the
  // internal annotation toolbar which causes the RawTooltipState ticker crash.
  // jumpToPage alone puts the user on the correct page where the highlight is.
  void _navigateToHighlight(String highlightId, int page) {
    _controller.jumpToPage(page); // page is 1-based from storage
  }

  // Delete a highlight from both viewer and storage.
  Future<void> _deleteHighlight(String highlightId) async {
    final annotation = _annotationRegistry.remove(highlightId);
    if (annotation != null) {
      _controller.removeAnnotation(annotation);
    }

    // Wait one frame so the viewer's internal model reflects the removal
    // before saveDocument() serialises it.
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    try {
      final savedBytes = await _controller.saveDocument();
      final newBytes = Uint8List.fromList(savedBytes);
      await File(widget.document.filePath).writeAsBytes(newBytes);
      _pdfBytes = newBytes;
    } catch (e) {
      debugPrint('[PdfReader] saveDocument after delete error: $e');
    }

    if (mounted) {
      await context.read<HighlightProvider>().removeHighlight(highlightId);
    }

    // Reset _saving so text selection works again after a delete.
    _saving = false;
  }

  // Text selection — debounced to prevent rapid overlay create/destroy
  // during drag which caused the color bar to disappear intermittently.
  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    _selectionDebounce?.cancel();

    final text = details.selectedText?.trim() ?? '';

    if (text.isEmpty) {
      _closeOverlay();
      _selectedText = '';
      _selectedLines = [];
      return;
    }

    if (text == _selectedText && _overlayEntry != null) return;

    // Debounce: wait 300ms of silence before showing overlay.
    // SfPdfViewer fires this callback many times during a drag.
    _selectionDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final currentText = details.selectedText?.trim() ?? '';
      if (currentText.isEmpty || _saving) return;

      _selectedText = currentText;
      _selectedLines =
          _pdfViewerKey.currentState?.getSelectedTextLines() ?? [];

      if (_selectedLines.isNotEmpty) {
        final region = details.globalSelectedRegion;
        if (region != null) _showOverlayMenu(region);
      }
    });
  }

  void _showOverlayMenu(Rect selectionRegion) {
    if (_overlayInserting || _saving) return;
    _overlayInserting = true;

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    const menuWidth = 240.0;
    const menuHeight = 60.0;

    double top = selectionRegion.top - menuHeight - 12;
    if (top < 24) top = selectionRegion.bottom + 12;
    top = top.clamp(24.0, screenSize.height - menuHeight - 24);

    double left = (selectionRegion.center.dx - menuWidth / 2)
        .clamp(12.0, screenSize.width - menuWidth - 12);

    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: top,
        left: left,
        child: Material(
          color: Colors.transparent,
          child: HighlightBar(
            selectedText: _selectedText,
            onHighlight: (color) {
              _closeOverlay();
              _saveHighlight(color);
            },
            onCopy: () {
              _closeOverlay();
              Clipboard.setData(ClipboardData(text: _selectedText));
              _controller.clearSelection();
              _snackbar('Copied to clipboard', Colors.blueGrey);
            },
            onClose: () {
              _closeOverlay();
              _controller.clearSelection();
            },
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
    _overlayInserting = false;
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayInserting = false;
  }

  Future<void> _saveHighlight(Color color) async {
    if (_selectedText.isEmpty || _selectedLines.isEmpty || _saving) return;
    _saving = true;

    final text = _selectedText;
    final lines = List<PdfTextLine>.from(_selectedLines);

    // PdfTextLine.pageNumber is 1-based — store it as-is.
    // _navigateToHighlight passes it directly to jumpToPage() without +1.
    final pageNumber = lines.first.pageNumber;

    final messenger = ScaffoldMessenger.of(context);

    // Step 1: Add annotation visually
    final annotation = HighlightAnnotation(textBoundsCollection: lines);
    annotation.color = color;
    annotation.opacity = 0.55;
    _controller.addAnnotation(annotation);
    _controller.clearSelection();

    // Step 2: Save to disk
    try {
      final savedBytes = await _controller.saveDocument();
      final newBytes = Uint8List.fromList(savedBytes);
      await File(widget.document.filePath).writeAsBytes(newBytes);
      _pdfBytes = newBytes;
    } catch (e) {
      debugPrint('[PdfReader] saveDocument error: $e');
    }

    // Step 3: Persist metadata
    if (!mounted) { _saving = false; return; }
    String? newId;
    try {
      final boundsFlat = lines
          .expand((l) => [l.bounds.left, l.bounds.top, l.bounds.width, l.bounds.height])
          .toList();
      newId = await context.read<HighlightProvider>().addHighlight(
            docId: widget.document.id,
            page: pageNumber,
            text: text,
            colorValue: color.toARGB32(),
            bounds: [
              lines.first.bounds.left,
              lines.first.bounds.top,
              lines.first.bounds.width,
              lines.first.bounds.height,
            ],
            boundsCollectionFlat: boundsFlat,
          );
    } catch (e) {
      debugPrint('[PdfReader] addHighlight storage error: $e');
    }

    // Step 4: Register live annotation by id
    if (newId != null) {
      final all = _controller.getAnnotations();
      if (all.isNotEmpty) {
        _annotationRegistry[newId] = all.last;
      }
    }

    _selectedText = '';
    _selectedLines = [];

    if (mounted) messenger.showSnackBar(_buildSnackBar('Highlight saved', color));
    _saving = false;
  }

  void _snackbar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(msg, color));
  }

  SnackBar _buildSnackBar(String msg, Color color) => SnackBar(
        content: Row(children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(msg, style: const TextStyle(color: Colors.white)),
        ]),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      );

  @override
  Widget build(BuildContext context) {
    if (_firstLoad || _pdfBytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SfPdfViewer.memory(
      _pdfBytes!,
      key: _pdfViewerKey,
      controller: _controller,
      initialPageNumber: _currentPage,
      enableTextSelection: true,
      canShowTextSelectionMenu: false,
      // Immediately deselect any annotation the user taps.
      // This prevents the internal annotation toolbar (Tooltip widgets
      // using SingleTickerProviderStateMixin) from being built, which
      // caused the RawTooltipState ticker crash on rapid tap/deselect cycles.
      onAnnotationSelected: (annotation) {
        // Deselect on next frame so the viewer registers the selection
        // before we clear it — avoids assertion errors.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _controller.deselectAnnotation(annotation);
        });
      },
      onDocumentLoaded: (details) {
        final total = details.document.pages.count;
        context.read<ReaderProvider>()
          ..setTotalPages(total)
          ..setPage(_currentPage);
        // Add live scroll listener — fires on every scroll/zoom frame
        _controller.addListener(_updateSliderFromScroll);
        // Calculate total content height for continuous scroll mapping
        _calculateTotalContentHeight();
        // Register slider drag: drags scroll PDF live via jumpTo
        context.read<ReaderProvider>().registerSliderDragCallback((fraction) {
          _handleSliderDrag(fraction, total);
        });
        _rebuildAnnotationRegistry();
      },
      onPageChanged: (details) {
        _currentPage = details.newPageNumber;
        // setScrollFraction keeps slider smooth between pages
        final total = context.read<ReaderProvider>().totalPages;
        final fraction = total > 1
            ? (details.newPageNumber - 1) / (total - 1)
            : 0.0;
        context.read<ReaderProvider>().setScrollFraction(fraction);
      },
      onZoomLevelChanged: (_) {
        // Recalculate total height after zoom so fraction stays accurate
        _calculateTotalContentHeight();
      },
      onTextSelectionChanged: _onTextSelectionChanged,
    );
  }

  // ── Live scroll ↔ slider sync ──────────────────────────────────────────

  /// Calculates total scrollable content height by jumping to first/last page.
  /// Called once on load and again after zoom changes.
  Future<void> _calculateTotalContentHeight() async {
    if (!mounted) return;
    if (_controller.pageCount <= 1) {
      _totalContentHeight = 0.0;
      return;
    }

    final originalOffset = _controller.scrollOffset;

    try {
      _controller.jumpToPage(1);
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      final startY = _controller.scrollOffset.dy;

      _controller.jumpToPage(_controller.pageCount);
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      final endY = _controller.scrollOffset.dy;

      _totalContentHeight =
          (endY - startY).abs().clamp(1.0, double.infinity);
    } finally {
      if (mounted) _controller.jumpTo(yOffset: originalOffset.dy);
    }
  }

  /// Called by controller.addListener — fires on every scroll frame.
  /// Skipped while slider is being dragged to prevent feedback loop.
  void _updateSliderFromScroll() {
    if (!mounted || _isSliderDragging) return;
    final provider = context.read<ReaderProvider>();
    if (_totalContentHeight <= 0) return;

    // ~60fps debounce — reduces update frequency without losing smoothness
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 16), () {
      if (!mounted || _isSliderDragging) return;
      final fraction =
          (_controller.scrollOffset.dy / _totalContentHeight).clamp(0.0, 1.0);
      provider.setScrollFraction(fraction);
    });
  }

  /// Called by slider drag via registerSliderDragCallback.
  /// Locks _isSliderDragging so _updateSliderFromScroll is suppressed
  /// during the drag — prevents the oscillation feedback loop.
  void _handleSliderDrag(double fraction, int totalPages) {
    if (_totalContentHeight <= 0) {
      final page =
          totalPages > 1 ? (fraction * (totalPages - 1)).round() + 1 : 1;
      _controller.jumpToPage(page.clamp(1, totalPages));
      return;
    }

    _isSliderDragging = true;
    _controller.jumpTo(yOffset: fraction * _totalContentHeight);

    // Release lock after PDF has settled
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _isSliderDragging = false;
    });
  }

  // ── Rebuild annotation registry ───────────────────────────────────────
  // Called on every onDocumentLoaded. Page numbers are 1-based in both
  // storage (PdfTextLine.pageNumber) and the viewer (Annotation.pageNumber).
  void _rebuildAnnotationRegistry() {
    _annotationRegistry.clear();

    final highlights = List.of(context.read<HighlightProvider>().highlights)
      ..sort((a, b) => a.page.compareTo(b.page));

    final liveAnnotations = _controller.getAnnotations();
    if (liveAnnotations.isEmpty || highlights.isEmpty) return;

    final Map<int, List<Annotation>> byPage = {};
    for (final a in liveAnnotations) {
      byPage.putIfAbsent(a.pageNumber, () => []).add(a);
    }

    for (final h in highlights) {
      final candidates = List<Annotation>.from(byPage[h.page] ?? []);
      if (candidates.isEmpty) continue;

      final targetColor = Color(h.colorValue);

      Annotation? match;
      for (final a in candidates) {
        if (_colorsMatch(a.color, targetColor)) {
          match = a;
          break;
        }
      }
      match ??= candidates.first;

      _annotationRegistry[h.id] = match;
      byPage[h.page]?.remove(match);
    }
  }

  bool _colorsMatch(Color a, Color b) =>
      (a.r - b.r).abs() < 0.04 &&
      (a.g - b.g).abs() < 0.04 &&
      (a.b - b.b).abs() < 0.04;
}
