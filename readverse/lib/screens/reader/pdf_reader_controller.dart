/// Thin controller that bridges PdfReader ↔ HighlightsPanel ↔ DocxReader.
class PdfReaderController {
  void Function(String highlightId, int page)? onNavigateToHighlight;
  Future<void> Function(String highlightId)? onDeleteHighlight;

  /// Called by next/prev buttons — text readers scroll to that page.
  void Function(int page)? onPageChanged;

  /// Called by slider drag (onChanged) — text readers jump instantly to fraction.
  /// This is separate from onPageChanged so we can use jumpTo (no animation)
  /// while the finger is moving, giving real-time response.
  void Function(double fraction)? onScrollFraction;

  void navigateTo(String highlightId, int page) =>
      onNavigateToHighlight?.call(highlightId, page);

  Future<void> delete(String highlightId) =>
      onDeleteHighlight?.call(highlightId) ?? Future.value();

  /// Called by next/prev buttons — animated scroll.
  void jumpToPage(int page) => onPageChanged?.call(page);

  /// Called by slider drag — instant scroll, no animation.
  void scrollToFraction(double fraction) => onScrollFraction?.call(fraction);
}
