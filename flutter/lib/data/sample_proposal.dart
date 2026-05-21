/// ─────────────────────────────────────────────────────────────────────────────
/// BENCHMARK — exact JSON shape the parent software must provide.
///
/// PdfEditorWidget.fromJson(json: sampleProposalJson, apiBaseUrl: '...')
///
/// Colors: 32-bit ARGB  0xAARRGGBB
///   0xFF0284C7 blue · 0xFF0F172A dark · 0xFF64748B muted · 0xFFCBD5E1 border
///
/// text.style keys
///   fontFamily : 'Roboto'|'Merriweather'|'Lato'|'Oswald'|'Open Sans'
///   fontWeight : 400 | 700
///   fontStyle  : 0 (normal) | 1 (italic)
///   textAlign  : 0 (left) | 1 (right) | 2 (center) | 3 (justify)
///
/// table keys
///   tableData.headers         : List<String>
///   tableData.rows            : List<List<String>>
///   tablestyle.headerBg       : int (ARGB)
///   tablestyle.borderColor    : int (ARGB)
///   tablestyle.cellPadding    : double
///   tablestyle.alternateRows  : bool
///   tablestyle.alternateRowColor : int (ARGB)
///
/// signature_block keys (all optional — shown with defaults)
///   signatureLabel / signatureValue / dateLabel / dateValue
/// ─────────────────────────────────────────────────────────────────────────────

