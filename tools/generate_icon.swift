//
//  generate_icon.swift
//  PeriodicTable
//
//  Renders the application icon at every size required by an .iconset
//  and writes PeriodicTable/Resources/AppIcon.icns.
//
//  Usage:  xcrun swift tools/generate_icon.swift
//

import AppKit
import CoreGraphics
import Foundation

let canvas: CGFloat = 1024.0

// MARK: - Palette

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1.0) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

let deepSpace = rgb(0x0A0F18)
let midSpace  = rgb(0x1B2436)
let loSpace   = rgb(0x25314A)
let cyan      = rgb(0x5FE1FF)
let cyanDeep  = rgb(0x2A7DFF)
let violet    = rgb(0xB084FF)
let mint      = rgb(0x5AF2C4)

// MARK: - Geometry helpers

/// Apple-style "squircle" (superellipse). n = 5 is a good macOS match.
func squirclePath(in rect: CGRect, n: CGFloat = 5.0) -> CGPath {
    let path = CGMutablePath()
    let cx = rect.midX, cy = rect.midY
    let a = rect.width / 2.0, b = rect.height / 2.0
    let steps = 1024
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2.0 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2.0 / n), ct)
        let y = cy + b * copysign(pow(abs(st), 2.0 / n), st)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
        else      { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient? {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
               colors: colors as CFArray,
               locations: locations)
}

func fillLinear(_ ctx: CGContext, _ g: CGGradient, from: CGPoint, to: CGPoint) {
    ctx.drawLinearGradient(g, start: from, end: to,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func fillRadial(_ ctx: CGContext, _ g: CGGradient, center: CGPoint,
                startRadius: CGFloat, endRadius: CGFloat) {
    ctx.drawRadialGradient(g, startCenter: center, startRadius: startRadius,
                           endCenter: center, endRadius: endRadius,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Rotated ellipse stroke. Angle in radians, applied around `center`.
func strokeEllipse(_ ctx: CGContext, center: CGPoint, rx: CGFloat, ry: CGFloat,
                   rotation: CGFloat, color: CGColor, width: CGFloat, glow: Bool) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: rotation)
    let rect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)

    if glow {
        ctx.setBlendMode(.plusLighter)
        ctx.setStrokeColor(color.copy(alpha: 0.22) ?? color)
        ctx.setLineWidth(width * 4.0)
        ctx.strokeEllipse(in: rect)
        ctx.setBlendMode(.normal)
    }

    ctx.setShadow(offset: .zero, blur: width * 4.0, color: color.copy(alpha: 0.55))
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.strokeEllipse(in: rect)
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.restoreGState()
}

/// Point on an ellipse after rotation around its centre.
func pointOnEllipse(center: CGPoint, rx: CGFloat, ry: CGFloat,
                    rotation: CGFloat, t: CGFloat) -> CGPoint {
    let x = rx * cos(t), y = ry * sin(t)
    let c = cos(rotation), s = sin(rotation)
    return CGPoint(x: center.x + x * c - y * s,
                   y: center.y + x * s + y * c)
}

func drawElectron(_ ctx: CGContext, at p: CGPoint, radius: CGFloat, color: CGColor) {
    ctx.saveGState()
    ctx.setBlendMode(.plusLighter)
    if let g = gradient([color.copy(alpha: 0.0) ?? color,
                         color.copy(alpha: 0.55) ?? color,
                         color.copy(alpha: 0.0) ?? color],
                        [0.0, 0.55, 1.0]) {
        fillRadial(ctx, g, center: p, startRadius: 0, endRadius: radius * 3.1)
    }
    if let g = gradient([rgb(0xFFFFFF), color], [0.0, 1.0]) {
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: p.x - radius, y: p.y - radius,
                                  width: radius * 2, height: radius * 2))
        ctx.clip()
        fillRadial(ctx, g, center: CGPoint(x: p.x - radius * 0.3, y: p.y + radius * 0.3),
                   startRadius: 0, endRadius: radius * 1.5)
        ctx.restoreGState()
    }
    ctx.restoreGState()
}

// MARK: - Text

func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func drawCenteredText(_ string: String, font: NSFont, color: NSColor,
                      kern: CGFloat = 0, center: CGPoint) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: kern,
        .paragraphStyle: style,
    ]
    let attr = NSAttributedString(string: string, attributes: attrs)
    let size = attr.size()
    attr.draw(in: CGRect(x: center.x - size.width / 2.0 - kern / 2.0,
                         y: center.y - size.height / 2.0,
                        width: size.width + kern,
                       height: size.height))
}

