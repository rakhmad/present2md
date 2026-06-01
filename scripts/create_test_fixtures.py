#!/usr/bin/env python3
# scripts/create_test_fixtures.py
# Generates minimal PPTX and ODS files for unit tests (no external deps needed).
import zipfile, os

FIXTURES = "Tests/Fixtures"
os.makedirs(FIXTURES, exist_ok=True)

# ── PPTX ──────────────────────────────────────────────────────────────────────
RELS = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
SLIDE1 = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:spTree>
    <p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>Slide One Title</a:t></a:r></a:p></p:txBody></p:sp>
    <p:sp><p:nvSpPr><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>Body text for slide one.</a:t></a:r></a:p></p:txBody></p:sp>
  </p:spTree></p:cSld>
</p:sld>'''

SLIDE2 = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:spTree>
    <p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>Slide Two Title</a:t></a:r></a:p></p:txBody></p:sp>
    <p:sp><p:nvSpPr><p:nvPr></p:nvPr></p:nvSpPr>
      <p:txBody>
        <a:tbl><a:tr>
          <a:tc><a:txBody><a:p><a:r><a:t>Col A</a:t></a:r></a:p></a:txBody></a:tc>
          <a:tc><a:txBody><a:p><a:r><a:t>Col B</a:t></a:r></a:p></a:txBody></a:tc>
        </a:tr><a:tr>
          <a:tc><a:txBody><a:p><a:r><a:t>val 1</a:t></a:r></a:p></a:txBody></a:tc>
          <a:tc><a:txBody><a:p><a:r><a:t>val 2</a:t></a:r></a:p></a:txBody></a:tc>
        </a:tr></a:tbl>
      </p:txBody></p:sp>
  </p:spTree></p:cSld>
</p:sld>'''

PRESENTATION = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldMasterIdLst/>
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
    <p:sldId id="257" r:id="rId2"/>
  </p:sldIdLst>
</p:presentation>'''

PRES_RELS = RELS + '''
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide2.xml"/>
</Relationships>'''

CONTENT_TYPES = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>'''

ROOT_RELS = RELS + '''
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>'''

pptx_path = os.path.join(FIXTURES, "sample.pptx")
with zipfile.ZipFile(pptx_path, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", CONTENT_TYPES)
    z.writestr("_rels/.rels", ROOT_RELS)
    z.writestr("ppt/presentation.xml", PRESENTATION)
    z.writestr("ppt/_rels/presentation.xml.rels", PRES_RELS)
    z.writestr("ppt/slides/slide1.xml", SLIDE1)
    z.writestr("ppt/slides/slide2.xml", SLIDE2)
print(f"Created {pptx_path}")

# ── ODS ───────────────────────────────────────────────────────────────────────
ODS_CONTENT = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
  xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
  xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0">
  <office:body><office:presentation>
    <draw:page draw:name="Slide1">
      <draw:text-box presentation:class="title"><text:p>ODS Slide One</text:p></draw:text-box>
      <draw:text-box><text:p>ODS body text here.</text:p></draw:text-box>
    </draw:page>
    <draw:page draw:name="Slide2">
      <draw:text-box presentation:class="title"><text:p>ODS Slide Two</text:p></draw:text-box>
      <draw:text-box>
        <table:table>
          <table:table-row>
            <table:table-cell><text:p>Header A</text:p></table:table-cell>
            <table:table-cell><text:p>Header B</text:p></table:table-cell>
          </table:table-row>
          <table:table-row>
            <table:table-cell><text:p>Row 1A</text:p></table:table-cell>
            <table:table-cell><text:p>Row 1B</text:p></table:table-cell>
          </table:table-row>
        </table:table>
      </draw:text-box>
    </draw:page>
  </office:presentation></office:body>
</office:document-content>'''

ODS_MANIFEST = '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0">
  <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.presentation"/>
  <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
</manifest:manifest>'''

ods_path = os.path.join(FIXTURES, "sample.ods")
with zipfile.ZipFile(ods_path, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("mimetype", "application/vnd.oasis.opendocument.presentation")
    z.writestr("content.xml", ODS_CONTENT)
    z.writestr("META-INF/manifest.xml", ODS_MANIFEST)
print(f"Created {ods_path}")
