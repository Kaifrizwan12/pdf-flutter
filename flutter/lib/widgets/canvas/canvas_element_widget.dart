import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/template_element_model.dart';
import '../../providers/template_editor_provider.dart';
import '../elements/divider_element_widget.dart';
import '../elements/image_element_widget.dart';
import '../elements/logo_element_widget.dart';
import '../elements/signature_block_widget.dart';
import '../elements/table_element_widget.dart';
import '../elements/text_element_widget.dart';

/// Wraps a single template element with drag, tap, double-tap, and
/// context-menu interactions. During drag it reads a per-element
/// ValueNotifier<Offset> instead of rebuilding the full provider tree.
class CanvasElementWidget extends StatefulWidget {
  final TemplateElement element;
  final TransformationController transformController;

  const CanvasElementWidget({
    super.key,
    required this.element,
    required this.transformController,
  });

  @override
  State<CanvasElementWidget> createState() => _CanvasElementWidgetState();
}

class _CanvasElementWidgetState extends State<CanvasElementWidget> {
  double _startX = 0, _startY = 0;
  bool _isDragging = false;
  Offset? _pointerDown;
  int? _activePointer;

  TemplateEditorProvider get _provider =>
      context.read<TemplateEditorProvider>();

  @override
  Widget build(BuildContext context) {
    final el = widget.element;
    if (!el.visible) return const SizedBox.shrink();

    // Use ValueListenableBuilder for the drag position so only this widget
    // rebuilds during drag, not the entire canvas consumer.
    final dragNotifier = _provider.dragPositionFor(el.id);
    final isDragging = _isDragging || dragNotifier != null;

    return ValueListenableBuilder<Offset>(
      valueListenable: dragNotifier ?? ValueNotifier(Offset(el.x, el.y)),
      builder: (context, pos, _) {
        final x = dragNotifier != null ? pos.dx : el.x;
        final y = dragNotifier != null ? pos.dy : el.y;

        return Positioned(
          left: x,
          top: y,
          width: el.width,
          height: el.height,
          child: _buildInteractiveLayer(el, x, y, isDragging),
        );
      },
    );
  }

