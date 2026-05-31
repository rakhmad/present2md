# present2md

A native macOS application that converts presentation and document files into CommonMark Markdown, ready for use with Markdown-based presentation tools like [Marp](https://marp.app/).

## Supported formats

| Format | Extension |
|---|---|
| PDF | `.pdf` |
| PowerPoint (OpenXML) | `.pptx` |
| OpenDocument Presentation | `.ods` |

> **Note:** Legacy `.ppt` (binary PowerPoint) is not supported. Convert to `.pptx` first using PowerPoint or LibreOffice.

## Features

- Browse or drag-and-drop files to convert
- Batch conversion — select multiple files at once
- Per-file status with progress indicators
- Output written alongside the source file in `snake_case.md`
- CommonMark-compliant output: titles, body text, tables, and image placeholders
- Lightweight — no external runtime dependencies, ~10MB app bundle
- Runs on macOS 13.0 (Ventura) and later

## Output

Each slide or page is separated by a `---` thematic break. Slide titles become Markdown headings. Tables are rendered as CommonMark pipe tables. Embedded images are noted as placeholders (`![image](image_N.png)`).

Example output:

```markdown
---
title: My Presentation Title
---

Introduction body text here.

---

## Second Slide

| Column A | Column B |
|----------|----------|
| Value 1  | Value 2  |

---

## Third Slide

![image](image_1.png)
```

## Building

Requirements: Xcode 15+, macOS 13.0+

```bash
git clone https://github.com/rakhmad/present2md.git
cd present2md
open present2md.xcodeproj
```

Build and run with `Cmd+R` in Xcode, or via command line:

```bash
xcodebuild -scheme present2md -configuration Release build
```

## Testing

```bash
# Unit and integration tests
swift test

# Download large performance test fixtures first
bash scripts/download_test_fixtures.sh
swift test --filter PerformanceTests
```

## License

MIT — see [LICENSE](LICENSE).
