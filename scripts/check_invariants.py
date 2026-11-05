"""Check the invariants that used to be six hand-typed `rg` commands.

Every invariant is a counting rule over the repository, so a violation prints
the file and line instead of just "something changed". Standard library only:

    python3 scripts/check_invariants.py
    python3 scripts/check_invariants.py --self-test

Any failing check exits 1. `--self-test` plants one violation per check in an
in-memory copy of the repository and fails if a check misses its canary, so a
silently broken check cannot keep printing PASS.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = "RoamControl"
TEST_TARGET = "RoamControlTests"
ADAPTER = "RoamControl/Services/Location/DeviceCoordinateAdapter.swift"
SCHEMA_SOURCE = "RoamControl/Features/Routes/Storage/RouteStore.swift"
STATUS_DOC = "Documentation/ImplementationStatus.md"
PBXPROJ = "RoamControl.xcodeproj/project.pbxproj"

# Directories whose text is loaded for the scans. Images and binaries drop out
# because they do not decode as UTF-8.
TEXT_ROOTS = (
    APP,
    TEST_TARGET,
    "RoamControl.xcodeproj",
    "Documentation",
    "Configuration",
    ".github",
)
TEXT_FILES = ("README.md", "CHANGELOG.md")

# The single place that may install the GCJ-02 -> WGS-84 conversion. The
# transform itself and the diagnostics screen may call
# `ChinaCoordinateTransform.gcj02ToWGS84`, but nobody else may pick the
# conversion for injection.
INJECTION = re.compile(r"DeviceCoordinateAdapter\(conversion:\s*\.gcj02ToWGS84\)")
STRAY_OFFSETS = re.compile(r"offsetDegrees|coordinateOffset")

ARCH_DIRS = ("RoamControl/Features/Routes/Core", "RoamControl/Features/Routes/Models")
ARCH_FORBIDDEN = (
    re.compile(r"import SwiftUI"),
    re.compile(r"import MapKit"),
    re.compile(r"\bAppModel\b"),
    re.compile(r"MKRoute|MKMapPoint|MKPolyline"),
)

LOCALIZATION = ROOT / "scripts/check_localizations.py"
LOCALIZATION_LINE = re.compile(r"All \d+ keys have non-empty zh-Hans values\.")

UPSTREAM = re.compile(r"seanhowarthdev")
# The implementation ledger and the handoff archive quote the old gate commands
# and the old URLs on purpose, so they keep the string. Everything else must be
# clean: README, CHANGELOG, Configuration/, .github/ and the live Documentation
# pages.
UPSTREAM_SKIP = ("Documentation/ImplementationStatus.md", "Documentation/Handoffs/")

ANALYTICS = re.compile(r"UsageAnalytics|ProductInteraction|DeviceID|PurposeAnalytics")

BUILD_TIMESTAMP = re.compile(r"ROAMCONTROL_BUILD_TIMESTAMP")

MARKETING = re.compile(r"MARKETING_VERSION = ([0-9]+(?:\.[0-9]+)*);")
BUILD_NUMBER = re.compile(r"CURRENT_PROJECT_VERSION = ([0-9]+);")
CHANGELOG_SECTION = re.compile(r"^## \[?([0-9]+\.[0-9]+\.[0-9]+)\]?[^\n]*$", re.MULTILINE)
UNRELEASED = ("待发布", "unreleased", "Unreleased")
README_RELEASE = re.compile(r"Current release:?\s*(?:</strong>)?\s*([0-9]+(?:\.[0-9]+)*)\s*\(([0-9]+)\)")

SCHEMA_ASSIGNMENT = re.compile(r"currentSchemaVersion\s*=\s*([0-9]+)")


class Corpus:
    """In-memory copy of the repository text, so canaries can be planted."""

    def __init__(self, files):
        self.files = files

    def text(self, path):
        return self.files.get(path, "")

    def under(self, prefix, suffix=None):
        if prefix and not prefix.endswith("/"):
            prefix += "/"
        return sorted(p for p in self.files if p.startswith(prefix) and (suffix is None or p.endswith(suffix)))

    def swift(self, prefix):
        return self.under(prefix, ".swift")


def load_corpus():
    files = {}
    for root in TEXT_ROOTS:
        base = ROOT / root
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            try:
                files[path.relative_to(ROOT).as_posix()] = path.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
    for name in TEXT_FILES:
        path = ROOT / name
        if path.is_file():
            files[name] = path.read_text(encoding="utf-8")
    return Corpus(files)


def line_hits(corpus, paths, pattern):
    """Return `(path, lineno)` for every line matching `pattern`."""
    hits = []
    for path in paths:
        for number, line in enumerate(corpus.text(path).splitlines(), start=1):
            if pattern.search(line):
                hits.append((path, number))
    return hits


def check_coordinates(corpus):
    """Exactly one injection site, in the adapter, and no stray offset knobs."""
    injections = line_hits(corpus, corpus.swift(APP), INJECTION)
    outside_adapter = [hit for hit in injections if hit[0] != ADAPTER]
    offsets = [hit for hit in line_hits(corpus, corpus.swift(APP), STRAY_OFFSETS) if hit[0] != ADAPTER]
    problems = []
    if len(injections) != 1:
        problems.append(f"expected exactly 1 injection site, found {len(injections)}: {fmt(injections)}")
    if outside_adapter:
        problems.append(f"injection outside {ADAPTER}: {fmt(outside_adapter)}")
    if offsets:
        problems.append(f"stray offset names outside {ADAPTER}: {fmt(offsets)}")
    where = f"{injections[0][0]}:{injections[0][1]}" if len(injections) == 1 else "none"
    return not problems, f"1 injection site at {where}; {len(offsets)} stray offsets", problems


def check_architecture(corpus):
    """Route core and models stay free of UI, MapKit and app-level types."""
    paths = [p for directory in ARCH_DIRS for p in corpus.swift(directory)]
    hits = []
    for pattern in ARCH_FORBIDDEN:
        hits.extend(line_hits(corpus, paths, pattern))
    problems = [f"forbidden symbol at {path}:{number}" for path, number in hits]
    return not problems, f"0 violations across {len(paths)} file(s) in Core/ and Models/", problems


def run_localization_script():
    proc = subprocess.run(
        [sys.executable, str(LOCALIZATION)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def check_localizations(corpus, run=run_localization_script):
    """The catalog gate keeps passing and keeps reporting its key count."""
    code, output = run()
    problems = []
    if code != 0:
        problems.append(f"{LOCALIZATION.name} exited {code}")
    match = LOCALIZATION_LINE.search(output)
    if not match:
        problems.append(f"{LOCALIZATION.name} did not report '{LOCALIZATION_LINE.pattern.strip()}'")
        return False, "localization gate did not report a key count", problems
    keys = re.search(r"All (\d+) keys", match.group(0)).group(1)
    return not problems, f"All {keys} keys have non-empty zh-Hans values.", problems


def version_tuple(text):
    return tuple(int(part) for part in text.split("."))


def check_versions(corpus):
    """pbxproj, CHANGELOG and README agree on the version that ships."""
    pbxproj = corpus.text(PBXPROJ)
    marketing = MARKETING.findall(pbxproj)
    builds = BUILD_NUMBER.findall(pbxproj)
    sections = [
        (match.group(1), "待发布" in match.group(0) or any(word in match.group(0) for word in UNRELEASED),
         match.group(0).strip())
        for match in CHANGELOG_SECTION.finditer(corpus.text("CHANGELOG.md"))
    ]
    readme = README_RELEASE.search(corpus.text("README.md"))

    problems = []
    if len(marketing) != 2 or len(set(marketing)) != 1:
        problems.append(f"{PBXPROJ}: MARKETING_VERSION lines are {marketing}, expected 2 identical")
    if len(builds) != 2 or len(set(builds)) != 1:
        problems.append(f"{PBXPROJ}: CURRENT_PROJECT_VERSION lines are {builds}, expected 2 identical")
    if not sections:
        problems.append("CHANGELOG.md: no version section found")
    if not readme:
        problems.append("README.md: no 'Current release:' line found")
    if problems:
        return False, "version sources are unreadable", problems

    current, current_build = marketing[0], builds[0]
    top = sections[0]
    if top[0] != current:
        problems.append(f"CHANGELOG.md top section is {top[0]}, pbxproj says {current}")

    readme_version, readme_build = readme.group(1), readme.group(2)
    known = [section[0] for section in sections]
    if readme_version not in known:
        problems.append(f"README.md names {readme_version}, which has no CHANGELOG section")
    # A version section may be staged for release before the app ships it, so the
    # newest *released* section -- not the newest section -- is what the README
    # has to show.
    released = [section[0] for section in sections if not section[1]]
    newest_released = max(released, key=version_tuple) if released else None
    if newest_released and readme_version != newest_released:
        problems.append(
            f"README.md 'Current release' is {readme_version}, newest released CHANGELOG section is {newest_released}"
        )
    if readme_version == current and readme_build != current_build:
        problems.append(f"README.md build is {readme_build}, pbxproj says {current_build}")
    if version_tuple(readme_version) > version_tuple(current):
        problems.append(f"README.md claims {readme_version}, ahead of pbxproj {current}")

    summary = f"pbxproj {current} ({current_build}), CHANGELOG {top[0]}, README {readme_version} ({readme_build})"
    if top[1]:
        summary += f"; {top[0]} staged for release, README keeps the shipped build"
    return not problems, summary, problems


def check_leftovers(corpus):
    """No upstream identity in the docs or config, no telemetry keys in code."""
    docs = [p for p in corpus.under("") if not p.startswith(UPSTREAM_SKIP)]
    upstream_hits = line_hits(corpus, docs, UPSTREAM)
    analytics_hits = line_hits(corpus, corpus.swift(APP) + corpus.swift(TEST_TARGET), ANALYTICS)
    problems = [f"upstream name at {path}:{number}" for path, number in upstream_hits]
    problems += [f"telemetry key at {path}:{number}" for path, number in analytics_hits]
    summary = (
        f"0 upstream hits in {len(docs)} doc/config file(s) "
        f"(skipped {', '.join(UPSTREAM_SKIP)}); 0 telemetry keys in app and tests"
    )
    return not problems, summary, problems


def check_build_timestamp(corpus):
    """The build time comes from CI, never from a checked-in setting."""
    hits = line_hits(corpus, [PBXPROJ], BUILD_TIMESTAMP)
    problems = [f"hard-coded build timestamp at {PBXPROJ}:{number}" for _, number in hits]
    return not problems, "0 ROAMCONTROL_BUILD_TIMESTAMP entries in project.pbxproj", problems


def check_schema(corpus):
    """The route file schema version matches the status document."""
    code = sorted(set(SCHEMA_ASSIGNMENT.findall(corpus.text(SCHEMA_SOURCE))))
    documented = sorted(set(SCHEMA_ASSIGNMENT.findall(corpus.text(STATUS_DOC))))
    problems = []
    if len(code) != 1:
        problems.append(f"{SCHEMA_SOURCE}: expected 1 currentSchemaVersion value, found {code}")
    if len(documented) != 1:
        problems.append(f"{STATUS_DOC}: expected 1 currentSchemaVersion value, found {documented}")
    if not problems and code[0] != documented[0]:
        problems.append(f"schema version differs: RouteStore {code[0]}, {STATUS_DOC} {documented[0]}")
    code_value = code[0] if code else "?"
    doc_value = documented[0] if documented else "?"
    return not problems, f"RouteStore {code_value} == {STATUS_DOC} {doc_value}", problems


CHECKS = (
    ("coordinate injection", check_coordinates),
    ("architecture boundary", check_architecture),
    ("localization", check_localizations),
    ("version consistency", check_versions),
    ("upstream and telemetry leftovers", check_leftovers),
    ("build timestamp not hard-coded", check_build_timestamp),
    ("route schema version", check_schema),
)


def fmt(hits):
    return ", ".join(f"{path}:{number}" for path, number in hits)


def run_checks(corpus, checks=CHECKS):
    """Run every check, print one line each, return True when all pass."""
    ok = True
    for index, (name, function) in enumerate(checks, start=1):
        passed, summary, problems = function(corpus)
        print(f"{'PASS' if passed else 'FAIL'} {index} {name}: {summary}")
        for problem in problems:
            print(f"     - {problem}")
        ok = ok and passed
    return ok


# Each canary plants one violation in a copy of the corpus and the matching
# check has to notice it.
CANARIES = (
    (
        "coordinate injection",
        "add a stray offset constant under RoamControl",
        lambda files: files.__setitem__(
            "RoamControl/Services/Location/Stray.swift", "let coordinateOffset = 0.01\n"
        ),
    ),
    (
        "architecture boundary",
        "import MapKit inside Features/Routes/Core",
        lambda files: files.__setitem__(
            "RoamControl/Features/Routes/Core/Canary.swift", "import MapKit\n"
        ),
    ),
    (
        "localization",
        "make the catalog gate fail",
        None,
    ),
    (
        "version consistency",
        "point the README at a version the CHANGELOG does not have",
        lambda files: files.__setitem__(
            "README.md",
            README_RELEASE.sub("Current release:</strong> 9.9.9 (1)", files["README.md"]),
        ),
    ),
    (
        "upstream and telemetry leftovers",
        "put the upstream handle back into the README",
        lambda files: files.__setitem__("README.md", files["README.md"] + "\nsee seanhowarthdev\n"),
    ),
    (
        "build timestamp not hard-coded",
        "bake a build timestamp into project.pbxproj",
        lambda files: files.__setitem__(
            PBXPROJ,
            files[PBXPROJ] + "\n\t\t\t\tROAMCONTROL_BUILD_TIMESTAMP = 2026-01-01T00:00:00Z;\n",
        ),
    ),
    (
        "route schema version",
        "bump RouteStore without updating the status document",
        lambda files: files.__setitem__(
            SCHEMA_SOURCE,
            SCHEMA_ASSIGNMENT.sub("currentSchemaVersion = 99", files[SCHEMA_SOURCE]),
        ),
    ),
)


def self_test():
    """Every check has to fail on its own canary; a blind check fails the run."""
    base = load_corpus()
    functions = dict(CHECKS)
    missed = []
    for index, (name, description, plant) in enumerate(CANARIES, start=1):
        if plant is None:
            passed, _, _ = check_localizations(base, run=lambda: (1, "1 problem(s):\n"))
        else:
            files = dict(base.files)
            plant(files)
            passed, _, _ = functions[name](Corpus(files))
        print(f"{'CAUGHT' if not passed else 'MISSED'} canary {index} {name}: {description}")
        if passed:
            missed.append(name)
    if missed:
        print(f"\nself-test failed: {len(missed)} canary/canaries not caught: {', '.join(missed)}")
        return False
    print(f"\nself-test passed: {len(CANARIES)}/{len(CANARIES)} canaries caught.")
    return True


def main(argv):
    if "--self-test" in argv:
        return 0 if self_test() else 1
    unknown = [arg for arg in argv if arg != "--self-test"]
    if unknown:
        print(f"unknown argument(s): {' '.join(unknown)}", file=sys.stderr)
        return 2
    ok = run_checks(load_corpus())
    print("\nAll invariants hold." if ok else "\nInvariant check failed.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
