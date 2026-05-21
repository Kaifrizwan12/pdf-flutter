/**
 * PDF Editor Module — minimal Node.js server.
 *
 * Exposes a single endpoint used by PdfEditorWidget:
 *   POST /api/templates/:templateId/generate
 *
 * The Flutter widget sends { elements, pageSize } and receives raw PDF bytes.
 *
 * Start:  node src/server.js
 * Env:    PORT (default 3000)  •  ALLOWED_ORIGIN (default *)
 */

import express from 'express';
import cors from 'cors';
import { validateGenerateRequest } from './template.schema.js';
import { generatePdf } from './pdf.service.js';

const app = express();

app.use(cors({ origin: process.env.ALLOWED_ORIGIN ?? '*' }));
app.use(express.json({ limit: '10mb' }));

// ── Health ────────────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ ok: true }));

// ── PDF generate ─────────────────────────────────────────────────────────────
// POST /api/templates/:templateId/generate
// Body: { elements: [...], pageSize: { width, height } }
// Returns: application/pdf bytes
app.post('/api/templates/:templateId/generate', async (req, res) => {
  try {
    const { elements, pageSize } = validateGenerateRequest(req.body);
    const sorted = [...elements].sort((a, b) => (a.zIndex ?? 0) - (b.zIndex ?? 0));
    const bytes = await generatePdf(sorted, pageSize);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'inline; filename="document.pdf"');
    res.send(Buffer.from(bytes));
  } catch (err) {
    const status = err.message?.startsWith('Element missing') ? 400 : 500;
    res.status(status).json({ error: err.message });
  }
});

const PORT = process.env.PORT ?? 3000;
app.listen(PORT, () => console.log(`PDF Editor Module server running on :${PORT}`));