// MARK: - Background

func drawBackground(_ ctx: CGContext, shape: CGPath) {
    // Drop shadow behind the squircle.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -22),
                  blur: 44,
                  color: rgb(0x000000, 0.55))
    ctx.addPath(shape)
    ctx.setFillColor(midSpace)
    ctx.fillPath()
    ctx.restoreGState()

    // Clip to the squircle for all interior artwork.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    // Base vertical gradient.
    if let g = gradient([loSpace, midSpace, deepSpace], [0.0, 0.45, 1.0]) {
        fillLinear(ctx, g, from: CGPoint(x: 512, y: 1024), to: CGPoint(x: 512, y: 0))
    }

    // Cool glow behind the hero tile.
    if let g = gradient([rgb(0x3F8CFF, 0.33), rgb(0x3F8CFF, 0.10), rgb(0x3F8CFF, 0.0)],
                        [0.0, 0.45, 1.0]) {
        fillRadial(ctx, g, center: CGPoint(x: 512, y: 540), startRadius: 0, endRadius: 540)
    }

    // Violet accent in the upper left, mint accent lower right.
    if let g = gradient([rgb(0xB084FF, 0.20), rgb(0xB084FF, 0.0)], [0.0, 1.0]) {
        fillRadial(ctx, g, center: CGPoint(x: 230, y: 830), startRadius: 0, endRadius: 420)
    }
    if let g = gradient([rgb(0x5AF2C4, 0.13), rgb(0x5AF2C4, 0.0)], [0.0, 1.0]) {
        fillRadial(ctx, g, center: CGPoint(x: 830, y: 240), startRadius: 0, endRadius: 380)
    }

    ctx.restoreGState()
}

/// A faint periodic-table mosaic in the background, behind the hero tile.
func drawMosaic(_ ctx: CGContext, shape: CGPath) {
    let cols = 18
    let tile: CGFloat = 29.0
    let gap: CGFloat = 7.0
    let rowHeight = tile + gap
    let totalW = CGFloat(cols) * tile + CGFloat(cols - 1) * gap

    // Category colours sampled from the app palette.
    let colors: [CGColor] = [
        rgb(0xF86B6B), // alkali metal
        rgb(0xFDC259), // alkaline earth metal
        rgb(0xF29999), // transition metal
        rgb(0xC7CCD4), // post-transition metal
        rgb(0xA1DB8C), // metalloid
        rgb(0x70C7E3), // reactive nonmetal
        rgb(0xC2EB59), // halogen
        rgb(0x73D99A), // noble gas
        rgb(0xD994F2), // lanthanide
        rgb(0xF586B8), // actinide
    ]

    func colorFor(col: Int, period: Int) -> CGColor {
        if period == 1 { return col == 0 ? colors[5] : colors[7] }
        switch col {
        case 0:  return colors[0]
        case 1:  return colors[1]
        case 2...11: return colors[2]
        case 12: return period <= 3 ? colors[4] : colors[3]
        case 13: return period <= 3 ? colors[5] : colors[3]
        case 14: return period <= 3 ? colors[5] : colors[3]
        case 15: return period <= 3 ? colors[5] : colors[3]
        case 16: return colors[6]
        default: return colors[7]
        }
    }

    // Main block (7 periods) plus the two f-block rows.
    var cells: [(col: Int, row: Int, color: CGColor)] = []
    for period in 1...7 {
        let row = 9 - period // period 1 at the top
        for col in 0..<cols {
            let inMainBlock = period == 1
                ? (col == 0 || col == 17)
                : (period <= 3 ? (col <= 1 || col >= 12) : true)
            guard inMainBlock else { continue }
            cells.append((col, row, colorFor(col: col, period: period)))
        }
    }
    // Lanthanides / actinides: 15 tiles, indented under the d-block.
    for (row, category) in [(1, colors[8]), (0, colors[9])] {
        for col in 3..<18 {
            cells.append((col, row, category))
        }
    }

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    let originX = (canvas - totalW) / 2.0
    let tableHeight = 9.0 * rowHeight
    let topY = 512.0 + tableHeight / 2.0 + 4.0

    ctx.setAlpha(0.14)
    for cell in cells {
        let x = originX + CGFloat(cell.col) * (tile + gap)
        let y = topY - CGFloat(cell.row + 1) * rowHeight + gap
        let rect = CGRect(x: x, y: y, width: tile, height: tile)
        let path = CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(cell.color)
        ctx.fillPath()
    }
    ctx.restoreGState()
}

