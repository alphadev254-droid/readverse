import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/document_model.dart';
import '../providers/highlight_provider.dart';
import '../providers/reader_provider.dart';
import '../widgets/highlight_bar.dart';
import '../screens/reader/pdf_reader_controller.dart';

class TxtReader extends StatefulWidget {
  final DocumentModel document;
  final PdfReaderController readerController;

  const TxtReader({
    super.key,
    required this.document,
    required this.readerController,
  });

  @override
  State<TxtReader> createState() => _TxtReaderState();
}

class _TxtReaderState extends State<TxtReader> {
  final ScrollController _scrollController = ScrollController();

  String _text = '';
  bool _firstLoad = true;
  bool _pageInfoSet = false;
  int _totalPages = 1;

  final Map<String, _TxtHighlight> _highlights = {};
  String? _flashingId;

  OverlayEntry? _overlayEntry;
  String _selectedText = '';
  TextSelection? _currentSelection;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.readerController.onNavigateToHighlight = _navigateToHighlight;
    widget.readerController.onDeleteHighlight = _deleteHighlight;
    widget.readerController.onPageChanged = _scrollToPage;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  @override
  void dispose() {
    context.read<ReaderProvider>().unregisterSliderDragCallback();
    _closeOverlay();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    final raw = await File(widget.document.filePath).readAsString();
    if (!mounted) return;

    final stored = context.read<HighlightProvider>().highlights;
    final map = <String, _TxtHighlight>{};
    for (final h in stored) {
      if (h.bounds.length >= 2) {
        map[h.id] = _TxtHighlight(
          start: h.bounds[0].toInt(),
          end: h.bounds[1].toInt(),
          color: Color(h.colorValue),
        );
      }
    }

    setState(() {
      _text = raw;
      _highlights.addAll(map);
      _firstLoad = false;
    });

    if (!mounted) return;
    _totalPages = (_text.length / 3000).ceil().clamp(1, 99999);
    final rp = context.read<ReaderProvider>();
    rp.setTotalPages(_totalPages);
    rp.setPage(1);
    rp.registerSliderDragCallback(_scrollToFraction);

    final lastPage = widget.document.lastPage;
    if (lastPage > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPage(lastPage));
    }

