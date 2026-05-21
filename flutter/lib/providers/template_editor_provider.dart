import 'dart:async';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../models/pdf_document_data.dart';
import '../models/template_element_model.dart';
import '../models/template_model.dart';
import '../repositories/template_repository.dart';
import '../services/clipboard_service.dart';
import '../utils/canvas_math.dart';

enum SaveState { idle, saving, saved, error }

/// Central state manager for the PDF template editor.
///
/// Undo/Redo: snapshot pattern — deep copies of List<TemplateElement>
/// stored before every mutation. Max 50 states. See ADR-002.
///
/// Drag performance: callers update a per-element ValueNotifier<Offset>
/// during active dragging; this provider only receives the final position
/// on drag-end. See ADR-003.
class TemplateEditorProvider extends ChangeNotifier {
  static const double _flowGap = 8.0;
  static const double _pageMargin = 8.0;

  final TemplateRepository _repo;
  final ClipboardService _clipboard;
  final String _companyId;

  TemplateEditorProvider({
    required TemplateRepository repo,
    required String companyId,
    ClipboardService? clipboard,
  })  : _repo = repo,
        _clipboard = clipboard ?? ClipboardService.instance,
        _companyId = companyId;

  // ── Core model ─────────────────────────────────────────────────────────

  TemplateModel? _template;
  TemplateModel? get template => _template;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  String? _loadError;
  String? get loadError => _loadError;

  // ── Element state ──────────────────────────────────────────────────────

  List<TemplateElement> _elements = [];
  List<TemplateElement> get elements => List.unmodifiable(_elements);

  List<TemplateElement> get sortedElements =>
      [..._elements]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  // ── Selection ──────────────────────────────────────────────────────────

  Set<String> _selectedIds = {};
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  bool isSelected(String id) => _selectedIds.contains(id);
  bool get hasSelection => _selectedIds.isNotEmpty;
  bool get hasMultiSelection => _selectedIds.length > 1;

  String? _focusRequestId;
  String? get focusRequestId => _focusRequestId;

  int _focusRequestVersion = 0;
  int get focusRequestVersion => _focusRequestVersion;

