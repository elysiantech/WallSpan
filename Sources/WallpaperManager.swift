import AppKit

enum ScreenGeometry {
    /// Returns the combined pixel width across all screens, capped at 5120.
    static func combinedPixelWidth() -> Int {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return 3840 }

        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        for screen in screens {
            minX = min(minX, screen.frame.minX)
            maxX = max(maxX, screen.frame.maxX)
        }
        let totalPoints = maxX - minX
        let pixels = Int(totalPoints * 2.0)
        return min(pixels, 5120)
    }
}

class WallpaperManager {
    private let supportDir: URL
    private var currentTag: String = ""

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        supportDir = appSupport.appendingPathComponent("WallSpan")
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
    }

    /// Generates a unique tag and cleans up previous wallpaper files.
    private func rotateTag() -> String {
        let oldTag = currentTag
        let newTag = UUID().uuidString.prefix(8).lowercased()
        currentTag = String(newTag)

        // Clean up old files
        if !oldTag.isEmpty {
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(at: supportDir, includingPropertiesForKeys: nil) {
                for file in files where file.lastPathComponent.contains(oldTag) {
                    try? fm.removeItem(at: file)
                }
            }
        }
        return currentTag
    }

    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    /// Downloads the image and spans it across all connected screens.
    func applyWallpaper(from url: URL, completion: @escaping (Error?) -> Void) {
        downloadSession.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data else {
                completion(error ?? WallSpanError.noData)
                return
            }

            DispatchQueue.main.async {
                guard let image = NSImage(data: data) else {
                    completion(WallSpanError.imageProcessingFailed)
                    return
                }

                do {
                    try self.spanAcrossScreens(image: image)
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }.resume()
    }

    // MARK: - Multi-monitor spanning

    private func spanAcrossScreens(image: NSImage) throws {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { throw WallSpanError.noScreens }

        // Single monitor — just set the full image
        let tag = rotateTag()
        if screens.count == 1 {
            let fileURL = supportDir.appendingPathComponent("wallpaper_\(tag)_0.jpg")
            try saveImage(image, to: fileURL)
            try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screens[0], options: [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                .allowClipping: true
            ])
            return
        }

        // Multi-monitor: compute bounding box across all screens (point coordinates)
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity

        for screen in screens {
            let f = screen.frame
            minX = min(minX, f.minX)
            minY = min(minY, f.minY)
            maxX = max(maxX, f.maxX)
            maxY = max(maxY, f.maxY)
        }

        let totalWidth = maxX - minX
        let totalHeight = maxY - minY

        // Render at 2x for Retina quality
        let renderScale: CGFloat = 2.0
        let canvasW = Int(totalWidth * renderScale)
        let canvasH = Int(totalHeight * renderScale)

        // Scale the source image to fill the canvas (aspect fill)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let canvas = aspectFill(cgImage: cgImage, targetWidth: canvasW, targetHeight: canvasH)
        else {
            throw WallSpanError.imageProcessingFailed
        }

        // Crop each screen's slice and set as wallpaper
        for (index, screen) in screens.enumerated() {
            let f = screen.frame

            // Screen position in canvas coords (top-left origin for image)
            let cropX = Int((f.minX - minX) * renderScale)
            let cropY = Int((totalHeight - (f.minY - minY) - f.height) * renderScale)
            let cropW = Int(f.width * renderScale)
            let cropH = Int(f.height * renderScale)

            let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

            guard let cropped = canvas.cropping(to: cropRect) else { continue }

            // If screen has a different backing scale, resize to native pixels
            let nativeW = Int(f.width * screen.backingScaleFactor)
            let nativeH = Int(f.height * screen.backingScaleFactor)
            let finalImage: CGImage
            if nativeW != cropW || nativeH != cropH {
                finalImage = resize(cgImage: cropped, toWidth: nativeW, height: nativeH) ?? cropped
            } else {
                finalImage = cropped
            }

            let fileURL = supportDir.appendingPathComponent("wallpaper_\(tag)_\(index).jpg")
            let bitmapRep = NSBitmapImageRep(cgImage: finalImage)
            guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else { continue }
            try jpegData.write(to: fileURL)

            try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                .allowClipping: true
            ])
        }
    }

    // MARK: - Image processing

    /// Scales the image to fill the target size (aspect fill, centered crop).
    private func aspectFill(cgImage: CGImage, targetWidth: Int, targetHeight: Int) -> CGImage? {
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let tgtW = CGFloat(targetWidth)
        let tgtH = CGFloat(targetHeight)

        let scale = max(tgtW / imgW, tgtH / imgH)
        let scaledW = Int(imgW * scale)
        let scaledH = Int(imgH * scale)
        let offsetX = (scaledW - targetWidth) / 2
        let offsetY = (scaledH - targetHeight) / 2

        guard let ctx = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: -offsetX, y: -offsetY, width: scaledW, height: scaledH))
        return ctx.makeImage()
    }

    /// Resizes a CGImage to exact pixel dimensions.
    private func resize(cgImage: CGImage, toWidth width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    /// Saves an NSImage as JPEG.
    private func saveImage(_ image: NSImage, to url: URL) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw WallSpanError.imageProcessingFailed
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
            throw WallSpanError.imageProcessingFailed
        }
        try data.write(to: url)
    }
}
