import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../models/template_element_model.dart';
import '../../providers/template_editor_provider.dart';
import '../shared/color_picker_widget.dart';
import '../shared/font_selector_widget.dart';

/// Right-side properties panel for the selected element.
/// On desktop it's a fixed sidebar; on mobile it slides up as a bottom sheet.
class RightPanelProperties extends StatelessWidget {
  const RightPanelProperties({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Consumer<TemplateEditorProvider>(
        builder: (context, provider, _) {
          final el = provider.primarySelected;
          if (el == null) return const _PageProperties();
          return _ElementProperties(element: el, provider: provider);
        },
      ),
    );
  }
}

// ── Page-level properties (nothing selected) ──────────────────────────────

class _PageProperties extends StatelessWidget {
  const _PageProperties();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Page',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.body)),
            SizedBox(height: AppSpacing.s4),
            Text('A4 — 595 × 842 pt',
                style: TextStyle(fontSize: 12, color: AppColors.bodyMuted)),
          ],
        ),
      );
}

// ── Element properties ────────────────────────────────────────────────────

class _ElementProperties extends StatelessWidget {
  final TemplateElement element;
  final TemplateEditorProvider provider;

  const _ElementProperties({
    required this.element,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(element.type.label),
          const SizedBox(height: AppSpacing.s4),
          _PositionSizeFields(element: element, provider: provider),
          const _Divider(),
          ..._typeSpecificFields(context),
        ],
      ),
    );
  }

  List<Widget> _typeSpecificFields(BuildContext context) => switch (element) {
        TextElement te => _TextFields(element: te, provider: provider).build(),
        ImageElement ie => _ImageFields(element: ie, provider: provider).build(),
        TableElement tbl => _TableFields(element: tbl, provider: provider).build(),
        LogoElement le => _LogoFields(element: le, provider: provider).build(),
        SignatureBlockElement sb =>
          _SignatureFields(element: sb, provider: provider).build(),
        DividerElement de => _DividerFields(element: de, provider: provider).build(),
      };

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.body,
        ),
      );
}

// ── Position & Size ───────────────────────────────────────────────────────

class _PositionSizeFields extends StatelessWidget {
  final TemplateElement element;
  final TemplateEditorProvider provider;

  const _PositionSizeFields({required this.element, required this.provider});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(children: [
            Expanded(child: _NumField('X', element.x, (v) {
              provider.updateElement(_setX(element, v));
            })),
            const SizedBox(width: AppSpacing.s2),
            Expanded(child: _NumField('Y', element.y, (v) {
              provider.updateElement(_setY(element, v));
            })),
          ]),
          const SizedBox(height: AppSpacing.s2),
          Row(children: [
            Expanded(child: _NumField('W', element.width, (v) {
              provider.updateElement(_setW(element, v));
            })),
            const SizedBox(width: AppSpacing.s2),
            Expanded(child: _NumField('H', element.height, (v) {
              provider.updateElement(_setH(element, v));
            })),
          ]),
        ],
      );

  TemplateElement _setX(TemplateElement el, double v) => switch (el) {
        TextElement te => te.copyWith(x: v),
        ImageElement ie => ie.copyWith(x: v),
        TableElement tbl => tbl.copyWith(x: v),
        LogoElement le => le.copyWith(x: v),
        SignatureBlockElement sb => sb.copyWith(x: v),
        DividerElement de => de.copyWith(x: v),
      };

  TemplateElement _setY(TemplateElement el, double v) => switch (el) {
        TextElement te => te.copyWith(y: v),
        ImageElement ie => ie.copyWith(y: v),
        TableElement tbl => tbl.copyWith(y: v),
        LogoElement le => le.copyWith(y: v),
        SignatureBlockElement sb => sb.copyWith(y: v),
        DividerElement de => de.copyWith(y: v),
      };

  TemplateElement _setW(TemplateElement el, double v) => switch (el) {
        TextElement te => te.copyWith(width: v),
        ImageElement ie => ie.copyWith(width: v),
        TableElement tbl => tbl.copyWith(width: v),
        LogoElement le => le.copyWith(width: v),
        SignatureBlockElement sb => sb.copyWith(width: v),
        DividerElement de => de.copyWith(width: v),
      };

  TemplateElement _setH(TemplateElement el, double v) => switch (el) {
        TextElement te => te.copyWith(height: v),
        ImageElement ie => ie.copyWith(height: v),
        TableElement tbl => tbl.copyWith(height: v),
        LogoElement le => le.copyWith(height: v),
        SignatureBlockElement sb => sb.copyWith(height: v),
        DividerElement de => de.copyWith(height: v),
      };
}

// ── Text fields ───────────────────────────────────────────────────────────

class _TextFields {
  final TextElement element;
  final TemplateEditorProvider provider;

  const _TextFields({required this.element, required this.provider});