const Map<String, dynamic> sampleProposalJson = {
  'name': 'Proposal / Scope of Work',
  'pageSize': {'width': 595, 'height': 842},
  'elements': [

    // ── 1 · Logo placeholder ─────────────────────────────────────────────────
    {
      'id': 'el_1', 'type': 'logo',
      'x': 30, 'y': 30, 'width': 120, 'height': 55,
      'zIndex': 1, 'locked': false, 'visible': true,
      'src': '', 'opacity': 1,
    },

    // ── 2 · Document title ───────────────────────────────────────────────────
    {
      'id': 'el_2', 'type': 'text',
      'x': 225, 'y': 34, 'width': 340, 'height': 30,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'PROPOSAL',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 26, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 2,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 3 · Company subtitle ─────────────────────────────────────────────────
    {
      'id': 'el_3', 'type': 'text',
      'x': 250, 'y': 72, 'width': 315, 'height': 36,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'BuilderSolve Construction Pty Ltd\n123 Builder Street, Sydney NSW 2000',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 9, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF64748B, 'textAlign': 2,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 4 · Divider ──────────────────────────────────────────────────────────
    {
      'id': 'el_4', 'type': 'divider',
      'x': 30, 'y': 125, 'width': 535, 'height': 2,
      'zIndex': 3, 'locked': false, 'visible': true,
      'orientation': 'horizontal', 'thickness': 1,
      'color': 0xFFCBD5E1, 'dashStyle': 'solid',
    },

    // ── 5 · "Client" label ───────────────────────────────────────────────────
    {
      'id': 'el_5', 'type': 'text',
      'x': 30, 'y': 145, 'width': 120, 'height': 16,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Client',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 9, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF64748B, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 6 · Client value ─────────────────────────────────────────────────────
    {
      'id': 'el_6', 'type': 'text',
      'x': 30, 'y': 164, 'width': 245, 'height': 42,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Client Name\nProject Address',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 11, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 7 · "Proposal No." label ─────────────────────────────────────────────
    {
      'id': 'el_7', 'type': 'text',
      'x': 330, 'y': 145, 'width': 100, 'height': 16,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Proposal No.',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 9, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF64748B, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 8 · Proposal number ──────────────────────────────────────────────────
    {
      'id': 'el_8', 'type': 'text',
      'x': 440, 'y': 145, 'width': 100, 'height': 16,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'PRO-001',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 11, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 9 · "Date" label ─────────────────────────────────────────────────────
    {
      'id': 'el_9', 'type': 'text',
      'x': 330, 'y': 168, 'width': 100, 'height': 16,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Date',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 9, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF64748B, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 10 · Date value ──────────────────────────────────────────────────────
    {
      'id': 'el_10', 'type': 'text',
      'x': 440, 'y': 168, 'width': 100, 'height': 16,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': '1 June 2024',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 11, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 11 · Divider ─────────────────────────────────────────────────────────
    {
      'id': 'el_11', 'type': 'divider',
      'x': 30, 'y': 220, 'width': 535, 'height': 2,
      'zIndex': 3, 'locked': false, 'visible': true,
      'orientation': 'horizontal', 'thickness': 1,
      'color': 0xFFCBD5E1, 'dashStyle': 'solid',
    },

    // ── 12 · "Scope" heading ─────────────────────────────────────────────────
    {
      'id': 'el_12', 'type': 'text',
      'x': 30, 'y': 238, 'width': 160, 'height': 28,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Scope',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 14, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 13 · Scope description ───────────────────────────────────────────────
    {
      'id': 'el_13', 'type': 'text',
      'x': 30, 'y': 267, 'width': 535, 'height': 38,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Simple editable proposal for a small construction scope. Update the rows, totals and notes before export.',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 10, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.6, 'letterSpacing': 0,
      },
    },

    // ── 14 · Line items table ────────────────────────────────────────────────
    {
      'id': 'el_14', 'type': 'table',
      'x': 30, 'y': 325, 'width': 535, 'height': 165,
      'zIndex': 4, 'locked': false, 'visible': true,
      'tableData': {
        'headers': ['Item', 'Qty', 'Rate', 'Total'],
        'rows': [
          ['Site setup',     '1', '\$1,200',  '\$1,200'],
          ['Concrete works', '1', '\$8,500',  '\$8,500'],
          ['Framing works',  '1', '\$12,000', '\$12,000'],
        ],
      },
      'tablestyle': {
        'headerBg':          0xFF0284C7,
        'borderColor':       0xFFCBD5E1,
        'cellPadding':       6,
        'alternateRows':     true,
        'alternateRowColor': 0xFFF8FAFC,
      },
    },

    // ── 15 · Subtotal label ──────────────────────────────────────────────────
    {
      'id': 'el_15', 'type': 'text',
      'x': 360, 'y': 510, 'width': 100, 'height': 18,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Subtotal',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 11, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 16 · Subtotal value ──────────────────────────────────────────────────
    {
      'id': 'el_16', 'type': 'text',
      'x': 465, 'y': 510, 'width': 100, 'height': 18,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': '\$21,700',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 11, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 2,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 17 · GST label ───────────────────────────────────────────────────────
    {
      'id': 'el_17', 'type': 'text',
      'x': 360, 'y': 532, 'width': 100, 'height': 18,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'GST',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 11, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 18 · GST value ───────────────────────────────────────────────────────
    {
      'id': 'el_18', 'type': 'text',
      'x': 465, 'y': 532, 'width': 100, 'height': 18,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': '\$2,170',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 11, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 2,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 19 · TOTAL label ─────────────────────────────────────────────────────
    {
      'id': 'el_19', 'type': 'text',
      'x': 360, 'y': 560, 'width': 100, 'height': 20,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'TOTAL',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 14, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF0284C7, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 20 · TOTAL value ─────────────────────────────────────────────────────
    {
      'id': 'el_20', 'type': 'text',
      'x': 465, 'y': 560, 'width': 100, 'height': 20,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': '\$23,870',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 14, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF0284C7, 'textAlign': 2,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 21 · Divider ─────────────────────────────────────────────────────────
    {
      'id': 'el_21', 'type': 'divider',
      'x': 30, 'y': 610, 'width': 535, 'height': 2,
      'zIndex': 3, 'locked': false, 'visible': true,
      'orientation': 'horizontal', 'thickness': 1,
      'color': 0xFFCBD5E1, 'dashStyle': 'solid',
    },

    // ── 22 · "Notes" heading ─────────────────────────────────────────────────
    {
      'id': 'el_22', 'type': 'text',
      'x': 30, 'y': 628, 'width': 200, 'height': 16,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Notes',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 11, 'fontWeight': 700,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 23 · Notes body ──────────────────────────────────────────────────────
    {
      'id': 'el_23', 'type': 'text',
      'x': 30, 'y': 650, 'width': 535, 'height': 44,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Payment terms: deposit on acceptance, balance by progress claim.\nAll changes must be approved in writing.',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 9, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF0F172A, 'textAlign': 0,
        'lineHeight': 1.7, 'letterSpacing': 0,
      },
    },

    // ── 24 · Builder signature block ─────────────────────────────────────────
    {
      'id': 'el_24', 'type': 'signature_block',
      'x': 30, 'y': 728, 'width': 240, 'height': 60,
      'zIndex': 10, 'locked': false, 'visible': true,
      'signatureLabel': 'Authorised by',
      'signatureValue': '',
      'dateLabel':      'Date',
      'dateValue':      '',
    },

    // ── 25 · Client signature block ──────────────────────────────────────────
    {
      'id': 'el_25', 'type': 'signature_block',
      'x': 315, 'y': 728, 'width': 240, 'height': 60,
      'zIndex': 10, 'locked': false, 'visible': true,
      'signatureLabel': 'Client signature',
      'signatureValue': '',
      'dateLabel':      'Date',
      'dateValue':      '',
    },

    // ── 26 · Builder caption ─────────────────────────────────────────────────
    {
      'id': 'el_26', 'type': 'text',
      'x': 30, 'y': 794, 'width': 240, 'height': 14,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Builder',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 9, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF64748B, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

    // ── 27 · Client caption ──────────────────────────────────────────────────
    {
      'id': 'el_27', 'type': 'text',
      'x': 315, 'y': 794, 'width': 240, 'height': 14,
      'zIndex': 2, 'locked': false, 'visible': true,
      'content': 'Client',
      'style': {
        'fontFamily': 'Roboto', 'fontSize': 9, 'fontWeight': 400,
        'fontStyle': 0, 'color': 0xFF64748B, 'textAlign': 0,
        'lineHeight': 1.5, 'letterSpacing': 0,
      },
    },

  ],
};
