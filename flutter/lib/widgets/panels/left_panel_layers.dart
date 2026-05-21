import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../models/template_element_model.dart';
import '../../providers/template_editor_provider.dart';

/// Figma-style layers panel. Shows all elements in ascending z-index order
/// (backmost element at the top of the list). Each row shows element icon,
/// name, visibility toggle, and lock toggle.
///
/// Table and SignatureBlock rows expand inline to show their child
/// fields without affecting the drag-reorder order.
class LeftPanelLayers extends StatefulWidget {
  const LeftPanelLayers({super.key});

  @override
  State<LeftPanelLayers> createState() => _LeftPanelLayersState();
}

class _LeftPanelLayersState extends State<LeftPanelLayers> {
  // IDs of layer rows the user has expanded (table / signature).
  final Set<String> _expanded = {};

  void _toggleExpanded(String id) => setState(
      () => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'Layers',
            action: IconButton(
              icon: const Icon(Icons.add, size: 18),
              tooltip: 'Add element',
              onPressed: () => _showAddMenu(context),
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: Consumer<TemplateEditorProvider>(
              builder: (context, provider, _) {
                // Ascending z-index: index 0 = backmost, last = frontmost.
                final layers = provider.sortedElements;

                if (layers.isEmpty) {
                  return const Center(
                    child: Text(
                      'No elements yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.bodyMuted, fontSize: 12),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: layers.length,
                  onReorder: (oldIdx, newIdx) =>
                      _onReorder(provider, layers, oldIdx, newIdx),
                  itemBuilder: (context, idx) {
                    final el = layers[idx];
                    final isExpanded = _expanded.contains(el.id);
                    return _buildLayerItem(
                      key: ValueKey(el.id),
                      context: context,
                      idx: idx,
                      el: el,
                      provider: provider,
                      isExpanded: isExpanded,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerItem({
    required Key key,
    required BuildContext context,
    required int idx,
    required TemplateElement el,
    required TemplateEditorProvider provider,
    required bool isExpanded,
  }) {
    final hasChildren = el is TableElement || el is SignatureBlockElement;

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LayerRow(
          index: idx,
          element: el,
          isSelected: provider.isSelected(el.id),
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onTap: () => provider.selectElement(el.id, focus: true),
          onExpandToggle: hasChildren ? () => _toggleExpanded(el.id) : null,
          onVisibilityToggle: () => provider.toggleVisibility(el.id),
          onLockToggle: () => provider.toggleLock(el.id),
        ),
        if (isExpanded && el is TableElement)
          _TableChildren(
            table: el,
            isSelected: provider.isSelected(el.id),
          ),
        if (isExpanded && el is SignatureBlockElement)
          _SignatureChildren(
            element: el,
            isSelected: provider.isSelected(el.id),
          ),
      ],
    );
  }

  void _onReorder(
    TemplateEditorProvider provider,
    List<TemplateElement> layers,
    int oldIdx,
    int newIdx,
  ) {
    if (newIdx > oldIdx) newIdx--;
    final reordered = [...layers];
    final moved = reordered.removeAt(oldIdx);
    reordered.insert(newIdx, moved);
    // Batch all z-index updates in one undo state via the dedicated method.
    provider.reorderLayers(reordered.map((e) => e.id).toList());
  }

  void _showAddMenu(BuildContext context) {
    final provider = context.read<TemplateEditorProvider>();
    showDialog<void>(
      context: context,
      builder: (_) => _AddElementDialog(provider: provider),
    );
  }
}

// ── Panel header ──────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _PanelHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.body,
                )),
            const Spacer(),
            if (action != null) action!,
          ],
        ),
      );
}

// ── Layer row ─────────────────────────────────────────────────────────────────

class _LayerRow extends StatelessWidget {
  final int index;
  final TemplateElement element;
  final bool isSelected;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onExpandToggle;
  final VoidCallback onVisibilityToggle;
  final VoidCallback onLockToggle;