  TemplateElement? get primarySelected {
    if (_selectedIds.isEmpty) return null;
    final id = _selectedIds.first;
    try {
      return _elements.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<TemplateElement> get selectedElements =>
      _elements.where((e) => _selectedIds.contains(e.id)).toList();

  // ── Text edit mode ─────────────────────────────────────────────────────

  String? _editingTextId;
  String? get editingTextId => _editingTextId;
  bool get isEditingText => _editingTextId != null;

  // ── Active drag (per-element ValueNotifiers) ────────────────────────────

  // These are READ by CanvasElementWidget only; not notified through the
  // main ChangeNotifier path to avoid full tree rebuilds during drag.
  final Map<String, ValueNotifier<Offset>> _dragPositions = {};

  ValueNotifier<Offset>? dragPositionFor(String id) => _dragPositions[id];

  // Snap guides updated during drag for SnapGuideWidget
  final ValueNotifier<List<SnapGuide>> snapGuides = ValueNotifier(const []);

  // ── Undo / Redo ────────────────────────────────────────────────────────

  static const int _maxUndo = 50;
  final List<List<TemplateElement>> _undoStack = [];
  final List<List<TemplateElement>> _redoStack = [];

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // ── Zoom ───────────────────────────────────────────────────────────────

  double _zoom = 1.0;
  double get zoom => _zoom;

  // ── Save state ─────────────────────────────────────────────────────────

  SaveState _saveState = SaveState.idle;
  SaveState get saveState => _saveState;

  String? _saveError;
  String? get saveError => _saveError;

  static const Duration _autoSaveDelay = Duration(milliseconds: 900);
  Timer? _autoSaveTimer;
  bool _saveInFlight = false;
  bool _saveQueued = false;
  int _autoSaveLocks = 0;
  bool _autoSavePending = false;
  bool _isDirty = false;

  // ── Load ───────────────────────────────────────────────────────────────

  Future<void> load(String templateId) async {
    _isLoaded = false;
    _loadError = null;
    _template = null;
    _elements = [];
    _selectedIds = {};
    _editingTextId = null;
    _autoSaveTimer?.cancel();
    _autoSavePending = false;
    _autoSaveLocks = 0;
    _saveQueued = false;
    _saveInFlight = false;
    _isDirty = false;
    notifyListeners();

    try {
      final t = await _repo.fetchTemplate(_companyId, templateId);
      if (t == null) throw Exception('Template not found: $templateId');
      debugPrint(
        '[TemplateEditor] loaded template id=${t.id} name="${t.name}" elements=${t.elements.length}',
      );
      _template = t.copyWith(
        pageSize: PageSize(width: t.pageSize.width, height: 842),
      );
      _elements = _normalizeLoadedElements(t.elements);
      debugPrint(
        '[TemplateEditor] canvas elements after copy=${_elements.length}',
      );
      _isLoaded = true;
    } catch (e) {
      _loadError = e.toString();
      debugPrint('[TemplateEditor] load failed for $templateId: $_loadError');
    }
    notifyListeners();
  }

  // ── Load from external data (no API call) ─────────────────────────────

  void loadFromData(PdfDocumentData data) {
    _isLoaded = false;
    _loadError = null;
    _template = null;
    _elements = [];
    _selectedIds = {};
    _editingTextId = null;
    _autoSaveTimer?.cancel();
    _autoSavePending = false;
    _autoSaveLocks = 0;
    _saveQueued = false;
    _saveInFlight = false;
    _isDirty = false;
    notifyListeners();

    final model = data.toTemplateModel();
    _template = model.copyWith(
      pageSize: PageSize(width: model.pageSize.width, height: 842),
    );
    _elements = _normalizeLoadedElements(model.elements);
    _isLoaded = true;
    notifyListeners();
  }

  // ── Undo / Redo ─────────────────────────────────────────────────────────

  void _pushUndo() {
    _undoStack.add(_deepCopy(_elements));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_deepCopy(_elements));
    _elements = _undoStack.removeLast();
    _selectedIds = {};
    _editingTextId = null;
    _scheduleAutoSave();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_deepCopy(_elements));
    _elements = _redoStack.removeLast();
    _selectedIds = {};
    _scheduleAutoSave();
    notifyListeners();
  }

  List<TemplateElement> _deepCopy(List<TemplateElement> src) =>
      src.map((e) => e.deepCopy()).toList();

  bool _layoutChanged(TemplateElement before, TemplateElement after) =>
      before.x != after.x ||
      before.y != after.y ||
      before.width != after.width ||
      before.height != after.height ||
      (before is TableElement &&
          after is TableElement &&
          (before.tableData.rows.length != after.tableData.rows.length ||
              before.tableData.headers.length !=
                  after.tableData.headers.length));

  TemplateElement _normalizeElementSize(
    TemplateElement before,
    TemplateElement after,
  ) {
    if (before is TextElement && after is TextElement) {
      final visualLines = _estimateWrappedLines(
        after.content,
        after.width,
        after.fontSize,
      );
      if (visualLines <= 1) return after;
      final preferredHeight =
          (visualLines * after.fontSize * after.lineHeight + 4)
              .clamp(20.0, double.infinity)
              .toDouble();
      if (after.height < preferredHeight) {
        return after.copyWith(height: preferredHeight);
      }
    }

    return after;
  }

