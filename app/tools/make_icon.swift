// Draws the Quasi app icon (waveform on a dark rounded square) at 1024 px.
// Usage: swift tools/make_icon.swift <output.png> [ios]
// With "ios" the background fills the whole square, as iOS applies its own mask.
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let fullBleed = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "ios"
let inset: CGFloat = fullBleed ? 0 : 100
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let radius: CGFloat = fullBleed ? 0 : 185
let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
NSGradient(colors: [NSColor(red: 0.16, green: 0.17, blue: 0.24, alpha: 1),
                    NSColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1)])!.draw(in: shape, angle: -90)

let heights: [CGFloat] = [0.18, 0.34, 0.58, 0.82, 0.50, 0.94, 0.66, 0.40, 0.72, 0.30, 0.16]
let barWidth: CGFloat = 34
let gap: CGFloat = 24
let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
let maxHeight = rect.height * 0.52
var x = (size - total) / 2
let barGradient = NSGradient(colors: [NSColor(red: 1.0, green: 0.45, blue: 0.35, alpha: 1),
                                      NSColor(red: 1.0, green: 0.72, blue: 0.30, alpha: 1)])!
for height in heights {
    let barHeight = max(barWidth, height * maxHeight)
    let bar = NSRect(x: x, y: (size - barHeight) / 2, width: barWidth, height: barHeight)
    barGradient.draw(in: NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2), angle: 90)
    x += barWidth + gap
}
image.unlockFocus()

let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
