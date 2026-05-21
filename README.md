# PDF Editor Module

An embeddable, fully-featured PDF document editor. The parent app passes a document as JSON — the user edits it on a WYSIWYG canvas and downloads the result as a PDF.

No template picker. No sign-up flow. Just: **pass data → edit → download.**

---

## What's in v1

### Canvas & interactions
- **Drag, resize, and reorder** any element — 8-point resize handles with minimum-size enforcement
- **Multi-select** via Shift+Click or rubber-band drag
- **Smart snap guides** — real-time guide lines that snap to page edges, page center, thirds, and other element edges/centers (8 px threshold)
- **Alignment tools** — align left, right, top, bottom, center-H, center-V across a selection
- **Z-order controls** — bring forward/back one step or jump to front/back; drag-to-reorder in the layers panel
- **Undo / redo** — 50-state snapshot stack, Cmd/Ctrl+Z / Cmd/Ctrl+Shift+Z
- **Full keyboard shortcuts** — copy, cut, paste, duplicate (Cmd+D), select-all, delete, arrow-nudge (1 px / 10 px with Shift), zoom in/out/reset

### Element types (6)
| Type | What it does |
|---|---|
| `text` | Inline-editable text — font family, size, weight, italic, color, alignment, line-height, letter-spacing, background color |
| `image` | URL or base64 source — opacity, border radius, object-fit, drop shadow |
| `logo` | Simplified image placeholder — double-tap to pick a file, opacity control |
| `table` | Dynamic headers + rows — header/border/row colors, cell padding, alternating rows, inline cell editing |
| `signature_block` | Two-row signature + date field — renders blank line when value is empty |
| `divider` | Horizontal or vertical rule — solid, dashed, or dotted; color and thickness |

### Editor chrome
- **Layers panel** — sortable list with per-element visibility (👁) and lock (🔒) toggles; z-order drag handle; Add Element menu
- **Properties panel** — position/size inputs + type-specific controls (color pickers, font selectors, dropdowns) that sync live with the canvas
- **Toolbar** — undo/redo with count badges, live zoom readout, download PDF, print, full-screen preview
- **Zoom** — 20 %–500 % via pinch, scroll wheel, or toolbar buttons
- **Responsive layout** — three-column (layers + canvas + properties) on desktop; canvas-only on mobile

### Export & PDF generation
- One-click **Download PDF** and **Print** via the Node backend
- Server-side auto-flow layout engine — estimates wrapped line heights and adjusts downstream elements to avoid overlap
- Embeds Roboto (regular + bold) from Google Fonts; falls back to Helvetica on network failure
- Renders all six element types faithfully, including dashed dividers, alternating table rows, and image opacity

---

## Roadmap

> These are the next capabilities we plan to ship. The core editing experience is solid; everything below extends it.

- **Multi-page documents** — templates that span more than one page, with automatic overflow detection and configurable page-break rules
- **New element types** — shapes (rect, circle, line), QR codes, bar charts/pie charts, rich-text blocks (bold/italic/lists inline), and auto page-number stamps
- **Canvas element toolbar** — drag-and-drop new elements directly onto the canvas from a floating toolbar, without touching JSON or the layers panel
- **Preset template library** — built-in layout picker (invoice, proposal, contract, purchase order, etc.) so users can start from a polished base
- **Per-field input locking** — parent app can freeze specific sidebar controls (e.g. prevent changing a font, a color, or a table column) so end-users edit only what they're allowed to
- **Conditional visibility** — show or hide elements at render time based on data values passed in from the parent app (e.g. hide a discount row when discount is zero)
- **Element grouping** — group elements together so they move, resize, and copy as a single unit
- **Additional export formats** — download as PNG (page snapshot), SVG, or DOCX alongside PDF

---

## Structure

```
module/
  flutter/          Flutter widget (drop into any Flutter app)
  node/             Node.js PDF generation server
```

---

## Quick start

### 1 — Start the Node server

```bash
cd module/node
npm install
node src/index.js          # production
node --watch src/index.js  # development (auto-restart)
```

Server runs on `http://localhost:3000` by default.  
Set `PORT=8080` env var to change it.

### 2 — Run the Flutter demo

```bash
cd module/flutter
flutter pub get
flutter run -d chrome
```

Opens the sample proposal document ready to edit.

---

## Using the widget in your app

### Option A — path dependency (monorepo)

In your app's `pubspec.yaml`:
```yaml
dependencies:
  pdf_editor_module:
    path: ../module/flutter
```

### Option B — copy the files

Copy `module/flutter/lib/` into your project and add the same dependencies from `module/flutter/pubspec.yaml`.

### Usage

```dart
import 'package:pdf_editor_module/pdf_editor_module.dart';

// Somewhere in your widget tree:
PdfEditorWidget.fromJson(
  json: myDocumentJson,       // Map<String, dynamic> — see format below
  apiBaseUrl: 'http://localhost:3000',
  companyId: 'your-company',  // optional — sent as x-company-id header
  onClose: () => Navigator.pop(context),  // optional — shows ✕ button
)
```

Or if you already have a `PdfDocumentData` object:
```dart
PdfEditorWidget(
  initialData: PdfDocumentData.fromJson(myJson),
  apiBaseUrl: 'http://localhost:3000',
)
```

---

## Document JSON format

```json
{
  "name": "My Document",
  "pageSize": { "width": 595, "height": 842 },
  "elements": [ ... ]
}
```

| Field | Type | Required | Default |
|---|---|---|---|
| `name` | string | No | `"Document"` |
| `pageSize.width` | number | No | `595` (A4) |
| `pageSize.height` | number | No | `842` (A4) |
| `elements` | array | Yes | — |

