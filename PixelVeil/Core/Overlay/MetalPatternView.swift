//
//  MetalPatternView.swift
//  Pixel Veil
//
//  An MTKView that renders the privacy pattern procedurally in a fragment
//  shader. Uses `presentsWithTransaction = false` and an on-demand draw model
//  (`isPaused = true`, `enableSetNeedsDisplay = true`) so we only draw when a
//  uniform actually changes — zero background CPU/GPU when idle.
//
//  Constructed via the `make()` factory because Metal availability is
//  theoretically optional. A failable override of `init()` on MTKView is not
//  legal (it's a convenience init in the superclass), so we use a private
//  designated init plus a factory that owns the failure paths.
//

import MetalKit
import simd

// Must match the Metal struct byte-for-byte. Swift's default layout of
// Floats and Int32 is fine for this size; alignment to 16 isn't required
// because Metal reads the buffer with the declared layout.
struct PatternUniforms {
    var resolution: SIMD2<Float>
    var strength: Float
    var density: Float
    var mode: Int32
    var time: Float
    var phaseSeed: Float
    var localDimAlpha: Float
}

final class MetalPatternView: MTKView {
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var uniforms = PatternUniforms(resolution: .zero,
                                           strength: 0.7,
                                           density: 0.5,
                                           mode: 0,
                                           time: 0,
                                           phaseSeed: 0,
                                           localDimAlpha: 0)

    static func make() -> MetalPatternView? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        guard let queue = device.makeCommandQueue() else { return nil }

        // Compile the shader at runtime from the embedded Swift string. This
        // lets the project build via plain SwiftPM (no `metal` / `metallib`
        // binaries required).
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: MetalPatternShaders.source,
                                             options: nil)
        } catch {
            assertionFailure("Metal shader compile failed: \(error)")
            return nil
        }
        guard
            let vfn = library.makeFunction(name: "pv_vertex"),
            let ffn = library.makeFunction(name: "pv_fragment")
        else { return nil }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vfn
        desc.fragmentFunction = ffn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].rgbBlendOperation = .add
        desc.colorAttachments[0].alphaBlendOperation = .add
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .one
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipe = try? device.makeRenderPipelineState(descriptor: desc) else { return nil }

        return MetalPatternView(device: device, queue: queue, pipeline: pipe)
    }

    private init(device: MTLDevice, queue: MTLCommandQueue, pipeline: MTLRenderPipelineState) {
        self.commandQueue = queue
        self.pipeline = pipeline
        super.init(frame: .zero, device: device)

        self.colorPixelFormat = .bgra8Unorm
        self.framebufferOnly = true
        // NSView.isOpaque is read-only — toggle the backing layer instead.
        self.wantsLayer = true
        self.layer?.isOpaque = false
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        // Draw-on-demand — we don't need a 60 Hz repaint for a static pattern.
        self.enableSetNeedsDisplay = true
        self.isPaused = true
    }

    required init(coder: NSCoder) { fatalError("not supported") }

    // MARK: Public updates

    func update(strength: Double,
                density: Double,
                pattern: PatternMode,
                localDimAlpha: Double = 0) {
        uniforms.strength = Float(strength)
        uniforms.density  = Float(density)
        uniforms.mode     = Int32(Self.modeIndex(pattern))
        uniforms.phaseSeed = 17
        uniforms.localDimAlpha = Float(max(0.0, min(0.55, localDimAlpha)))
        needsDisplay = true
    }

    private static func modeIndex(_ m: PatternMode) -> Int {
        switch m {
        case .verticalStripes: return 0
        case .horizontalLines: return 1
        case .checkerboard:    return 2
        case .adaptiveText:    return 3
        case .custom:          return 4
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard
            let drawable = currentDrawable,
            let rpd = currentRenderPassDescriptor,
            let buffer = commandQueue.makeCommandBuffer(),
            let encoder = buffer.makeRenderCommandEncoder(descriptor: rpd)
        else { return }

        uniforms.resolution = SIMD2<Float>(Float(drawableSize.width),
                                           Float(drawableSize.height))
        uniforms.time = Float(CACurrentMediaTime())

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms,
                                 length: MemoryLayout<PatternUniforms>.stride,
                                 index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }
}
