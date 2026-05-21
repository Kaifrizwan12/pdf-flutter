import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/template_editor_provider.dart';

// ── Intent declarations ──────────────────────────────────────────────────────

class UndoIntent extends Intent { const UndoIntent(); }
class RedoIntent extends Intent { const RedoIntent(); }
class CopyIntent extends Intent { const CopyIntent(); }
class CutIntent extends Intent { const CutIntent(); }
class PasteIntent extends Intent { const PasteIntent(); }
class DuplicateIntent extends Intent { const DuplicateIntent(); }
class SelectAllIntent extends Intent { const SelectAllIntent(); }
class DeleteElementIntent extends Intent { const DeleteElementIntent(); }
class DeselectIntent extends Intent { const DeselectIntent(); }
class BringForwardIntent extends Intent { const BringForwardIntent(); }
class SendBackwardIntent extends Intent { const SendBackwardIntent(); }
class BringToFrontIntent extends Intent { const BringToFrontIntent(); }
class SendToBackIntent extends Intent { const SendToBackIntent(); }

class NudgeIntent extends Intent {
  final double dx;
  final double dy;
  const NudgeIntent(this.dx, this.dy);
}

class ZoomInIntent extends Intent { const ZoomInIntent(); }
class ZoomOutIntent extends Intent { const ZoomOutIntent(); }
class ZoomResetIntent extends Intent { const ZoomResetIntent(); }
class SaveIntent extends Intent { const SaveIntent(); }

// ── Cross-platform modifier detection ────────────────────────────────────────

