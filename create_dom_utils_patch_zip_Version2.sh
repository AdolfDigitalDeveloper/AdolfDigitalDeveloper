#!/usr/bin/env bash
set -euo pipefail

# create_dom_utils_patch_zip.sh
# Creates dom-utils-consolidation-patch.zip containing:
#  - package.json
#  - rollup.config.js
#  - src/ (new consolidated contents)
#  - legacy/ (legacy files moved or stubbed by the previous patch script)
#  - README-DOM-UTILS-PATCH.md
#  - CHANGELOG.txt
#
# Usage:
#   chmod +x create_dom_utils_patch_zip.sh
#   ./create_dom_utils_patch_zip.sh
#
# Result: dom-utils-consolidation-patch.zip in current directory.

OUT_ZIP="dom-utils-consolidation-patch.zip"
TMPDIR="$(mktemp -d)"
CWD="$(pwd)"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "Creating temporary staging dir: $TMPDIR"

# Files and folders to include (only if present)
INCLUDE=(
  "package.json"
  "rollup.config.js"
  "src"
  "legacy"
  "apply_dom_utils_patch.sh"
  "apply_dom_utils_patch.sh.sig"
)

# Copy files/dirs that exist into tmp dir while preserving structure
for path in "${INCLUDE[@]}"; do
  if [ -e "$CWD/$path" ]; then
    echo "Including: $path"
    if [ -d "$CWD/$path" ]; then
      mkdir -p "$TMPDIR/$(dirname "$path")"
      cp -a "$CWD/$path" "$TMPDIR/"
    else
      mkdir -p "$TMPDIR/$(dirname "$path")"
      cp -p "$CWD/$path" "$TMPDIR/$path"
    fi
  else
    echo "Not found (skipping): $path"
  fi
done

# Add README inside the zip describing contents
cat > "$TMPDIR/README-DOM-UTILS-PATCH.md" <<'EOF'
DOM Utils Consolidation Patch
-----------------------------

This archive was prepared by the consolidation patch scripts.

Contains:
 - package.json (updated with exports and bottom-sheet subpath)
 - rollup.config.js (updated to output index.* and bottom-sheet.*)
 - src/ (consolidated new entrypoint & helpers)
 - legacy/ (legacy/old files moved here)
 - apply_dom_utils_patch.sh (if present)
 - README-DOM-UTILS-PATCH.md (this file)
 - CHANGELOG.txt (summary of changes)

How to use:
 1) Unzip dom-utils-consolidation-patch.zip
 2) Inspect files and run 'npm install' and 'npm run build' in the repo root
 3) If all good, commit changes on a feature branch and open a PR.

EOF

# Add CHANGELOG
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$TMPDIR/CHANGELOG.txt" <<EOF
DOM Utils Consolidation Patch - Changelog
Generated: $NOW (UTC)

Summary:
- Consolidated src/index.js to use the new modular entrypoint.
- Replaced src/core/dom-extensions.js with the extended implementation (chainable DOM helpers, event helpers, animations).
- Added src/ajax/index.js as compatibility adapter delegating to src/modules/ajax.js.
- Updated rollup.config.js to emit:
  - dist/index.esm.js, dist/index.cjs.js, dist/index.umd.js
  - dist/bottom-sheet.esm.js, dist/bottom-sheet.cjs.js
- Updated package.json:
  - Added "exports" mapping for "." and "./bottom-sheet"
  - Set "sideEffects": false to improve tree-shaking
- Made bottom-sheet custom element registration conditional (only register if window exists and element not already defined).
- Moved legacy/duplicated/old files into legacy/ (keeps history and prevents conflicts).
- Included README-DOM-UTILS-PATCH.md and this CHANGELOG.txt in the zip.

Files moved to legacy/ (examples; check legacy/ folder in archive for full list):
 - legacy/src.index.old.js
 - legacy/src/core/dom-extensions.old.js
 - legacy/src/ajax/fetch.old.js
 - legacy/rollup.config.old.js
 - legacy/src/core/bottom-sheet-base.old.js
 - legacy/src/core/bottom-sheet.old.js

Notes:
- After extracting, run:
    npm install
    npm run build
  and review the build output.
- Verify examples import paths (examples/index.html expects /dist/bottom-sheet.esm.js).
- Run tests and linting, then create a branch & PR.

EOF

# Create zip
echo "Creating ZIP: $OUT_ZIP"
# Use zip if available, else fallback to python zipfile
if command -v zip >/dev/null 2>&1; then
  (cd "$TMPDIR" && zip -r "../$OUT_ZIP" .)
  mv "$TMPDIR/../$OUT_ZIP" "$CWD/$OUT_ZIP"
else
  echo "zip not found: trying python3"
  python3 - <<PY
import os, zipfile
root = "${TMPDIR}"
out = os.path.join("${CWD}", "${OUT_ZIP}")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for base, dirs, files in os.walk(root):
        for f in files:
            path = os.path.join(base, f)
            arcname = os.path.relpath(path, root)
            z.write(path, arcname)
print("Wrote", out)
PY
fi

echo "Created $OUT_ZIP in $CWD"
echo "Contents (first 50 lines):"
unzip -l "$OUT_ZIP" | sed -n '1,50p'
echo "Done."