---

## Element types

Every element shares these **base fields**:

| Field | Type | Notes |
|---|---|---|
| `id` | string | Unique per document |
| `type` | string | `text` `image` `logo` `table` `signature_block` `divider` |
| `x` | number | Canvas left (0–595) |
| `y` | number | Canvas top (0–842) |
| `width` | number | |
| `height` | number | |
| `zIndex` | number | Higher = in front |
| `locked` | boolean | Prevents move/resize |
| `visible` | boolean | |

---

### `text`

```json
{
  "id": "el_1", "type": "text",
  "x": 30, "y": 30, "width": 535, "height": 28,
  "zIndex": 2, "locked": false, "visible": true,
  "content": "Invoice #1042",
  "style": {
    "fontFamily": "Roboto",
    "fontSize": 22,
    "fontWeight": 700,
    "fontStyle": 0,
    "color": 4278190080,
    "textAlign": 0,
    "lineHeight": 1.5,
    "letterSpacing": 0
  }
}
```

| `style` field | Values |
|---|---|
| `fontFamily` | `"Roboto"` `"Merriweather"` `"Lato"` `"Oswald"` `"Open Sans"` `"PT Sans"` |
| `fontWeight` | `400` normal · `700` bold |
| `fontStyle` | `0` normal · `1` italic |
| `textAlign` | `0` left · `1` right · `2` center · `3` justify |
| `color` | 32-bit ARGB integer (see Colors section) |

---

### `logo`

Logo placeholder — double-tap lets the user pick an image file.

```json
{
  "id": "el_2", "type": "logo",
  "x": 30, "y": 30, "width": 120, "height": 55,
  "zIndex": 1, "locked": false, "visible": true,
  "src": "",
  "opacity": 1
}
```

---

### `image`

```json
{
  "id": "el_3", "type": "image",
  "x": 400, "y": 30, "width": 165, "height": 90,
  "zIndex": 2, "locked": false, "visible": true,
  "src": "https://example.com/photo.jpg",
  "opacity": 1.0,
  "borderRadius": 4,
  "objectFit": 1
}
```

| `objectFit` | |
|---|---|
| `0` | fill |
| `1` | contain |
| `2` | cover |

---

### `table`

```json
{
  "id": "el_4", "type": "table",
  "x": 30, "y": 200, "width": 535, "height": 165,
  "zIndex": 4, "locked": false, "visible": true,
  "tableData": {
    "headers": ["Description", "Qty", "Unit Price", "Total"],
    "rows": [
      ["Consulting services", "8", "$150.00", "$1,200.00"],
      ["Travel expenses",     "1", "$250.00", "$250.00"]
    ]
  },
  "tablestyle": {
    "headerBg":          4278355143,
    "borderColor":       4291548641,
    "cellPadding":       6,
    "alternateRows":     true,
    "alternateRowColor": 4294638330
  }
}
```

---

### `signature_block`

```json
{
  "id": "el_5", "type": "signature_block",
  "x": 30, "y": 760, "width": 240, "height": 60,
  "zIndex": 10, "locked": false, "visible": true,
  "signatureLabel": "Authorised by",
  "signatureValue": "",
  "dateLabel":      "Date",
  "dateValue":      ""
}
```

---

### `divider`

```json
{
  "id": "el_6", "type": "divider",
  "x": 30, "y": 150, "width": 535, "height": 2,
  "zIndex": 3, "locked": false, "visible": true,
  "orientation": "horizontal",
  "thickness": 1,
  "color": 4291548641,
  "dashStyle": "solid"
}
```

| `orientation` | `"horizontal"` · `"vertical"` |
|---|---|
| `dashStyle` | `"solid"` · `"dashed"` · `"dotted"` |

---

## Colors

Colors are **32-bit ARGB integers**: `0xAARRGGBB`

```
0xFF0284C7  →  4278355143  opaque blue   (brand accent)
0xFF0F172A  →  4279179050  opaque dark   (body text)
0xFF64748B  →  4284773515  opaque muted  (labels)
0xFFCBD5E1  →  4291548641  opaque border
0xFFF8FAFC  →  4294638330  near-white    (alt row)
0xFF000000  →  4278190080  black
0xFFFFFFFF  →  4294967295  white
```

Convert hex to decimal: strip `0x`, parse as base-16.  
In Dart you can write the literal directly: `'color': 0xFF0284C7`.

---

## Node server API

Only one endpoint is used by the Flutter widget:

```
POST /api/templates/:templateId/generate
Content-Type: application/json

{
  "elements": [ ... ],
  "pageSize": { "width": 595, "height": 842 }
}

→ 200 application/pdf
→ 400 { "error": "..." }  (validation failure)
→ 500 { "error": "..." }  (generation failure)
```

The `:templateId` in the URL is ignored — it exists only for URL-path compatibility with the full BuilderSolve backend.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | Port to listen on |
| `ALLOWED_ORIGIN` | `*` | CORS allowed origin |

---

## Sample document

`flutter/lib/data/sample_proposal.dart` contains `sampleProposalJson` — a complete Proposal / Scope of Work document with all six element types. Use it as the reference for building your own documents.

---

## Dependencies

### Flutter
| Package | Purpose |
|---|---|
| `provider` | State management |
| `http` | API calls |
| `file_picker` | Logo/image upload |
| `uuid` | Element ID generation |
| `google_fonts` | Font rendering |

### Node
| Package | Purpose |
|---|---|
| `express` | HTTP server |
| `pdf-lib` | PDF generation |
| `cors` | Cross-origin requests |
| `axios` | Font downloads |