  List<TemplateElement> _applyAutoFlow(
    List<TemplateElement> source,
    String changedId,
    Rect oldRect,
    Rect newRect,
  ) {
    if (source.length < 2) return source;

    var next = [...source];
    var changed = next.firstWhere((e) => e.id == changedId);
    final deltaBottom = newRect.bottom - oldRect.bottom;

    if (deltaBottom < -0.5) {
      final pullUpBy = deltaBottom;
      next = next.map((el) {
        if (el.id == changedId || el.locked) return el;
        if (el.y < oldRect.bottom - 1) return el;
        final y =
            (el.y + pullUpBy).clamp(newRect.bottom + _flowGap, el.y).toDouble();
        return _moveElement(el, el.x, y);
      }).toList();
      changed = next.firstWhere((e) => e.id == changedId);
    }

    final changedMidY = changed.y + changed.height / 2;
    final candidates = next
        .where((el) =>
            el.id != changedId &&
            !el.locked &&
            el.y + el.height / 2 >= changedMidY - _flowGap)
        .toList()
      ..sort((a, b) {
        final byY = a.y.compareTo(b.y);
        if (byY != 0) return byY;
        return a.x.compareTo(b.x);
      });

    // Process candidates in Y-level groups so that side-by-side elements
    // (same Y, different X) are always moved to the same Y and advance the
    // cursor only once — preventing horizontal siblings from being staggered.
    var cursor = changed.y + changed.height + _flowGap;
    int i = 0;
    while (i < candidates.length) {
      final groupY = candidates[i].y;

      // Collect all elements whose Y is within 2px of this group's Y.
      final group = <TemplateElement>[];
      while (i < candidates.length &&
          (candidates[i].y - groupY).abs() < 2.0) {
        group.add(candidates[i]);
        i++;
      }

      if (groupY < cursor) {
        // Move every element in the group to the same cursor Y.
        final targetY = cursor.clamp(_pageMargin, double.infinity).toDouble();
        double maxBottom = 0;
        for (final groupEl in group) {
          final idx = next.indexWhere((e) => e.id == groupEl.id);
          if (idx == -1) continue;
          final moved = _moveElement(next[idx], next[idx].x, targetY);
          next = [...next]..[idx] = moved;
          final bottom = moved.y + moved.height;
          if (bottom > maxBottom) maxBottom = bottom;
        }
        cursor = maxBottom + _flowGap;
      } else {
        // Group is already below cursor; advance cursor past the tallest in group.
        double maxBottom = 0;
        for (final groupEl in group) {
          final bottom = groupEl.y + groupEl.height;
          if (bottom > maxBottom) maxBottom = bottom;
        }
        cursor = maxBottom + _flowGap;
      }
    }

    return next;
  }

  List<TemplateElement> _normalizeLoadedElements(
    List<TemplateElement> elements,
  ) {
    var next = elements.map((e) => e.deepCopy()).toList();
    final ordered = [...next]..sort((a, b) {
        final byY = a.y.compareTo(b.y);
        if (byY != 0) return byY;
        return a.x.compareTo(b.x);
      });

    for (final original in ordered) {
      final idx = next.indexWhere((e) => e.id == original.id);
      if (idx == -1) continue;
      final before = next[idx];
      final normalized = _normalizeElementSize(before, before);
      if (!_layoutChanged(before, normalized)) continue;
      next = [...next]..[idx] = normalized;
      next = _applyAutoFlow(next, normalized.id, before.rect, normalized.rect);
    }

    return next;
  }

  int _estimateWrappedLines(String text, double width, double fontSize) {
    final safeWidth = width <= 0 ? 1.0 : width;
    final charsPerLine = (safeWidth / (fontSize * 0.52)).floor();
    final safeCharsPerLine = charsPerLine < 1 ? 1 : charsPerLine;
    var lines = 0;
    for (final paragraph in text.split('\n')) {
      final words = paragraph.trim().split(RegExp(r'\s+'));
      var current = 0;
      if (words.length == 1 && words.first.isEmpty) {
        lines++;
        continue;
      }
      for (final word in words) {
        final wordLength = word.length;
        if (current == 0) {
          current = wordLength;
          lines += (wordLength / safeCharsPerLine).floor();
          current = wordLength % safeCharsPerLine;
        } else if (current + 1 + wordLength <= safeCharsPerLine) {
          current += 1 + wordLength;
        } else {
          lines++;
          current = wordLength;
          lines += (wordLength / safeCharsPerLine).floor();
          current = wordLength % safeCharsPerLine;
        }
      }
      if (current > 0) lines++;
    }
    return lines < 1 ? 1 : lines;
  }

  void _syncPageHeightToContent() {
    final template = _template;
    if (template == null) return;
    if (template.pageSize.height != 842) {
      _template = template.copyWith(
        pageSize: PageSize(
          width: template.pageSize.width,
          height: 842,
        ),
      );
    }
  }

