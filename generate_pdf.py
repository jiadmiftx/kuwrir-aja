#!/usr/bin/env python3
"""
Converts SYSTEM_OVERVIEW.md and SPECIFICATION.md to styled PDFs
using python-markdown + weasyprint.
"""
import os, sys
import markdown
from weasyprint import HTML, CSS

BASE = os.path.dirname(os.path.abspath(__file__))

CSS_STYLE = """
@page {
    size: A4;
    margin: 2cm 2.2cm 2cm 2.2cm;
    @bottom-right {
        content: "Halaman " counter(page) " dari " counter(pages);
        font-size: 9pt;
        color: #888;
    }
}

body {
    font-family: 'Helvetica Neue', Arial, sans-serif;
    font-size: 10.5pt;
    line-height: 1.65;
    color: #1a1a2e;
}

h1 {
    font-size: 22pt;
    font-weight: 800;
    color: #e84e3c;
    border-bottom: 3px solid #e84e3c;
    padding-bottom: 8px;
    margin-top: 0;
    margin-bottom: 16px;
}

h2 {
    font-size: 14pt;
    font-weight: 700;
    color: #1a1a2e;
    border-bottom: 1.5px solid #e0e0e0;
    padding-bottom: 5px;
    margin-top: 28px;
    margin-bottom: 12px;
}

h3 {
    font-size: 11.5pt;
    font-weight: 700;
    color: #e84e3c;
    margin-top: 18px;
    margin-bottom: 8px;
}

h4 {
    font-size: 10.5pt;
    font-weight: 700;
    color: #333;
    margin-top: 14px;
    margin-bottom: 6px;
}

p { margin: 0 0 10px 0; }

a { color: #e84e3c; text-decoration: none; }

/* Tables */
table {
    width: 100%;
    border-collapse: collapse;
    margin: 12px 0 18px 0;
    font-size: 9.5pt;
    page-break-inside: avoid;
}

th {
    background-color: #1a1a2e;
    color: #ffffff;
    padding: 7px 10px;
    text-align: left;
    font-weight: 600;
}

td {
    padding: 6px 10px;
    border-bottom: 1px solid #e8e8e8;
    vertical-align: top;
}

tr:nth-child(even) td { background-color: #f8f8fb; }
tr:hover td { background-color: #fff3f2; }

/* Code blocks */
pre {
    background-color: #1e1e2e;
    color: #cdd6f4;
    padding: 14px 16px;
    border-radius: 6px;
    font-family: 'Courier New', Courier, monospace;
    font-size: 8.5pt;
    line-height: 1.5;
    overflow-x: auto;
    margin: 12px 0 16px 0;
    page-break-inside: avoid;
    white-space: pre-wrap;
    word-wrap: break-word;
}

code {
    background-color: #f0f0f5;
    color: #c0392b;
    padding: 1px 5px;
    border-radius: 3px;
    font-family: 'Courier New', Courier, monospace;
    font-size: 9pt;
}

pre code {
    background: none;
    color: inherit;
    padding: 0;
    font-size: 8.5pt;
}

/* Lists */
ul, ol {
    margin: 6px 0 10px 0;
    padding-left: 22px;
}

li { margin-bottom: 4px; }

/* Blockquotes */
blockquote {
    border-left: 4px solid #e84e3c;
    margin: 12px 0;
    padding: 8px 16px;
    background-color: #fff8f8;
    color: #555;
    font-style: italic;
    border-radius: 0 4px 4px 0;
}

/* HR */
hr {
    border: none;
    border-top: 2px solid #e0e0e0;
    margin: 24px 0;
}

/* Cover page styling for first h1 */
.cover {
    text-align: center;
    padding: 60px 0 40px 0;
    page-break-after: always;
}

.cover h1 {
    font-size: 32pt;
    border: none;
    color: #e84e3c;
}

.cover .subtitle {
    font-size: 13pt;
    color: #666;
    margin-top: 8px;
}

.cover .meta {
    font-size: 10pt;
    color: #888;
    margin-top: 30px;
    border-top: 1px solid #e0e0e0;
    padding-top: 16px;
}

/* Page break hints */
h2 { page-break-after: avoid; }
h3 { page-break-after: avoid; }
table { page-break-inside: avoid; }
"""

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<title>{title}</title>
</head>
<body>
{body}
</body>
</html>"""

def md_to_pdf(md_file, pdf_file, title):
    print(f"  Converting {os.path.basename(md_file)} → {os.path.basename(pdf_file)} ...")

    with open(md_file, 'r', encoding='utf-8') as f:
        md_text = f.read()

    body = markdown.markdown(
        md_text,
        extensions=['tables', 'fenced_code', 'nl2br', 'toc'],
        output_format='html',
    )

    html = HTML_TEMPLATE.format(title=title, body=body)
    css = CSS(string=CSS_STYLE)
    HTML(string=html, base_url=BASE).write_pdf(pdf_file, stylesheets=[css])
    size_kb = os.path.getsize(pdf_file) // 1024
    print(f"  ✓ {os.path.basename(pdf_file)} ({size_kb} KB)")

docs = [
    ("SYSTEM_OVERVIEW.md",  "SYSTEM_OVERVIEW.pdf",  "KUWRIR System Overview & Design Proposal"),
    ("SPECIFICATION.md",    "SPECIFICATION.pdf",    "KUWRIR Platform Technical Specification"),
    ("CHANGELOG.md",        "CHANGELOG.pdf",        "KUWRIR Platform Changelog"),
]

print("\n=== KUWRIR PDF Generator ===\n")
for md_name, pdf_name, title in docs:
    md_path  = os.path.join(BASE, md_name)
    pdf_path = os.path.join(BASE, pdf_name)
    if not os.path.exists(md_path):
        print(f"  SKIP: {md_name} not found")
        continue
    try:
        md_to_pdf(md_path, pdf_path, title)
    except Exception as e:
        print(f"  ERROR generating {pdf_name}: {e}")

print("\nDone. PDF files saved to project root.\n")
