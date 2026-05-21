# PDF Editor Module

An embeddable PDF document editor. The parent software passes document data in a defined JSON format — the user edits it in a full WYSIWYG canvas and downloads the result as a PDF.

No template selection screen. No preset library. Just: **pass data → edit → download.**

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