bool get _isMac {
  if (kIsWeb) return false;
  try {
    return Platform.isMacOS || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

// ── Shortcut map ─────────────────────────────────────────────────────────────

Map<ShortcutActivator, Intent> buildShortcuts() => {
      // Undo / Redo
      SingleActivator(LogicalKeyboardKey.keyZ, meta: _isMac, control: !_isMac):
          const UndoIntent(),
      SingleActivator(LogicalKeyboardKey.keyZ,
          meta: _isMac, control: !_isMac, shift: true): const RedoIntent(),
      SingleActivator(LogicalKeyboardKey.keyY, meta: _isMac, control: !_isMac):
          const RedoIntent(),

      // Clipboard
      SingleActivator(LogicalKeyboardKey.keyC, meta: _isMac, control: !_isMac):
          const CopyIntent(),
      SingleActivator(LogicalKeyboardKey.keyX, meta: _isMac, control: !_isMac):
          const CutIntent(),
      SingleActivator(LogicalKeyboardKey.keyV, meta: _isMac, control: !_isMac):
          const PasteIntent(),
      SingleActivator(LogicalKeyboardKey.keyD, meta: _isMac, control: !_isMac):
          const DuplicateIntent(),

      // Selection
      SingleActivator(LogicalKeyboardKey.keyA, meta: _isMac, control: !_isMac):
          const SelectAllIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const DeselectIntent(),

      // Delete
      const SingleActivator(LogicalKeyboardKey.delete): const DeleteElementIntent(),
      const SingleActivator(LogicalKeyboardKey.backspace): const DeleteElementIntent(),

      // Z-order
      SingleActivator(LogicalKeyboardKey.bracketRight,
          meta: _isMac, control: !_isMac): const BringForwardIntent(),
      SingleActivator(LogicalKeyboardKey.bracketLeft,
          meta: _isMac, control: !_isMac): const SendBackwardIntent(),
      SingleActivator(LogicalKeyboardKey.bracketRight,
          meta: _isMac, control: !_isMac, shift: true): const BringToFrontIntent(),
      SingleActivator(LogicalKeyboardKey.bracketLeft,
          meta: _isMac, control: !_isMac, shift: true): const SendToBackIntent(),

      // Nudge 1 unit
      const SingleActivator(LogicalKeyboardKey.arrowLeft): const NudgeIntent(-1, 0),
      const SingleActivator(LogicalKeyboardKey.arrowRight): const NudgeIntent(1, 0),
      const SingleActivator(LogicalKeyboardKey.arrowUp): const NudgeIntent(0, -1),
      const SingleActivator(LogicalKeyboardKey.arrowDown): const NudgeIntent(0, 1),

      // Nudge 10 units (Shift+Arrow)
      const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
          const NudgeIntent(-10, 0),
      const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
          const NudgeIntent(10, 0),
      const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
          const NudgeIntent(0, -10),
      const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
          const NudgeIntent(0, 10),

      // Zoom
      SingleActivator(LogicalKeyboardKey.equal, meta: _isMac, control: !_isMac):
          const ZoomInIntent(),
      SingleActivator(LogicalKeyboardKey.minus, meta: _isMac, control: !_isMac):
          const ZoomOutIntent(),
      SingleActivator(LogicalKeyboardKey.digit0, meta: _isMac, control: !_isMac):
          const ZoomResetIntent(),

      // Save
      SingleActivator(LogicalKeyboardKey.keyS, meta: _isMac, control: !_isMac):
          const SaveIntent(),

    };

// ── Action builder ───────────────────────────────────────────────────────────

Map<Type, Action<Intent>> buildActions({
  required TemplateEditorProvider provider,
  required VoidCallback onSave,
}) =>
    {
      UndoIntent: CallbackAction<UndoIntent>(
        onInvoke: (_) { provider.undo(); return null; },
      ),
      RedoIntent: CallbackAction<RedoIntent>(
        onInvoke: (_) { provider.redo(); return null; },
      ),
      CopyIntent: CallbackAction<CopyIntent>(
        onInvoke: (_) { provider.copySelected(); return null; },
      ),
      CutIntent: CallbackAction<CutIntent>(
        onInvoke: (_) { provider.cutSelected(); return null; },
      ),
      PasteIntent: CallbackAction<PasteIntent>(
        onInvoke: (_) { provider.paste(); return null; },
      ),
      DuplicateIntent: CallbackAction<DuplicateIntent>(
        onInvoke: (_) { provider.duplicateSelected(); return null; },
      ),
      SelectAllIntent: CallbackAction<SelectAllIntent>(
        onInvoke: (_) { provider.selectAll(); return null; },
      ),
      DeleteElementIntent: CallbackAction<DeleteElementIntent>(
        onInvoke: (_) {
          // Guard: do not delete while the user is typing inside a text field.
          if (!provider.isEditingText) provider.deleteSelected();
          return null;
        },
      ),
      DeselectIntent: CallbackAction<DeselectIntent>(
        onInvoke: (_) {
          if (provider.isEditingText) {
            provider.exitTextEdit();
          } else {
            provider.deselectAll();
          }
          return null;
        },
      ),
      BringForwardIntent: CallbackAction<BringForwardIntent>(
        onInvoke: (_) {
          final id = provider.primarySelected?.id;
          if (id != null) provider.bringForward(id);
          return null;
        },
      ),
      SendBackwardIntent: CallbackAction<SendBackwardIntent>(
        onInvoke: (_) {
          final id = provider.primarySelected?.id;
          if (id != null) provider.sendBackward(id);
          return null;
        },
      ),
      BringToFrontIntent: CallbackAction<BringToFrontIntent>(
        onInvoke: (_) {
          final id = provider.primarySelected?.id;
          if (id != null) provider.bringToFront(id);
          return null;
        },
      ),
      SendToBackIntent: CallbackAction<SendToBackIntent>(
        onInvoke: (_) {
          final id = provider.primarySelected?.id;
          if (id != null) provider.sendToBack(id);
          return null;
        },
      ),
      NudgeIntent: CallbackAction<NudgeIntent>(
        onInvoke: (intent) {
          if (!provider.isEditingText) provider.nudge(intent.dx, intent.dy);
          return null;
        },
      ),
      ZoomInIntent: CallbackAction<ZoomInIntent>(
        onInvoke: (_) { provider.setZoom(provider.zoom + 0.1); return null; },
      ),
      ZoomOutIntent: CallbackAction<ZoomOutIntent>(
        onInvoke: (_) { provider.setZoom(provider.zoom - 0.1); return null; },
      ),
      ZoomResetIntent: CallbackAction<ZoomResetIntent>(
        onInvoke: (_) { provider.resetZoom(); return null; },
      ),
      SaveIntent: CallbackAction<SaveIntent>(
        onInvoke: (_) { onSave(); return null; },
      ),
    };

// ── Convenience wrapper widget ────────────────────────────────────────────────

/// Wraps the editor scaffold with Shortcuts + Actions.
/// All keyboard logic lives here — nothing keyboard-related is in widget files.
class EditorShortcutsWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onSave;

  const EditorShortcutsWrapper({
    super.key,
    required this.child,
    required this.onSave,
  });

  @override
  State<EditorShortcutsWrapper> createState() => _EditorShortcutsWrapperState();
}

class _EditorShortcutsWrapperState extends State<EditorShortcutsWrapper> {
  bool _hasEditableFocus = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
    _hasEditableFocus = _isEditableTextFocused();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    final next = _isEditableTextFocused();
    if (next == _hasEditableFocus) return;
    setState(() => _hasEditableFocus = next);
  }

  bool _isEditableTextFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TemplateEditorProvider>();
    return Shortcuts(
      shortcuts: _hasEditableFocus ? const {} : buildShortcuts(),
      child: Actions(
        actions: buildActions(provider: provider, onSave: widget.onSave),
        child: Focus(
          autofocus: true,
          child: widget.child,
        ),
      ),
    );
  }
}
