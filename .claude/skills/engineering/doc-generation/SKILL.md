---
name: doc-generation
description: Generate Office documents (DOCX, PDF, PPTX, XLSX) programmatically. Use when creating reports, invoices, presentations, spreadsheets, or any structured document from data.
argument-hint: "Generate a PDF invoice from the order data with company branding and line items"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references: []
thinking-level: low
---

# Document Generation Skill

Programmatically create Office documents from data: reports, invoices, presentations, spreadsheets, or structured output.

## Library Selection

| Format | JavaScript/TypeScript | Python |
|--------|----------------------|--------|
| DOCX | [docx](https://docx.js.org/) | [python-docx](https://python-docx.readthedocs.io/) |
| PDF | [pdf-lib](https://pdf-lib.js.org/), [@react-pdf/renderer](https://react-pdf.js.org/) | [reportlab](https://www.reportlab.com/), [weasyprint](https://doc.courtbouillon.org/weasyprint/) |
| PPTX | [pptxgenjs](https://gitbrent.github.io/pptxgenjs/) | [python-pptx](https://python-pptx.readthedocs.io/) |
| XLSX | [exceljs](https://exceljs.js.org/), [xlsx](https://sheetjs.com/) | [openpyxl](https://openpyxl.readthedocs.io/), [pandas](https://pandas.pydata.org/) |

## DOCX Example

Generate a document with headings, paragraphs, table, and image:

```javascript
const { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, AlignmentType, ImageRun } = require('docx');
const fs = require('fs');

async function generateReport(data) {
  const doc = new Document({
    sections: [{
      properties: {},
      children: [
        new Paragraph({
          text: "Quarterly Sales Report",
          heading: HeadingLevel.TITLE,
          alignment: AlignmentType.CENTER,
        }),
        new Paragraph({
          children: [new TextRun({ text: `Generated: ${data.date}`, italics: true })]
        }),
        new Paragraph({ text: "" }),
        new Paragraph({ text: "Executive Summary", heading: HeadingLevel.HEADING_1 }),
        new Paragraph({ text: data.summary }),
        new Table({
          rows: [
            new TableRow({
              children: [
                new TableCell({ children: [new Paragraph({ text: "Product", bold: true })] }),
                new TableCell({ children: [new Paragraph({ text: "Q1 Sales", bold: true })] }),
                new TableCell({ children: [new Paragraph({ text: "Q2 Sales", bold: true })] }),
              ],
            }),
            ...data.products.map(p => new TableRow({
              children: [
                new TableCell({ children: [new Paragraph({ text: p.name })] }),
                new TableCell({ children: [new Paragraph({ text: String(p.q1)) })] }),
                new TableCell({ children: [new Paragraph({ text: String(p.q2)) })] }),
              ],
            })),
          ],
        }),
      ],
    }],
  });

  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync("report.docx", buffer);
  return "report.docx";
}
```

## PDF Example

Generate an invoice with header, line items table, totals, and footer:

```javascript
const { PDFDocument, rgb, StandardFonts } = require('pdf-lib');

async function generateInvoice(invoiceData) {
  const pdfDoc = await PDFDocument.create();
  const page = pdfDoc.addPage([595, 842]); // A4
  const { width, height } = page.getSize();
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

  let y = height - 50;

  // Header with company branding
  page.drawText("INVOICE", { x: 50, y, size: 24, font: boldFont, color: rgb(0, 0.53, 0.71) });
  y -= 30;
  page.drawText(invoiceData.companyName, { x: 50, y, size: 14, font: boldFont });
  y -= 20;
  page.drawText(invoiceData.companyAddress, { x: 50, y, size: 10, font });

  // Invoice meta
  y -= 40;
  page.drawText(`Invoice #: ${invoiceData.number}`, { x: 50, y, size: 10, font });
  page.drawText(`Date: ${invoiceData.date}`, { x: 400, y, size: 10, font });

  // Line items header
  y -= 30;
  page.drawText("Description", { x: 50, y, size: 10, font: boldFont });
  page.drawText("Qty", { x: 300, y, size: 10, font: boldFont });
  page.drawText("Price", { x: 380, y, size: 10, font: boldFont });
  page.drawText("Total", { x: 480, y, size: 10, font: boldFont });

  // Line items
  y -= 20;
  let subtotal = 0;
  for (const item of invoiceData.items) {
    const total = item.qty * item.price;
    subtotal += total;
    page.drawText(item.description, { x: 50, y, size: 10, font });
    page.drawText(String(item.qty), { x: 300, y, size: 10, font });
    page.drawText(`$${item.price.toFixed(2)}`, { x: 380, y, size: 10, font });
    page.drawText(`$${total.toFixed(2)}`, { x: 480, y, size: 10, font });
    y -= 20;
  }

  // Totals
  y -= 10;
  const tax = subtotal * 0.1;
  const grandTotal = subtotal + tax;
  page.drawText(`Subtotal: $${subtotal.toFixed(2)}`, { x: 380, y, size: 10, font });
  y -= 15;
  page.drawText(`Tax (10%): $${tax.toFixed(2)}`, { x: 380, y, size: 10, font });
  y -= 20;
  page.drawText(`Total: $${grandTotal.toFixed(2)}`, { x: 380, y, size: 12, font: boldFont });

  // Footer
  page.drawText("Thank you for your business!", { x: 50, y: 50, size: 10, font, color: rgb(0.5, 0.5, 0.5) });

  const pdfBytes = await pdfDoc.save();
  fs.writeFileSync("invoice.pdf", pdfBytes);
  return "invoice.pdf";
}
```

## XLSX Example

Generate a spreadsheet with formatting, formulas, and charts:

```javascript
const ExcelJS = require('exceljs');

async function generateSpreadsheet(salesData) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'Doc Gen';
  workbook.created = new Date();

  const sheet = workbook.addWorksheet('Sales Report');

  sheet.columns = [
    { header: 'Product', key: 'product', width: 20 },
    { header: 'Q1', key: 'q1', width: 12 },
    { header: 'Q2', key: 'q2', width: 12 },
    { header: 'Q3', key: 'q3', width: 12 },
    { header: 'Q4', key: 'q4', width: 12 },
    { header: 'Total', key: 'total', width: 12 },
  ];

  // Data with formulas
  for (const row of salesData.products) {
    const addedRow = sheet.addRow({
      product: row.name,
      q1: row.q1, q2: row.q2, q3: row.q3, q4: row.q4,
    });
    addedRow.getCell('total').value = { formula: `SUM(C${addedRow.number}:F${addedRow.number})` };
  }

  // Summary row
  sheet.addRow([]);
  const totalRow = sheet.addRow({
    product: 'GRAND TOTAL',
    q1: { formula: 'SUM(C2:C100)' },
    q2: { formula: 'SUM(D2:D100)' },
    q3: { formula: 'SUM(E2:E100)' },
    q4: { formula: 'SUM(F2:F100)' },
  });
  totalRow.font = { bold: true };

  // Header styling
  sheet.getRow(1).font = { bold: true };
  sheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: '4472C4' } };
  sheet.getRow(1).alignment = { horizontal: 'center' };

  // Chart
  const chart = workbook.addChart({
    type: 'bar',
    title: 'Quarterly Sales by Product',
    yAxis: { title: 'Sales' },
    xAxis: { title: 'Product' },
  });
  chart.addSeries('Total', 'A2:A10', 'G2:G10');
  sheet.addChart(chart, 'I2');

  await workbook.xlsx.writeFile('sales-report.xlsx');
  return 'sales-report.xlsx';
}
```

## PPTX Example

Generate presentation with title slide, content slides, and images:

```javascript
const PptxGenJS = require('pptxgenjs');

