/// Single import for the PDF Editor Module.
///
/// Usage:
///   import 'package:pdf_editor_module/pdf_editor_module.dart';
///
///   PdfEditorWidget.fromJson(
///     json: myDocumentJson,
///     apiBaseUrl: 'https://your-server.com',
///     companyId: 'acme',
///     onClose: () => Navigator.pop(context),
///   )
library pdf_editor_module;

export 'pdf_editor_widget.dart';
export 'models/pdf_document_data.dart';
export 'models/template_element_model.dart';
export 'models/template_model.dart';
export 'models/element_type.dart';
