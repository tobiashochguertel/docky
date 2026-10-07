#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Render an HTML replica of Docky's bar from docky-layout.json.

Opens a 2x-scale visualization with toggleable alignment guides
(tile top, icon bottom, label baseline, tile bottom), per-tile metrics
on click, and inter-tile gap readouts — for exploring sizes, paddings,
and margins without screenshots.
"""

from __future__ import annotations

import html
import json
import math
import subprocess
from pathlib import Path

SNAPSHOT = Path.home() / "Library/Logs/Docky/docky-layout.json"
OUTPUT = Path("/tmp/docky-dock-preview.html")
SCALE = 2

KIND_COLORS = {
    "app": "#3b82f6",
    "appFolder": "#a855f7",
    "min": "#f59e0b",
    "folder": "#84cc16",
    "trash": "#6b7280",
    "divider": "#374151",
    "launchpad": "#06b6d6",
    "startMenu": "#ec4899",
    "widget": "#14b8a6",
    "smartStack": "#14b6a6",
    "spacer": "#1f2937",
    "flexSpacer": "#1f2937",
}


def main() -> None:
    if not SNAPSHOT.exists():
        raise SystemExit(f"No snapshot at {SNAPSHOT}; enable debug logging first.")
    data = json.loads(SNAPSHOT.read_text())
    tiles = data["tiles"]
    font = float(data.get("fontSize", 11))
    row = math.ceil(font * 1.2) + 2

    heights = {t["h"] for t in tiles}
    verdict_h = "UNIFORM" if len(heights) == 1 else f"MIXED {sorted(heights)}"
    spacing = float(data.get("spacing", 0))
    bad_gaps = []
    for a, b in zip(tiles, tiles[1:]):
        gap = b["c"] - a["c"] - (a["w"] + b["w"]) / 2
        if abs(gap - spacing) > 0.6:
            bad_gaps.append((a["id"], b["id"], round(gap, 1)))
    verdict_g = "UNIFORM" if not bad_gaps else f"{len(bad_gaps)} VIOLATIONS"

    print(f"tiles={len(tiles)} heights={verdict_h} gaps={verdict_g} scale={SCALE}x")
    for a, b, gap in bad_gaps:
        print(f"  gap {a} -> {b}: {gap}")

    min_c = min(t["c"] - t["w"] / 2 for t in tiles)
    total_w = (max(t["c"] + t["w"] / 2 for t in tiles) - min_c) * SCALE
    max_h = max(t["h"] for t in tiles) * SCALE
    row_px = row * SCALE
    font_px = font * SCALE

    tile_divs = []
    for i, t in enumerate(tiles):
        x = (t["c"] - t["w"] / 2 - min_c) * SCALE
        w = t["w"] * SCALE
        h = t["h"] * SCALE
        color = KIND_COLORS.get(t["kind"], "#9ca3af")
        name = html.escape(t["label"] or t["id"].split(":")[-1][:14])
        full_id = html.escape(t["id"])
        tile_divs.append(
            f'<div class="tile" data-i="{i}" style="left:{x:.1f}px;width:{w:.1f}px;height:{h:.1f}px" '
            f'title="{full_id}">'
            f'<div class="icon" style="height:{h - row_px:.1f}px;background:{color}55;border:1px solid {color}">'
            f'<span class="kind">{html.escape(t["kind"])}</span></div>'
            f'<div class="tlabel" style="height:{row_px:.1f}px;font-size:{font_px:.0f}px">{name}</div>'
            f"</div>"
        )

    guides = (
        '<label><input type="checkbox" class="g" data-g="g-top" checked> tile top</label>'
        '<label><input type="checkbox" class="g" data-g="g-icon" checked> icon bottom</label>'
        '<label><input type="checkbox" class="g" data-g="g-base" checked> label baseline ≈</label>'
        '<label><input type="checkbox" class="g" data-g="g-bot" checked> tile bottom</label>'
    )
    baseline_y = max_h - row_px + font_px * 0.8

    page = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Docky bar inspector</title>
<style>
body{{background:#111827;color:#e5e7eb;font:12px system-ui;margin:16px}}
#bar{{position:relative;width:{total_w:.0f}px;height:{max_h:.0f}px;background:#1f2937;border-radius:12px;margin:24px 0;overflow:visible}}
.tile{{position:absolute;bottom:0;border:1px solid #4b5563;border-radius:6px;box-sizing:border-box;cursor:pointer}}
.tile .icon{{display:flex;align-items:center;justify-content:center;color:#fff;opacity:.9;border-radius:4px;overflow:hidden}}
.tile .kind{{font-size:9px;opacity:.8}}
.tile .tlabel{{color:#fff;text-align:center;white-space:nowrap;overflow:hidden;line-height:1.1;opacity:.9}}
.gline{{position:absolute;left:-8px;right:-8px;height:0;border-top:1px dashed #facc15;pointer-events:none}}
#panel{{position:fixed;top:12px;right:12px;width:300px;background:#030712;border:1px solid #374151;border-radius:8px;padding:10px;font:11px monospace;white-space:pre-wrap}}
.controls label{{margin-right:12px}}
.sel{{outline:2px solid #fff !important}}
</style></head><body>
<h2>Docky bar — {len(tiles)} tiles @ {SCALE}x (heights {html.escape(verdict_h)}, gaps {html.escape(verdict_g)})</h2>
<div class="controls">{guides}</div>
<div id="bar">
<div class="gline" id="g-top" style="top:0"></div>
<div class="gline" id="g-icon" style="top:{max_h - row_px:.1f}px"></div>
<div class="gline" id="g-base" style="top:{baseline_y:.1f}px"></div>
<div class="gline" id="g-bot" style="top:{max_h - 1:.1f}px"></div>
{"".join(tile_divs)}
</div>
<div id="panel">click a tile for metrics…</div>
<script>
const TILES = {json.dumps(tiles)};
document.querySelectorAll('.g').forEach(cb => cb.onchange = () =>
  document.getElementById(cb.dataset.g).style.display = cb.checked ? '' : 'none');
document.querySelectorAll('.tile').forEach(el => el.onclick = () => {{
  document.querySelectorAll('.tile').forEach(e => e.classList.remove('sel'));
  el.classList.add('sel');
  const t = TILES[+el.dataset.i];
  const n = TILES[+el.dataset.i + 1];
  let gap = '—';
  if (n) gap = ((n.c - t.c - (n.w + t.w) / 2)).toFixed(1) + 'pt';
  document.getElementById('panel').textContent =
    'id: ' + t.id + '\\nkind: ' + t.kind + '\\nw×h: ' + t.w + '×' + t.h +
    '\\ncenter: ' + t.c + '\\nlabel: ' + (t.label || '(none)') + '\\ngap→next: ' + gap;
}});
</script></body></html>"""
    OUTPUT.write_text(page)
    print(f"wrote {OUTPUT}")
    subprocess.run(["open", str(OUTPUT)], check=False)


if __name__ == "__main__":
    main()
