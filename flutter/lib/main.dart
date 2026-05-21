import 'package:flutter/material.dart';

import 'data/sample_proposal.dart';
import 'pdf_editor_widget.dart';

/// Demo entry point — shows the proposal benchmark document.
/// Replace sampleProposalJson with your own data in production.
void main() {
  runApp(PdfEditorWidget.fromJson(
    json: sampleProposalJson,
    apiBaseUrl: 'http://localhost:3000',
    companyId: 'demo',
  ));
}
