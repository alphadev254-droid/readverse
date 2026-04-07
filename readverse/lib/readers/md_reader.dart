import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/document_model.dart';
import '../providers/highlight_provider.dart';
import '../providers/reader_provider.dart';
import '../widgets/highlight_bar.dart';
import '../screens/reader/pdf_reader_controller.dart';

class MdReader extends StatefulWidget {
  final DocumentModel document;
  final PdfReaderController readerController;

  const MdReader({
    super.key,
    required this.document,
    required this.readerController,
  });

  @override
  State<MdReader> createState() => _MdReaderState();
}

class _MdReaderState extends State<MdReader> {
  final ScrollController _scrollController = ScrollController();

  String _rawMarkdown = '';
  bool _firstLoad = true;
  int _totalPages = 1;

  final Map<String, _MdHighlight> _highlights = {};
  String? _flashingId;

  OverlayEntry? _overlayEntry;
  String _selectedText = '';
  int _selStart = 0;
  int _selEnd = 0;
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
    final map = <String, _MdHighlight>{};
    for (final h in stored) {
      if (h.bounds.length >= 2) {
        map[h.id] = _MdHighlight(
          start: h.bounds[0].toInt(),
          end: h.bounds[1].toInt(),
          color: Color(h.colorValue),
        );
      }
    }

    setState(() {
      _rawMarkdown = raw;
      _highlights.addAll(map);
      _firstLoad = false;
    });

    if (!mounted) return;
    _totalPages = (_rawMarkdown.length / 3000).ceil().clamp(1, 99999);
    final rp = context.read<ReaderProvider>();
    rp.setTotalPages(_totalPages);
    rp.setPage(1);
    rp.registerSliderDragCallback(_scrollToFraction);

    final lastPage = widget.document.lastPage;
    if (lastPage > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPage(lastPage));
    }

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

  void _scrollToPage(int page) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final fraction = _totalPages > 1 ? (page - 1) / (_totalPages - 1) : 0.0;
    _scrollController.jumpTo((fraction * max).clamp(0.0, max));
  }

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
    final fraction =
        h.start / _rawMarkdown.length.clamp(1, _rawMarkdown.length);
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

  Future<void> _deleteHighlight(String highlightId) async {
    setState(() => _highlights.remove(highlightId));
    if (mounted) {
      await context.read<HighlightProvider>().removeHighlight(highlightId);
    }
  }

  // ── Overlay menu ───────────────────────────────────────────────────────
  void _showOverlayMenu(String text) {
    _closeOverlay();
    _selectedText = text;
    final idx = _rawMarkdown.indexOf(text);
    _selStart = idx >= 0 ? idx : 0;
    _selEnd = _selStart + text.length;

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 240.0;
    const menuHeight = 60.0;

    final top = (screenSize.height * 0.35)
        .clamp(24.0, screenSize.height - menuHeight - 24);
    final left = (screenSize.width / 2 - menuWidth / 2)
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

  Future<void> _saveHighlight(Color color) async {
    if (_selectedText.isEmpty || _saving) return;
    _saving = true;

    final start = _selStart;
    final end = _selEnd;
    final text = _selectedText;
    final messenger = ScaffoldMessenger.of(context);

    final tempId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _highlights[tempId] = _MdHighlight(start: start, end: end, color: color);
    });

    if (!mounted) { _saving = false; return; }

    String newId;
    try {
      newId = await context.read<HighlightProvider>().addHighlight(
        docId: widget.document.id,
        page: (start / 3000).floor(),
        text: text,
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
      _highlights[newId] = _MdHighlight(start: start, end: end, color: color);
    });

    _selectedText = '';
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

  @override
  Widget build(BuildContext context) {
    if (_firstLoad) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(height: 1.7, fontSize: 16),
      h1: theme.textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.bold),
      h2: theme.textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.bold),
      h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      code: TextStyle(
        fontFamily: 'monospace',
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        fontSize: 14,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 4)),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
      ),
    );

    return SelectionArea(
      onSelectionChanged: (value) {
        if (value == null || value.plainText.trim().isEmpty) {
          _closeOverlay();
          return;
        }
        _showOverlayMenu(value.plainText.trim());
      },
      contextMenuBuilder: (_, __) => const SizedBox.shrink(),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          _onScroll();
          return false;
        },
        child: Markdown(
          controller: _scrollController,
          data: _rawMarkdown,
          styleSheet: styleSheet,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          selectable: false,
        ),
      ),
    );
  }
}

class _MdHighlight {
  final int start;
  final int end;
  final Color color;
  const _MdHighlight(
      {required this.start, required this.end, required this.color});
}
