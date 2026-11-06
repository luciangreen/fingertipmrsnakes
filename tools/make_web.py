#!/usr/bin/env python3
"""Build web/index.html from web/index.template.html, embedding the level
maps from levels.pl so the page can also be played offline.
Run from the repository folder:  python3 tools/make_web.py"""
import json, re, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "levels.pl").read_text()
levels = []
for m in re.finditer(r'level\((\d+), "((?:[^"\\]|\\.)*)", (\w+), (\d+),\s*\[(.*?)\]\)\.', src, re.S):
    rows = re.findall(r'"([^"]*)"', m.group(5))
    levels.append({"n": int(m.group(1)), "name": m.group(2), "dir": m.group(3),
                   "speed": int(m.group(4)), "rows": rows})
levels.sort(key=lambda l: l["n"])
tpl = (root / "web" / "index.template.html").read_text()
out = tpl.replace("/*LEVELS*/", json.dumps(levels, indent=1))
(root / "web" / "index.html").write_text(out)
print(f"web/index.html built with {len(levels)} levels")