// MARK: - Hero element tile

func drawHeroTile(_ ctx: CGContext, side: CGFloat, symbolSize: CGFloat, compact: Bool) {
    let centerY: CGFloat = compact ? 512.0 : 516.0
    let rect = CGRect(x: 512 - side / 2, y: centerY - side / 2, width: side, height: side)
    let radius = side * 0.215
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Ambient glow around the card.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: side * 0.11, color: cyan.copy(alpha: 0.55))
    ctx.addPath(path)
    ctx.setFillColor(cyanDeep)
    ctx.fillPath()
    ctx.restoreGState()

    // Card gradient.
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    if let g = gradient([rgb(0x7DEBFF), rgb(0x35B6FF), rgb(0x2A6BF2), rgb(0x2346C8)],
                        [0.0, 0.38, 0.72, 1.0]) {
        fillLinear(ctx, g, from: CGPoint(x: rect.minX, y: rect.maxY),
                   to: CGPoint(x: rect.maxX, y: rect.minY))
    }

    // Soft top-left sheen.
    if let g = gradient([rgb(0xFFFFFF, 0.35), rgb(0xFFFFFF, 0.0)], [0.0, 1.0]) {
        fillRadial(ctx, g, center: CGPoint(x: rect.minX + side * 0.22, y: rect.maxY - side * 0.05),
                   startRadius: 0, endRadius: side * 0.8)
    }

    // Bottom depth.
    if let g = gradient([rgb(0x0B1B57, 0.0), rgb(0x0B1B57, 0.40)], [0.0, 1.0]) {
        fillLinear(ctx, g, from: CGPoint(x: 512, y: rect.midY),
                   to: CGPoint(x: 512, y: rect.minY))
    }

    // Inner hairline.
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.30))
    ctx.setLineWidth(max(2.5, side * 0.007))
    let inset = rect.insetBy(dx: 3, dy: 3)
    ctx.addPath(CGPath(roundedRect: inset, cornerWidth: radius - 3, cornerHeight: radius - 3,
                       transform: nil))
    ctx.strokePath()
    ctx.restoreGState()

    // Big symbol — always present.
    drawCenteredText("C", font: font(symbolSize, .heavy),
                     color: .white,
                     center: CGPoint(x: 512, y: rect.midY + symbolSize * 0.015))

    guard !compact else { return }

    // Atomic number, optically aligned with the top-left corner.
    drawCenteredText("6", font: font(side * 0.132, .semibold),
                     color: NSColor.white.withAlphaComponent(0.85),
                     center: CGPoint(x: rect.minX + side * 0.172, y: rect.maxY - side * 0.175))

    // Element name, letter-spaced along the bottom.
    drawCenteredText("CARBON", font: font(side * 0.084, .semibold),
                     color: NSColor.white.withAlphaComponent(0.92),
                     kern: side * 0.016,
                     center: CGPoint(x: 512, y: rect.minY + side * 0.15))
}

// MARK: - Orbits

func drawOrbits(_ ctx: CGContext, compact: Bool) {
    let center = CGPoint(x: 512, y: 518)
    let rx: CGFloat = compact ? 392 : 372
    let ry: CGFloat = compact ? 142 : 132

    let rings: [(CGFloat, CGColor, CGFloat)] = [
        (-0.36, cyan,       0.95),
        ( 0.62, violet,     0.90),
        ( 1.72, mint,       0.85),
    ]

    ctx.saveGState()
    for (angle, color, alpha) in rings {
        strokeEllipse(ctx, center: center, rx: rx, ry: ry, rotation: angle,
                      color: color.copy(alpha: alpha) ?? color,
                      width: compact ? 12.0 : 4.0, glow: true)
        // One electron per orbit.
        let t: CGFloat = angle * 2.4 + 0.6
        let p = pointOnEllipse(center: center, rx: rx, ry: ry, rotation: angle, t: t)
        drawElectron(ctx, at: p, radius: compact ? 18 : 13, color: color)
    }
    ctx.restoreGState()
}

// MARK: - Tiny variant

