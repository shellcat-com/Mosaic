import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Permanently develops a photo with the group's film look before the JPEG is stored or uploaded.
/// Recaps therefore render the same developed pixels that the contributor approved in review.
enum DisposableCameraFilter {
    private struct Profile {
        let saturation: Float
        let contrast: Float
        let exposure: Float
        let tint: CIColor
        let tintOpacity: CGFloat
    }

    private static let context = CIContext(options: [
        .cacheIntermediates: false,
        .workingColorSpace: NSNull()
    ])

    static func developJPEG(
        _ data: Data,
        look: FilmLookID,
        maximumDimension: CGFloat = 2_400,
        compressionQuality: CGFloat = 0.88
    ) -> Data? {
        guard let source = UIImage(data: data),
              let normalized = normalizedCGImage(source, maximumDimension: maximumDimension) else { return nil }

        let extent = CGRect(x: 0, y: 0, width: normalized.width, height: normalized.height)
        let profile = profile(for: look)
        var image = CIImage(cgImage: normalized)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: profile.saturation,
                kCIInputContrastKey: profile.contrast,
                kCIInputBrightnessKey: 0.012
            ])
            .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: profile.exposure])
            .applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputShadowAmount": 0.24,
                "inputHighlightAmount": 0.82
            ])

        let tintColor = CIColor(
            red: profile.tint.red,
            green: profile.tint.green,
            blue: profile.tint.blue,
            alpha: profile.tintOpacity
        )
        let tint = CIImage(color: tintColor).cropped(to: extent)
        image = tint.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image])

        // A small highlight bloom mimics inexpensive plastic optics and direct-flash halation.
        image = image.applyingFilter("CIBloom", parameters: [
            kCIInputRadiusKey: max(2, min(extent.width, extent.height) * 0.003),
            kCIInputIntensityKey: 0.16
        ])

        // Monochrome luminance noise gives every developed frame organic film grain.
        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage {
            let grain = noise
                .cropped(to: extent)
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputContrastKey: 1.28
                ])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.055)
                ])
            image = grain.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        }

        image = image
            .cropped(to: extent)
            .applyingFilter("CIVignette", parameters: [
                kCIInputIntensityKey: 0.72,
                kCIInputRadiusKey: 1.35
            ])
            .cropped(to: extent)

        guard let output = context.createCGImage(image, from: extent) else { return nil }
        return UIImage(cgImage: output, scale: 1, orientation: .up)
            .jpegData(compressionQuality: compressionQuality)
    }

    private static func normalizedCGImage(_ image: UIImage, maximumDimension: CGFloat) -> CGImage? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let factor = min(1, maximumDimension / max(sourceSize.width, sourceSize.height))
        let target = CGSize(
            width: max(1, (sourceSize.width * factor).rounded()),
            height: max(1, (sourceSize.height * factor).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }.cgImage
    }

    private static func profile(for look: FilmLookID) -> Profile {
        switch look {
        case .sunwashed:
            Profile(
                saturation: 0.9,
                contrast: 1.08,
                exposure: 0.12,
                tint: CIColor(red: 1, green: 0.72, blue: 0.28),
                tintOpacity: 0.12
            )
        case .garden:
            Profile(
                saturation: 0.84,
                contrast: 1.06,
                exposure: 0.07,
                tint: CIColor(red: 0.42, green: 0.67, blue: 0.35),
                tintOpacity: 0.1
            )
        case .afterglow:
            Profile(
                saturation: 0.9,
                contrast: 1.05,
                exposure: 0.09,
                tint: CIColor(red: 1, green: 0.4, blue: 0.42),
                tintOpacity: 0.1
            )
        }
    }
}