  // ── Selection ──────────────────────────────────────────────────────────

  void selectElement(
    String id, {
    bool addToSelection = false,
    bool focus = false,
  }) {
    if (addToSelection) {
      _selectedIds = {..._selectedIds, id};
    } else {
      _selectedIds = {id};
    }
    _editingTextId = null;
    if (focus) {
      _focusRequestId = id;
      _focusRequestVersion++;
    }
    notifyListeners();
  }

  void deselectAll() {
    if (_selectedIds.isEmpty && _editingTextId == null) return;
    _selectedIds = {};
    _editingTextId = null;
    notifyListeners();
  }

  void selectAll() {
    _selectedIds = _elements.map((e) => e.id).toSet();
    notifyListeners();
  }

  void selectByRubberBand(double x, double y, double width, double height) {
    final hit = _elements
        .where((e) => CanvasMath.intersectsRubberBand(e, x, y, width, height))
        .map((e) => e.id)
        .toSet();
    if (setEquals(hit, _selectedIds)) return;
    _selectedIds = hit;
    notifyListeners();
  }

  void beginInlineEdit(String id, {bool focus = false}) {
    _selectedIds = {id};
    _editingTextId = id;
    if (focus) {
      _focusRequestId = id;
      _focusRequestVersion++;
    }
    notifyListeners();
  }

  void endInlineEdit() {
    if (_editingTextId == null) return;
    _editingTextId = null;
    notifyListeners();
  }

  // ── Text edit ──────────────────────────────────────────────────────────

  /// Called on double-tap of a text/logo element. Captures undo snapshot now;
  /// the final committed text is applied in [commitTextEdit].
  void beginTextEdit(String id) {
    _pushUndo(); // Snapshot before the edit session
    _selectedIds = {id};
    _editingTextId = id;
    notifyListeners();
  }

