#if os(macOS)
import AppKit
import SwiftUI

/// Strumenti condivisi dai test che disegnano. Non è un target di test, così più
/// target di test possono dipenderne; nessun target dell'app lo usa.

public enum RenderingError: Error {
    case noImage
}

/// Renderizza a scala 2 e, se GLYPH_SNAPSHOT_DIR è impostata, lascia la PNG su disco:
/// le schermate si guardano, non si immaginano.
@MainActor
public func renderImage(_ view: some View, size: CGSize, named name: String) throws -> NSBitmapImageRep {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 2
    guard let image = renderer.cgImage else { throw RenderingError.noImage }
    let bitmap = NSBitmapImageRep(cgImage: image)
    if let directory = ProcessInfo.processInfo.environment["GLYPH_SNAPSHOT_DIR"],
        let png = bitmap.representation(using: .png, properties: [:])
    {
        try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
    return bitmap
}

/// Pixel chiari su fondo scuro: restano solo i tratti e il testo davvero disegnati.
public func inkPixels(_ bitmap: NSBitmapImageRep) -> Int {
    guard let data = bitmap.bitmapData, bitmap.bitsPerSample == 8 else { return 0 }
    let bytesPerPixel = bitmap.bitsPerPixel / 8
    var count = 0
    for y in 0..<bitmap.pixelsHigh {
        let row = data + y * bitmap.bytesPerRow
        for x in 0..<bitmap.pixelsWide
        where Int(row[x * bytesPerPixel]) + Int(row[x * bytesPerPixel + 1]) + Int(row[x * bytesPerPixel + 2]) > 200 {
            count += 1
        }
    }
    return count
}
#endif
