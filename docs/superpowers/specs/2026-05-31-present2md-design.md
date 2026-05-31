# present2md — Design Spec

**Date:** 2026-05-31  
**Status:** Approved  
**Author:** rakhmad

---

## 1. Overview

`present2md` is a native macOS application that converts presentation and document files (PDF, PPTX, ODS) into CommonMark Markdown files suitable for use with Markdown presentation tools such as Marp. The output filename uses snake_case and is written to the same directory as the source file.

---

## 2. Architecture

The app has three layers with clean, protocol-defined boundaries:

```
┌─────────────────────────────────────────┐
│             UI Layer (SwiftUI)           │
│  ContentView → FileListView → FileRowView│
│  NSOpenPanel (file picker)              │
└──────────────┬──────────────────────────┘
               │ [ConversionJob]
┌──────────────▼──────────────────────────┐
│         ConversionCoordinator           │
│  ObservableObject — manages job queue,  │
│  dispatches to converters, publishes    │
│  state updates to UI via @Published     │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         FileConverter (Protocol)        │
│  PDFConverter   — PDFKit                │
│  PPTXConverter  — ZIPFoundation + XML   │
│  ODSConverter   — ZIPFoundation + XML   │
└─────────────────────────────────────────┘
```

Each converter conforms to a `FileConverter` protocol with a single method:

```swift
protocol FileConverter {
    func convert(url: URL) throws -> [Slide]
}
```

All conversion runs on a detached background `Task`. The `MarkdownSerializer` is format-agnostic — it accepts `[Slide]` and emits a CommonMark string. Converters never produce Markdown directly.

---

## 3. Data Model

```swift
struct ConversionJob: Identifiable {
    let id: UUID
    let sourceURL: URL
    var status: JobStatus
    var outputURL: URL?
    var errorMessage: String?
}

enum JobStatus {
    case pending
    case converting
    case done
    case failed
}

struct Slide {
    var title: String?
    var blocks: [SlideBlock]
}

enum SlideBlock {
    case text(String)
    case table([[String]])
    case imagePlaceholder(Int)
}
```

`ConversionCoordinator` holds `@Published var jobs: [ConversionJob]`. SwiftUI binds directly to this — no separate view model layer needed.

---

## 4. Output Format

### Filename
Source filename is sanitized to snake_case:

```
"My Deck – 2024 (v2).pptx"
→ lowercase
→ spaces, hyphens, em-dashes → underscores
→ strip non-alphanumeric (except underscores)
→ collapse consecutive underscores
→ truncate to 200 chars
→ append ".md"
= "my_deck_2024_v2.md"
```

Output is written to the same directory as the source file. Existing `.md` files are overwritten without prompt (conversion is idempotent).

### Markdown Structure (CommonMark)

```markdown
---
title: First Slide Title
---

Body text for first slide.

| Col A | Col B |
|-------|-------|
| val 1 | val 2 |

![image](image_1.png)

---

## Second Slide Title

Body text for second slide.
```

- Slides separated by `---` (thematic break)
- First slide title → YAML front-matter `title:` field
- Subsequent slide titles → `##` headings
- Tables → CommonMark pipe tables
- Images → `![image](image_N.png)` placeholder (bytes not extracted)

---

## 5. Conversion Engine

### PDFConverter (PDFKit — zero added dependencies)
- Open with `PDFDocument(url:)`
- Per page: extract `PDFPage.string` for text
- Title detection: first text block with font size above body average → heading
- Table detection: text blocks with consistent horizontal column alignment
- Each page = one slide section
- Expected performance: <5s for 100-page PDF

### PPTXConverter (ZIPFoundation + XML)
- Unzip to temp directory using `ZIPFoundation`
- Slide order from `ppt/presentation.xml` → `<p:sldIdLst>`
- Per slide: parse `ppt/slides/slideN.xml`
  - `<a:t>` → text runs
  - `<p:sp>` placeholder type → title vs body distinction
  - `<a:tr>/<a:tc>` → table cells
- Temp directory cleaned up after conversion

### ODSConverter (ZIPFoundation + XML)
- Unzip, parse `content.xml` (ODF namespace)
- `<draw:page>` = one slide
- `<draw:text-box presentation:class="title">` = slide title
- `<draw:text-box>` = body text
- `<table:table>` = table

### MarkdownSerializer (shared)
- Accepts `[Slide]`, returns `String`
- Single source of truth for all Markdown syntax
- Converters are Markdown-unaware

---

## 6. UI Layout

Single-window app. Minimum size: 480×320pt. Resizable.

```
┌─────────────────────────────────────────┐
│  present2md                    [Browse] │  ← Toolbar
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐│
│  │ my_deck.pptx          [Converting…]││
│  │ quarterly_report.pdf  [✓ Done] [⎋]  ││  ← ⎋ = Reveal in Finder
│  │ budget.ods            [✗ Failed]    ││
│  └─────────────────────────────────────┘│
│                                         │
│  (empty state: "Browse or drop files   │
│   to begin conversion")                │
├─────────────────────────────────────────┤
│  [Clear Completed]          2/3 done   │  ← Footer
└─────────────────────────────────────────┘
```

