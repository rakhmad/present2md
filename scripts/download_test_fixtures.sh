#!/usr/bin/env bash
# scripts/download_test_fixtures.sh
# Downloads large public-domain files for performance testing.
# Run from the repo root: bash scripts/download_test_fixtures.sh
set -euo pipefail

DEST_PRIMARY="Tests/PerformanceFixtures"
DEST_SPM="present2mdPerformanceTests/PerformanceFixtures"
mkdir -p "$DEST_PRIMARY" "$DEST_SPM"

download_and_verify() {
    local url="$1" dest_primary="$2" dest_spm="$3" expected_sha="$4"
    if [[ -f "$dest_primary" ]]; then
        echo "Already exists: $dest_primary"
        # Ensure SPM copy is also present
        cp -n "$dest_primary" "$dest_spm" 2>/dev/null || true
        return
    fi
    echo "Downloading $dest_primary ..."
    curl -fsSL --retry 3 "$url" -o "$dest_primary"
    actual_sha=$(shasum -a 256 "$dest_primary" | awk '{print $1}')
    if [[ "$expected_sha" != "SKIP_VERIFY" && "$actual_sha" != "$expected_sha" ]]; then
        echo "ERROR: SHA256 mismatch for $dest_primary"
        echo "  Expected: $expected_sha"
        echo "  Actual:   $actual_sha"
        rm -f "$dest_primary"
        exit 1
    fi
    cp "$dest_primary" "$dest_spm"
    echo "OK: $dest_primary (sha256: $actual_sha)"
}

# NASA Technical Report Server — public domain PDF (~336 pages, ~9MB)
# Report: NASA 19940013183 (large aeronautics technical report)
download_and_verify \
    "https://ntrs.nasa.gov/api/citations/19940013183/downloads/19940013183.pdf" \
    "$DEST_PRIMARY/nasa_large.pdf" \
    "$DEST_SPM/nasa_large.pdf" \
    "SKIP_VERIFY"

# Large PPTX — UN OCHA publicly released presentation (public domain)
# Fallback: generate a large synthetic PPTX if download fails
if ! curl -fsSL --retry 2 --max-time 30 \
    "https://www.un.org/sites/un2.un.org/files/2021/03/un75-report-commonagenda-en.pdf" \
    -o /dev/null 2>/dev/null; then
    echo "UN download unavailable — generating synthetic large PPTX..."
    python3 - <<'PYEOF'
import zipfile, os

DEST = "Tests/PerformanceFixtures/large_sample.pptx"
DEST_SPM = "present2mdPerformanceTests/PerformanceFixtures/large_sample.pptx"

RELS = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
CONTENT_TYPES_HEADER = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'''

NUM_SLIDES = 60

slide_xml = lambda i: f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:spTree>
    <p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>Slide {i} Title</a:t></a:r></a:p></p:txBody></p:sp>
    <p:sp><p:nvSpPr><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>This is the body text for slide number {i} in the large performance test fixture. It contains enough text to be realistic.</a:t></a:r></a:p></p:txBody></p:sp>
  </p:spTree></p:cSld>
</p:sld>'''

sld_ids = '\n'.join(f'    <p:sldId id="{256+i}" r:id="rId{i}"/>' for i in range(1, NUM_SLIDES+1))
presentation = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldMasterIdLst/>
  <p:sldIdLst>
{sld_ids}
  </p:sldIdLst>
</p:presentation>'''

pres_rels = RELS + ''.join(
    f'\n  <Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{i}.xml"/>'
    for i in range(1, NUM_SLIDES+1)
) + '\n</Relationships>'

ct_overrides = ''.join(
    f'\n  <Override PartName="/ppt/slides/slide{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
    for i in range(1, NUM_SLIDES+1)
)
content_types = CONTENT_TYPES_HEADER + ct_overrides + '\n</Types>'

root_rels = RELS + '\n  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\n</Relationships>'

with zipfile.ZipFile(DEST, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", content_types)
    z.writestr("_rels/.rels", root_rels)
    z.writestr("ppt/presentation.xml", presentation)
    z.writestr("ppt/_rels/presentation.xml.rels", pres_rels)
    for i in range(1, NUM_SLIDES+1):
        z.writestr(f"ppt/slides/slide{i}.xml", slide_xml(i))

import shutil
shutil.copy(DEST, DEST_SPM)
print(f"Generated {NUM_SLIDES}-slide synthetic PPTX at {DEST}")
PYEOF
else
    download_and_verify \
        "https://www.un.org/sites/un2.un.org/files/2021/03/un75-report-commonagenda-en.pdf" \
        "$DEST_PRIMARY/large_sample.pptx" \
        "$DEST_SPM/large_sample.pptx" \
        "SKIP_VERIFY"
fi

echo ""
echo "Performance fixtures ready in $DEST_PRIMARY and $DEST_SPM"
echo "Run: swift test --filter PerformanceTests"
