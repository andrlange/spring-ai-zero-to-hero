#!/usr/bin/env bash
# prepare.sh — configure the embedded workshop slide deck (slides.html).
#
# Asks for the per-event details (location, date, presenter names, version
# numbers, whether to skip the Petclinic live-coding slide), then patches the
# slide deck used by the dashboard at /dashboard.
#
# A pristine copy is kept at slides.html.original so changes can be reverted
# at any time. Patching is always done from the .original baseline, so the
# script is safe to re-run as many times as you like.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
SLIDES_FILE="$SCRIPT_DIR/components/config-dashboard/src/main/resources/static/slides.html"
ORIGINAL_FILE="$SLIDES_FILE.original"

if [[ ! -f "$SLIDES_FILE" ]]; then
  echo "ERROR: slides.html not found at:" >&2
  echo "       $SLIDES_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required but not on PATH." >&2
  exit 1
fi

# Ensure the pristine baseline exists. The first run snapshots the current
# slides.html; subsequent runs always patch from this snapshot.
if [[ ! -f "$ORIGINAL_FILE" ]]; then
  cp "$SLIDES_FILE" "$ORIGINAL_FILE"
  echo "Created baseline copy: ${ORIGINAL_FILE#$SCRIPT_DIR/}"
fi

ask() {
  # ask "Prompt" "default" -> echoes the answer (or default if empty input)
  local prompt="$1" default="${2:-}" answer
  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  IFS= read -r answer || answer=""
  if [[ -z "$answer" && -n "$default" ]]; then
    answer="$default"
  fi
  printf '%s' "$answer"
}

# 1. Revert?
REVERT="$(ask "Revert slides.html to original (skip the rest)?" "N")"
if [[ "$REVERT" == [Yy]* ]]; then
  cp "$ORIGINAL_FILE" "$SLIDES_FILE"
  echo "Reverted slides.html to original."
  exit 0
fi

# 2. Slide 1
LOCATION="$(ask "Slide 1 — Location" "Barcelona")"
SLIDE_DATE="$(ask "Slide 1 — Date" "April 13–15, 2026")"
NAMES_RAW="$(ask "Slide 1 — Presenter names (comma separated)" \
                  "Neven Cvetkovic, David Caron, Andreas Lange, Oded Shopen")"

# 3. Slide 30
SKIP_PETCLINIC="$(ask "Skip Slide 30 — Live Coding Demo (Spring AI Petclinic)?" "N")"

# 4. Optional version overrides
SB_VERSION="$(ask "Spring Boot version" "4.0.6")"
SAI_VERSION="$(ask "Spring AI version"   "2.0.0-RC1")"
JAVA_VERSION="$(ask "Java version"        "25")"

# Reset to baseline so the script is idempotent across runs.
cp "$ORIGINAL_FILE" "$SLIDES_FILE"

python3 - "$SLIDES_FILE" \
          "$LOCATION" "$SLIDE_DATE" "$NAMES_RAW" \
          "$SKIP_PETCLINIC" \
          "$SB_VERSION" "$SAI_VERSION" "$JAVA_VERSION" <<'PYEOF'
import re
import sys

(path, location, slide_date, names_raw,
 skip, sb, sai, jv) = sys.argv[1:9]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

def replace_once(text, old, new, label):
    if old not in text:
        sys.stderr.write(f"warning: pattern not found, skipped: {label}\n")
        return text
    return text.replace(old, new, 1)

# Slide 1 — "<location> · <date>"
content = replace_once(
    content,
    "Barcelona · April 13–15, 2026",
    f"{location} · {slide_date}",
    "slide 1 location/date",
)

# Slide 1 — presenter names ("A, B, C" -> "A · B · C")
names = " · ".join(n.strip() for n in names_raw.split(",") if n.strip())
content = replace_once(
    content,
    "Neven Cvetkovic · David Caron · Andreas Lange · Oded Shopen",
    names,
    "slide 1 presenters",
)

# Version numbers (each currently appears exactly once in slides.html)
content = replace_once(content, "Spring Boot 4.0.6", f"Spring Boot {sb}",   "Spring Boot version")
content = replace_once(content, "Spring AI 2.0.0-RC1", f"Spring AI {sai}",   "Spring AI version")
content = replace_once(content, "Java 25",            f"Java {jv}",         "Java version")

# Optionally drop Slide 30 (Petclinic live-coding demo) — delete from the
# "SLIDE 30" comment marker up to (but not including) the "SLIDE 31" marker.
skip_slide_30 = skip.strip().lower().startswith("y")
if skip_slide_30:
    content, n = re.subn(
        r'<!-- ============== SLIDE 30: Live Coding ============== -->.*?'
        r'(?=<!-- ============== SLIDE 31:)',
        "",
        content,
        flags=re.DOTALL,
    )
    if n == 0:
        sys.stderr.write("warning: slide 30 marker not found, nothing skipped\n")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print()
print("slides.html patched:")
print(f"  Slide 1 location/date : {location} · {slide_date}")
print(f"  Slide 1 presenters    : {names}")
print(f"  Slide 30 (Petclinic)  : {'skipped' if skip_slide_30 else 'kept'}")
print(f"  Spring Boot version   : {sb}")
print(f"  Spring AI version     : {sai}")
print(f"  Java version          : {jv}")
PYEOF
