#!/usr/bin/env swift
import AppKit

let canvas: CGFloat = 1024

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

// ── Background: deep navy rounded rect ──────────────────────────────────────
let bgRect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 220, yRadius: 220)
NSGradient(
    colors: [
        NSColor(red: 0.11, green: 0.14, blue: 0.28, alpha: 1),
        NSColor(red: 0.06, green: 0.08, blue: 0.18, alpha: 1)
    ],
    atLocations: [0, 1],
    colorSpace: .sRGB
)!.draw(in: bgPath, angle: 135)

// ── Slide: white landscape rectangle ────────────────────────────────────────
let slideW: CGFloat = 560
let slideH: CGFloat = 390
let slideX: CGFloat = (canvas - slideW) / 2
let slideY: CGFloat = (canvas - slideH) / 2 + 28

// Drop shadow
NSColor(red: 0, green: 0, blue: 0, alpha: 0.45).setFill()
NSBezierPath(roundedRect: NSRect(x: slideX + 10, y: slideY - 14, width: slideW, height: slideH),
             xRadius: 22, yRadius: 22).fill()

// White slide face
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: slideX, y: slideY, width: slideW, height: slideH),
             xRadius: 22, yRadius: 22).fill()

// ── Markdown content on the slide ───────────────────────────────────────────
let slideTop = slideY + slideH          // top of slide in bottom-left coords
let inset: CGFloat = 40
let textColor = NSColor(red: 0.10, green: 0.12, blue: 0.24, alpha: 1)
let mutedColor = NSColor(red: 0.70, green: 0.72, blue: 0.78, alpha: 1)
let accentColor = NSColor(red: 0.42, green: 0.50, blue: 0.98, alpha: 1)

// "# Title" heading
let hashAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 46, weight: .bold),
    .foregroundColor: accentColor
]
NSAttributedString(string: "#", attributes: hashAttrs)
    .draw(at: NSPoint(x: slideX + inset, y: slideTop - 88))

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 46, weight: .bold),
    .foregroundColor: textColor
]
NSAttributedString(string: " Title", attributes: titleAttrs)
    .draw(at: NSPoint(x: slideX + inset + 46, y: slideTop - 88))

// Thin rule under heading
mutedColor.withAlphaComponent(0.45).setFill()
NSBezierPath(rect: NSRect(x: slideX + inset, y: slideTop - 104, width: slideW - inset * 2, height: 2)).fill()

// Body text lines (three faked lines of content)
let lineColor = NSColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1)
lineColor.setFill()
let lineYs: [CGFloat] = [slideTop - 148, slideTop - 192, slideTop - 236]
let lineWidths: [CGFloat] = [slideW - inset * 2 - 20, slideW - inset * 2 - 80, slideW - inset * 2 - 140]
for (y, w) in zip(lineYs, lineWidths) {
    NSBezierPath(roundedRect: NSRect(x: slideX + inset, y: y, width: w, height: 18),
                 xRadius: 9, yRadius: 9).fill()
}

// "---" slide separator near bottom
let sepAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 30, weight: .regular),
    .foregroundColor: mutedColor
]
NSAttributedString(string: "─ ─ ─", attributes: sepAttrs)
    .draw(at: NSPoint(x: slideX + inset, y: slideY + 26))

image.unlockFocus()

// ── Write 1024×1024 PNG ──────────────────────────────────────────────────────
guard
    let tiff = image.tiffRepresentation,
    let bmp = NSBitmapImageRep(data: tiff),
    let png = bmp.representation(using: .png, properties: [:])
else { fputs("Failed to render image\n", stderr); exit(1) }

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1
              ? CommandLine.arguments[1]
              : "icon_1024.png")
do {
    try png.write(to: out)
    print("Wrote \(out.path)")
} catch {
    fputs("Write error: \(error)\n", stderr); exit(1)
}
