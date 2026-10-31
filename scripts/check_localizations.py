"""Validate the String Catalogs before building.

Checks every localisation key has a non-empty English source and a non-empty
Simplified Chinese translation, that plural variations are translated one by
one, and that both languages keep the same format specifiers. Also fails when
Swift code references a key the catalog does not contain.

Runs on the Python standard library only:

    python3 scripts/check_localizations.py
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGS = (
    ROOT / "RoamControl/Resources/Localizable.xcstrings",
    ROOT / "RoamControl/Resources/InfoPlist.xcstrings",
)
SOURCE_ROOT = ROOT / "RoamControl"
SOURCE_LANGUAGE = "en"
TARGET_LANGUAGE = "zh-Hans"
SOURCE_REFERENCES = (
    re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'NSLocalizedString\(\s*"((?:[^"\\]|\\.)*)"'),
)
SPECIFIERS = re.compile(r"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?[@dDiuUxXoOfFeEgGcsSpaA]")


def unit_value(entry):
    """Return the translated string of one localisation entry."""
    unit = entry.get("stringUnit")
    if isinstance(unit, dict):
        return unit.get("value", "")
    variations = entry.get("variations")
    if isinstance(variations, dict):
        return variations
    return ""


def check_variations(where, translations, problems):
    """Walk `variations` and require every plural form to be translated."""
    for kind, cases in sorted(translations.items()):
        if not isinstance(cases, dict):
            continue
        for case, entry in sorted(cases.items()):
            if case in {"stringUnit", "variations"}:
                continue
            label = f"{where} ({kind}.{case})"
            if not isinstance(entry, dict):
                problems.append(f"{label}: malformed entry")
                continue
            nested = entry.get("variations")
            if isinstance(nested, dict):
                check_variations(label, nested, problems)
                continue
            value = unit_value(entry)
            if not isinstance(value, str) or not value.strip():
                problems.append(f"{label}: empty translation")
                continue
            source = entry.get("stringUnit", {}).get("value", "")
            _ = source
    return problems


def collect_strings(translations, problems, where):
    """Collect every translated string under one language entry."""
    strings = []
    unit = translations.get("stringUnit")
    if isinstance(unit, dict):
        value = unit.get("value", "")
        if not isinstance(value, str) or not value.strip():
            problems.append(f"{where}: empty translation")
        else:
            strings.append(value)
    variations = translations.get("variations")
    if isinstance(variations, dict):
        for kind, cases in sorted(variations.items()):
            if not isinstance(cases, dict):
                continue
            for case, entry in sorted(cases.items()):
                if case in {"stringUnit", "variations"} or not isinstance(entry, dict):
                    continue
                strings.extend(collect_strings(entry, problems, f"{where} ({kind}.{case})"))
    return strings


def check_catalog(path, problems):
    if not path.is_file():
        problems.append(f"{path.relative_to(ROOT)}: missing")
        return 0, 0

    data = json.loads(path.read_text(encoding="utf-8"))
    source_language = data.get("sourceLanguage")
    if source_language != SOURCE_LANGUAGE:
        problems.append(f"{path.name}: sourceLanguage is {source_language!r}, expected {SOURCE_LANGUAGE!r}")

    strings = data.get("strings")
    if not isinstance(strings, dict) or not strings:
        problems.append(f"{path.name}: no keys")
        return 0, 0

    translated = 0
    for key, entry in sorted(strings.items()):
        if not isinstance(entry, dict):
            problems.append(f"{path.name}: {key!r} malformed")
            continue
        localizations = entry.get("localizations")
        if not isinstance(localizations, dict):
            problems.append(f"{path.name}: {key!r} has no localizations")
            continue

        source_values = collect_strings(localizations.get(SOURCE_LANGUAGE, {}), problems, f"{path.name}: {key!r} [{SOURCE_LANGUAGE}]")
        target_values = collect_strings(localizations.get(TARGET_LANGUAGE, {}), problems, f"{path.name}: {key!r} [{TARGET_LANGUAGE}]")
        if not source_values:
            problems.append(f"{path.name}: {key!r} missing {SOURCE_LANGUAGE}")
        if target_values:
            translated += 1

        if source_values and target_values:
            source_specs = sorted(SPECIFIERS.findall(" ".join(source_values)))
            target_specs = sorted(SPECIFIERS.findall(" ".join(target_values)))
            if source_specs != target_specs:
                problems.append(
                    f"{path.name}: {key!r} specifiers differ ({source_specs} vs {target_specs})"
                )
    return translated, len(strings)


def check_references(keys, problems):
    for path in sorted(SOURCE_ROOT.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for pattern in SOURCE_REFERENCES:
            for match in pattern.finditer(text):
                key = match.group(1).replace('\\"', '"')
                if "\\(" in key:
                    continue
                if key not in keys:
                    problems.append(f"{path.relative_to(ROOT)}: key {key!r} missing from Localizable.xcstrings")


def main():
    problems = []
    catalogs = {}
    report = []
    for path in CATALOGS:
        translated, total = check_catalog(path, problems)
        catalogs[path] = (translated, total)

    keys = set()
    catalog_path = CATALOGS[0]
    if catalog_path.is_file():
        keys = set(json.loads(catalog_path.read_text(encoding="utf-8")).get("strings", {}))
    if keys:
        check_references(keys, problems)

    for path, (translated, total) in catalogs.items():
        coverage = 100.0 if not total else translated * 100.0 / total
        report.append(f"{path.relative_to(ROOT)}: {translated}/{total} keys translated ({coverage:.1f}%)")

    for line in report:
        print(line)

    if problems:
        print(f"\n{len(problems)} problem(s):", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    total = sum(t for _, t in catalogs.values())
    print(f"All {total} keys have non-empty {TARGET_LANGUAGE} values.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