  List<Widget> build() => [
        FontSelectorWidget(
          value: element.fontFamily,
          onChanged: (f) => provider.updateElement(element.copyWith(fontFamily: f)),
        ),
        const SizedBox(height: AppSpacing.s3),
        _NumField('Font Size', element.fontSize,
            (v) => provider.updateElement(element.copyWith(fontSize: v))),
        const SizedBox(height: AppSpacing.s3),
        Row(children: [
          _ToggleBtn(
            label: 'B',
            active: element.fontWeight == FontWeight.bold,
            onTap: () => provider.updateElement(element.copyWith(
              fontWeight: element.fontWeight == FontWeight.bold
                  ? FontWeight.normal
                  : FontWeight.bold,
            )),
          ),
          const SizedBox(width: AppSpacing.s2),
          _ToggleBtn(
            label: 'I',
            active: element.fontStyle == FontStyle.italic,
            onTap: () => provider.updateElement(element.copyWith(
              fontStyle: element.fontStyle == FontStyle.italic
                  ? FontStyle.normal
                  : FontStyle.italic,
            )),
          ),
        ]),
        const SizedBox(height: AppSpacing.s3),
        _LabeledRow(
          label: 'Color',
          child: ColorPickerWidget(
            compact: true,
            initialColor: element.color,
            onColorChanged: (c) =>
                provider.updateElement(element.copyWith(color: c)),
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        _NumField('Line Height', element.lineHeight,
            (v) => provider.updateElement(element.copyWith(lineHeight: v))),
        const SizedBox(height: AppSpacing.s2),
        _NumField('Letter Spacing', element.letterSpacing,
            (v) => provider.updateElement(element.copyWith(letterSpacing: v))),
      ];
}

// ── Image fields ──────────────────────────────────────────────────────────

class _ImageFields {
  final ImageElement element;
  final TemplateEditorProvider provider;

  const _ImageFields({required this.element, required this.provider});

  List<Widget> build() => [
        _NumField('Opacity', element.opacity,
            (v) => provider.updateElement(element.copyWith(opacity: v.clamp(0, 1)))),
        const SizedBox(height: AppSpacing.s2),
        _NumField('Corner Radius', element.borderRadius,
            (v) => provider.updateElement(element.copyWith(borderRadius: v))),
      ];
}

// ── Logo fields ───────────────────────────────────────────────────────────

class _LogoFields {
  final LogoElement element;
  final TemplateEditorProvider provider;

  const _LogoFields({required this.element, required this.provider});

  List<Widget> build() => [
        _NumField('Opacity', element.opacity,
            (v) => provider.updateElement(element.copyWith(opacity: v.clamp(0, 1)))),
        const SizedBox(height: AppSpacing.s3),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickLogo,
            icon: const Icon(Icons.upload_outlined, size: 14),
            label: const Text('Replace Logo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ];

  Future<void> _pickLogo() async {
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

    provider.updateElement(element.copyWith(src: src));
  }
}

// ── Table fields ──────────────────────────────────────────────────────────

class _TableFields {
  final TableElement element;
  final TemplateEditorProvider provider;

  const _TableFields({required this.element, required this.provider});

  List<Widget> build() => [
        // ── Style ──────────────────────────────────────────────────────
        _LabeledRow(
          label: 'Header BG',
          child: ColorPickerWidget(
            compact: true,
            initialColor: element.tableStyle.headerBg,
            onColorChanged: (c) => provider.updateElement(
                element.copyWith(
                    tableStyle: element.tableStyle.copyWith(headerBg: c))),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Alternate Row Colors',
              style: TextStyle(fontSize: 12, color: AppColors.body)),
          value: element.tableStyle.alternateRows,
          onChanged: (v) => provider.updateElement(element.copyWith(
              tableStyle: element.tableStyle.copyWith(alternateRows: v))),
        ),

        const _Divider(),

        // ── Row management ─────────────────────────────────────────────
        const Text('Rows',
            style: TextStyle(
                fontSize: 10,
                color: AppColors.bodyMuted,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.s2),
        Row(children: [
          Expanded(
            child: _TableActionBtn(
              icon: Icons.add,
              label: 'Add Row',
              onTap: _addRow,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: _TableActionBtn(
              icon: Icons.remove,
              label: 'Remove Row',
              enabled: element.tableData.rows.isNotEmpty,
              onTap: _removeRow,
            ),
          ),
        ]),

        const SizedBox(height: AppSpacing.s3),

        // ── Column management ──────────────────────────────────────────
        const Text('Columns',
            style: TextStyle(
                fontSize: 10,
                color: AppColors.bodyMuted,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.s2),
        Row(children: [
          Expanded(
            child: _TableActionBtn(
              icon: Icons.add,
              label: 'Add Column',
              onTap: _addColumn,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: _TableActionBtn(
              icon: Icons.remove,
              label: 'Remove Column',
              enabled: element.tableData.headers.isNotEmpty,
              onTap: _removeColumn,
            ),
          ),
        ]),
      ];

  // Each data row is ~27 pt tall; the header row counts as one row in the
  // height budget. Column widths are redistributed evenly across the element width.
  static const double _rowH = 27.0;

  void _addRow() {
    final td = element.tableData;
    final newRow = List<String>.filled(td.headers.length, '');
    provider.updateElement(element.copyWith(
      height: element.height + _rowH,
      tableData: td.copyWith(rows: [...td.rows, newRow]),
    ));
  }

  void _removeRow() {
    final td = element.tableData;
    if (td.rows.isEmpty) return;
    provider.updateElement(element.copyWith(
      height: (element.height - _rowH).clamp(
          _rowH * 2, double.infinity), // keep at least header + 1 row tall
      tableData: td.copyWith(rows: td.rows.sublist(0, td.rows.length - 1)),
    ));
  }

  void _addColumn() {
    final td = element.tableData;
    final newHeaders = [...td.headers, 'Column ${td.headers.length + 1}'];
    final newRows = td.rows.map((row) => [...row, '']).toList();
    // Widen the element by one average column width so all columns stay readable.
    final avgColW = td.headers.isEmpty
        ? 80.0
        : (element.width / td.headers.length);
    provider.updateElement(element.copyWith(
      width: element.width + avgColW,
      tableData: td.copyWith(headers: newHeaders, rows: newRows),
    ));
  }

  void _removeColumn() {
    final td = element.tableData;
    if (td.headers.isEmpty) return;
    final newHeaders = td.headers.sublist(0, td.headers.length - 1);
    final newRows = td.rows
        .map((row) => row.isEmpty ? row : row.sublist(0, row.length - 1))
        .toList();
    final colW = element.width / td.headers.length;
    provider.updateElement(element.copyWith(
      width: (element.width - colW).clamp(60.0, double.infinity),
      tableData: td.copyWith(headers: newHeaders, rows: newRows),
    ));
  }
}

// ── Table action button ───────────────────────────────────────────────────

class _TableActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _TableActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 13),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 11),
        ),
      );
}

// ── Divider fields ────────────────────────────────────────────────────────

class _SignatureFields {
  final SignatureBlockElement element;
  final TemplateEditorProvider provider;

  const _SignatureFields({required this.element, required this.provider});

  List<Widget> build() => [
        _StringField(
          'Signature Label',
          element.signatureLabel,
          (v) => provider.updateElement(element.copyWith(
            signatureLabel: v.trim().isEmpty ? 'Signature' : v.trim(),
          )),
        ),
        const SizedBox(height: AppSpacing.s3),
        _StringField(
          'Signature Value',
          element.signatureValue,
          (v) => provider.updateElement(element.copyWith(
            signatureValue: v.trim(),
          )),
        ),
        const SizedBox(height: AppSpacing.s3),
        _StringField(
          'Date Label',
          element.dateLabel,
          (v) => provider.updateElement(element.copyWith(
            dateLabel: v.trim().isEmpty ? 'Date' : v.trim(),
          )),
        ),
        const SizedBox(height: AppSpacing.s3),
        _StringField(
          'Date Value',
          element.dateValue,
          (v) => provider.updateElement(element.copyWith(
            dateValue: v.trim(),
          )),
        ),
      ];
}

class _DividerFields {
  final DividerElement element;
  final TemplateEditorProvider provider;

  const _DividerFields({required this.element, required this.provider});

  List<Widget> build() => [
        _NumField('Thickness', element.thickness,
            (v) => provider.updateElement(element.copyWith(thickness: v))),
        const SizedBox(height: AppSpacing.s3),
        _LabeledRow(
          label: 'Color',
          child: ColorPickerWidget(
            compact: true,
            initialColor: element.color,
            onColorChanged: (c) =>
                provider.updateElement(element.copyWith(color: c)),
          ),
        ),
      ];
}

// ── Shared UI primitives ──────────────────────────────────────────────────

class _NumField extends StatefulWidget {
  final String label;
  final double value;
  final void Function(double) onChanged;

  const _NumField(this.label, this.value, this.onChanged);

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(_NumField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_ctrl.text.endsWith('.')) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.bodyMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          SizedBox(
            height: 32,
            child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.body),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              onSubmitted: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) widget.onChanged(parsed);
              },
            ),
          ),
        ],
      );
}

class _StringField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _StringField(this.label, this.value, this.onChanged);

  @override
  State<_StringField> createState() => _StringFieldState();
}

class _StringFieldState extends State<_StringField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_StringField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.bodyMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          SizedBox(
            height: 32,
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(fontSize: 12, color: AppColors.body),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              onSubmitted: widget.onChanged,
              onEditingComplete: () => widget.onChanged(_ctrl.text),
            ),
          ),
        ],
      );
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.charcoal50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: active ? AppColors.primary : AppColors.body,
                fontSize: 13,
              )),
        ),
      );
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.bodyMuted)),
          ),
          child,
        ],
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s3),
        child: Divider(height: 1, color: AppColors.border),
      );
}
