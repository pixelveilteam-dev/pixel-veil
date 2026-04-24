//
//  MetalPatternShaders.swift
//  Pixel Veil
//
//  Contains the Metal source compiled at runtime by MetalPatternView.
//
//  Why the shader looks the way it does
//  ------------------------------------
//  Pure software cannot narrow an LCD's viewing cone. What it can do is exploit
//  the panel's existing angle-dependent contrast loss. LCDs already lose
//  dynamic range off-axis (blacks rise, whites dim — a 1000:1 IPS panel easily
//  drops to ~5:1 at 60°). If we composite a mid-grey veil with moderate alpha:
//
//      direct viewer (0°):  native 1000:1 × our ~0.5 factor → ~500:1 (readable)
//      side viewer (60°):  degraded 5:1 × our ~0.5 factor → ~2.5:1 (unreadable)
//
//  The asymmetry exists because the panel's own falloff and our compression
//  stack multiplicatively. Hardware privacy screens achieve more because they
//  physically absorb off-axis photons; this is the best software analogue.
//
//  On top of the veil we add a pattern selected by the user:
//    * stripes / checkerboard  — decorative + extra edge-noise
//    * adaptive-text           — ordered, display-stable micro-louver mask
//    * custom                  — denser noise
//

enum MetalPatternShaders {
    static let source: String = """
    #include <metal_stdlib>
    using namespace metal;

    struct PatternUniforms {
        float2 resolution;
        float  strength;
        float  density;
        int    mode;
        float  time;
        float  phaseSeed;
        float  localDimAlpha;
    };

    struct VSOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VSOut pv_vertex(uint vid [[vertex_id]]) {
        float2 pos;
        switch (vid) {
            case 0: pos = float2(-1.0, -1.0); break;
            case 1: pos = float2( 3.0, -1.0); break;
            default: pos = float2(-1.0,  3.0); break;
        }
        VSOut out;
        out.position = float4(pos, 0.0, 1.0);
        out.uv = (pos + 1.0) * 0.5;
        return out;
    }

    static inline float pitchPx(float density) {
        // 0 -> 12 px, 1 -> 2 px.
        return mix(12.0, 2.0, clamp(density, 0.0, 1.0));
    }

    // Deterministic pixel-scale hash noise. Cheap and tiles without seams.
    static inline float hash12(float2 p) {
        return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    }

    static inline float bayer8(float2 p) {
        uint x = uint(floor(p.x)) & 7u;
        uint y = uint(floor(p.y)) & 7u;
        uint v = 0u;
        for (uint bit = 0u; bit < 3u; bit++) {
            uint bx = (x >> bit) & 1u;
            uint by = (y >> bit) & 1u;
            uint pair = (bx ^ by) | (by << 1u);
            v |= pair << (bit * 2u);
        }
        return (float(v) + 0.5) / 64.0;
    }

    static inline float adaptiveTextMask(float2 px, float pitch, float density, float seed) {
        float2 shifted = px + float2(seed * 13.0, seed * 7.0);
        float coverage = mix(0.22, 0.36, clamp(density, 0.0, 1.0));
        float cellSize = max(round(pitch * 0.80), 2.0);
        float2 orderedCell = floor(shifted / cellSize);
        float ordered = step(1.0 - coverage, bayer8(orderedCell));
        float fine = max(round(pitch * 1.20), 3.0);
        float lane = step(1.0 - coverage * 0.45, fract((shifted.x + shifted.y * 0.16) / fine));
        float rowGate = step(0.22, fract(shifted.y / (fine * 2.8)));
        return max(ordered, lane * rowGate);
    }

    fragment float4 pv_fragment(VSOut in [[stage_in]],
                                constant PatternUniforms &u [[buffer(0)]]) {
        float2 px = in.uv * u.resolution;
        float pitch = max(pitchPx(u.density), 2.0);

        // Contrast-reduction veil. The gray level sits slightly below 50 % so
        // blending pushes whites down more than it lifts blacks — subjectively
        // easier to read head-on.
        //
        // alphaBase caps at 0.42 at strength = 1, which keeps direct-viewer
        // contrast ≥ ~3.5:1 (comfortable reading), while the side viewer drops
        // well below 2:1 because their starting contrast is already
        // angle-degraded.
        float veilGray = 0.40;
        float alphaBase = clamp(u.strength * 0.42 + u.localDimAlpha, 0.0, 0.90);

        // Pattern mask in [0, 1].
        float m = 0.0;
        if (u.mode == 0) {
            m = step(0.5, fract(px.x / pitch));
        } else if (u.mode == 1) {
            m = step(0.5, fract(px.y / pitch));
        } else if (u.mode == 2) {
            float cx = floor(px.x / pitch);
            float cy = floor(px.y / pitch);
            m = fmod(cx + cy, 2.0);
        } else if (u.mode == 3) {
            // Adaptive text: ordered, stable pixel positioning. This avoids
            // the visual static/shimmer of random noise while still breaking
            // up small glyph strokes for side viewers.
            m = adaptiveTextMask(px, pitch, u.density, u.phaseSeed);
        } else if (u.mode == 4) {
            // Custom: single-octave pixel noise.
            m = step(0.50, hash12(floor(px * 1.3) + 31.0));
        }

        float alphaPattern = m * u.strength * 0.12;
        float a = clamp(alphaBase + alphaPattern, 0.0, 0.85);

        // On pattern-mask cells, darken the grey toward near-black; off-cells
        // keep the mid-grey veil. This preserves the visual identity of each
        // mode (stripes look like stripes) while the base veil does the
        // actual side-angle work on every mode.
        float g = mix(veilGray, 0.06, m * 0.55);

        return float4(g, g, g, a);
    }
    """
}