/// At 16 pt there is no room for the card, orbits or mosaic. The tile itself
/// becomes the mark: the same blue gradient with a single bold "C".
func drawTinyTile(_ ctx: CGContext, shape: CGPath) {
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    if let g = gradient([rgb(0x7DEBFF), rgb(0x35B6FF), rgb(0x2A6BF2), rgb(0x2346C8)],
                        [0.0, 0.38, 0.72, 1.0]) {
        fillLinear(ctx, g, from: CGPoint(x: 100, y: 936), to: CGPoint(x: 924, y: 112))
    }
    if let g = gradient([rgb(0xFFFFFF, 0.30), rgb(0xFFFFFF, 0.0)], [0.0, 1.0]) {
        fillRadial(ctx, g, center: CGPoint(x: 260, y: 900), startRadius: 0, endRadius: 720)
    }
    ctx.restoreGState()

    // Hairline rim.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.25))
    ctx.setLineWidth(7.0)
    ctx.strokePath()
    ctx.restoreGState()

    drawCenteredText("C", font: font(455, .heavy), color: .white,
                     center: CGPoint(x: 512, y: 524))
}

// MARK: - Master drawing

func drawIcon(_ ctx: CGContext, pixels: Int) {
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // macOS 26+ places icons that contain transparency on a default light
    // "plate". Painting the whole canvas and scaling the artwork so its
    // squircle fills the tile keeps this icon full-bleed and plate-free.
    ctx.setFillColor(deepSpace)
    ctx.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))

    ctx.saveGState()
    let iconCenter = CGPoint(x: 512, y: 524)
    let bleed = canvas / 824.0
    ctx.translateBy(x: 512, y: 512)
    ctx.scaleBy(x: bleed, y: bleed)
    ctx.translateBy(x: -512, y: -iconCenter.y)

    let compact = pixels < 128
    let tiny = pixels <= 16
    let iconRect = CGRect(x: 100, y: 112, width: 824, height: 824)
    let shape = squirclePath(in: iconRect)

    drawBackground(ctx, shape: shape)
    if !compact { drawMosaic(ctx, shape: shape) }
    if !tiny { drawOrbits(ctx, compact: compact) }

    if tiny {
        drawTinyTile(ctx, shape: shape)
    } else if compact {
        drawHeroTile(ctx, side: 540, symbolSize: 372, compact: true)
    } else {
        drawHeroTile(ctx, side: 440, symbolSize: 292, compact: false)
    }

    // Rim light.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.14))
    ctx.setLineWidth(3.0)
    ctx.strokePath()
    ctx.restoreGState()

    // Top edge highlight, clipped inside the squircle.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    if let g = gradient([rgb(0xFFFFFF, 0.16), rgb(0xFFFFFF, 0.0)], [0.0, 1.0]) {
        fillLinear(ctx, g, from: CGPoint(x: 512, y: 936),
                   to: CGPoint(x: 512, y: 740))
    }
    ctx.restoreGState()

    ctx.restoreGState()
}

// MARK: - Rendering

func render(size: Int) -> Data {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: size, pixelsHigh: size,
                                     bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else {
        fatalError("Could not allocate \(size)x\(size) bitmap")
    }
    rep.size = NSSize(width: size, height: size)
    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let cg = graphics.cgContext
    cg.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(cg, pixels: size)
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG for size \(size)")
    }
    return data
}

// MARK: - Entry point

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let resources = root.appendingPathComponent("PeriodicTable/Resources")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")

try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

struct IconEntry { let name: String; let pixels: Int }
let entries: [IconEntry] = [
    .init(name: "icon_16x16.png",      pixels: 16),
    .init(name: "icon_16x16@2x.png",   pixels: 32),
    .init(name: "icon_32x32.png",      pixels: 32),
    .init(name: "icon_32x32@2x.png",   pixels: 64),
    .init(name: "icon_128x128.png",    pixels: 128),
    .init(name: "icon_128x128@2x.png", pixels: 256),
    .init(name: "icon_256x256.png",    pixels: 256),
    .init(name: "icon_256x256@2x.png", pixels: 512),
    .init(name: "icon_512x512.png",    pixels: 512),
    .init(name: "icon_512x512@2x.png", pixels: 1024),
]

for entry in entries {
    let data = render(size: entry.pixels)
    try data.write(to: iconset.appendingPathComponent(entry.name))
    if entry.pixels == 1024 {
        try data.write(to: root.appendingPathComponent("build/icon-preview.png"))
    }
    print("rendered \(entry.name) (\(entry.pixels)px)")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path,
                     "-o", resources.appendingPathComponent("AppIcon.icns").path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}
print("wrote PeriodicTable/Resources/AppIcon.icns")
