#!/usr/bin/env python3
# regenerate EMOJI in charms.js: python3 emoji.py [max Emoji version, 17.0 by default — Noto doesn't draw beyond that]
# Unicode emoji-test.txt (fully-qualified, no skin tones) + CLDR en words. Words already in the table
# (your own, hand-written) are kept
import json, re, sys, urllib.request
from pathlib import Path

maxv = float(sys.argv[1]) if len(sys.argv) > 1 else 17.0
js = Path(__file__).with_name("charms.js")
CLDR = "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/"


def get(url):
    return urllib.request.urlopen(url).read().decode()


def ann(lang):
    out = {}
    for p in (f"cldr-annotations-full/annotations/{lang}/annotations.json",
              f"cldr-annotations-derived-full/annotationsDerived/{lang}/annotations.json"):
        d = json.loads(get(CLDR + p))
        out.update((d.get("annotations") or d["annotationsDerived"])["annotations"])
    return out


EN = ann("en")
look = lambda a, e: a.get(e) or a.get(e.replace(chr(0xFE0F), "")) or {}
norm = lambda s: s.lower().replace('"', "'")

src = js.read_text(encoding="utf-8")
block = re.search(r"const EMOJI = \[\n(.*?)\n\];\n", src, re.S)
old = dict(re.findall(r'\["([^"]+)", "([^"]*)"\]', block.group(1)))

rows = []
for l in get("https://unicode.org/Public/emoji/latest/emoji-test.txt").splitlines():
    m = re.match(r"^([0-9A-F ]+?)\s+; fully-qualified\s+# (\S+) E(\d+\.\d+) (.+)$", l)
    if not m or float(m.group(3)) > maxv or any(0x1F3FB <= int(c, 16) <= 0x1F3FF for c in m.group(1).split()):
        continue
    e, en = m.group(2), look(EN, m.group(2))
    head = [norm(m.group(4))]
    seen, extra = set(" ".join(head).split()), []
    for w in norm(" ".join(en.get("default", []) + [old.get(e, "")])).replace(",", " ").split():
        if w not in seen:
            seen.add(w)
            extra.append(w)
    rows.append(f'    ["{e}", "{" ".join(head + extra)}"],')

js.write_text(src[:block.start(1)] + "\n".join(rows) + src[block.end(1):], encoding="utf-8")
print(len(rows), "emoji", file=sys.stderr)
