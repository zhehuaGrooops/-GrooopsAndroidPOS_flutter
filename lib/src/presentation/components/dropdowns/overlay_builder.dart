part of 'custom_dropdown.dart';

class _OverlayBuilder extends StatefulWidget {
  final Widget Function(Size, VoidCallback) overlay;
  final Widget Function(VoidCallback) child;

  const _OverlayBuilder({
    required this.overlay,
    required this.child,
  });

  @override
  _OverlayBuilderState createState() => _OverlayBuilderState();
}

class _OverlayBuilderState extends State<_OverlayBuilder> {
  OverlayEntry? overlayEntry;

  bool get isShowingOverlay => overlayEntry != null;

  void showOverlay() {
    if (!mounted) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final size = renderObject.size;

    // Build an OverlayEntry that does NOT access this State.context later.
    overlayEntry = OverlayEntry(
      builder: (_) => widget.overlay(size, hideOverlay),
    );

    addToOverlay(overlayEntry!);
  }

  void addToOverlay(OverlayEntry entry) => Overlay.of(context).insert(entry);

  void hideOverlay() {
    overlayEntry!.remove();
    overlayEntry = null;
  }

  @override
  void dispose() {
    // Ensure overlay removed if still present when this State is disposed.
    try {
      overlayEntry?.remove();
    } catch (_) {}
    overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child(showOverlay);
}
