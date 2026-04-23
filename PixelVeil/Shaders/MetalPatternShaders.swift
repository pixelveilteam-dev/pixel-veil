//
//  MetalPatternShaders.swift
//  Pixel Veil
//
//  Contains the Metal source compiled at runtime by MetalPatternView.
//
//  Why the shader looks the way it does
//  ------------------------------------
//  Pure software cannot narrow an LCD's viewing cone. What it CAN do is exploit
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
//    * adaptive-text           — per-pixel blue-ish noise; best for text
//    * custom                  — denser noise
//  All modes ride on top of the contrast-reduction base.
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
        float alphaBase = clamp(u.strength * 0.42, 0.0, 0.90);

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
            // Adaptive text: two overlaid hashes create a busier, finer noise
            // field that shreds glyph edges at off-axis angles.
            float n1 = hash12(floor(px));
            float n2 = hash12(floor(px * 0.5) + 17.0);
            m = step(0.55, n1 * 0.65 + n2 * 0.35);
        } else {
            // Custom: single-octave pixel noise.
            m = step(0.50, hash12(floor(px * 1.3) + 31.0));
        }

        // The pattern contributes a smaller additional alpha on top of the
        // veil so decorative modes stay readable at high strength.
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
