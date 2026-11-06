#!/usr/bin/env python3
"""Pre-render check of the landing species keys (see website/_quarto.yml).

landing.js keeps the data of the six hero species in ROWS. Each home page
(PT, EN, ES) has a hero photo, a biome button, a map pin and a map card per
species. They connect by the ``data-sp`` key, not by their order. This check
stops the build when a key is missing, repeats, or has no ROWS entry, when a
photo file does not have the name of its key, when a category code disagrees
with ROWS, or when a card is not at the position of its pin.

Standard library only, so it runs in the Quarto-only publish CI. An optional
argument replaces the website directory (the tests use a copy).
"""

from __future__ import annotations

import re
import sys
from html.parser import HTMLParser
from pathlib import Path

PAGES = ("index.qmd", "en/index.qmd", "es/index.qmd")
KINDS = ("lp-photo", "lp-biome", "lp-pin", "lp-card")


def read_rows(js: str) -> dict[str, str]:
    """Return {id: category code} from the ROWS array of landing.js."""
    block = js[js.index("var ROWS = ["):]
    block = block[: block.index("\n  ];")]
    entries = re.findall(r'\{ id: "([^"]+)".*?cat: "([A-Z]+)" \}', block, flags=re.S)
    if not entries or len(entries) != block.count("{ id:"):
        raise ValueError("landing.js: every ROWS entry needs an id and a cat")
    return dict(entries)


class Landing(HTMLParser):
    """Collect the biome, pin and card attributes of one page."""

    def __init__(self) -> None:
        super().__init__()
        self.found = {kind: [] for kind in KINDS}
        self.card = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = (attrs.get("class") or "").split()
        for kind in KINDS:
            if kind in classes:
                item = {
                    "sp": attrs.get("data-sp"),
                    "code": attrs.get("data-code"),
                    "pos": attrs.get("style"),
                    "file": attrs.get("src") or attrs.get("data-src"),
                }
                self.found[kind].append(item)
                self.card = item if kind == "lp-card" else self.card
        if "lp-card-cat" in classes and self.card is not None:
            self.card["code"] = attrs.get("data-code")


def check_page(name: str, text: str, rows: dict[str, str]) -> list[str]:
    parser = Landing()
    parser.feed(text)
    errors = []
    by_kind = {}
    for kind, items in parser.found.items():
        keys = [item["sp"] for item in items]
        if None in keys:
            errors.append(f"{name}: a .{kind} has no data-sp")
        repeated = sorted({k for k in keys if k and keys.count(k) > 1})
        if repeated:
            errors.append(f"{name}: .{kind} repeats data-sp {', '.join(repeated)}")
        if set(keys) != set(rows):
            missing = sorted(set(rows) - set(keys))
            unknown = sorted(k for k in set(keys) - set(rows) if k)
            if missing:
                errors.append(f"{name}: no .{kind} for {', '.join(missing)}")
            if unknown:
                errors.append(f"{name}: .{kind} {', '.join(unknown)} has no ROWS entry in landing.js")
        by_kind[kind] = {item["sp"]: item for item in items if item["sp"]}
    for kind in ("lp-biome", "lp-card"):
        for sp, item in by_kind[kind].items():
            if sp in rows and item["code"] != rows[sp]:
                errors.append(f"{name}: .{kind} {sp} has category {item['code']}, ROWS has {rows[sp]}")
    for sp, photo in by_kind["lp-photo"].items():
        if Path(photo["file"] or "").stem != sp:
            errors.append(f"{name}: the .lp-photo {sp} shows {photo['file']}")
    for sp, card in by_kind["lp-card"].items():
        pin = by_kind["lp-pin"].get(sp)
        if pin and pin["pos"] != card["pos"]:
            errors.append(f"{name}: the .lp-card {sp} is not at the position of its .lp-pin")
    return errors


def main(website: Path) -> int:
    rows = read_rows((website / "assets/js/landing.js").read_text(encoding="utf-8"))
    errors = []
    for page in PAGES:
        errors += check_page(page, (website / page).read_text(encoding="utf-8"), rows)
    for error in errors:
        print(f"check_landing: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    default = Path(__file__).resolve().parent.parent
    sys.exit(main(Path(sys.argv[1]) if len(sys.argv) > 1 else default))
