import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../core/logging_http_client.dart';
import '../models/template_element_model.dart';
import '../models/template_model.dart';

// Platform-conditional download/print helpers live in separate files so that
// dart:html (web) code is never compiled into native builds.
import 'pdf_platform_stub.dart'
    if (dart.library.html) 'pdf_platform_web.dart';

class PdfExportService {
  final String _baseUrl;
  final String _companyId;
  final http.Client _client;

  // Preset thumbnails — cached by presetId, stable for the session.
  final Map<String, Future<Uint8List>> _presetThumbnailCache = {};

  // User-template thumbnails — cached by "$templateId_$updatedAtMs" so a
  // save automatically busts the stale entry on the next home-page visit.
  final Map<String, Future<Uint8List>> _userThumbnailCache = {};

  PdfExportService({
    required String baseUrl,
    String companyId = 'demo-company',
    http.Client? client,
  })  : _baseUrl = baseUrl,
        _companyId = companyId,
        _client = client ?? LoggingHttpClient();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-company-id': _companyId,
      };

  /// Generates and returns raw PDF bytes from the backend.
  Future<Uint8List> generatePdfBytes({
    required String templateId,
    required List<TemplateElement> elements,
    required PageSize pageSize,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/templates/$templateId/generate');
    final response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'elements': elements.map((e) => e.toJson()).toList(),
        'pageSize': pageSize.toJson(),
      }),
    );

    if (response.statusCode != 200) {
      throw PdfExportException(
          'PDF generation failed (${response.statusCode}): ${response.body}');
    }
    return response.bodyBytes;
  }

  /// Returns a PNG thumbnail for a preset template.
  /// Results are cached for the lifetime of this service instance so the
  /// backend is called at most once per preset per session.
  Future<Uint8List> generatePresetThumbnailBytes({
    required String presetId,
  }) =>
      _presetThumbnailCache.putIfAbsent(presetId, () => _fetchPresetThumbnail(presetId));

  Future<Uint8List> _fetchPresetThumbnail(String presetId) async {
    final uri = Uri.parse('$_baseUrl/api/presets/$presetId/thumbnail');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode({}));
    if (response.statusCode != 200) {
      throw PdfExportException(
          'Preset thumbnail failed (${response.statusCode}): ${response.body}');
    }
    return response.bodyBytes;
  }

  /// Returns a PNG thumbnail for a user-created template.
  ///
  /// The cache key is "${templateId}_${updatedAt.ms}" so a save automatically
  /// invalidates the old entry — no explicit invalidation needed.
  Future<Uint8List> generateUserTemplateThumbnailBytes({
    required TemplateModel template,
  }) {
    final key =
        '${template.id}_${template.updatedAt.millisecondsSinceEpoch}';
    return _userThumbnailCache.putIfAbsent(
      key,
      () => generateThumbnailBytes(
        templateId: template.id,
        elements: template.elements,
        pageSize: template.pageSize,
      ),
    );
  }

  /// Generates a PNG thumbnail and returns the raw bytes.
  Future<Uint8List> generateThumbnailBytes({
    required String templateId,
    required List<TemplateElement> elements,
    required PageSize pageSize,
  }) async {
    final uri =
        Uri.parse('$_baseUrl/api/templates/$templateId/thumbnail');
    final response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'elements': elements.map((e) => e.toJson()).toList(),
        'pageSize': pageSize.toJson(),
      }),
    );

    if (response.statusCode != 200) {
      throw PdfExportException(
          'Thumbnail generation failed (${response.statusCode}): ${response.body}');
    }
    return response.bodyBytes;
  }

  /// Triggers a browser download of the generated PDF.
  /// On non-web platforms, returns the bytes for the caller to handle.
  Future<Uint8List> downloadPdf({
    required String templateId,
    required List<TemplateElement> elements,
    required PageSize pageSize,
    String? fileName,
  }) async {
    final bytes = await generatePdfBytes(
      templateId: templateId,
      elements: elements,
      pageSize: pageSize,
    );

    if (kIsWeb) {
      triggerWebDownload(
        bytes: bytes,
        mimeType: 'application/pdf',
        fileName: fileName ?? 'template.pdf',
      );
    }

    return bytes;
  }

  /// Opens the generated PDF in a new browser tab (suitable for Print dialog).
  /// On non-web platforms, returns the bytes for the caller to handle.
  Future<Uint8List> printPdf({
    required String templateId,
    required List<TemplateElement> elements,
    required PageSize pageSize,
  }) async {
    final printTarget = kIsWeb ? prepareWebPrintTarget() : null;
    final bytes = await generatePdfBytes(
      templateId: templateId,
      elements: elements,
      pageSize: pageSize,
    );

    if (kIsWeb) {
      openWebBlob(
        bytes: bytes,
        mimeType: 'application/pdf',
        printTarget: printTarget,
      );
    }

    return bytes;
  }
}

class PdfExportException implements Exception {
  final String message;
  const PdfExportException(this.message);

  @override
  String toString() => 'PdfExportException: $message';
}