function generatePresentation(presentationData) {
  const pres = new PptxGenJS();
  pres.layout = 'LAYOUT_16x9';
  pres.author = 'Doc Gen';
  pres.title = presentationData.title;

  // Title slide
  const titleSlide = pres.addSlide();
  titleSlide.addText(presentationData.title, {
    x: 0.5, y: 2.5, w: 9, h: 1,
    fontSize: 44, bold: true, color: '2E4057', align: 'center'
  });
  titleSlide.addText(presentationData.subtitle || '', {
    x: 0.5, y: 3.5, w: 9, h: 0.5,
    fontSize: 24, color: '666666', align: 'center'
  });

  // Content slides
  presentationData.slides.forEach((slide) => {
    const s = pres.addSlide();
    s.addText(slide.title, {
      x: 0.5, y: 0.3, w: 9, h: 0.6,
      fontSize: 32, bold: true, color: '2E4057'
    });

    if (slide.bullets) {
      s.addText(slide.bullets.map(b => ({ text: b, options: { bullet: true, fontSize: 18 } })), {
        x: 0.5, y: 1.2, w: 9, h: 4,
        fontSize: 18, color: '333333', lineSpacing: 30
      });
    }

    if (slide.image) {
      s.addImage({ path: slide.image, x: 1, y: 1.5, w: 8, h: 4, sizing: { type: 'contain', w: 8, h: 4 } });
    }
  });

  pres.writeFile({ fileName: 'presentation.pptx' });
  return 'presentation.pptx';
}
```

## Common Patterns

### Templating — Reusable templates for recurring document types:

```javascript
// template.js - define structure
const createInvoiceTemplate = (companyLogo) => ({
  header: { logo: companyLogo, type: 'INVOICE' },
  sections: [
    { type: 'address', fields: ['from', 'to'] },
    { type: 'lineItems', columns: ['description', 'qty', 'rate'] },
    { type: 'totals', calculations: ['subtotal', 'tax', 'total'] }
  ]
});

