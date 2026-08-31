import Foundation
import AVFoundation
import CoreGraphics
import UIKit

// ─── AVEN Demo Video Service ──────────────────────────────────────────────────
//
// Generates a real playable MP4 video locally using AVFoundation.
// Used when the production backend is unavailable (Simulator / dev mode).
//
// Fixes vs. previous version:
//   ✅ Integer frame timestamps: CMTimeMake(frame, fps) — no float rounding
//   ✅ Writer status checked before startSession
//   ✅ Pixel buffer pool nil-guarded
//   ✅ Buffer writing on a dedicated SerialQueue via requestMediaDataWhenReady
//   ✅ Correct CGContext bitmapInfo for kCVPixelFormatType_32BGRA
//   ✅ Output file verified after finishWriting
//   ✅ Simulator-compatible H.264 + AAC-less MP4

final class AVENDemoVideoService {

    private let width:     Int = 720
    private let height:    Int = 1280
    private let fps:       Int32 = 30
    private let durationS: Int  = 12   // seconds

    // ─── Entry point ──────────────────────────────────────────────────────────

    func generateDemoVideo(
        hook:     String,
        platform: String,
        style:    String,
        caption:  String
    ) async throws -> URL {

        // ── 1. Output URL ─────────────────────────────────────────────────────
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aven_demo_\(UInt32.random(in: 100000...999999)).mp4")
        try? FileManager.default.removeItem(at: outURL)

        // ── 2. Writer ─────────────────────────────────────────────────────────
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
        } catch {
            throw AVENVideoError.writerCreationFailed(error.localizedDescription)
        }

