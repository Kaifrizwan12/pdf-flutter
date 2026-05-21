import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_colors.dart';
import 'core/app_spacing.dart';
import 'core/app_theme.dart';
import 'keyboard/editor_shortcuts_handler.dart';
import 'models/pdf_document_data.dart';
import 'providers/template_editor_provider.dart';
import 'models/element_type.dart';
import 'models/template_model.dart';
import 'repositories/template_repository.dart';
import 'services/pdf_export_service.dart';
import 'views/template_preview_page.dart';
import 'widgets/canvas/editor_canvas_widget.dart';
import 'widgets/panels/left_panel_layers.dart';
import 'widgets/panels/right_panel_properties.dart';

/// Embeddable PDF editor widget.
///
/// Drop this anywhere in your app. The parent software supplies
/// [initialData] — no template selection screen is shown. The user
/// edits the document and can preview/download/print it.
///
/// ```dart
/// PdfEditorWidget(
///   initialData: PdfDocumentData.fromJson(myJson),
///   apiBaseUrl: 'https://api.example.com',
///   companyId: 'acme',
///   onClose: () => Navigator.pop(context),
/// )
/// ```
class PdfEditorWidget extends StatelessWidget {
  final PdfDocumentData initialData;
  final String apiBaseUrl;
  final String companyId;

  /// Called when the user taps the close/back button in the toolbar.
  /// If null, no close button is shown.
  final VoidCallback? onClose;

  const PdfEditorWidget({
    super.key,
    required this.initialData,
    required this.apiBaseUrl,
    this.companyId = '',
    this.onClose,
  });

  /// Convenience constructor — parent software passes raw JSON directly.
  ///
  /// ```dart
  /// PdfEditorWidget.fromJson(
  ///   json: apiResponse,   // Map<String, dynamic> from your backend
  ///   apiBaseUrl: 'https://api.example.com',
  ///   companyId: 'acme',
  ///   onClose: () => Navigator.pop(context),
  /// )
  /// ```
  factory PdfEditorWidget.fromJson({
    Key? key,
    required Map<String, dynamic> json,
    required String apiBaseUrl,
    String companyId = '',
    VoidCallback? onClose,
  }) =>
      PdfEditorWidget(
        key: key,
        initialData: PdfDocumentData.fromJson(json),
        apiBaseUrl: apiBaseUrl,
        companyId: companyId,
        onClose: onClose,
      );

  @override
  Widget build(BuildContext context) {
    // _NoOpRepository: the module never saves to a backend — the provider's
    // auto-save calls are silently discarded instead of hitting the API.
    final repo = _NoOpRepository();
    final exportService =
        PdfExportService(baseUrl: apiBaseUrl, companyId: companyId);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => TemplateEditorProvider(
              repo: repo,
              companyId: companyId,
            ),
          ),
          Provider<PdfExportService>.value(value: exportService),
        ],
        child: _EditorShell(
          initialData: initialData,
          onClose: onClose,
        ),
      ),
    );
  }
}

// ── Shell (stateful — owns loadFromData call) ─────────────────────────────────

class _EditorShell extends StatefulWidget {
  final PdfDocumentData initialData;
  final VoidCallback? onClose;

  const _EditorShell({required this.initialData, this.onClose});

