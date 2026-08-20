import CoreGraphics
import CoreImage
import Foundation
import UIKit

struct RecapRenderRequest: Sendable {
    let meta: RecapMeta
    let timeline: RecapTimeline
    let options: RecapDetailsOptions
    let music: RecapMusicTrack?
}

final class RecapFrameRenderer: @unchecked Sendable {
    static let version = 2

    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let imageCache = NSCache<NSURL, UIImage>()

    func makeImage(request: RecapRenderRequest, time: TimeInterval, size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: Int(size.width) * 4, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        render(request: request, time: time, in: context, size: size)
        return context.makeImage()
    }

    func render(request: RecapRenderRequest, time: TimeInterval, in context: CGContext, size: CGSize) {
        let frame = request.timeline.frame(at: time)
        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(background(for: request.timeline.preset.grade).cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        switch request.timeline.preset.visualStyle {
        case .standard:
            switch frame.phase {
            case .intro: drawIntro(request, frame: frame, context: context, size: size)
            case .memory: drawMemory(request, frame: frame, context: context, size: size)
            case .finalReveal: drawMosaic(request, progress: frame.tileProgress, context: context, size: size, hero: true)
            case .impactReceipt: drawImpact(request, context: context, size: size)
            case .outro: drawOutro(request, context: context, size: size)
            }
        case .porcelainPrint:
            drawPorcelainPrint(request, frame: frame, context: context, size: size)
        case .kilnTape:
            drawKilnTape(request, frame: frame, context: context, size: size)
        case .pocketKiln:
            drawPocketKiln(request, frame: frame, context: context, size: size)
        }

        context.setFillColor(UIColor.black.withAlphaComponent(CGFloat(1 - frame.opacity)).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.restoreGState()
    }

    // MARK: - Mosaic event templates

    private func drawPorcelainPrint(
        _ request: RecapRenderRequest,
        frame: RecapTimeline.FrameState,
        context: CGContext,
        size: CGSize
    ) {
        let ink = UIColor(red: 0.145, green: 0.133, blue: 0.122, alpha: 1)
        let porcelain = UIColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1)
        let paper = UIColor(red: 1, green: 0.994, blue: 0.975, alpha: 1)
        context.setFillColor(porcelain.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        drawSpeckles(in: CGRect(origin: .zero, size: size), color: UIColor(red: 0.72, green: 0.62, blue: 0.5, alpha: 0.13), context: context)

        let margin = size.width * 0.055
        let card = CGRect(x: margin, y: size.height * 0.025, width: size.width - margin * 2, height: size.height * 0.95)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: size.width * 0.018), blur: size.width * 0.035,
                          color: UIColor.black.withAlphaComponent(0.16).cgColor)
        context.setFillColor(paper.cgColor)
        context.addPath(UIBezierPath(roundedRect: card, cornerRadius: size.width * 0.022).cgPath)
        context.fillPath()
        context.restoreGState()

        let inset = size.width * 0.035
        let viewport = CGRect(x: card.minX + inset, y: card.minY + inset,
                              width: card.width - inset * 2, height: card.height * 0.79)
        drawTemplateScene(request, frame: frame, viewport: viewport, style: .porcelainPrint, context: context)

        let footerY = viewport.maxY + card.height * 0.035
        let memory = memoryPosition(request, frame: frame)
        let footer = frame.phase == .memory ? "MEMORY \(memory.current) OF \(memory.total)" : "A MOSAIC STORY"
        drawFittedText(footer, in: CGRect(x: card.minX + inset, y: footerY, width: card.width - inset * 2, height: size.height * 0.028),
                       maximumSize: size.width * 0.023, minimumSize: size.width * 0.014,
                       weight: .bold, color: ink.withAlphaComponent(0.62), context: context, alignment: .center, monospaced: true)
        drawFittedText(request.meta.groupName.uppercased(),
                       in: CGRect(x: card.minX + inset, y: footerY + size.height * 0.036,
                                  width: card.width - inset * 2, height: size.height * 0.035),
                       maximumSize: size.width * 0.026, minimumSize: size.width * 0.015,
                       weight: .semibold, color: ink, context: context, alignment: .center)
        drawMakerMark(at: CGPoint(x: card.midX, y: card.maxY - size.height * 0.035), color: UIColor(red: 0.35, green: 0.28, blue: 0.84, alpha: 1), context: context, size: size.width)
    }

    private func drawKilnTape(
        _ request: RecapRenderRequest,
        frame: RecapTimeline.FrameState,
        context: CGContext,
        size: CGSize
    ) {
        let shellColor = UIColor(red: 0.105, green: 0.105, blue: 0.11, alpha: 1)
        let firedPaper = UIColor(red: 0.135, green: 0.13, blue: 0.125, alpha: 1)
        let ivory = UIColor(red: 0.97, green: 0.945, blue: 0.9, alpha: 1)
        let persimmon = UIColor(red: 0.96, green: 0.36, blue: 0.19, alpha: 1)
        context.setFillColor(UIColor(red: 0.035, green: 0.035, blue: 0.04, alpha: 1).cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let shell = CGRect(x: size.width * 0.025, y: size.height * 0.018, width: size.width * 0.95, height: size.height * 0.964)
        context.setFillColor(shellColor.cgColor)
        context.addPath(UIBezierPath(roundedRect: shell, cornerRadius: size.width * 0.035).cgPath)
        context.fillPath()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(max(1, size.width * 0.003))
        context.addPath(UIBezierPath(roundedRect: shell, cornerRadius: size.width * 0.035).cgPath)
        context.strokePath()

        let memory = memoryPosition(request, frame: frame)
        drawFittedText(frame.phase == .memory ? "PLAY // \(String(format: "%02d", memory.current))" : "PLAY // MOSAIC",
                       in: CGRect(x: shell.minX + size.width * 0.045, y: shell.minY + size.height * 0.025,
                                  width: shell.width * 0.42, height: size.height * 0.028),
                       maximumSize: size.width * 0.022, minimumSize: size.width * 0.014, weight: .bold,
                       color: ivory.withAlphaComponent(0.8), context: context, monospaced: true)
        drawFittedText(shortEventDate(request.meta),
                       in: CGRect(x: shell.midX, y: shell.minY + size.height * 0.025,
                                  width: shell.width * 0.45, height: size.height * 0.028),
                       maximumSize: size.width * 0.02, minimumSize: size.width * 0.012, weight: .bold,
                       color: UIColor(red: 0.9, green: 0.45, blue: 0.52, alpha: 1), context: context,
                       alignment: .right, monospaced: true)

        let screen = CGRect(x: shell.minX + size.width * 0.045, y: shell.minY + size.height * 0.075,
                            width: shell.width - size.width * 0.09, height: shell.height * 0.79)
        context.setFillColor(UIColor.black.cgColor)
        context.addPath(UIBezierPath(roundedRect: screen, cornerRadius: size.width * 0.018).cgPath)
        context.fillPath()
        context.setStrokeColor(UIColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1).cgColor)
        context.setLineWidth(size.width * 0.012)
        context.addPath(UIBezierPath(roundedRect: screen, cornerRadius: size.width * 0.018).cgPath)
        context.strokePath()
        drawTemplateScene(request, frame: frame, viewport: screen.insetBy(dx: size.width * 0.012, dy: size.width * 0.012),
                          style: .kilnTape, context: context)

        let footerY = screen.maxY + size.height * 0.026
        drawTapeTriangle(in: CGRect(x: shell.minX + size.width * 0.045, y: footerY, width: size.width * 0.035, height: size.width * 0.035),
                         color: persimmon, context: context)
        drawFittedText("KILN TAPE  //  MOSAIC", in: CGRect(x: shell.minX + size.width * 0.09, y: footerY,
                                                           width: shell.width * 0.55, height: size.width * 0.04),
                       maximumSize: size.width * 0.02, minimumSize: size.width * 0.012, weight: .bold,
                       color: ivory.withAlphaComponent(0.72), context: context, monospaced: true)
        drawProgressDots(progress: frame.tileProgress,
                         in: CGRect(x: shell.maxX - size.width * 0.19, y: footerY + size.width * 0.004,
                                    width: size.width * 0.14, height: size.width * 0.028),
                         active: persimmon, inactive: firedPaper, context: context)
    }