    // Start listening to scroll after layout
    _scrollController.addListener(_onScroll);
  }

  // ── Scroll tracking ────────────────────────────────────────────────────
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final fraction = (_scrollController.offset / max).clamp(0.0, 1.0);
    context.read<ReaderProvider>().setScrollFraction(fraction);
  }

  // Called by next/prev buttons via _PageChangeForwarder
  void _scrollToPage(int page) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final fraction = _totalPages > 1 ? (page - 1) / (_totalPages - 1) : 0.0;
    _scrollController.jumpTo((fraction * max).clamp(0.0, max));
  }

  // Called by slider drag via registerSliderDragCallback — instant
  void _scrollToFraction(double fraction) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo((fraction * max).clamp(0.0, max));
  }

  // ── Navigate to highlight ──────────────────────────────────────────────
  void _navigateToHighlight(String highlightId, int page) {
    final h = _highlights[highlightId];
    if (h == null) return;
    if (!_scrollController.hasClients) return;
    final fraction = h.start / _text.length.clamp(1, _text.length);
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      (fraction * max).clamp(0.0, max),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() => _flashingId = highlightId);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _flashingId = null);
    });
  }

  // ── Delete highlight ───────────────────────────────────────────────────
  Future<void> _deleteHighlight(String highlightId) async {
    setState(() => _highlights.remove(highlightId));
    if (mounted) {
      await context.read<HighlightProvider>().removeHighlight(highlightId);
    }
  }

  // ── Overlay menu ───────────────────────────────────────────────────────
  void _showOverlayMenu(Rect region, String text, TextSelection sel) {
    _closeOverlay();
    _selectedText = text;
    _currentSelection = sel;

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 240.0;
    const menuHeight = 60.0;

    double top = region.top - menuHeight - 12;
    if (top < 24) top = region.bottom + 12;
    top = top.clamp(24.0, screenSize.height - menuHeight - 24);
    final left = (region.center.dx - menuWidth / 2)
        .clamp(12.0, screenSize.width - menuWidth - 12);

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: top,
        left: left,
        child: Material(
          color: Colors.transparent,
          child: HighlightBar(
            selectedText: text,
            onHighlight: (color) {
              _closeOverlay();
              _saveHighlight(color);
            },
            onCopy: () {
              _closeOverlay();
              Clipboard.setData(ClipboardData(text: text));
              _snackbar('Copied to clipboard', Colors.blueGrey);
            },
            onClose: _closeOverlay,
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── Save highlight ─────────────────────────────────────────────────────
  Future<void> _saveHighlight(Color color) async {
    final sel = _currentSelection;
    if (_selectedText.isEmpty || sel == null || _saving) return;
    _saving = true;

    final start = sel.start;
    final end = sel.end;
    final messenger = ScaffoldMessenger.of(context);

    final tempId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _highlights[tempId] = _TxtHighlight(start: start, end: end, color: color);
    });

    if (!mounted) { _saving = false; return; }

    String newId;
    try {
      newId = await context.read<HighlightProvider>().addHighlight(
        docId: widget.document.id,
        page: (start / 3000).floor(),
        text: _selectedText,
        colorValue: color.toARGB32(),
        bounds: [start.toDouble(), end.toDouble(), 0, 0],
      );
    } catch (e) {
      setState(() => _highlights.remove(tempId));
      _saving = false;
      return;
    }

    setState(() {
      _highlights.remove(tempId);
      _highlights[newId] = _TxtHighlight(start: start, end: end, color: color);
    });

    _selectedText = '';
    _currentSelection = null;
    messenger.showSnackBar(_buildSnackBar('Highlight saved', color));
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

  // ── Build highlighted RichText ─────────────────────────────────────────
  List<TextSpan> _buildSpans(ThemeData theme) {
    if (_highlights.isEmpty) return [TextSpan(text: _text)];

    final sorted = _highlights.entries.toList()
      ..sort((a, b) => a.value.start.compareTo(b.value.start));

    final spans = <TextSpan>[];
    int cursor = 0;

    for (final entry in sorted) {
      final id = entry.key;
      final h = entry.value;
      final start = h.start.clamp(0, _text.length);
      final end = h.end.clamp(0, _text.length);
      if (start >= end) continue;

      if (cursor < start) {
        spans.add(TextSpan(text: _text.substring(cursor, start)));
      }

      final isFlashing = _flashingId == id;
      spans.add(TextSpan(
        text: _text.substring(start, end),
        style: TextStyle(
          backgroundColor:
              isFlashing ? Colors.white : h.color.withValues(alpha: 0.45),
        ),
      ));
      cursor = end;
    }

    if (cursor < _text.length) {
      spans.add(TextSpan(text: _text.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    if (_firstLoad) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: 16,
      height: 1.6,
      color: theme.colorScheme.onSurface,
    );

    return SelectionArea(
      onSelectionChanged: (value) {
        if (value == null || value.plainText.trim().isEmpty) {
          _closeOverlay();
          return;
        }
        final selectedText = value.plainText.trim();
        final idx = _text.indexOf(selectedText);
        if (idx < 0) return;

        final screenSize = MediaQuery.of(context).size;
        final region = Rect.fromCenter(
          center: Offset(screenSize.width / 2, screenSize.height * 0.4),
          width: 200,
          height: 40,
        );
        _showOverlayMenu(
          region,
          selectedText,
          TextSelection(baseOffset: idx, extentOffset: idx + selectedText.length),
        );
      },
      contextMenuBuilder: (_, __) => const SizedBox.shrink(),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          _onScroll();
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: RichText(
            text: TextSpan(style: textStyle, children: _buildSpans(theme)),
          ),
        ),
      ),
    );
  }
}

class _TxtHighlight {
  final int start;
  final int end;
  final Color color;
  const _TxtHighlight(
      {required this.start, required this.end, required this.color});
}