**Browse button:** Opens `NSOpenPanel` with allowed types: `pdf`, `pptx`, `ods`. Multi-select enabled. Legacy `.ppt` excluded from picker.

**Drag-and-drop:** Files can be dropped onto the list area (SwiftUI `.onDrop`).

**FileRowView:** Filename, animated spinner while converting, status badge when done, "Reveal in Finder" button on success, error tooltip on failure.

**Clear Completed:** Removes all `done` and `failed` rows.

**No Preferences window** — no configurable settings.

---

## 7. Error Handling

Errors are per-job — one failing file never blocks others.

| Scenario | Behavior |
|---|---|
| File unreadable / permission denied | Failed — "Cannot read file. Check permissions." |
| Corrupt ZIP (PPTX/ODS) | Failed — "File appears corrupt or is not a valid PPTX/ODS." |
| Empty document (0 slides/pages) | Failed — "No content found in file." |
| Output write failure | Failed — "Cannot write to output directory." |
| Conversion exceeds 60 seconds | Modal sheet: "Conversion is taking longer than expected. Continue waiting or cancel?" — [Keep Waiting] resets timer, [Cancel] marks job failed with "Cancelled by user." |
| Slide with no text | Outputs `---` separator only, no content block |
| Table with merged cells | Flattened to plain text rows |
| Password-protected PDF | Treated as empty slides |
| Filename collision | Overwrite silently (idempotent) |
| Filename >200 chars after sanitization | Truncated to 200 chars |

**Out of scope:**
- Legacy `.ppt` binary format (excluded from file picker)
- Encrypted/DRM PPTX
- Right-to-left text reordering

---

## 8. Testing Strategy

All tests run with `swift test`. No Xcode required for CI.

### Unit Tests (`present2mdTests/`)
- `FilenameConverterTests` — ~20 cases covering spaces, hyphens, em-dashes, unicode, already-snake-case, very long names, all-special-chars
- `MarkdownSerializerTests` — given hardcoded `[Slide]` arrays, assert exact CommonMark string output
- `PPTXConverterTests` — fixture `.pptx` from `Tests/Fixtures/`, assert extracted `[Slide]` matches expected titles and blocks
- `ODSConverterTests` — same pattern with fixture `.ods`
- `PDFConverterTests` — fixture `.pdf` with known content, assert page extraction

### Integration Tests (`present2mdIntegrationTests/`)
- End-to-end: feed real files through `ConversionCoordinator`, assert `.md` output appears at correct path with correct content
- Timeout prompt test: mock converter that stalls >60s, assert prompt fires

### Performance Tests (`present2mdPerformanceTests/`)
- Large PPTX (>50 slides), large PDF (>100 pages), large ODS (>30 slides)
- Assert each completes in <60 seconds
- Fixtures downloaded by `scripts/download_test_fixtures.sh` with SHA256 verification

### Fixture Strategy
- Small fixtures (<1MB): committed to `Tests/Fixtures/`
- Large performance fixtures (>1MB): git-ignored, downloaded via `scripts/download_test_fixtures.sh` from stable public URLs (NASA technical reports, UN presentations, World Bank data)

---

## 9. Project Structure

```
present2md/
├── README.md
├── LICENSE                            # MIT
├── Package.swift                      # ZIPFoundation dependency
├── .gitignore
├── present2md.xcodeproj/
├── present2md/
│   ├── App/
│   │   ├── present2mdApp.swift
│   │   └── ContentView.swift
│   ├── UI/
│   │   ├── FileListView.swift
│   │   ├── FileRowView.swift
│   │   └── EmptyStateView.swift
│   ├── Coordinator/
│   │   └── ConversionCoordinator.swift
│   ├── Converters/
│   │   ├── FileConverter.swift
│   │   ├── PDFConverter.swift
│   │   ├── PPTXConverter.swift
│   │   └── ODSConverter.swift
│   ├── Model/
│   │   ├── ConversionJob.swift
│   │   ├── Slide.swift
│   │   └── SlideBlock.swift
│   ├── Serializer/
│   │   └── MarkdownSerializer.swift
│   └── Utilities/
│       └── FilenameConverter.swift
├── present2mdTests/
├── present2mdIntegrationTests/
├── present2mdPerformanceTests/
├── Tests/
│   ├── Fixtures/
│   └── PerformanceFixtures/           # git-ignored
├── scripts/
│   └── download_test_fixtures.sh
└── docs/
    ├── plans/                         # Implementation plans
    └── superpowers/specs/             # Design docs (this file)
```

---

## 10. Dependencies

| Package | Purpose | Size |
|---|---|---|
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | ZIP archive reading for PPTX/ODS | ~500KB |

No other external dependencies. PDFKit, Foundation (`XMLParser`), SwiftUI, and AppKit are all system frameworks included with macOS.

**Minimum macOS version:** 13.0 (Ventura) — required for latest SwiftUI APIs used.
