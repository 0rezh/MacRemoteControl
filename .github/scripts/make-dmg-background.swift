// Génère le fond de la fenêtre de l'installeur : make dmg-background
// - .github/assets/dmg-background.png et dmg-background@2x.png (écrans Retina)
// L'app à gauche, le dossier Applications à droite, une flèche entre les deux et la consigne en dessous.
// Fond clair : avec une image de fond, le Finder affiche la fenêtre en clair même en mode sombre.
// La taille de la fenêtre et la position des icônes sont reprises dans .github/scripts/make-dmg.sh.
// L'image dépasse la fenêtre de 20 points en bas : la barre de titre n'a pas la même hauteur selon la
// version de macOS (28 points sur macOS 14, 32 sur macOS 26), le fond couvre la fenêtre dans tous les cas.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let rgb = CGColorSpace(name: CGColorSpace.sRGB)!

// En points, origine en haut à gauche comme dans le Finder.
let window = CGSize(width: 640, height: 380)
let image = CGSize(width: window.width, height: window.height + 20)
let appCenter = CGPoint(x: 170, y: 155)
let applicationsCenter = CGPoint(x: 470, y: 155)
let iconSize: CGFloat = 128
let captionCenterY: CGFloat = 280
let dotSpacing: CGFloat = 16

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

func render(scale: CGFloat, to url: URL) throws {
    let context = CGContext(
        data: nil, width: Int(image.width * scale), height: Int(image.height * scale), bitsPerComponent: 8,
        bytesPerRow: 0, space: rgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.scaleBy(x: scale, y: scale)
    // Core Graphics compte depuis le bas, le Finder depuis le haut.
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: image.height - y) }

    // Fond gris très clair des réglages iOS, en léger dégradé.
    let background = CGGradient(colorsSpace: rgb, colors: [color(0xFCFCFD), color(0xF1F1F4)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(background, start: point(0, 0), end: point(0, image.height), options: [])

    // Grille de points discrète, centrée sur la fenêtre.
    context.setFillColor(color(0x1C1C1E, 0.11))
    for x in stride(from: dotSpacing / 2, to: image.width, by: dotSpacing) {
        for y in stride(from: dotSpacing / 2, to: image.height, by: dotSpacing) {
            let center = point(x, y)
            context.fillEllipse(in: CGRect(x: center.x - 1.1, y: center.y - 1.1, width: 2.2, height: 2.2))
        }
    }

    // Flèche au trait, légèrement bombée, dans le style des symboles des touches.
    let gap = iconSize / 2 + 30
    let start = point(appCenter.x + gap, appCenter.y)
    let end = point(applicationsCenter.x - gap, applicationsCenter.y)
    let control = CGPoint(x: (start.x + end.x) / 2, y: start.y + 16)
    context.setStrokeColor(color(0x8E8E93))
    context.setLineWidth(3.5)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: start)
    context.addQuadCurve(to: end, control: control)
    let angle = atan2(end.y - control.y, end.x - control.x)
    for side in [-1.0, 1.0] {
        let wing = angle + .pi + side * .pi / 5
        context.move(to: CGPoint(x: end.x + 13 * cos(wing), y: end.y + 13 * sin(wing)))
        context.addLine(to: end)
    }
    context.strokePath()

    // Consigne centrée sous les icônes.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let caption = NSAttributedString(
        string: "Glissez Mac Remote Control dans le dossier Applications",
        attributes: [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor(cgColor: color(0x6E6E73))!,
        ]
    )
    let textSize = caption.size()
    caption.draw(at: point((window.width - textSize.width) / 2, captionCenterY + textSize.height / 2))
    NSGraphicsContext.restoreGraphicsState()

    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let assets = root.appendingPathComponent(".github/assets")
try render(scale: 1, to: assets.appendingPathComponent("dmg-background.png"))
try render(scale: 2, to: assets.appendingPathComponent("dmg-background@2x.png"))

print("Fond de l'installeur généré : .github/assets/dmg-background.png et dmg-background@2x.png")
