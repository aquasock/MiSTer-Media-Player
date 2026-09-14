#!/usr/bin/env python3
"""Render the actual UI font ROM as a standalone browser character sheet."""
from pathlib import Path
import html
root=Path(__file__).resolve().parents[1]
rows=[int(line,2) for line in (root/'rtl/media_overlay_font.mem').read_text().splitlines() if line and not line.startswith('//')]
assert len(rows)==256*8
cards=[];available=[]
for code in range(256):
 glyph=rows[code*8:code*8+7]
 if not any(glyph):continue
 available.append(chr(code))
 pixels=''.join(f'<rect x="{x}" y="{y}" width="1" height="1"/>' for y,row in enumerate(glyph) for x in range(5) if row&(1<<(4-x)))
 cards.append(f'<article><svg viewBox="0 0 5 7" role="img" aria-label="{html.escape(chr(code),quote=True)}">{pixels}</svg><strong>{html.escape(chr(code))}</strong><span>0x{code:02X}</span></article>')
missing=' '.join(c for c in 'abcdefghijklmnopqrstuvwxyz' if c not in available)
page='''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MiSTer Media Player UI font</title>
<style>
body{margin:0;background:#101216;color:#eef2f4;font:16px system-ui,sans-serif}main{max-width:1100px;margin:32px auto;padding:0 24px}h1{font-size:26px}p{line-height:1.6;color:#bdc6ce}section{display:grid;grid-template-columns:repeat(auto-fill,minmax(88px,1fr));gap:12px;margin:24px 0}article{background:#181b20;border:1px solid #414851;border-radius:5px;padding:16px 8px;text-align:center}svg{width:40px;height:56px;display:block;margin:0 auto 12px;fill:#eef2f4;shape-rendering:crispEdges}strong,span{display:block}span{font:12px monospace;color:#9bacb8;margin-top:5px}code{color:#eef2f4}a{color:#c8e0ef}
</style><main><h1>Current player UI font</h1>
'''+f'''<p><strong>{len(available)} visible glyphs</strong>, drawn directly from <code>rtl/media_overlay_font.mem</code>.
Each glyph uses 5 × 7 pixels; text advances by 6 pixels at base size. Enlarged 8× below.</p>
<p>Space is blank. All other unassigned character codes also draw blank; the hardware does not substitute uppercase letters.</p>
<section>{''.join(cards)}</section>
<p>Lowercase letters not yet defined: <code>{missing}</code>.</p>
<p>Generated with <code>python3 tools/make_font_sheet.py</code>. <a href="overlay-preview.html">Overlay layout preview</a>.</p></main></html>
'''
out=root/'docs/ui/font-sheet.html';out.write_text(page)
print(out)
print('Visible glyphs:',len(available))
