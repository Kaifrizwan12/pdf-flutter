import 'package:uuid/uuid.dart';

import '../models/template_element_model.dart';

/// In-app clipboard — does not touch the OS clipboard.
/// Elements are serialised to JSON on copy so the clipboard holds
/// an independent value snapshot (not references into the live model).
class ClipboardService {
  ClipboardService._();
  static final ClipboardService instance = ClipboardService._();

  List<Map<String, dynamic>>? _payload;

  bool get hasContent => _payload != null && _payload!.isNotEmpty;

  void copy(List<TemplateElement> elements) {
    _payload = elements.map((e) => e.toJson()).toList();
  }

  /// Returns deep copies of the copied elements with:
  ///   • New generated IDs (avoids ID collisions on paste)
  ///   • Position offset by +10, +10 from the original
  List<TemplateElement> paste() {
    if (_payload == null) return const [];
    return _payload!.map((json) {
      final copy = Map<String, dynamic>.from(json);
      copy['id'] = const Uuid().v4().substring(0, 8);
      copy['x'] = ((json['x'] as num).toDouble()) + 10;
      copy['y'] = ((json['y'] as num).toDouble()) + 10;
      return TemplateElement.fromJson(copy);
    }).toList();
  }

  void clear() => _payload = null;
}