    private func drawPocketKiln(
        _ request: RecapRenderRequest,
        frame: RecapTimeline.FrameState,
        context: CGContext,
        size: CGSize
    ) {
        let porcelain = UIColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1)
        let bodyColor = UIColor(red: 0.155, green: 0.165, blue: 0.16, alpha: 1)
        let clayControl = UIColor(red: 0.38, green: 0.38, blue: 0.355, alpha: 1)
        let ivory = UIColor(red: 0.97, green: 0.945, blue: 0.9, alpha: 1)
        let persimmon = UIColor(red: 0.96, green: 0.32, blue: 0.18, alpha: 1)
        context.setFillColor(porcelain.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        drawSpeckles(in: CGRect(origin: .zero, size: size), color: UIColor(red: 0.45, green: 0.38, blue: 0.31, alpha: 0.1), context: context)

        let body = CGRect(x: size.width * 0.055, y: size.height * 0.025, width: size.width * 0.89, height: size.height * 0.95)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: size.width * 0.02), blur: size.width * 0.04,
                          color: UIColor.black.withAlphaComponent(0.2).cgColor)
        context.setFillColor(bodyColor.cgColor)
        context.addPath(UIBezierPath(roundedRect: body, cornerRadius: size.width * 0.07).cgPath)
        context.fillPath()
        context.restoreGState()

        let screen = CGRect(x: body.minX + size.width * 0.055, y: body.minY + size.height * 0.065,
                            width: body.width - size.width * 0.11, height: body.height * 0.7)
        context.setFillColor(UIColor.black.cgColor)
        context.addPath(UIBezierPath(roundedRect: screen, cornerRadius: size.width * 0.025).cgPath)
        context.fillPath()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(size.width * 0.006)
        context.addPath(UIBezierPath(roundedRect: screen, cornerRadius: size.width * 0.025).cgPath)
        context.strokePath()
        drawTemplateScene(request, frame: frame, viewport: screen.insetBy(dx: size.width * 0.012, dy: size.width * 0.012),
                          style: .pocketKiln, context: context)

        let blinkOn = request.timeline.reduceMotion || Int(frame.time * 4).isMultiple(of: 2)
        if blinkOn {
            context.setFillColor(persimmon.cgColor)
            context.fillEllipse(in: CGRect(x: screen.minX + size.width * 0.025, y: screen.minY + size.height * 0.018,
                                           width: size.width * 0.017, height: size.width * 0.017))
        }
        drawFittedText("REC", in: CGRect(x: screen.minX + size.width * 0.05, y: screen.minY + size.height * 0.014,
                                         width: size.width * 0.12, height: size.height * 0.025),
                       maximumSize: size.width * 0.02, minimumSize: size.width * 0.013, weight: .bold,
                       color: ivory.withAlphaComponent(0.88), context: context, monospaced: true)
        drawFittedText(shortEventDate(request.meta),
                       in: CGRect(x: screen.midX, y: screen.minY + size.height * 0.014,
                                  width: screen.width * 0.46, height: size.height * 0.025),
                       maximumSize: size.width * 0.018, minimumSize: size.width * 0.011, weight: .bold,
                       color: ivory.withAlphaComponent(0.72), context: context, alignment: .right, monospaced: true)
        if frame.phase == .memory || frame.phase == .finalReveal {
            drawViewfinder(in: screen.insetBy(dx: screen.width * 0.25, dy: screen.height * 0.25), color: ivory.withAlphaComponent(0.68), context: context)
        }

        let controlsY = screen.maxY + size.height * 0.035
        for index in 0..<2 {
            let diameter = size.width * 0.075
            context.setFillColor(clayControl.cgColor)
            context.fillEllipse(in: CGRect(x: body.minX + size.width * (0.07 + CGFloat(index) * 0.1), y: controlsY,
                                           width: diameter, height: diameter))
        }
        let shutter = CGRect(x: body.maxX - size.width * 0.23, y: controlsY - size.width * 0.02,
                             width: size.width * 0.16, height: size.width * 0.16)
        context.setFillColor(clayControl.cgColor)
        context.fillEllipse(in: shutter)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(size.width * 0.006)
        context.strokeEllipse(in: shutter.insetBy(dx: size.width * 0.018, dy: size.width * 0.018))
        drawMakerMark(at: CGPoint(x: shutter.midX, y: shutter.midY), color: ivory.withAlphaComponent(0.56), context: context, size: size.width * 0.8)

        let memory = memoryPosition(request, frame: frame)
        let footer = frame.phase == .memory ? "MEMORY \(memory.current)/\(memory.total)" : "POCKET KILN // MOSAIC"
        drawFittedText(footer, in: CGRect(x: body.minX + size.width * 0.07, y: body.maxY - size.height * 0.075,
                                         width: body.width * 0.62, height: size.height * 0.035),
                       maximumSize: size.width * 0.021, minimumSize: size.width * 0.012, weight: .bold,
                       color: ivory.withAlphaComponent(0.68), context: context, monospaced: true)
    }

    private func drawTemplateScene(
        _ request: RecapRenderRequest,
        frame: RecapTimeline.FrameState,
        viewport: CGRect,
        style: RecapPreset.VisualStyle,
        context: CGContext
    ) {
        context.saveGState()
        context.addPath(UIBezierPath(roundedRect: viewport, cornerRadius: viewport.width * 0.018).cgPath)
        context.clip()
        context.setFillColor(templateBackground(style).cgColor)
        context.fill(viewport)

        let alpha = CGFloat(frame.transitionProgress)
        if frame.phase == .memory,
           request.timeline.preset.transition == .warmDissolve || request.timeline.reduceMotion,
           let previous = frame.previousSourceIndex,
           request.timeline.sources.indices.contains(previous),
           frame.transitionProgress < 1 {
            context.saveGState()
            context.setAlpha(1 - alpha)
            drawTemplateMemory(request.timeline.sources[previous], request: request, frame: frame,
                               viewport: viewport, style: style, context: context)
            context.restoreGState()
        }

        context.saveGState()
        if frame.segmentIndex > 0, frame.transitionProgress < 1,
           request.timeline.preset.transition != .hardSnap {
            context.setAlpha(alpha)
        }
        switch frame.phase {
        case .intro:
            drawTemplateIntro(request, frame: frame, viewport: viewport, style: style, context: context)
        case .memory:
            guard let index = frame.sourceIndex, request.timeline.sources.indices.contains(index) else {
                drawEmptyMemory(viewport: viewport, style: style, context: context)
                break
            }
            drawTemplateMemory(request.timeline.sources[index], request: request, frame: frame,
                               viewport: viewport, style: style, context: context)
        case .finalReveal:
            drawTemplateReveal(request, frame: frame, viewport: viewport, style: style, context: context)
        case .impactReceipt:
            drawTemplateImpact(request, viewport: viewport, style: style, context: context)
        case .outro:
            drawTemplateOutro(request, viewport: viewport, style: style, context: context)
        }
        context.restoreGState()

        if request.timeline.preset.transition == .recordBlink,
           !request.timeline.reduceMotion,
           frame.transitionProgress < 1 {
            context.setFillColor(UIColor.black.withAlphaComponent(CGFloat((1 - frame.transitionProgress) * 0.72)).cgColor)
            context.fill(viewport)
        }
        context.restoreGState()
    }

    private func drawTemplateIntro(
        _ request: RecapRenderRequest,
        frame: RecapTimeline.FrameState,
        viewport: CGRect,
        style: RecapPreset.VisualStyle,
        context: CGContext
    ) {
        if let asset = firstPhotoAsset(in: request.timeline.sources), let image = normalizedImage(for: asset) {
            drawAspectFill(image, in: viewport, context: context)
        }
        let darkStyle = style == .kilnTape || style == .pocketKiln
        context.setFillColor((darkStyle ? UIColor.black.withAlphaComponent(0.64) : UIColor(red: 0.12, green: 0.1, blue: 0.08, alpha: 0.48)).cgColor)
        context.fill(viewport)

        let ivory = UIColor(red: 0.98, green: 0.95, blue: 0.9, alpha: 1)
        let accent: UIColor = switch style {
        case .porcelainPrint, .kilnTape: UIColor(red: 0.95, green: 0.36, blue: 0.18, alpha: 1)
        case .pocketKiln: UIColor(red: 0.35, green: 0.28, blue: 0.84, alpha: 1)
        case .standard: UIColor(red: 0.49, green: 0.72, blue: 0.8, alpha: 1)
        }
        drawFittedText(eventYear(request.meta),
                       in: CGRect(x: viewport.minX + viewport.width * 0.08, y: viewport.minY + viewport.height * 0.17,
                                  width: viewport.width * 0.84, height: viewport.height * 0.19),
                       maximumSize: viewport.width * 0.22, minimumSize: viewport.width * 0.12,
                       weight: .regular, color: ivory, context: context, alignment: .center, display: true)
        drawFittedText(request.meta.challengeName,
                       in: CGRect(x: viewport.minX + viewport.width * 0.1, y: viewport.minY + viewport.height * 0.37,
                                  width: viewport.width * 0.8, height: viewport.height * 0.19),
                       maximumSize: viewport.width * 0.09, minimumSize: viewport.width * 0.045,
                       weight: .semibold, color: ivory, context: context, alignment: .center, display: true)
        context.setFillColor(accent.cgColor)
        context.fill(CGRect(x: viewport.midX - viewport.width * 0.06, y: viewport.minY + viewport.height * 0.59,
                            width: viewport.width * 0.12, height: max(2, viewport.width * 0.006)))
        drawFittedText(request.meta.groupName.uppercased() + "  •  " + dateRange(request.meta),
                       in: CGRect(x: viewport.minX + viewport.width * 0.09, y: viewport.minY + viewport.height * 0.64,
                                  width: viewport.width * 0.82, height: viewport.height * 0.09),
                       maximumSize: viewport.width * 0.035, minimumSize: viewport.width * 0.021,
                       weight: .bold, color: ivory.withAlphaComponent(0.82), context: context,
                       alignment: .center, monospaced: style != .porcelainPrint)
    }

    private func drawTemplateMemory(
        _ source: RecapSource,
        request: RecapRenderRequest,
        frame: RecapTimeline.FrameState,
        viewport: CGRect,
        style: RecapPreset.VisualStyle,
        context: CGContext
    ) {
        switch source.content {
        case let .photo(asset, note):
            if let image = normalizedImage(for: asset) {
                let moved = viewport.insetBy(dx: -viewport.width * (frame.scale - 1) / 2,
                                             dy: -viewport.height * (frame.scale - 1) / 2)
                    .offsetBy(dx: frame.panX * viewport.width, dy: 0)
                drawAspectFill(image, in: moved, context: context)
                drawGradeOverlay(request.timeline.preset.grade, in: viewport, context: context)
            } else {
                drawEmptyMemory(viewport: viewport, style: style, context: context)
            }
            if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let caption = CGRect(x: viewport.minX + viewport.width * 0.055,
                                     y: viewport.maxY - viewport.height * 0.2,
                                     width: viewport.width * 0.89, height: viewport.height * 0.14)
                context.setFillColor(templateCaptionBackground(style).cgColor)
                context.addPath(UIBezierPath(roundedRect: caption, cornerRadius: viewport.width * 0.025).cgPath)
                context.fillPath()
                drawFittedText(note, in: caption.insetBy(dx: caption.width * 0.055, dy: caption.height * 0.16),
                               maximumSize: viewport.width * 0.046, minimumSize: viewport.width * 0.024,
                               weight: .semibold, color: templateInk(style), context: context, display: true)
            }
        case let .reflection(text):
            context.setFillColor(templateBackground(style).cgColor)
            context.fill(viewport)
            drawFittedText("“\(text)”",
                           in: CGRect(x: viewport.minX + viewport.width * 0.1, y: viewport.minY + viewport.height * 0.2,
                                      width: viewport.width * 0.8, height: viewport.height * 0.52),
                           maximumSize: viewport.width * 0.073, minimumSize: viewport.width * 0.034,
                           weight: .semibold, color: templateInk(style), context: context, alignment: .center, display: true)
        case .tileOnly:
            drawCompactMosaic(request, progress: frame.tileProgress, in: viewport.insetBy(dx: viewport.width * 0.12,
                                                                                         dy: viewport.height * 0.18), context: context)
        }

        if request.options.showMissionLabels, let category = source.category {
            drawMetadataPill(category.rawValue.uppercased(),
                             in: CGRect(x: viewport.minX + viewport.width * 0.045, y: viewport.minY + viewport.height * 0.055,
                                        width: viewport.width * 0.38, height: viewport.height * 0.055),
                             style: style, context: context)
        }
        if request.options.showAttribution, source.attributionAllowed, let name = source.participantDisplayName {
            drawFittedText("— \(name)",
                           in: CGRect(x: viewport.minX + viewport.width * 0.06, y: viewport.maxY - viewport.height * 0.055,
                                      width: viewport.width * 0.88, height: viewport.height * 0.035),
                           maximumSize: viewport.width * 0.026, minimumSize: viewport.width * 0.016,
                           weight: .semibold, color: templateOverlayInk(style), context: context, alignment: .right)
        }
    }

    private func drawTemplateReveal(
        _ request: RecapRenderRequest,
        frame: RecapTimeline.FrameState,
        viewport: CGRect,
        style: RecapPreset.VisualStyle,
        context: CGContext
    ) {
        context.setFillColor(templateBackground(style).cgColor)
        context.fill(viewport)
        drawFittedText("Together, we made this",
                       in: CGRect(x: viewport.minX + viewport.width * 0.08, y: viewport.minY + viewport.height * 0.055,
                                  width: viewport.width * 0.84, height: viewport.height * 0.13),
                       maximumSize: viewport.width * 0.075, minimumSize: viewport.width * 0.04,
                       weight: .semibold, color: templateInk(style), context: context, alignment: .center, display: true)
        drawCompactMosaic(request, progress: frame.tileProgress,
                          in: CGRect(x: viewport.minX + viewport.width * 0.1, y: viewport.minY + viewport.height * 0.22,
                                     width: viewport.width * 0.8, height: viewport.height * 0.61), context: context)
        drawFittedText("\(request.meta.impact.acceptedActions) ACTIONS  •  \(request.meta.impact.participantCount) PEOPLE",
                       in: CGRect(x: viewport.minX + viewport.width * 0.08, y: viewport.maxY - viewport.height * 0.105,
                                  width: viewport.width * 0.84, height: viewport.height * 0.05),
                       maximumSize: viewport.width * 0.028, minimumSize: viewport.width * 0.017,
                       weight: .bold, color: templateInk(style).withAlphaComponent(0.72), context: context,
                       alignment: .center, monospaced: true)
    }

    private func drawTemplateImpact(
        _ request: RecapRenderRequest,
        viewport: CGRect,
        style: RecapPreset.VisualStyle,
        context: CGContext
    ) {
        let darkStyle = style == .kilnTape || style == .pocketKiln
        let card = viewport.insetBy(dx: viewport.width * 0.075, dy: viewport.height * 0.075)
        context.setFillColor((darkStyle ? UIColor(red: 0.12, green: 0.115, blue: 0.105, alpha: 1)
                                         : UIColor(red: 1, green: 0.994, blue: 0.975, alpha: 1)).cgColor)
        context.addPath(UIBezierPath(roundedRect: card, cornerRadius: viewport.width * 0.035).cgPath)
        context.fillPath()
        context.setStrokeColor(templateInk(style).withAlphaComponent(0.2).cgColor)
        context.setLineWidth(max(1, viewport.width * 0.003))
        context.addPath(UIBezierPath(roundedRect: card, cornerRadius: viewport.width * 0.035).cgPath)
        context.strokePath()
        drawFittedText("Impact Receipt",
                       in: CGRect(x: card.minX + card.width * 0.08, y: card.minY + card.height * 0.065,
                                  width: card.width * 0.84, height: card.height * 0.13),
                       maximumSize: card.width * 0.095, minimumSize: card.width * 0.05,
                       weight: .semibold, color: templateInk(style), context: context, alignment: .center, display: true)
        let rows: [(String, String)] = [
            ("Accepted actions", "\(request.meta.impact.acceptedActions)"),
            ("Participants", "\(request.meta.impact.participantCount)"),
            ("Pass-the-Tile joins", "\(request.meta.impact.passTheTileJoins)")
        ] + request.meta.impact.organizerUnits.map { ($0.label, $0.value) }
        let visibleRows = Array(rows.prefix(5))
        let rowHeight = card.height * 0.105
        var y = card.minY + card.height * 0.27
        for row in visibleRows {
            drawFittedText(row.0, in: CGRect(x: card.minX + card.width * 0.08, y: y,
                                             width: card.width * 0.61, height: rowHeight * 0.7),
                           maximumSize: card.width * 0.045, minimumSize: card.width * 0.027,
                           weight: .medium, color: templateInk(style).withAlphaComponent(0.8), context: context)
            drawFittedText(row.1, in: CGRect(x: card.minX + card.width * 0.7, y: y,
                                             width: card.width * 0.22, height: rowHeight * 0.7),
                           maximumSize: card.width * 0.055, minimumSize: card.width * 0.03,
                           weight: .bold, color: templateInk(style), context: context, alignment: .right)
            context.setFillColor(templateInk(style).withAlphaComponent(0.12).cgColor)
            context.fill(CGRect(x: card.minX + card.width * 0.08, y: y + rowHeight * 0.78,
                                width: card.width * 0.84, height: max(1, card.width * 0.002)))
            y += rowHeight
        }
        drawFittedText("Verified in Mosaic",
                       in: CGRect(x: card.minX + card.width * 0.1, y: card.maxY - card.height * 0.1,
                                  width: card.width * 0.8, height: card.height * 0.045),
                       maximumSize: card.width * 0.03, minimumSize: card.width * 0.02,
                       weight: .bold, color: templateInk(style).withAlphaComponent(0.58), context: context,
                       alignment: .center, monospaced: true)
    }

    private func drawTemplateOutro(
        _ request: RecapRenderRequest,
        viewport: CGRect,
        style: RecapPreset.VisualStyle,
        context: CGContext
    ) {
        context.setFillColor(templateBackground(style).cgColor)
        context.fill(viewport)
        drawCompactMosaic(request, progress: 1,
                          in: CGRect(x: viewport.minX + viewport.width * 0.33, y: viewport.minY + viewport.height * 0.1,
                                     width: viewport.width * 0.34, height: viewport.height * 0.25), context: context)
        drawFittedText("Every action had a place",
                       in: CGRect(x: viewport.minX + viewport.width * 0.09, y: viewport.minY + viewport.height * 0.42,
                                  width: viewport.width * 0.82, height: viewport.height * 0.18),
                       maximumSize: viewport.width * 0.08, minimumSize: viewport.width * 0.04,
                       weight: .semibold, color: templateInk(style), context: context, alignment: .center, display: true)
        drawFittedText(request.meta.challengeName + "\nMOSAIC  •  MAKE KINDNESS VISIBLE",
                       in: CGRect(x: viewport.minX + viewport.width * 0.1, y: viewport.minY + viewport.height * 0.64,
                                  width: viewport.width * 0.8, height: viewport.height * 0.12),
                       maximumSize: viewport.width * 0.035, minimumSize: viewport.width * 0.021,
                       weight: .bold, color: templateInk(style).withAlphaComponent(0.78), context: context,
                       alignment: .center)
        if let attribution = request.music?.attribution?.components(separatedBy: "\n").first {
            drawFittedText("Music: \(attribution)",
                           in: CGRect(x: viewport.minX + viewport.width * 0.08, y: viewport.maxY - viewport.height * 0.09,
                                      width: viewport.width * 0.84, height: viewport.height * 0.04),
                           maximumSize: viewport.width * 0.022, minimumSize: viewport.width * 0.014,
                           weight: .medium, color: templateInk(style).withAlphaComponent(0.58), context: context,
                           alignment: .center)
        }
    }

    private func drawCompactMosaic(
        _ request: RecapRenderRequest,
        progress: Double,
        in rect: CGRect,
        context: CGContext
    ) {
        let count = max(max(request.meta.goal, request.timeline.sources.count), 1)
        let columns = 5
        let rows = min(Int(ceil(Double(count) / Double(columns))), 5)
        let spacing = max(2, min(rect.width, rect.height) * 0.018)
        let tile = max(3, min((rect.width - CGFloat(columns - 1) * spacing) / CGFloat(columns),
                              (rect.height - CGFloat(max(rows - 1, 0)) * spacing) / CGFloat(max(rows, 1))))
        let width = CGFloat(columns) * tile + CGFloat(columns - 1) * spacing
        let height = CGFloat(rows) * tile + CGFloat(max(rows - 1, 0)) * spacing
        let origin = CGPoint(x: rect.midX - width / 2, y: rect.midY - height / 2)
        let capacity = min(count, columns * rows)
        let visible = Int(ceil(Double(capacity) * min(max(progress, 0), 1)))

        for index in 0..<capacity {
            let tileRect = CGRect(x: origin.x + CGFloat(index % columns) * (tile + spacing),
                                  y: origin.y + CGFloat(index / columns) * (tile + spacing),
                                  width: tile, height: tile)
            let source = request.timeline.sources.first { $0.tile?.finalPosition == index }
            let fill = index < visible
                ? tileColor(source?.tile?.emotion)
                : UIColor(red: 0.55, green: 0.5, blue: 0.43, alpha: 0.22)
            context.setFillColor(fill.cgColor)
            context.addPath(UIBezierPath(roundedRect: tileRect, cornerRadius: tile * 0.19).cgPath)
            context.fillPath()
            context.setStrokeColor(UIColor.white.withAlphaComponent(index < visible ? 0.38 : 0.1).cgColor)
            context.setLineWidth(max(1, tile * 0.018))
            context.addPath(UIBezierPath(roundedRect: tileRect, cornerRadius: tile * 0.19).cgPath)
            context.strokePath()

            if index < visible, source?.tile?.isRevived == true {
                context.setStrokeColor(UIColor(red: 0.84, green: 0.66, blue: 0.22, alpha: 1).cgColor)
                context.setLineWidth(max(1.5, tile * 0.045))
                context.move(to: CGPoint(x: tileRect.minX + tile * 0.12, y: tileRect.maxY - tile * 0.18))
                context.addLine(to: CGPoint(x: tileRect.midX, y: tileRect.midY))
                context.addLine(to: CGPoint(x: tileRect.maxX - tile * 0.12, y: tileRect.minY + tile * 0.16))
                context.strokePath()
            }
        }
    }

    private func drawEmptyMemory(
        viewport: CGRect,
        style: RecapPreset.VisualStyle,
        context: CGContext
    ) {
        context.setFillColor(templateBackground(style).cgColor)
        context.fill(viewport)
        let tileArea = CGRect(x: viewport.midX - viewport.width * 0.19, y: viewport.midY - viewport.width * 0.2,
                              width: viewport.width * 0.38, height: viewport.width * 0.38)
        let colors = [
            UIColor(red: 0.49, green: 0.72, blue: 0.8, alpha: 1),
            UIColor(red: 0.49, green: 0.6, blue: 0.51, alpha: 1),
            UIColor(red: 0.89, green: 0.65, blue: 0.71, alpha: 1),
            UIColor(red: 0.96, green: 0.43, blue: 0.24, alpha: 1)
        ]
        let spacing = tileArea.width * 0.045
        let side = (tileArea.width - spacing * 2) / 3
        for index in 0..<9 {
            let rect = CGRect(x: tileArea.minX + CGFloat(index % 3) * (side + spacing),
                              y: tileArea.minY + CGFloat(index / 3) * (side + spacing), width: side, height: side)
            context.setFillColor(colors[index % colors.count].withAlphaComponent(0.72).cgColor)
            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: side * 0.2).cgPath)
            context.fillPath()
        }
        drawFittedText("A shared memory",
                       in: CGRect(x: viewport.minX + viewport.width * 0.14, y: tileArea.maxY + viewport.height * 0.06,
                                  width: viewport.width * 0.72, height: viewport.height * 0.08),
                       maximumSize: viewport.width * 0.05, minimumSize: viewport.width * 0.028,
                       weight: .semibold, color: templateInk(style), context: context, alignment: .center, display: true)
    }

    private func drawMetadataPill(
        _ text: String,
        in rect: CGRect,
        style: RecapPreset.VisualStyle,
        context: CGContext
    ) {
        let dark = style == .kilnTape || style == .pocketKiln
        context.setFillColor((dark ? UIColor.black.withAlphaComponent(0.64) : UIColor.white.withAlphaComponent(0.84)).cgColor)
        context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).cgPath)
        context.fillPath()
        drawFittedText(text, in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.18),
                       maximumSize: rect.height * 0.42, minimumSize: rect.height * 0.28,
                       weight: .bold, color: dark ? UIColor.white.withAlphaComponent(0.88) : UIColor(red: 0.15, green: 0.13, blue: 0.12, alpha: 1),
                       context: context, alignment: .center, monospaced: true)
    }

    private func drawFittedText(
        _ text: String,
        in rect: CGRect,
        maximumSize: CGFloat,
        minimumSize: CGFloat,
        weight: UIFont.Weight,
        color: UIColor,
        context: CGContext,
        alignment: NSTextAlignment = .left,
        monospaced: Bool = false,
        display: Bool = false
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        var size = maximumSize
        var font = fittedFont(size: size, weight: weight, monospaced: monospaced, display: display)
        while size > minimumSize {
            let bounds = (text as NSString).boundingRect(
                with: rect.size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph],
                context: nil
            )
            if bounds.width <= rect.width + 0.5, bounds.height <= rect.height + 0.5 { break }
            size = max(minimumSize, size - max(0.75, maximumSize * 0.035))
            font = fittedFont(size: size, weight: weight, monospaced: monospaced, display: display)
        }
        drawText(text, in: rect, font: font, color: color, context: context, alignment: alignment)
    }

    private func fittedFont(size: CGFloat, weight: UIFont.Weight, monospaced: Bool, display: Bool) -> UIFont {
        if monospaced { return .monospacedSystemFont(ofSize: size, weight: weight) }
        if display { return displayFont(size, weight: weight) }
        return .systemFont(ofSize: size, weight: weight)
    }

    private func drawSpeckles(in rect: CGRect, color: UIColor, context: CGContext) {
        context.setFillColor(color.cgColor)
        for index in 0..<72 {
            let x = rect.minX + CGFloat((index * 47) % 101) / 101 * rect.width
            let y = rect.minY + CGFloat((index * 71) % 103) / 103 * rect.height
            let diameter = max(0.7, rect.width * (index.isMultiple(of: 5) ? 0.0024 : 0.0015))
            context.fillEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
        }
    }

    private func drawMakerMark(at center: CGPoint, color: UIColor, context: CGContext, size: CGFloat) {
        let radius = max(3, size * 0.012)
        context.setFillColor(color.cgColor)
        context.move(to: CGPoint(x: center.x, y: center.y - radius))
        context.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        context.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        context.addLine(to: CGPoint(x: center.x - radius, y: center.y))
        context.closePath()
        context.fillPath()
    }

    private func drawTapeTriangle(in rect: CGRect, color: UIColor, context: CGContext) {
        context.setFillColor(color.cgColor)
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        context.closePath()
        context.fillPath()
    }

    private func drawProgressDots(
        progress: Double,
        in rect: CGRect,
        active: UIColor,
        inactive: UIColor,
        context: CGContext
    ) {
        let count = 4
        let diameter = min(rect.height, rect.width / CGFloat(count * 2))
        let gap = (rect.width - diameter * CGFloat(count)) / CGFloat(max(count - 1, 1))
        let activeCount = max(1, Int(ceil(progress * Double(count))))
        for index in 0..<count {
            context.setFillColor((index < activeCount ? active : inactive.withAlphaComponent(0.8)).cgColor)
            context.fillEllipse(in: CGRect(x: rect.minX + CGFloat(index) * (diameter + gap), y: rect.midY - diameter / 2,
                                           width: diameter, height: diameter))
        }
    }

    private func drawViewfinder(in rect: CGRect, color: UIColor, context: CGContext) {
        let arm = min(rect.width, rect.height) * 0.18
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(max(1.5, rect.width * 0.012))
        let corners = [
            (CGPoint(x: rect.minX, y: rect.minY + arm), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + arm, y: rect.minY)),
            (CGPoint(x: rect.maxX - arm, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + arm)),
            (CGPoint(x: rect.minX, y: rect.maxY - arm), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX + arm, y: rect.maxY)),
            (CGPoint(x: rect.maxX - arm, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY - arm))
        ]
        for corner in corners {
            context.move(to: corner.0)
            context.addLine(to: corner.1)
            context.addLine(to: corner.2)
            context.strokePath()
        }
    }

    private func memoryPosition(_ request: RecapRenderRequest, frame: RecapTimeline.FrameState) -> (current: Int, total: Int) {
        let memories = request.timeline.segments.filter { $0.phase == .memory }
        let current = memories.firstIndex { $0.id == request.timeline.segments[frame.segmentIndex].id }.map { $0 + 1 } ?? 0
        return (current, max(memories.count, 1))
    }

    private func firstPhotoAsset(in sources: [RecapSource]) -> RecapMediaAsset? {
        sources.lazy.compactMap { source in
            if case let .photo(asset, _) = source.content { return asset }
            return nil
        }.first
    }

    private func normalizedImage(for asset: RecapMediaAsset) -> CGImage? {
        guard let url = asset.localURL else { return nil }
        let key = url as NSURL
        if let cached = imageCache.object(forKey: key) { return cached.cgImage }
        guard let source = UIImage(contentsOfFile: url.path) else { return nil }
        let normalized: UIImage
        if source.imageOrientation == .up {
            normalized = source
        } else {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            normalized = UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
                source.draw(in: CGRect(origin: .zero, size: source.size))
            }
        }
        imageCache.setObject(normalized, forKey: key)
        return normalized.cgImage
    }

    private func eventYear(_ meta: RecapMeta) -> String {
        let formatter = dateFormatter(meta, format: "yyyy")
        return formatter.string(from: meta.endDate)
    }

    private func shortEventDate(_ meta: RecapMeta) -> String {
        dateFormatter(meta, format: "MMM d, yyyy").string(from: meta.endDate).uppercased()
    }

    private func dateRange(_ meta: RecapMeta) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let sameDay = calendar.isDate(meta.startDate, inSameDayAs: meta.endDate)
        if sameDay { return dateFormatter(meta, format: "MMM d, yyyy").string(from: meta.endDate) }
        let start = dateFormatter(meta, format: "MMM d").string(from: meta.startDate)
        let end = dateFormatter(meta, format: "MMM d, yyyy").string(from: meta.endDate)
        return "\(start)–\(end)"
    }

    private func dateFormatter(_ meta: RecapMeta, format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: meta.localeIdentifier)
        formatter.timeZone = TimeZone(identifier: meta.timeZoneIdentifier)
        formatter.dateFormat = format
        return formatter
    }

    private func templateBackground(_ style: RecapPreset.VisualStyle) -> UIColor {
        switch style {
        case .porcelainPrint: UIColor(red: 0.91, green: 0.865, blue: 0.8, alpha: 1)
        case .kilnTape, .pocketKiln, .standard: UIColor(red: 0.055, green: 0.052, blue: 0.05, alpha: 1)
        }
    }

    private func templateInk(_ style: RecapPreset.VisualStyle) -> UIColor {
        switch style {
        case .porcelainPrint: UIColor(red: 0.15, green: 0.13, blue: 0.12, alpha: 1)
        case .kilnTape, .pocketKiln, .standard: UIColor(red: 0.97, green: 0.945, blue: 0.9, alpha: 1)
        }
    }

    private func templateOverlayInk(_ style: RecapPreset.VisualStyle) -> UIColor {
        style == .porcelainPrint
            ? UIColor(red: 0.15, green: 0.13, blue: 0.12, alpha: 0.82)
            : UIColor.white.withAlphaComponent(0.84)
    }

    private func templateCaptionBackground(_ style: RecapPreset.VisualStyle) -> UIColor {
        style == .porcelainPrint
            ? UIColor(red: 1, green: 0.994, blue: 0.975, alpha: 0.93)
            : UIColor.black.withAlphaComponent(0.7)
    }

    private func drawIntro(_ request: RecapRenderRequest, frame: RecapTimeline.FrameState, context: CGContext, size: CGSize) {
        drawText(request.meta.groupName.uppercased(), in: CGRect(x: 78, y: 155, width: size.width - 156, height: 60),
                 font: .systemFont(ofSize: 28, weight: .bold), color: ink(for: request.timeline.preset.grade), context: context)
        drawText(request.meta.challengeName, in: CGRect(x: 72, y: 235, width: size.width - 144, height: 240),
                 font: displayFont(78, weight: .semibold), color: ink(for: request.timeline.preset.grade), context: context)
        let details = "\(request.meta.impact.acceptedActions) accepted actions  ·  \(request.meta.impact.participantCount) participants\nGoal: \(request.meta.goal)"
        drawText(details, in: CGRect(x: 78, y: 490, width: size.width - 156, height: 130),
                 font: .systemFont(ofSize: 31, weight: .semibold), color: ink(for: request.timeline.preset.grade).withAlphaComponent(0.76), context: context)
        drawMosaic(request, progress: frame.tileProgress, context: context, size: size, hero: false)
    }

    private func drawMemory(_ request: RecapRenderRequest, frame: RecapTimeline.FrameState, context: CGContext, size: CGSize) {
        guard let index = frame.sourceIndex, request.timeline.sources.indices.contains(index) else { return }
        let source = request.timeline.sources[index]
        switch source.content {
        case let .photo(asset, note):
            let card = CGRect(x: 58, y: 160, width: size.width - 116, height: size.height * 0.64)
            context.saveGState()
            let translatedX = frame.panX * size.width
            context.translateBy(x: translatedX, y: 0)
            let scaled = card.insetBy(dx: -card.width * (frame.scale - 1) / 2, dy: -card.height * (frame.scale - 1) / 2)
            if let image = normalizedImage(for: asset) {
                context.saveGState()
                context.addPath(UIBezierPath(roundedRect: scaled, cornerRadius: 36).cgPath)
                context.clip()
                drawAspectFill(image, in: scaled, context: context)
                context.restoreGState()
                drawGradeOverlay(request.timeline.preset.grade, in: scaled, context: context)
            } else {
                context.setFillColor(UIColor.white.withAlphaComponent(0.16).cgColor)
                context.fill(scaled)
                drawText("MEMORY DEVELOPING", in: scaled.insetBy(dx: 50, dy: 80), font: .systemFont(ofSize: 34, weight: .bold), color: .white, context: context)
            }
            context.restoreGState()
            if let note {
                drawPaperCaption(note, source: source, request: request, context: context, size: size)
            }
        case let .reflection(text):
            drawText("“\(text)”", in: CGRect(x: 92, y: 330, width: size.width - 184, height: 650),
                     font: displayFont(58, weight: .semibold), color: ink(for: request.timeline.preset.grade), context: context)
        case .tileOnly:
            drawMosaic(request, progress: frame.tileProgress, context: context, size: size, hero: true)
        }
        drawChrome(request.timeline.preset, source: source, index: index, context: context, size: size)
        drawMosaicRail(request, frame: frame, context: context, size: size)
    }

    private func drawPaperCaption(_ note: String, source: RecapSource, request: RecapRenderRequest, context: CGContext, size: CGSize) {
        let rect = CGRect(x: 95, y: size.height - 440, width: size.width - 190, height: 250)
        context.setFillColor(UIColor(red: 1, green: 0.99, blue: 0.96, alpha: 0.96).cgColor)
        context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 28).cgPath)
        context.fillPath()
        drawText(note, in: rect.insetBy(dx: 34, dy: 30), font: displayFont(38, weight: .semibold), color: UIColor(red: 0.15, green: 0.13, blue: 0.12, alpha: 1), context: context)
        if request.options.showAttribution, source.attributionAllowed, let name = source.participantDisplayName {
            drawText("— \(name)", in: CGRect(x: rect.minX + 34, y: rect.maxY - 57, width: rect.width - 68, height: 32),
                     font: .systemFont(ofSize: 23, weight: .semibold), color: UIColor.darkGray, context: context)
        }
    }

    private func drawMosaic(_ request: RecapRenderRequest, progress: Double, context: CGContext, size: CGSize, hero: Bool) {
        let count = max(request.meta.goal, request.timeline.sources.count)
        let columns = 5
        let tile: CGFloat = hero ? 130 : 90
        let spacing: CGFloat = 12
        let rows = Int(ceil(Double(count) / Double(columns)))
        let width = CGFloat(columns) * tile + CGFloat(columns - 1) * spacing
        let cappedRows = min(rows, hero ? 7 : 5)
        let start = CGPoint(x: (size.width - width) / 2, y: hero ? 340 : 810)
        let artworkRect = CGRect(
            x: start.x - 28,
            y: start.y - 28,
            width: width + 56,
            height: CGFloat(cappedRows) * tile + CGFloat(max(0, cappedRows - 1)) * spacing + 56
        )
        drawThemeField(request.meta.theme, progress: progress, in: artworkRect, context: context)
        let visible = Int(ceil(Double(min(count, columns * cappedRows)) * progress))
        for index in 0..<min(count, columns * cappedRows) {
            let rect = CGRect(x: start.x + CGFloat(index % columns) * (tile + spacing),
                              y: start.y + CGFloat(index / columns) * (tile + spacing), width: tile, height: tile)
            let filled = index < visible
            let source = request.timeline.sources.first { $0.tile?.finalPosition == index }
            context.setFillColor((filled ? tileColor(source?.tile?.emotion) : UIColor(red: 0.72, green: 0.66, blue: 0.57, alpha: 0.28)).cgColor)
            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: tile * 0.19).cgPath)
            context.fillPath()
            context.setStrokeColor(UIColor.white.withAlphaComponent(filled ? 0.42 : 0.12).cgColor)
            context.setLineWidth(2)
            context.strokePath()
            if source?.tile?.isRevived == true {
                context.setStrokeColor(UIColor(red: 0.84, green: 0.66, blue: 0.22, alpha: 1).cgColor)
                context.setLineWidth(5)
                context.move(to: CGPoint(x: rect.minX + 10, y: rect.maxY - 18))
                context.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
                context.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.minY + 15))
                context.strokePath()
            }
        }
    }

    private func drawThemeField(_ selection: ThemeSelection, progress: Double, in rect: CGRect, context: CGContext) {
        let theme = selection.theme
        let colors = adjustedThemeColors(theme.signatureHex, palette: selection.paletteID)
        context.saveGState()
        context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 44).cgPath)
        context.clip()
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors.map(\.cgColor) as CFArray,
                                     locations: [0, 0.55, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY),
                                       end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
        }

        // Deterministic pinprick and brush marks make exports retain the authored paper/ceramic feel.
        var value = UInt64(max(1, selection.seed))
        for index in 0..<42 {
            value = value &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let x = rect.minX + CGFloat(value % 10_000) / 10_000 * rect.width
            value = value &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let y = rect.minY + CGFloat(value % 10_000) / 10_000 * rect.height
            let radius = CGFloat(1 + index % 4)
            context.setFillColor(UIColor.white.withAlphaComponent(0.08 + CGFloat(index % 3) * 0.025).cgColor)
            context.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
        }

        if let symbol = UIImage(systemName: theme.heroSymbol)?.withTintColor(
            selection.paletteID == .kilnNight ? UIColor.white : UIColor(hex: 0x302923),
            renderingMode: .alwaysOriginal
        ) {
            let side = min(rect.width, rect.height) * 0.52
            let symbolRect = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2,
                                    width: side, height: side)
            UIGraphicsPushContext(context)
            symbol.draw(in: symbolRect, blendMode: .normal, alpha: CGFloat(0.08 + progress * 0.10))
            UIGraphicsPopContext()
        }
        context.restoreGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.32).cgColor)
        context.setLineWidth(3)
        context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 44).cgPath)
        context.strokePath()
    }

    private func adjustedThemeColors(_ hex: [UInt32], palette: KinderThemePaletteID) -> [UIColor] {
        let source = hex.isEmpty ? [0xE87975, 0xD6A937, 0x7896C7] : hex
        return source.prefix(3).map { value in
            let color = UIColor(hex: value)
            return switch palette {
            case .signature: color
            case .soft: color.mixed(with: .white, amount: 0.54)
            case .kilnNight: color.mixed(with: UIColor(hex: 0x17151D), amount: 0.67)
            }
        }
    }

    private func drawMosaicRail(_ request: RecapRenderRequest, frame: RecapTimeline.FrameState, context: CGContext, size: CGSize) {
        let rect = CGRect(x: 60, y: size.height - 105, width: size.width - 120, height: 16)
        context.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.fillEllipse(in: rect)
        context.setFillColor(UIColor(red: 0.84, green: 0.66, blue: 0.22, alpha: 1).cgColor)
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width * frame.tileProgress, height: rect.height))
    }

    private func drawImpact(_ request: RecapRenderRequest, context: CGContext, size: CGSize) {
        drawText("Impact Receipt", in: CGRect(x: 80, y: 180, width: size.width - 160, height: 110),
                 font: displayFont(70, weight: .semibold), color: ink(for: request.timeline.preset.grade), context: context)
        let rows = [
            ("Accepted actions", "\(request.meta.impact.acceptedActions)"),
            ("Participants", "\(request.meta.impact.participantCount)"),
            ("Pass-the-Tile joins", "\(request.meta.impact.passTheTileJoins)")
        ] + request.meta.impact.organizerUnits.map { ($0.label, $0.value) }
        var y: CGFloat = 420
        for row in rows {
            drawText(row.0, in: CGRect(x: 110, y: y, width: 600, height: 60), font: .systemFont(ofSize: 35, weight: .medium), color: ink(for: request.timeline.preset.grade), context: context)
            drawText(row.1, in: CGRect(x: size.width - 300, y: y, width: 190, height: 60), font: .systemFont(ofSize: 40, weight: .bold), color: ink(for: request.timeline.preset.grade), context: context, alignment: .right)
            y += 92
        }
        drawMosaic(request, progress: 1, context: context, size: size, hero: false)
    }

    private func drawOutro(_ request: RecapRenderRequest, context: CGContext, size: CGSize) {
        drawMosaic(request, progress: 1, context: context, size: size, hero: false)
        drawText("Every action had a place", in: CGRect(x: 74, y: 260, width: size.width - 148, height: 170),
                 font: displayFont(66, weight: .semibold), color: ink(for: request.timeline.preset.grade), context: context)
        drawText(request.meta.challengeName + "\nMOSAIC  ·  Start your own mosaic", in: CGRect(x: 76, y: 470, width: size.width - 152, height: 130),
                 font: .systemFont(ofSize: 30, weight: .bold), color: ink(for: request.timeline.preset.grade).withAlphaComponent(0.8), context: context)
        if let attribution = request.music?.attribution {
            drawText("Music: \(attribution)", in: CGRect(x: 70, y: size.height - 120, width: size.width - 140, height: 50),
                     font: .systemFont(ofSize: 19, weight: .medium), color: ink(for: request.timeline.preset.grade).withAlphaComponent(0.65), context: context)
        }
    }

    private func drawChrome(_ preset: RecapPreset, source: RecapSource, index: Int, context: CGContext, size: CGSize) {
        guard preset.chrome != .none else { return }
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(3)
        context.stroke(CGRect(x: 36, y: 90, width: size.width - 72, height: size.height - 180))
        if preset.chrome == .memoryCamera {
            let label = source.category?.rawValue.uppercased() ?? "MOMENT"
            drawText("● REC     MEMORY \(index + 1)\n\(label)", in: CGRect(x: 58, y: 110, width: size.width - 116, height: 80),
                     font: .monospacedSystemFont(ofSize: 24, weight: .bold), color: .white, context: context)
        }
    }

    private func drawGradeOverlay(_ grade: RecapPreset.Grade, in rect: CGRect, context: CGContext) {
        let color: UIColor = switch grade {
        case .coolMonochrome: UIColor(red: 0.2, green: 0.3, blue: 0.42, alpha: 0.25)
        case .mutedOlive: UIColor(red: 0.35, green: 0.4, blue: 0.22, alpha: 0.18)
        case .softRose: UIColor(red: 0.85, green: 0.45, blue: 0.5, alpha: 0.16)
        case .tealNight: UIColor(red: 0.02, green: 0.28, blue: 0.3, alpha: 0.28)
        case .fadedAmber: UIColor(red: 0.75, green: 0.42, blue: 0.12, alpha: 0.2)
        case .goldenHour: UIColor(red: 0.85, green: 0.56, blue: 0.18, alpha: 0.16)
        }
        context.setFillColor(color.cgColor)
        context.fill(rect)
    }

    private func drawAspectFill(_ image: CGImage, in rect: CGRect, context: CGContext) {
        let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        context.draw(image, in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
    }

    private func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, context: CGContext, alignment: NSTextAlignment = .left) {
        UIGraphicsPushContext(context)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ], context: nil)
        UIGraphicsPopContext()
    }

    private func displayFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let name = weight >= .semibold ? MosaicFontRegistrar.semiboldPostScriptName : MosaicFontRegistrar.regularPostScriptName
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    private func background(for grade: RecapPreset.Grade) -> UIColor {
        switch grade {
        case .tealNight, .coolMonochrome: UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        case .mutedOlive: UIColor(red: 0.88, green: 0.86, blue: 0.73, alpha: 1)
        case .softRose: UIColor(red: 0.96, green: 0.83, blue: 0.84, alpha: 1)
        case .fadedAmber: UIColor(red: 0.78, green: 0.61, blue: 0.38, alpha: 1)
        case .goldenHour: UIColor(red: 0.97, green: 0.89, blue: 0.72, alpha: 1)
        }
    }

    private func ink(for grade: RecapPreset.Grade) -> UIColor {
        grade == .tealNight || grade == .coolMonochrome ? UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1) : UIColor(red: 0.15, green: 0.13, blue: 0.12, alpha: 1)
    }

    private func tileColor(_ emotion: RecapEmotion?) -> UIColor {
        switch emotion {
        case .hopeful: UIColor(red: 0.49, green: 0.72, blue: 0.8, alpha: 1)
        case .joyful: UIColor(red: 0.96, green: 0.43, blue: 0.24, alpha: 1)
        case .caring: UIColor(red: 0.89, green: 0.65, blue: 0.71, alpha: 1)
        case .calm: UIColor(red: 0.49, green: 0.6, blue: 0.51, alpha: 1)
        case nil: UIColor(red: 0.72, green: 0.62, blue: 0.5, alpha: 1)
        }
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: 1)
    }

    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0; var g1: CGFloat = 0; var b1: CGFloat = 0; var a1: CGFloat = 0
        var r2: CGFloat = 0; var g2: CGFloat = 0; var b2: CGFloat = 0; var a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = min(max(amount, 0), 1)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}
