#!/usr/bin/env python3
"""Lists user-facing strings in App/ that have no Ukrainian translation (T-016).

Looks at string literals passed to SwiftUI text APIs and String(localized:). Interpolations
and format specifiers are compared as placeholders, so "\\(n) min" matches "%lld min".
Usage: python3 scripts/check-localization.py   (exit code 1 when something is missing)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CALLS = r"(?:Text|Button|Label|Section|LabeledContent|Toggle|Picker|Stepper|TextField|NumberField|navigationTitle|" \
        r"confirmationDialog|alert|ContentUnavailableView|LocalizedStringKey|NavigationLink|Tab|Menu|String\(localized:)"
LITERAL = re.compile(CALLS + r"\(?\s*\"((?:[^\"\\]|\\.)*)\"")
# Both sides of `cond ? "A" : "B"` inside one of the calls above.
TERNARY = re.compile(CALLS + r"\([^\"]*\?\s*\"((?:[^\"\\]|\\.)*)\"\s*:\s*\"((?:[^\"\\]|\\.)*)\"")
KEY = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=', re.M)
PLACEHOLDER = "\0"


def interpolations_to_placeholders(text):
    out, i = [], 0
    while i < len(text):
        if text.startswith("\\(", i):
            depth, j = 1, i + 2
            while j < len(text) and depth:
                depth += {"(": 1, ")": -1}.get(text[j], 0)
                j += 1
            if depth:
                return None
            out.append(PLACEHOLDER)
            i = j
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def normalize_key(text):
    text = re.sub(r"%(?:\d+\$)?[-+0#]*\d*(?:\.\d+)?(?:lld|ld|d|@|f|lf)", PLACEHOLDER, text)
    return text.replace('\\"', '"')


def main():
    keys = {normalize_key(k) for k in KEY.findall((ROOT / "App/Resources/uk.lproj/Localizable.strings").read_text())}
    missing = {}
    for path in sorted((ROOT / "App").rglob("*.swift")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if "verbatim:" in line:
                line = re.sub(r"verbatim:\s*\"(?:[^\"\\]|\\.)*\"", "", line)
            found = LITERAL.findall(line) + [side for pair in TERNARY.findall(line) for side in pair]
            for literal in found:
                if not re.search(r"[A-Za-z]", literal) or literal.startswith(("http", "chevron", "checkmark")):
                    continue
                # A literal cut short by quotes inside an interpolation ("\\(x, specifier: "%.1f")") is skipped.
                key = interpolations_to_placeholders(literal)
                if key is None:
                    continue
                key = key.replace('\\"', '"')
                if key not in keys:
                    missing.setdefault(key, f"{path.relative_to(ROOT)}:{number}")
    for key, where in sorted(missing.items(), key=lambda kv: kv[1]):
        print(f"{where}\t{key.replace(PLACEHOLDER, '%')}")
    print(f"{len(missing)} missing", file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
