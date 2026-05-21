import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/template_editor_provider.dart';
import 'canvas_element_widget.dart';
import 'rubber_band_widget.dart';
import 'selection_handles_widget.dart';
import 'snap_guide_widget.dart';

/// The main WYSIWYG canvas. Wraps an A4-proportioned white Stack inside
/// an InteractiveViewer for zoom/pan. All element coordinates are in
/// canvas logical units (595 × 842); the InteractiveViewer handles the
/// viewport transform.
class EditorCanvasWidget extends StatefulWidget {
  const EditorCanvasWidget({super.key});

  @override
  State<EditorCanvasWidget> createState() => _EditorCanvasWidgetState();
}

class _EditorCanvasWidgetState extends State<EditorCanvasWidget> {
  final TransformationController _transformController =
      TransformationController();

  // Rubber-band state — all in canvas-local coordinates (localPosition).
  Offset? _rubberStart;
  double _rubberX = 0, _rubberY = 0, _rubberW = 0, _rubberH = 0;
  bool _isRubberBanding = false;

  bool _didCenter = false;
  int _handledFocusRequestVersion = 0;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  // Center the page horizontally within the available viewport on first render.
  void _centerPage(Size viewSize, double pageW) {
    if (_didCenter) return;
    _didCenter = true;
    const padding = 48.0;
    final contentW = pageW + padding * 2;
    final dx = ((viewSize.width - contentW) / 2).clamp(0.0, 400.0);
    if (dx > 4) {
      _transformController.value =
          Matrix4.identity()..translate(dx, 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TemplateEditorProvider>();
    final pageSize = provider.template?.pageSize;
    final pageW = pageSize?.width ?? 595.0;
    final pageH = pageSize?.height ?? 842.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Center on the very first layout pass (only once).
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            _centerPage(constraints.biggest, pageW);
            _handleFocusRequest(provider, constraints.biggest);
          },
        );

        return Container(
          color: AppColors.pageBackground,
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.2,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(1200),
                constrained: false,
                // Keep wheel/trackpad gestures for panning long pages.
                // Zoom is intentionally only via the controls to avoid
                // accidental mouse-wheel zoom-outs.
                trackpadScrollCausesScale: false,
                onInteractionUpdate: (_) => provider.setZoom(
                  _transformController.value.getMaxScaleOnAxis(),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: _buildPage(context, provider, pageW, pageH),
                ),
              ),

              // Zoom controls — bottom-right corner
              Positioned(
                right: 12,
                bottom: 12,
                child: _ZoomControls(
                  controller: _transformController,
                  viewportSize: constraints.biggest,
                  pageWidth: pageW,
                  onScaleChanged: provider.setZoom,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleFocusRequest(
    TemplateEditorProvider provider,
    Size viewportSize,
  ) {
    if (_handledFocusRequestVersion == provider.focusRequestVersion) return;
    _handledFocusRequestVersion = provider.focusRequestVersion;

    final id = provider.focusRequestId;
    if (id == null) return;

    final matches = provider.elements.where((el) => el.id == id);
    if (matches.isEmpty) return;
    final el = matches.first;

    const pagePadding = 48.0;
    final scale = _transformController.value.getMaxScaleOnAxis()
        .clamp(0.2, 5.0)
        .toDouble();
    final scenePoint = Offset(
      pagePadding + el.x + el.width / 2,
      pagePadding + el.y + el.height / 2,
    );

    _transformController.value = Matrix4.identity()
      ..translate(
        viewportSize.width / 2 - scenePoint.dx * scale,
        viewportSize.height / 2 - scenePoint.dy * scale,
      )
      ..scale(scale);
    provider.setZoom(scale);
  }

  Widget _buildPage(
    BuildContext context,
    TemplateEditorProvider provider,
    double pageW,
    double pageH,
  ) {
    return Container(
      width: pageW,
      height: pageH,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      // onTap (not onTapDown) so that touching a resize handle doesn't
      // immediately deselect — see selection_handles_widget.dart.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // TapGestureRecognizer fires handleTapUp during its own dispose(),
          // which runs inside finalizeTree while the framework is locked.
          // Deferring to the next frame avoids the markNeedsBuild-while-locked crash.
          if (!mounted) return;
          final p = context.read<TemplateEditorProvider>();
          WidgetsBinding.instance.addPostFrameCallback((_) => p.deselectAll());
        },
        onPanStart: (d) => _onRubberStart(d.localPosition),
        onPanUpdate: (d) => _onRubberUpdate(d.localPosition),
        onPanEnd: (_) => _onRubberEnd(provider),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            _MarginGuides(pageW: pageW, pageH: pageH),
            ...provider.sortedElements.map(
              (el) => CanvasElementWidget(
                key: ValueKey(el.id),
                element: el,
                transformController: _transformController,
              ),
            ),
            SnapGuideWidget(
              guidesNotifier: provider.snapGuides,
              pageWidth: pageW,
              pageHeight: pageH,
            ),
            CanvasSelectionLayer(
              transformController: _transformController,
            ),
            if (_isRubberBanding)
              RubberBandWidget(
                x: _rubberX,
                y: _rubberY,
                width: _rubberW,
                height: _rubberH,
              ),
          ],
        ),
      ),
    );
  }

  // ── Rubber-band ───────────────────────────────────────────────────────

  void _onRubberStart(Offset local) {
    _rubberStart = local;
    setState(() {
      _rubberX = local.dx;
      _rubberY = local.dy;
      _rubberW = 0;
      _rubberH = 0;
      _isRubberBanding = false;
    });
  }

  void _onRubberUpdate(Offset local) {
    if (_rubberStart == null) return;
    setState(() {
      _rubberW = local.dx - _rubberStart!.dx;
      _rubberH = local.dy - _rubberStart!.dy;
      _isRubberBanding = (_rubberW.abs() + _rubberH.abs()) > 8;
    });
  }

  void _onRubberEnd(TemplateEditorProvider provider) {
    if (_isRubberBanding) {
      provider.selectByRubberBand(_rubberX, _rubberY, _rubberW, _rubberH);
    }
    setState(() {
      _rubberStart = null;
      _isRubberBanding = false;
      _rubberW = 0;
      _rubberH = 0;
    });
  }
}