  void commitTextEdit(String id, String newContent) {
    _editingTextId = null;
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx == -1) {
      notifyListeners();
      return;
    }
    final el = _elements[idx];
    if (el is TextElement) {
      final updated =
          _normalizeElementSize(el, el.copyWith(content: newContent));
      final next = [..._elements]..[idx] = updated;
      _elements = _layoutChanged(el, updated)
          ? _applyAutoFlow(next, id, el.rect, updated.rect)
          : next;
      _syncPageHeightToContent();
      _scheduleAutoSave();
    }
    notifyListeners();
  }

  void exitTextEdit() {
    if (_editingTextId == null) return;
    _editingTextId = null;
    notifyListeners();
  }

  // ── Add elements ───────────────────────────────────────────────────────

  void addElement(TemplateElement element) {
    _pushUndo();
    final withZ = _elementWithNextZ(element);
    _elements = [..._elements, withZ];
    _selectedIds = {withZ.id};
    _syncPageHeightToContent();
    _scheduleAutoSave();
    notifyListeners();
  }

  TemplateElement _elementWithNextZ(TemplateElement el) {
    final maxZ = _elements.isEmpty
        ? 0
        : _elements.map((e) => e.zIndex).reduce((a, b) => a > b ? a : b);
    return switch (el) {
      TextElement te => te.copyWith(zIndex: maxZ + 1),
      ImageElement ie => ie.copyWith(zIndex: maxZ + 1),
      TableElement tbl => tbl.copyWith(zIndex: maxZ + 1),
      LogoElement le => le.copyWith(zIndex: maxZ + 1),
      SignatureBlockElement sb => sb.copyWith(zIndex: maxZ + 1),
      DividerElement de => de.copyWith(zIndex: maxZ + 1),
    };
  }

  // ── Delete ─────────────────────────────────────────────────────────────

  void deleteSelected() {
    if (_selectedIds.isEmpty) return;
    _pushUndo();
    _elements = _elements.where((e) => !_selectedIds.contains(e.id)).toList();
    _selectedIds = {};
    _scheduleAutoSave();
    notifyListeners();
  }

  // ── Drag (performance-safe path) ───────────────────────────────────────

  /// Called by CanvasElementWidget on drag start.
  /// Creates a ValueNotifier for the dragged element — canvas updates
  /// subscribe to this directly, bypassing notifyListeners() during drag.
  void beginDrag(String id) {
    _suspendAutoSave();
    final el = _elements.firstWhere((e) => e.id == id);
    _dragPositions[id] = ValueNotifier(Offset(el.x, el.y));
    final guides = CanvasMath.computeGuides(
      _elements,
      id,
      _template?.pageSize.width ?? 595,
      _template?.pageSize.height ?? 842,
    );
    snapGuides.value = guides;
  }

  /// Called on every PointerMoveEvent — updates ValueNotifier only,
  /// no notifyListeners() call here (see ADR-003).
  void updateDrag(String id, double x, double y) {
    final notifier = _dragPositions[id];
    if (notifier == null) return;

    final el = _elements.firstWhere((e) => e.id == id);
    final guides = snapGuides.value;
    final (sx, sy) =
        CanvasMath.snapElementPosition(x, y, el.width, el.height, guides);

    notifier.value = Offset(sx, sy);
  }

  /// Called on drag end — commits to the main model and pushes undo state.
  void endDrag(String id) {
    final notifier = _dragPositions.remove(id);
    if (notifier == null) return;
    snapGuides.value = const [];

    _pushUndo();
    final pos = notifier.value;
    notifier.dispose();

    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final before = _elements[idx];
    final updated = _moveElement(before, pos.dx, pos.dy);
    final next = [..._elements]..[idx] = updated;
    _elements = _applyAutoFlow(next, id, before.rect, updated.rect);
    _syncPageHeightToContent();
    _resumeAutoSave();
    _scheduleAutoSave();
    notifyListeners();
  }

  TemplateElement _moveElement(TemplateElement el, double x, double y) =>
      switch (el) {
        TextElement te => te.copyWith(x: x, y: y),
        ImageElement ie => ie.copyWith(x: x, y: y),
        TableElement tbl => tbl.copyWith(x: x, y: y),
        LogoElement le => le.copyWith(x: x, y: y),
        SignatureBlockElement sb => sb.copyWith(x: x, y: y),
        DividerElement de => de.copyWith(x: x, y: y),
      };

  // ── Nudge (arrow keys) ────────────────────────────────────────────────

  void nudge(double dx, double dy) {
    if (_selectedIds.isEmpty) return;
    _pushUndo();
    _elements = _elements.map((e) {
      if (!_selectedIds.contains(e.id)) return e;
      return _moveElement(e, e.x + dx, e.y + dy);
    }).toList();
    _syncPageHeightToContent();
    _scheduleAutoSave();
    notifyListeners();
  }

  // ── Resize ─────────────────────────────────────────────────────────────

  void beginResize(String id) {
    _pushUndo();
    _suspendAutoSave();
  }

  void endResize(String id) {
    _resumeAutoSave();
    _scheduleAutoSave();
  }

  void applyResize(
    String id,
    double origX,
    double origY,
    double origW,
    double origH,
    HandlePosition handle,
    double dx,
    double dy, {
    bool constrainAspect = false,
  }) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final r = CanvasMath.applyResize(origX, origY, origW, origH, handle, dx, dy,
        constrainAspect: constrainAspect);

    final before = _elements[idx];
    final updated = _resizeElement(before, r.x, r.y, r.width, r.height);
    final next = [..._elements]..[idx] = updated;
    _elements = _applyAutoFlow(next, id, before.rect, updated.rect);
    _syncPageHeightToContent();
    _scheduleAutoSave();
    notifyListeners();
  }

  TemplateElement _resizeElement(
          TemplateElement el, double x, double y, double w, double h) =>
      switch (el) {
        TextElement te => te.copyWith(x: x, y: y, width: w, height: h),
        ImageElement ie => ie.copyWith(x: x, y: y, width: w, height: h),
        TableElement tbl => tbl.copyWith(x: x, y: y, width: w, height: h),
        LogoElement le => le.copyWith(x: x, y: y, width: w, height: h),
        SignatureBlockElement sb =>
          sb.copyWith(x: x, y: y, width: w, height: h),
        DividerElement de => de.copyWith(x: x, y: y, width: w, height: h),
      };

  // ── Z-order ───────────────────────────────────────────────────────────

  /// Reassigns z-indices from the ordered list produced by the layers panel
  /// drag-reorder. [orderedIds] is in layers-list order: index 0 = backmost
  /// (z=1), last index = frontmost (z=length). Pushes exactly one undo state.
  void reorderLayers(List<String> orderedIds) {
    _pushUndo();
    final newZ = <String, int>{
      for (int i = 0; i < orderedIds.length; i++) orderedIds[i]: i + 1,
    };
    _elements =
        _elements.map((el) => _setZ(el, newZ[el.id] ?? el.zIndex)).toList();
    _scheduleAutoSave();
    notifyListeners();
  }

  void bringForward(String id) => _shiftZ(id, 1);
  void sendBackward(String id) => _shiftZ(id, -1);

  void bringToFront(String id) {
    _pushUndo();
    final maxZ = _elements.map((e) => e.zIndex).reduce((a, b) => a > b ? a : b);
    _updateZ(id, maxZ + 1);
  }

  void sendToBack(String id) {
    _pushUndo();
    final minZ = _elements.map((e) => e.zIndex).reduce((a, b) => a < b ? a : b);
    _updateZ(id, minZ - 1);
  }

  void _shiftZ(String id, int delta) {
    _pushUndo();
    final el = _elements.firstWhere((e) => e.id == id);
    _updateZ(id, el.zIndex + delta);
  }

  void _updateZ(String id, int newZ) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _elements = [..._elements]..[idx] = _setZ(_elements[idx], newZ);
    _scheduleAutoSave();
    notifyListeners();
  }

  TemplateElement _setZ(TemplateElement el, int z) => switch (el) {
        TextElement te => te.copyWith(zIndex: z),
        ImageElement ie => ie.copyWith(zIndex: z),
        TableElement tbl => tbl.copyWith(zIndex: z),
        LogoElement le => le.copyWith(zIndex: z),
        SignatureBlockElement sb => sb.copyWith(zIndex: z),
        DividerElement de => de.copyWith(zIndex: z),
      };

  // ── Copy / Paste / Duplicate ──────────────────────────────────────────

  void copySelected() => _clipboard.copy(selectedElements);

  void cutSelected() {
    _clipboard.copy(selectedElements);
    deleteSelected();
  }

  void paste() {
    final pasted = _clipboard.paste();
    if (pasted.isEmpty) return;
    _pushUndo();
    final maxZ = _elements.isEmpty
        ? 0
        : _elements.map((e) => e.zIndex).reduce((a, b) => a > b ? a : b);
    final withZ = pasted
        .asMap()
        .entries
        .map((entry) => _setZ(entry.value, maxZ + 1 + entry.key))
        .toList();
    _elements = [..._elements, ...withZ];
    _selectedIds = withZ.map((e) => e.id).toSet();
    _scheduleAutoSave();
    notifyListeners();
  }

  void duplicateSelected() {
    if (_selectedIds.isEmpty) return;
    _clipboard.copy(selectedElements);
    paste();
  }

  // ── Style updates ──────────────────────────────────────────────────────

  /// Generic element update — replaces the element with the provided instance.
  void updateElement(TemplateElement updated) {
    _pushUndo();
    final idx = _elements.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    final before = _elements[idx];
    final normalized = _normalizeElementSize(before, updated);
    final next = [..._elements]..[idx] = normalized;
    _elements = _layoutChanged(before, normalized)
        ? _applyAutoFlow(next, normalized.id, before.rect, normalized.rect)
        : next;
    _syncPageHeightToContent();
    _scheduleAutoSave();
    notifyListeners();
  }

  // ── Visibility & lock ─────────────────────────────────────────────────

  void toggleVisibility(String id) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _pushUndo();
    final el = _elements[idx];
    _elements = [..._elements]..[idx] = _setVisible(el, !el.visible);
    _scheduleAutoSave();
    notifyListeners();
  }

  void toggleLock(String id) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _pushUndo();
    final el = _elements[idx];
    _elements = [..._elements]..[idx] = _setLocked(el, !el.locked);
    _scheduleAutoSave();
    notifyListeners();
  }

  TemplateElement _setVisible(TemplateElement el, bool v) => switch (el) {
        TextElement te => te.copyWith(visible: v),
        ImageElement ie => ie.copyWith(visible: v),
        TableElement tbl => tbl.copyWith(visible: v),
        LogoElement le => le.copyWith(visible: v),
        SignatureBlockElement sb => sb.copyWith(visible: v),
        DividerElement de => de.copyWith(visible: v),
      };

  TemplateElement _setLocked(TemplateElement el, bool v) => switch (el) {
        TextElement te => te.copyWith(locked: v),
        ImageElement ie => ie.copyWith(locked: v),
        TableElement tbl => tbl.copyWith(locked: v),
        LogoElement le => le.copyWith(locked: v),
        SignatureBlockElement sb => sb.copyWith(locked: v),
        DividerElement de => de.copyWith(locked: v),
      };

  // ── Alignment ─────────────────────────────────────────────────────────

  void alignSelected(String direction) {
    if (_selectedIds.length < 2) return;
    _pushUndo();
    final sel = selectedElements;
    final aligned = switch (direction) {
      'left' => CanvasMath.alignLeft(sel),
      'right' => CanvasMath.alignRight(sel),
      'top' => CanvasMath.alignTop(sel),
      'bottom' => CanvasMath.alignBottom(sel),
      'centerH' => CanvasMath.alignCenterH(sel),
      'centerV' => CanvasMath.alignCenterV(sel),
      _ => sel,
    };
    final alignedIds = {for (final e in aligned) e.id: e};
    _elements = _elements.map((e) => alignedIds[e.id] ?? e).toList();
    _scheduleAutoSave();
    notifyListeners();
  }

  // ── Rename ────────────────────────────────────────────────────────────

  void renameTemplate(String name) {
    if (_template == null) return;
    _template = _template!.copyWith(name: name);
    _scheduleAutoSave();
    notifyListeners();
  }

  // ── Zoom ──────────────────────────────────────────────────────────────

  void setZoom(double value) {
    _zoom = value.clamp(0.3, 4.0);
    notifyListeners();
  }

  void resetZoom() => setZoom(1.0);

  void _suspendAutoSave() {
    _autoSaveLocks++;
    if (_autoSaveTimer != null) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = null;
      _autoSavePending = true;
    }
  }

  void _resumeAutoSave() {
    if (_autoSaveLocks == 0) return;
    _autoSaveLocks--;
    if (_autoSaveLocks == 0 && _autoSavePending) {
      _autoSavePending = false;
      _scheduleAutoSave();
    }
  }

  void _scheduleAutoSave() {
    if (_template == null || !_isLoaded) return;
    _isDirty = true;
    if (_autoSaveLocks > 0) {
      _autoSavePending = true;
      return;
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, _runSave);
  }

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> save() async {
    _autoSaveTimer?.cancel();
    _isDirty = true;
    await _runSave(force: true);
  }

  Future<void> _runSave({bool force = false}) async {
    if (_template == null || !_isLoaded) return;
    if (!force && !_isDirty) return;
    if (_saveInFlight) {
      _saveQueued = true;
      return;
    }

    _saveInFlight = true;
    _saveState = SaveState.saving;
    _saveError = null;
    notifyListeners();

    try {
      final updated = _template!.copyWith(
        elements: _elements,
        updatedAt: DateTime.now(),
      );

      await _repo.updateTemplate(_companyId, updated);
      _template = updated;
      _saveState = SaveState.saved;
      _isDirty = _saveQueued;
    } catch (e) {
      _saveState = SaveState.error;
      _saveError = e.toString();
      _isDirty = true;
    }

    _saveInFlight = false;
    notifyListeners();

    if (_saveQueued) {
      _saveQueued = false;
      _runSave();
    }
  }

  void clearSaveState() {
    _saveState = SaveState.idle;
    _saveError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final n in _dragPositions.values) {
      n.dispose();
    }
    snapGuides.dispose();
    super.dispose();
  }
}

// Helper that mirrors Set.equals behaviour from flutter/foundation
bool setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