  Widget _buildInteractiveLayer(
    TemplateElement el,
    double x,
    double y,
    bool isDragging,
  ) {
    return Selector<TemplateEditorProvider,
        ({bool selected, bool editingText})>(
      selector: (_, p) => (
        selected: p.isSelected(el.id),
        editingText: p.editingTextId == el.id,
      ),
      builder: (context, state, _) {
        final content = _applyDragShadow(
          el,
          _buildElementContent(el, state.editingText, state.selected),
          isDragging,
        );

        if (el.locked) return content;

        // While a TextField is active, let it own ALL pointer events.
        // Keeping a GestureDetector with HitTestBehavior.opaque around an
        // active TextField causes a Flutter Web engine assertion
        // (targetElement == domElement) on every mouse move.
        if (state.editingText) return content;

        final allowDoubleTap = el is! SignatureBlockElement;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: content),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) => _onPointerDown(event, el),
                onPointerMove: (event) => _onPointerMove(event, el),
                onPointerUp: (event) => _onPointerUp(event, el),
                onPointerCancel: (event) => _onPointerCancel(event, el),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _provider.selectElement(
                  el.id,
                  addToSelection: _isShiftHeld(),
                ),
                onDoubleTap: allowDoubleTap ? () => _handleDoubleTap(el) : null,
                onLongPress: () => _showContextMenu(el),
              ),
            ),
          ],
        );
      },
    );
  }

  // Every element is clipped to its model bounds so that content that
  // overflows (e.g. Flutter's Table widget, which ignores tight height
  // constraints) never bleeds into adjacent elements or makes the
  // selection box appear smaller than the visible content.
  Widget _buildElementContent(
    TemplateElement el,
    bool isEditingText,
    bool isSelected,
  ) {
    final inner = switch (el) {
      TextElement te => TextElementWidget(
          element: te,
          isEditing: isEditingText,
          onCommit: (text) => _provider.commitTextEdit(te.id, text),
        ),
      ImageElement ie => ImageElementWidget(element: ie),
      TableElement tbl => TableElementWidget(
          element: tbl,
          isEditing: isEditingText,
          provider: _provider,
        ),
      LogoElement le => LogoElementWidget(element: le),
      SignatureBlockElement sb => SignatureBlockWidget(
          element: sb,
          isSelected: isSelected,
          onChanged: _provider.updateElement,
          onSelect: () => _provider.selectElement(sb.id),
          onBeginEdit: () => _provider.beginInlineEdit(sb.id),
          onEndEdit: _provider.endInlineEdit,
        ),
      DividerElement de => DividerElementWidget(element: de),
    };
    return ClipRect(child: inner);
  }

  Widget _applyDragShadow(
    TemplateElement el,
    Widget child,
    bool isDragging,
  ) {
    if (!isDragging) return child;

    final borderRadius = switch (el) {
      ImageElement ie => BorderRadius.circular(ie.borderRadius),
      _ => BorderRadius.zero,
    };

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }

  void _handleDoubleTap(TemplateElement el) {
    switch (el) {
      case TextElement _:
        _provider.beginTextEdit(el.id);
      case LogoElement le:
        _pickAndReplaceLogo(le);
      default:
        _provider.selectElement(el.id);
    }
  }

  Future<void> _pickAndReplaceLogo(LogoElement el) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ext = (file.extension ?? 'png').toLowerCase();
    final mime = (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : 'image/png';
    final src = 'data:$mime;base64,${base64Encode(bytes)}';

    _provider.updateElement(el.copyWith(src: src));
  }

  void _onPointerDown(PointerDownEvent event, TemplateElement el) {
    if (el.locked || _provider.editingTextId == el.id) return;
    _activePointer = event.pointer;
    _pointerDown = event.position;
    _startX = el.x;
    _startY = el.y;
  }

  void _onPointerMove(PointerMoveEvent event, TemplateElement el) {
    if (_activePointer != event.pointer || _pointerDown == null) return;

    final delta = event.position - _pointerDown!;
    if (!_isDragging && delta.distance < 4.0) return;

    if (!_isDragging) {
      if (!_provider.isSelected(el.id)) {
        _provider.selectElement(el.id);
      }
      _provider.beginDrag(el.id);
      if (mounted) setState(() => _isDragging = true);
    }

    final scale = widget.transformController.value.getMaxScaleOnAxis();
    _provider.updateDrag(
      el.id,
      _startX + delta.dx / scale,
      _startY + delta.dy / scale,
    );
  }

  void _onPointerUp(PointerUpEvent event, TemplateElement el) {
    if (_activePointer != event.pointer) return;
    _finishDrag(el);
  }

  void _onPointerCancel(PointerCancelEvent event, TemplateElement el) {
    if (_activePointer != event.pointer) return;
    _finishDrag(el);
  }

  void _finishDrag(TemplateElement el) {
    _pointerDown = null;
    _activePointer = null;
    if (_isDragging) {
      _provider.endDrag(el.id);
    }
    if (!mounted) return;
    setState(() => _isDragging = false);
  }

  bool _isShiftHeld() => HardwareKeyboard.instance.isShiftPressed;

  void _showContextMenu(TemplateElement el) {
    _provider.selectElement(el.id);
    // Long-press context menu for mobile (no physical keyboard).
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ContextMenuSheet(
        element: el,
        provider: _provider,
      ),
    );
  }
}

class _ContextMenuSheet extends StatelessWidget {
  final TemplateElement element;
  final TemplateEditorProvider provider;

  const _ContextMenuSheet({required this.element, required this.provider});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tile(context, 'Copy', Icons.copy, () => provider.copySelected()),
          _tile(context, 'Cut', Icons.cut, () => provider.cutSelected()),
          _tile(context, 'Paste', Icons.paste, () => provider.paste()),
          _tile(context, 'Duplicate', Icons.control_point_duplicate,
              () => provider.duplicateSelected()),
          _tile(context, 'Bring Forward', Icons.flip_to_front,
              () => provider.bringForward(element.id)),
          _tile(context, 'Send Back', Icons.flip_to_back,
              () => provider.sendBackward(element.id)),
          _tile(context, 'Delete', Icons.delete_outline,
              () => provider.deleteSelected(),
              isDestructive: true),
        ],
      ),
    );
  }

  ListTile _tile(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) =>
      ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : null, size: 20),
        title: Text(label,
            style: TextStyle(color: isDestructive ? Colors.red : null)),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
}
