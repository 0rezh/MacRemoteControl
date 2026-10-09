// Génère les icônes : make icons
// - web/public/*.png : icônes de la PWA (écran d'accueil de l'iPhone)
// - mac/Resources/AppIcon.icns : icône de l'app Mac
// Le dessin : une touche de clavier Mac sombre avec le symbole lecture/pause (F8), comme dans l'interface.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let rgb = CGColorSpace(name: CGColorSpace.sRGB)!

func gray(_ white: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: white, green: white, blue: white + 0.008, alpha: alpha)
}

/// Fond gris sidéral + touche + symbole, dessinés dans `rect`.
func drawArtwork(in context: CGContext, rect: CGRect) {
    let s = rect.width
    let background = CGGradient(colorsSpace: rgb, colors: [gray(0.23), gray(0.11)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(background, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])

    // La touche : ombre portée, surface légèrement plus claire, reflet en haut.
    let inset = s * 0.2
    let key = CGRect(x: rect.minX + inset, y: rect.minY + inset * 0.92, width: s - 2 * inset, height: s - 2 * inset)
    let radius = key.width * 0.12
    let keyPath = CGPath(roundedRect: key, cornerWidth: radius, cornerHeight: radius, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.02, color: gray(0, 0.55))
    context.addPath(keyPath)
    context.setFillColor(gray(0.17))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(keyPath)
    context.clip()
    let surface = CGGradient(colorsSpace: rgb, colors: [gray(0.21), gray(0.16)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(surface, start: CGPoint(x: 0, y: key.maxY), end: CGPoint(x: 0, y: key.minY), options: [])
    context.restoreGState()

    context.addPath(CGPath(roundedRect: key.insetBy(dx: s * 0.003, dy: s * 0.003), cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setStrokeColor(gray(1, 0.14))
    context.setLineWidth(s * 0.006)
    context.strokePath()

    // Symbole lecture/pause au trait, gris clair (#D8D8D8) comme sur les touches.
    let unit = key.width / 220 * 1.7
    context.setStrokeColor(gray(0.847))
    context.setLineWidth(4.4 * unit)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        // Coordonnées de la maquette (touche 220 × 219, symbole centré en 116, 83) recentrées sur la touche.
        CGPoint(x: key.midX + (x - 116) * unit, y: key.midY - (y - 83) * unit)
    }
    context.move(to: point(90, 67)); context.addLine(to: point(90, 99)); context.addLine(to: point(114, 83)); context.closePath()
    context.move(to: point(128.5, 68)); context.addLine(to: point(128.5, 98))
    context.move(to: point(141.5, 68)); context.addLine(to: point(141.5, 98))
    context.strokePath()
}

func makeContext(size: Int) -> CGContext {
    CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: rgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func write(_ context: CGContext, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

/// iPhone : carré plein, iOS arrondit lui-même les coins.
func renderWebIcon(size: Int, to url: URL) throws {
    let context = makeContext(size: size)
    drawArtwork(in: context, rect: CGRect(x: 0, y: 0, width: size, height: size))
    try write(context, to: url)
}

/// Mac : forme arrondie avec marge et ombre, comme le gabarit d'icônes macOS (824 px sur 1024).
func renderMacIcon(size: Int, to url: URL) throws {
    let s = CGFloat(size)
    let context = makeContext(size: size)
    let body = CGRect(x: s * 100 / 1024, y: s * 100 / 1024, width: s * 824 / 1024, height: s * 824 / 1024)
    let shape = CGPath(roundedRect: body, cornerWidth: body.width * 0.225, cornerHeight: body.width * 0.225, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.02, color: gray(0, 0.35))
    context.addPath(shape)
    context.setFillColor(gray(0.12))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    drawArtwork(in: context, rect: body)
    context.restoreGState()
    try write(context, to: url)
}

let web = root.appendingPathComponent("web/public")
try renderWebIcon(size: 180, to: web.appendingPathComponent("apple-touch-icon.png"))
try renderWebIcon(size: 192, to: web.appendingPathComponent("icon-192.png"))
try renderWebIcon(size: 512, to: web.appendingPathComponent("icon-512.png"))

let resources = root.appendingPathComponent("mac/Resources")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try renderMacIcon(size: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderMacIcon(size: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil a échoué") }

print("Icônes générées : web/public/*.png et mac/Resources/AppIcon.icns")
