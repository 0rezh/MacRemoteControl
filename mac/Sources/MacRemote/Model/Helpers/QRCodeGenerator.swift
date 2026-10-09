import AppKit
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    /// QR code net (pixels entiers, sans lissage) de `dimension` × `dimension` points.
    static func image(for string: String, dimension: CGFloat) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scale = (dimension * 2 / output.extent.width).rounded(.up)
        let scaled = output.samplingNearest().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: dimension, height: dimension))
    }
}