  const _LayerRow({
    required this.index,
    required this.element,
    required this.isSelected,
    required this.hasChildren,
    required this.isExpanded,
    required this.onTap,
    required this.onExpandToggle,
    required this.onVisibilityToggle,
    required this.onLockToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.3)
              : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.s2),
                child: Icon(Icons.drag_indicator,
                    size: 16, color: AppColors.bodySubtle),
              ),
            ),

            // Expand chevron (table / signature only)
            if (hasChildren)
              GestureDetector(
                onTap: onExpandToggle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: AppColors.bodyMuted,
                  ),
                ),
              )
            else
              const SizedBox(width: 18),

            Icon(element.type.icon, size: 14, color: AppColors.bodyMuted),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                _label(),
                style: TextStyle(
                  fontSize: 12,
                  color:
                      element.visible ? AppColors.body : AppColors.bodySubtle,
                  fontStyle:
                      element.visible ? FontStyle.normal : FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SmallIconBtn(
                    icon: element.visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    onTap: onVisibilityToggle,
                    tooltip: element.visible ? 'Hide' : 'Show',
                  ),
                  _SmallIconBtn(
                    icon: element.locked
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    onTap: onLockToggle,
                    tooltip: element.locked ? 'Unlock' : 'Lock',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label() => switch (element) {
        TextElement te =>
          te.content.trim().isEmpty ? 'Text' : te.content.replaceAll('\n', ' '),
        ImageElement _ => 'Image',
        TableElement _ => 'Table',
        LogoElement _ => 'Logo',
        SignatureBlockElement _ => 'Signature Block',
        DividerElement _ => 'Divider',
      };
}

// ── Table children ────────────────────────────────────────────────────────────

class _TableChildren extends StatelessWidget {
  final TableElement table;
  final bool isSelected;

  const _TableChildren({
    required this.table,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TemplateEditorProvider>();
    final td = table.tableData;
    final children = <Widget>[];

    // Header cells
    for (int i = 0; i < td.headers.length; i++) {
      children.add(_ChildRow(
        icon: Icons.title,
        label: td.headers[i].isEmpty ? 'Header ${i + 1}' : td.headers[i],
        isHeader: true,
        isSelected: isSelected,
        onTap: () => provider.selectElement(table.id, focus: true),
      ));
    }

    // Data rows — each row shown as one entry previewing the first two cells
    for (int r = 0; r < td.rows.length; r++) {
      final row = td.rows[r];
      final preview = row.where((c) => c.trim().isNotEmpty).take(2).join(' · ');
      children.add(_ChildRow(
        icon: Icons.table_rows_outlined,
        label: preview.isEmpty ? 'Row ${r + 1}' : preview,
        isHeader: false,
        isSelected: isSelected,
        onTap: () => provider.selectElement(table.id, focus: true),
      ));
    }

    if (children.isEmpty) {
      children.add(_ChildRow(
        icon: Icons.grid_off_outlined,
        label: 'Empty table',
        isHeader: false,
        isSelected: isSelected,
        onTap: () => provider.selectElement(table.id, focus: true),
      ));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

// ── Signature children ────────────────────────────────────────────────────────

class _SignatureChildren extends StatelessWidget {
  final SignatureBlockElement element;
  final bool isSelected;

  const _SignatureChildren({
    required this.element,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TemplateEditorProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChildRow(
          icon: Icons.draw_outlined,
          label:
              '${element.signatureLabel}: ${element.signatureValue.isEmpty ? '___________' : element.signatureValue}',
          isHeader: false,
          isSelected: isSelected,
          onTap: () => provider.selectElement(element.id, focus: true),
        ),
        _ChildRow(
          icon: Icons.calendar_today_outlined,
          label:
              '${element.dateLabel}: ${element.dateValue.isEmpty ? '___________' : element.dateValue}',
          isHeader: false,
          isSelected: isSelected,
          onTap: () => provider.selectElement(element.id, focus: true),
        ),
      ],
    );
  }
}

// ── Shared child row ──────────────────────────────────────────────────────────

class _ChildRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHeader;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChildRow({
    required this.icon,
    required this.label,
    required this.isHeader,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.only(
            left: AppSpacing.s6 + 18,
            right: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryLight.withValues(alpha: 0.22)
                : const Color(0xFFF8FAFC),
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
              bottom: const BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 12, color: AppColors.bodySubtle),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isHeader ? AppColors.primaryDark : AppColors.bodyMuted,
                    fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Small icon button ─────────────────────────────────────────────────────────

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _SmallIconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(icon, size: 14, color: AppColors.bodyMuted),
            ),
          ),
        ),
      );
}

// ── Add element dialog ────────────────────────────────────────────────────────

class _AddElementDialog extends StatelessWidget {
  final TemplateEditorProvider provider;

  const _AddElementDialog({required this.provider});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Element',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tile(context, 'Text', Icons.text_fields,
                () => provider.addElement(TextElement.defaults())),
            _tile(context, 'Image', Icons.image_outlined,
                () => provider.addElement(ImageElement.defaults())),
            _tile(context, 'Table', Icons.table_chart_outlined,
                () => provider.addElement(TableElement.defaults())),
            _tile(context, 'Logo', Icons.business_outlined,
                () => provider.addElement(LogoElement.defaults())),
            _tile(context, 'Signature Block', Icons.draw_outlined,
                () => provider.addElement(SignatureBlockElement.defaults())),
            _tile(context, 'Divider', Icons.horizontal_rule,
                () => provider.addElement(DividerElement.defaults())),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  ListTile _tile(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) =>
      ListTile(
        dense: true,
        leading: Icon(icon, color: AppColors.primary, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
}
