import AppKit
let output = CommandLine.arguments[1]
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.1, green: 0.14, blue: 0.12, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let symbol = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)!.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 560, weight: .medium))!.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [NSColor.white]))!
symbol.draw(in: NSRect(x: 225, y: 225, width: 574, height: 574))
NSColor(calibratedRed: 0.84, green: 0.93, blue: 0.59, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 634, y: 195, width: 200, height: 200)).fill()
let star = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)!.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 115, weight: .medium))!.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [NSColor.black]))!
star.draw(in: NSRect(x: 678, y: 238, width: 112, height: 112))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