  @override
  State<_EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<_EditorShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TemplateEditorProvider>().loadFromData(widget.initialData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TemplateEditorProvider>(
      builder: (context, provider, _) {
        if (!provider.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return EditorShortcutsWrapper(
          onSave: () {},
          child: Scaffold(
            backgroundColor: AppColors.pageBackground,
            body: Column(
              children: [
                _EmbeddedToolbar(
                  provider: provider,
                  onClose: widget.onClose,
                  onPreview: () => _openPreview(context, provider),
                  onDownload: () => _download(context, provider),
                  onPrint: () => _print(context, provider),
                ),
                Expanded(
                  child: _EditorBody(provider: provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPreview(BuildContext context, TemplateEditorProvider provider) {
    final template = provider.template;
    if (template == null) return;
    final snapshot = template.copyWith(elements: provider.elements.toList());
    final exportService = context.read<PdfExportService>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplatePreviewPage(
          template: snapshot,
          exportService: exportService,
        ),
      ),
    );
  }

  Future<void> _download(
      BuildContext context, TemplateEditorProvider provider) async {
    await _runExport(context, provider, print: false);
  }

  Future<void> _print(
      BuildContext context, TemplateEditorProvider provider) async {
    await _runExport(context, provider, print: true);
  }

  Future<void> _runExport(
    BuildContext context,
    TemplateEditorProvider provider, {
    required bool print,
  }) async {
    final template = provider.template;
    if (template == null) return;
    final exportService = context.read<PdfExportService>();
    final snapshot = template.copyWith(elements: provider.elements.toList());
    final name = snapshot.name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final fileName = (name.isEmpty ? 'document' : name) + '.pdf';

    try {
      if (print) {
        await exportService.printPdf(
          templateId: snapshot.id,
          elements: snapshot.elements,
          pageSize: snapshot.pageSize,
        );
      } else {
        await exportService.downloadPdf(
          templateId: snapshot.id,
          elements: snapshot.elements,
          pageSize: snapshot.pageSize,
          fileName: fileName,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(print ? 'Print failed: $e' : 'Download failed: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _EmbeddedToolbar extends StatelessWidget {
  final TemplateEditorProvider provider;
  final VoidCallback? onClose;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onPrint;

  const _EmbeddedToolbar({
    required this.provider,
    required this.onClose,
    required this.onPreview,
    required this.onDownload,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        children: [
          if (onClose != null) ...[
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              tooltip: 'Close editor',
            ),
            const SizedBox(width: AppSpacing.s2),
          ],

          // Document title
          Text(
            provider.template?.name ?? 'Document',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.body,
            ),
          ),

          const Spacer(),

          // Undo / Redo
          _UndoRedoButtons(provider: provider),

          const SizedBox(width: AppSpacing.s4),

          // Zoom
          Text(
            '${(provider.zoom * 100).round()}%',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.bodyMuted,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(width: AppSpacing.s4),

          _IconBtn(
            icon: Icons.download_outlined,
            tooltip: 'Download PDF',
            onTap: onDownload,
          ),
          const SizedBox(width: AppSpacing.s1),
          _IconBtn(
            icon: Icons.print_outlined,
            tooltip: 'Print PDF',
            onTap: onPrint,
          ),
          const SizedBox(width: AppSpacing.s3),

          OutlinedButton(
            onPressed: onPreview,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Preview'),
          ),
        ],
      ),
    );
  }
}

class _UndoRedoButtons extends StatelessWidget {
  final TemplateEditorProvider provider;

  const _UndoRedoButtons({required this.provider});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Tooltip(
            message: 'Undo (⌘Z)',
            child: InkWell(
              onTap: provider.canUndo ? provider.undo : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.undo,
                        size: 18,
                        color: provider.canUndo
                            ? AppColors.body
                            : AppColors.bodySubtle),
                    if (provider.undoCount > 0) ...[
                      const SizedBox(width: 2),
                      Text('${provider.undoCount}',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.bodyMuted)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Redo (⌘⇧Z)',
            child: InkWell(
              onTap: provider.canRedo ? provider.redo : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.redo,
                        size: 18,
                        color: provider.canRedo
                            ? AppColors.body
                            : AppColors.bodySubtle),
                    if (provider.redoCount > 0) ...[
                      const SizedBox(width: 2),
                      Text('${provider.redoCount}',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.bodyMuted)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 17, color: AppColors.bodyMuted),
          ),
        ),
      );
}

// ── Editor body ───────────────────────────────────────────────────────────────

class _EditorBody extends StatelessWidget {
  final TemplateEditorProvider provider;

  const _EditorBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 900;
    if (isDesktop) {
      return const Row(
        children: [
          LeftPanelLayers(),
          Expanded(child: EditorCanvasWidget()),
          RightPanelProperties(),
        ],
      );
    }
    return const EditorCanvasWidget();
  }
}

// ── No-op repository ──────────────────────────────────────────────────────────
// The module never persists to a backend — silently discards all save calls.

class _NoOpRepository implements TemplateRepository {
  @override
  Future<TemplateModel?> fetchTemplate(String c, String id) async => null;

  @override
  Future<void> updateTemplate(String c, TemplateModel t) async {}

  @override
  Future<TemplateModel> createTemplate(String c, TemplateModel t) async => t;

  @override
  Future<void> deleteTemplate(String c, String id) async {}

  @override
  Future<void> renameTemplate(String c, String id, String name) async {}

  @override
  Future<TemplateModel> duplicateTemplate(String c, String id, String name) async =>
      throw UnimplementedError();

  @override
  Future<TemplatePageResult> fetchTemplates(String c,
          {TemplateType? type, Object? cursor}) async =>
      const TemplatePageResult(items: []);

  @override
  Future<List<TemplateModel>> fetchPresetTemplates() async => [];

  @override
  Stream<List<TemplateModel>> watchTemplates(String c,
          {TemplateType? type}) =>
      const Stream.empty();
}
