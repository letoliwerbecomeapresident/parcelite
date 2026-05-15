#!/usr/bin/env swift
import AppKit
import CoreGraphics

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sizes: [(px: Int, name: String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

func render(size: Int) -> Data? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ns

    let f = CGFloat(size)
    let inset = f * 0.06
    let rect = NSRect(x: inset, y: inset, width: f - 2*inset, height: f - 2*inset)
    let radius = f * 0.22
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(red: 1.00, green: 0.62, blue: 0.15, alpha: 1),
        NSColor(red: 0.92, green: 0.30, blue: 0.05, alpha: 1),
    ])!
    gradient.draw(in: bg, angle: -90)

    // Subtle inner highlight
    NSColor.white.withAlphaComponent(0.18).setFill()
    let hl = NSBezierPath(roundedRect: NSRect(
        x: rect.minX, y: rect.midY, width: rect.width, height: rect.height/2
    ), xRadius: radius, yRadius: radius)
    hl.fill()

    let emoji = "📦" as NSString
    let fontSize = f * 0.60
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize)
    ]
    let ts = emoji.size(withAttributes: attrs)
    emoji.draw(
        at: NSPoint(x: (f - ts.width)/2, y: (f - ts.height)/2 - f*0.03),
        withAttributes: attrs
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let img = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: img)
    return rep.representation(using: .png, properties: [:])
}

for (px, name) in sizes {
    guard let data = render(size: px) else {
        FileHandle.standardError.write("Failed: \(name)\n".data(using: .utf8)!)
        continue
    }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("Icon set written to \(outDir)")
