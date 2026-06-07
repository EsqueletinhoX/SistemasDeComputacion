import sys, os, markdown, weasyprint

src = sys.argv[1] if len(sys.argv) > 1 else "informe_tp5.md"
out = os.path.splitext(src)[0] + ".pdf"
base = os.path.dirname(os.path.abspath(src))

cuerpo = markdown.markdown(
    open(src, encoding="utf-8").read(),
    extensions=["fenced_code", "tables"]
)

css = """
@page { size: A4; margin: 2.2cm 2cm; }
body { font-family: "DejaVu Serif", Georgia, serif; font-size: 11pt; line-height: 1.45; color: #1a1a1a; }
h1 { font-size: 20pt; border-bottom: 2px solid #333; padding-bottom: .2em; }
h2 { font-size: 15pt; margin-top: 1.4em; border-bottom: 1px solid #ccc; padding-bottom: .15em; }
h3 { font-size: 12.5pt; margin-top: 1.1em; }
pre { background: #f5f5f5; border: 1px solid #ddd; border-radius: 4px;
      padding: .7em; font-size: 8.5pt; line-height: 1.3;
      white-space: pre-wrap; word-wrap: break-word; overflow-wrap: break-word;
      font-family: "DejaVu Sans Mono", monospace; }
code { font-family: "DejaVu Sans Mono", monospace; font-size: 9pt; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; font-size: 10pt; }
th, td { border: 1px solid #bbb; padding: .4em .6em; text-align: left; }
th { background: #e8e8e8; }
img { max-width: 100%; display: block; margin: .6em auto; border: 1px solid #ddd; }
hr { border: none; border-top: 1px solid #ccc; margin: 1.5em 0; }
"""

full = f"<!doctype html><html><head><meta charset='utf-8'><style>{css}</style></head><body>{cuerpo}</body></html>"
weasyprint.HTML(string=full, base_url=base).write_pdf(out)
print("PDF generado:", out)