        // ── 3. Video input ────────────────────────────────────────────────────
        let videoSettings: [String: Any] = [
            AVVideoCodecKey:  AVVideoCodecType.h264,
            AVVideoWidthKey:  width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey:       1_200_000,
                AVVideoMaxKeyFrameIntervalKey:  fps,
                AVVideoProfileLevelKey:         AVVideoProfileLevelH264BaselineAutoLevel,
            ] as [String: Any],
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        // Pixel buffer attributes — must match CGContext bitmapInfo below
        let pbAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey  as String:          width,
            kCVPixelBufferHeightKey as String:          height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput:              input,
            sourcePixelBufferAttributes:   pbAttrs
        )

        guard writer.canAdd(input) else {
            throw AVENVideoError.cannotAddInput
        }
        writer.add(input)

        // ── 4. Start writing ──────────────────────────────────────────────────
        guard writer.startWriting() else {
            throw AVENVideoError.startFailed(writer.error?.localizedDescription ?? "unknown")
        }
        writer.startSession(atSourceTime: .zero)

        // ── 5. Build title-card sequence ──────────────────────────────────────
        let cards = buildCards(hook: hook, platform: platform, style: style, caption: caption)
        let totalFrames = durationS * Int(fps)

        // ── 6. Render frames via requestMediaDataWhenReady ────────────────────
        // This is the correct AVFoundation pattern: the framework tells us when
        // it's ready, avoiding the busy-wait loop of the previous version.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "com.aven.videorender", qos: .userInitiated)
            var frameIndex = 0
            var failed: Error? = nil

            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard frameIndex < totalFrames else {
                        input.markAsFinished()
                        if let e = failed { cont.resume(throwing: e) }
                        else { cont.resume() }
                        return
                    }

                    // Integer timestamps — no floating-point rounding
                    let pts = CMTimeMake(value: Int64(frameIndex), timescale: self.fps)
                    let time = Double(frameIndex) / Double(self.fps)

                    guard let pool = adaptor.pixelBufferPool else {
                        failed = AVENVideoError.noPixelBufferPool
                        input.markAsFinished()
                        cont.resume(throwing: AVENVideoError.noPixelBufferPool)
                        return
                    }

                    let card = self.card(at: time, in: cards)
                    let progress = Float(frameIndex) / Float(totalFrames)

                    if let buffer = self.renderFrame(
                        pool: pool, card: card, progress: progress, time: time
                    ) {
                        if !adaptor.append(buffer, withPresentationTime: pts) {
                            // append failure is non-fatal for individual frames
                            // (can happen on Simulator for a single frame; skip)
                        }
                    }

                    frameIndex += 1
                }
            }
        }

        // ── 7. Finish writing ─────────────────────────────────────────────────
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }

        guard writer.status == .completed else {
            throw AVENVideoError.writeFailed(
                writer.error?.localizedDescription ?? "Writer status: \(writer.status.rawValue)"
            )
        }

        // ── 8. Verify output ──────────────────────────────────────────────────
        let attrs = try? FileManager.default.attributesOfItem(atPath: outURL.path)
        let size  = (attrs?[.size] as? Int) ?? 0
        guard size > 1000 else {
            throw AVENVideoError.outputTooSmall(size)
        }

        return outURL
    }

    // ─── Title-card sequence ──────────────────────────────────────────────────

    struct Card {
        let startTime: Double
        let headline:  String
        let subtext:   String
        let phase:     CardPhase
    }

    enum CardPhase { case brand, platform, hook, caption, cta }

    private func buildCards(hook: String, platform: String, style: String, caption: String) -> [Card] {
        [
            Card(startTime: 0.0,  headline: "AVEN",        subtext: "KI-Video Konzept",      phase: .brand),
            Card(startTime: 2.0,  headline: platform,       subtext: style,                   phase: .platform),
            Card(startTime: 4.5,  headline: String(hook.prefix(55)),   subtext: "",           phase: .hook),
            Card(startTime: 8.0,  headline: String(caption.prefix(55)), subtext: "",          phase: .caption),
            Card(startTime: 10.5, headline: "Erstellt mit AVEN", subtext: "avengrowth.app",  phase: .cta),
        ]
    }

    private func card(at time: Double, in cards: [Card]) -> Card {
        cards.reversed().first { time >= $0.startTime } ?? cards[0]
    }

    // ─── Frame renderer ───────────────────────────────────────────────────────

    private func renderFrame(
        pool: CVPixelBufferPool,
        card: Card,
        progress: Float,
        time: Double
    ) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        let base = CVPixelBufferGetBaseAddress(buffer)

        // CGContext must match kCVPixelFormatType_32BGRA:
        // .byteOrder32Little | .premultipliedFirst  (= BGRA on little-endian)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data:             base,
            width:            w,
            height:           h,
            bitsPerComponent: 8,
            bytesPerRow:      bpr,
            space:            colorSpace,
            bitmapInfo:       CGImageAlphaInfo.premultipliedFirst.rawValue
                              | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return buffer }

        drawBackground(ctx: ctx, w: w, h: h, card: card, progress: progress, time: time)

        // Text drawing via UIKit (needs UIGraphics context push on the CG context)
        UIGraphicsPushContext(ctx)
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        drawText(ctx: ctx, card: card, w: w, h: h)
        UIGraphicsPopContext()

        return buffer
    }

    // ─── Drawing helpers ──────────────────────────────────────────────────────

    private func drawBackground(ctx: CGContext, w: Int, h: Int, card: Card, progress: Float, time: Double) {
        // Deep dark base
        ctx.setFillColor(CGColor(red: 0.035, green: 0.035, blue: 0.055, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        let cs = CGColorSpaceCreateDeviceRGB()

        // Animated top glow — colour shifts by phase
        let (glowR, glowG, glowB): (CGFloat, CGFloat, CGFloat) = {
            switch card.phase {
            case .brand:    return (0.48, 0.20, 1.0)
            case .platform: return (0.20, 0.60, 1.0)
            case .hook:     return (0.60, 0.20, 0.90)
            case .caption:  return (0.20, 0.80, 1.0)
            case .cta:      return (0.48, 0.20, 1.0)
            }
        }()
        let topGlowColors = [
            CGColor(red: glowR, green: glowG, blue: glowB, alpha: 0.28),
            CGColor(red: glowR, green: glowG, blue: glowB, alpha: 0),
        ] as CFArray
        let locs: [CGFloat] = [0, 1]
        if let grad = CGGradient(colorsSpace: cs, colors: topGlowColors, locations: locs) {
            ctx.saveGState()
            ctx.drawRadialGradient(
                grad,
                startCenter: CGPoint(x: w/2, y: h),
                startRadius: 0,
                endCenter:   CGPoint(x: w/2, y: h),
                endRadius:   CGFloat(h) * 0.72,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            ctx.restoreGState()
        }

        // Progress bar at bottom
        let barH: CGFloat = 4
        ctx.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: Int(barH)))
        let barColors = [
            CGColor(red: 0.48, green: 0.20, blue: 1.0, alpha: 1),
            CGColor(red: 0.0,  green: 0.80, blue: 1.0, alpha: 1),
        ] as CFArray
        if let grad = CGGradient(colorsSpace: cs, colors: barColors, locations: locs) {
            let barW = CGFloat(w) * CGFloat(progress)
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: barW, height: barH))
            ctx.drawLinearGradient(grad,
                start: CGPoint(x: 0, y: 0),
                end:   CGPoint(x: CGFloat(w), y: 0),
                options: [])
            ctx.restoreGState()
        }

        // Thin top separator line
        ctx.setFillColor(CGColor(red: 0.30, green: 0.18, blue: 0.60, alpha: 0.6))
        ctx.fill(CGRect(x: 0, y: h - 2, width: w, height: 2))
    }

    private func drawText(ctx: CGContext, card: Card, w: Int, h: Int) {
        let cw = CGFloat(w)
        let ch = CGFloat(h)
        let center = CGPoint(x: cw / 2, y: ch / 2)

        // AVEN watermark — always top
        let avenAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor(red: 0.48, green: 0.20, blue: 1.0, alpha: 0.65),
            .kern: 6.0,
        ]
        let avenStr = NSAttributedString(string: "AVEN", attributes: avenAttrs)
        let avenSz = avenStr.size()
        avenStr.draw(at: CGPoint(x: cw/2 - avenSz.width/2, y: ch - 64))

        // Headline
        if !card.headline.isEmpty {
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            para.lineSpacing = 8
            para.lineBreakMode = .byWordWrapping

            let fontSize: CGFloat = card.phase == .brand ? 64 : (card.headline.count > 30 ? 28 : 36)
            let headAttrs: [NSAttributedString.Key: Any] = [
                .font:            UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle:  para,
            ]
            let headRect = CGRect(
                x:      cw * 0.10,
                y:      center.y - 100,
                width:  cw * 0.80,
                height: 250
            )
            NSAttributedString(string: card.headline, attributes: headAttrs).draw(in: headRect)
        }

        // Subtext
        if !card.subtext.isEmpty {
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font:            UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor(red: 0.55, green: 0.65, blue: 0.85, alpha: 1),
                .paragraphStyle:  para,
            ]
            let subRect = CGRect(
                x:      cw * 0.10,
                y:      center.y + 90,
                width:  cw * 0.80,
                height: 120
            )
            NSAttributedString(string: card.subtext, attributes: subAttrs).draw(in: subRect)
        }

        // Phase label at bottom
        let phaseText: String = {
            switch card.phase {
            case .brand:    return ""
            case .platform: return "PLATTFORM"
            case .hook:     return "HOOK"
            case .caption:  return "CAPTION"
            case .cta:      return ""
            }
        }()
        if !phaseText.isEmpty {
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font:            UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor(red: 0.48, green: 0.20, blue: 1.0, alpha: 0.8),
                .kern:            2.0,
            ]
            let labelStr = NSAttributedString(string: phaseText, attributes: labelAttrs)
            let labelSz  = labelStr.size()
            labelStr.draw(at: CGPoint(x: cw/2 - labelSz.width/2, y: center.y - 145))
        }
    }
}

// ─── Error types ──────────────────────────────────────────────────────────────

enum AVENVideoError: Error, LocalizedError {
    case writerCreationFailed(String)
    case cannotAddInput
    case startFailed(String)
    case noPixelBufferPool
    case writeFailed(String)
    case outputTooSmall(Int)

    var errorDescription: String? {
        switch self {
        case .writerCreationFailed(let m): return "Writer creation failed: \(m)"
        case .cannotAddInput:              return "Cannot add video input to writer"
        case .startFailed(let m):          return "Writer failed to start: \(m)"
        case .noPixelBufferPool:           return "Pixel buffer pool unavailable"
        case .writeFailed(let m):          return "Write failed: \(m)"
        case .outputTooSmall(let s):       return "Output file too small (\(s) bytes)"
        }
    }
}