// ── Zoom controls ─────────────────────────────────────────────────────────────

class _ZoomControls extends StatelessWidget {
  final TransformationController controller;
  final Size viewportSize;
  final double pageWidth;
  final ValueChanged<double> onScaleChanged;

  const _ZoomControls({
    required this.controller,
    required this.viewportSize,
    required this.pageWidth,
    required this.onScaleChanged,
  });

  double get _scale => controller.value.getMaxScaleOnAxis();

  void _zoom(double factor) {
    final nextScale = (_scale * factor).clamp(0.2, 5.0).toDouble();
    final focal = Offset(viewportSize.width / 2, viewportSize.height / 2);
    final scenePoint = controller.toScene(focal);
    final next = Matrix4.identity()
      ..translate(
        focal.dx - scenePoint.dx * nextScale,
        focal.dy - scenePoint.dy * nextScale,
      )
      ..scale(nextScale);
    controller.value = next;
    onScaleChanged(nextScale);
  }

  void _reset() {
    const padding = 48.0;
    final contentW = pageWidth + padding * 2;
    final dx =
        ((viewportSize.width - contentW) / 2).clamp(0.0, 400.0).toDouble();
    controller.value = Matrix4.identity()..translate(dx, 0.0);
    onScaleChanged(1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 6),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomBtn(
              icon: Icons.add,
              tooltip: 'Zoom in (⌘+)',
              onTap: () => _zoom(1.2),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${(_scale * 100).round()}%',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            _ZoomBtn(
              icon: Icons.remove,
              tooltip: 'Zoom out (⌘-)',
              onTap: () => _zoom(1 / 1.2),
            ),
            const Divider(height: 1, thickness: 0.5, indent: 6, endIndent: 6),
            _ZoomBtn(
              icon: Icons.fit_screen_outlined,
              tooltip: 'Reset zoom (⌘0)',
              onTap: _reset,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ZoomBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16, color: const Color(0xFF475569)),
          ),
        ),
      );
}

// ── Margin guides ─────────────────────────────────────────────────────────────

class _MarginGuides extends StatelessWidget {
  final double pageW;
  final double pageH;

  const _MarginGuides({required this.pageW, required this.pageH});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          size: Size(pageW, pageH),
          painter: _MarginPainter(pageW, pageH),
        ),
      );
}

class _MarginPainter extends CustomPainter {
  final double pageW;
  final double pageH;
  static const double _margin = 8.0;

  const _MarginPainter(this.pageW, this.pageH);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x22B0C4DE)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRect(Rect.fromLTWH(
          _margin, _margin, pageW - _margin * 2, pageH - _margin * 2));

    const dashLen = 4.0;
    const gapLen = 3.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_MarginPainter old) =>
      old.pageW != pageW || old.pageH != pageH;
}
