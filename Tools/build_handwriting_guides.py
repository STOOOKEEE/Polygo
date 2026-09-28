#!/usr/bin/env python3
"""Build the handwriting stroke guides from Make Me a Hanzi medians.

The guides shipped in Content/assets/handwriting and the embedded catalog in
Apple/Handwriting/HandwritingGuides.swift are derived from the stroke medians
of Make Me a Hanzi's graphics.txt (Arphic Public License, see
Content/assets/handwriting/ARPHICPL.TXT). The source file is pinned by commit
and SHA-256 so a rebuild is reproducible.

Each median is mapped from the 1024 unit Make Me a Hanzi box (y up, baseline
at 900) into the normalized guide square (y down), scaled uniformly into
0.1...0.9 so every glyph keeps the same margin, then simplified with
Ramer-Douglas-Peucker so corners and hooks survive. Stroke order and
direction come from the source; labels are the stroke type names below.

Usage:
  python3 Tools/build_handwriting_guides.py [--graphics /path/to/graphics.txt]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
import urllib.request
from pathlib import Path

SOURCE_COMMIT = "bddc96d41bef78427ed0e034e9f7e31d71fd1b92"
SOURCE_URL = f"https://raw.githubusercontent.com/skishore/makemeahanzi/{SOURCE_COMMIT}/graphics.txt"
SOURCE_SHA256 = "a28c478b5178e98f67f510b2d52fde08a69dc664654ef43498253b9b764d46ee"
CONVERSION_DATE = "2026-09-28"

MARGIN = 0.1
SIMPLIFY_EPSILON = 0.006

# Stroke type names in source order; the count must match the source medians.
GUIDES = {
    "guide-hanzi-ni": ("你", ["撇", "竖", "撇", "横钩", "竖钩", "点", "点"]),
    "guide-hanzi-wo": ("我", ["撇", "横", "竖钩", "提", "斜钩", "撇", "点"]),
    "guide-hanzi-guo": ("国", ["竖", "横折", "横", "横", "竖", "提", "点", "横"]),
}

NOTICE = (
    "Derived from Make Me a Hanzi graphics.txt (commit {commit}), itself derived "
    "from Arphic PL KaitiM GB and Arphic PL UKai, under the Arphic Public License "
    "(see ARPHICPL.TXT). Modified on {date} by Tools/build_handwriting_guides.py: "
    "stroke medians rescaled into the unit square, simplified and labelled."
)

REPO_ROOT = Path(__file__).resolve().parent.parent
GUIDE_DIR = REPO_ROOT / "Content" / "assets" / "handwriting"
SWIFT_CATALOG = REPO_ROOT / "Apple" / "Handwriting" / "HandwritingGuides.swift"
SWIFT_BEGIN = "    // BEGIN GENERATED GUIDES (Tools/build_handwriting_guides.py)\n"
SWIFT_END = "    // END GENERATED GUIDES\n"


def load_source(path: Path | None) -> bytes:
    if path is None:
        with urllib.request.urlopen(SOURCE_URL, timeout=60) as response:
            data = response.read()
    else:
        data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SOURCE_SHA256:
        raise SystemExit(f"graphics.txt SHA-256 {digest} does not match pinned {SOURCE_SHA256}")
    return data


def medians_by_character(data: bytes, characters: set[str]) -> dict[str, list[list[list[int]]]]:
    found: dict[str, list[list[list[int]]]] = {}
    for line in data.decode("utf-8").splitlines():
        entry = json.loads(line)
        if entry["character"] in characters:
            found[entry["character"]] = entry["medians"]
    missing = characters - found.keys()
    if missing:
        raise SystemExit(f"characters missing from graphics.txt: {''.join(sorted(missing))}")
    return found


def normalize(point: list[int]) -> tuple[float, float]:
    x, y = point
    scale = 1 - 2 * MARGIN
    return MARGIN + scale * x / 1024, MARGIN + scale * (900 - y) / 1024


def simplify(points: list[tuple[float, float]], epsilon: float) -> list[tuple[float, float]]:
    """Ramer-Douglas-Peucker; always keeps both endpoints."""
    if len(points) < 3:
        return points
    (ax, ay), (bx, by) = points[0], points[-1]
    length = math.hypot(bx - ax, by - ay)
    best_index, best_distance = 0, -1.0
    for index in range(1, len(points) - 1):
        px, py = points[index]
        if length == 0:
            distance = math.hypot(px - ax, py - ay)
        else:
            distance = abs((bx - ax) * (ay - py) - (ax - px) * (by - ay)) / length
        if distance > best_distance:
            best_index, best_distance = index, distance
    if best_distance <= epsilon:
        return [points[0], points[-1]]
    head = simplify(points[: best_index + 1], epsilon)
    tail = simplify(points[best_index:], epsilon)
    return head[:-1] + tail


def build_guide(guide_id: str, character: str, labels: list[str], medians: list[list[list[int]]]) -> dict:
    if len(medians) != len(labels):
        raise SystemExit(f"{guide_id}: {len(medians)} source strokes, {len(labels)} labels")
    strokes = []
    for index, (median, label) in enumerate(zip(medians, labels), start=1):
        points = simplify([normalize(point) for point in median], SIMPLIFY_EPSILON)
        strokes.append({
            "id": index,
            "label": label,
            "points": [{"x": round(x, 3), "y": round(y, 3)} for x, y in points],
        })
    return {"character": character, "id": guide_id, "strokes": strokes}


def render_json(guide: dict, notice: str) -> str:
    lines = [
        "{",
        f'  "character": {json.dumps(guide["character"], ensure_ascii=False)},',
        f'  "id": "{guide["id"]}",',
        f'  "notice": {json.dumps(notice, ensure_ascii=False)},',
        '  "strokes": [',
    ]
    for stroke_index, stroke in enumerate(guide["strokes"]):
        lines += [
            "    {",
            f'      "id": {stroke["id"]},',
            f'      "label": {json.dumps(stroke["label"], ensure_ascii=False)},',
            '      "points": [',
        ]
        points = stroke["points"]
        for point_index, point in enumerate(points):
            comma = "," if point_index < len(points) - 1 else ""
            lines.append(f'        {{ "x": {point["x"]}, "y": {point["y"]} }}{comma}')
        lines.append("      ]")
        lines.append("    }," if stroke_index < len(guide["strokes"]) - 1 else "    }")
    lines += ["  ],", '  "viewBox": { "height": 1, "width": 1 }', "}", ""]
    return "\n".join(lines)


def swift_name(guide_id: str) -> str:
    return guide_id.removeprefix("guide-hanzi-")


def render_swift(guides: list[dict]) -> str:
    out = []
    for guide in guides:
        out.append(f"    private static let {swift_name(guide['id'])} = HandwritingGuide(\n")
        out.append(f'        id: AssetID(rawValue: "{guide["id"]}")!,\n')
        out.append(f'        character: "{guide["character"]}",\n')
        out.append("        strokes: [\n")
        for stroke_index, stroke in enumerate(guide["strokes"]):
            out.append(f"            HandwritingGuideStroke(id: {stroke['id']}, points: [\n")
            points = stroke["points"]
            for point_index, point in enumerate(points):
                comma = "," if point_index < len(points) - 1 else ""
                out.append(f"                HandwritingPoint(x: {point['x']}, y: {point['y']}){comma}\n")
            comma = "," if stroke_index < len(guide["strokes"]) - 1 else ""
            out.append(f'            ], label: "{stroke["label"]}"){comma}\n')
        out.append("        ]\n")
        out.append("    )\n")
        if guide is not guides[-1]:
            out.append("\n")
    return "".join(out)


def update_swift_catalog(guides: list[dict]) -> None:
    source = SWIFT_CATALOG.read_text(encoding="utf-8")
    pattern = re.compile(re.escape(SWIFT_BEGIN) + ".*?" + re.escape(SWIFT_END), re.DOTALL)
    if len(pattern.findall(source)) != 1:
        raise SystemExit(f"{SWIFT_CATALOG}: generated guide markers not found exactly once")
    replacement = SWIFT_BEGIN + render_swift(guides) + SWIFT_END
    SWIFT_CATALOG.write_text(pattern.sub(lambda _: replacement, source), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--graphics", type=Path, help="local copy of graphics.txt (default: download pinned commit)")
    args = parser.parse_args()

    data = load_source(args.graphics)
    medians = medians_by_character(data, {character for character, _ in GUIDES.values()})
    notice = NOTICE.format(commit=SOURCE_COMMIT[:7], date=CONVERSION_DATE)
    guides = []
    for guide_id, (character, labels) in GUIDES.items():
        guide = build_guide(guide_id, character, labels, medians[character])
        guides.append(guide)
        path = GUIDE_DIR / f"{guide_id}.json"
        path.write_text(render_json(guide, notice), encoding="utf-8")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        points = sum(len(stroke["points"]) for stroke in guide["strokes"])
        print(f"{guide_id} {character} strokes={len(guide['strokes'])} points={points} sha256={digest}")
    update_swift_catalog(guides)
    return 0


if __name__ == "__main__":
    sys.exit(main())