// Apply data to template
function renderInvoice(template, data) {
  return {
    header: { ...template.header, ...data.header },
    sections: template.sections.map(s => ({ ...s, ...data[s.type] }))
  };
}
```

### Batch Generation — Multiple documents from dataset:

```javascript
async function batchGenerate(template, records) {
  const results = [];
  for (const record of records) {
    const doc = await renderDocument(template, record);
    const filename = `${record.id}-${Date.now()}.docx`;
    await fs.promises.writeFile(filename, doc);
    results.push({ id: record.id, filename });
  }
  return results;
}

// Process large datasets in chunks
async function processLargeBatch(template, allRecords, batchSize = 50) {
  for (let i = 0; i < allRecords.length; i += batchSize) {
    const batch = allRecords.slice(i, i + batchSize);
    await batchGenerate(template, batch);
    console.log(`Processed ${Math.min(i + batchSize, allRecords.length)}/${allRecords.length}`);
  }
}
```

### Styling & Branding — Consistent branding across documents:

```javascript
const branding = {
  colors: { primary: '1E3A5F', secondary: '4A90A4', accent: 'F5A623', text: '333333' },
  fonts: { heading: 'Helvetica', body: 'Arial' },
  logo: 'assets/logo.png'
};

function applyBranding(element, type) {
  const c = branding.colors;
  switch(type) {
    case 'heading':
      element.fontSize = 24; element.fontFace = branding.fonts.heading; element.color = c.primary;
      break;
    case 'body':
      element.fontSize = 12; element.fontFace = branding.fonts.body; element.color = c.text;
      break;
    case 'accent':
      element.color = c.accent;
      break;
  }
  return element;
}
```

## Guidelines

| Library | Best For |
|---------|----------|
| pdf-lib | Straightforward PDF creation, no external deps |
| docx | Word docs with complex formatting |
| exceljs | Large datasets, formulas, charts |
| pptxgenjs | Responsive presentations |

- Generate asynchronously
- Handle file I/O errors gracefully
- Use streams for large files
