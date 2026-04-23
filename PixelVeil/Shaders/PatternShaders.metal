//
//  PatternShaders.metal
//  Pixel Veil
//
//  A single full-screen-triangle vertex stage feeds a fragment stage that
//  produces the privacy pattern. Everything is procedural — no textures —
//  so GPU overhead is tiny even at 5K.
//
//  Uniforms layout matches `PatternUniforms` in MetalPatternView.swift exactly.
//  Keep them in sync.
//

#include <metal_stdlib>
using namespace metal;

struct PatternUniforms {
    float2 resolution;   // pixels
    float  strength;     // 0..1 — alpha/contribution of the mask
    float  density;      // 0..1 — normalized pattern pitch
    int    mode;         // 0 vstripes, 1 hlines, 2 check, 3 adaptiveText, 4 custom
    float  time;         // seconds since engine start (for subtle shimmer)
};

struct VSOut {
    float4 position [[position]];
    float2 uv;
};

// Draw a full-screen triangle from vertex IDs 0/1/2 — saves a vertex buffer.
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

// Pitch in pixels. `density` 0 -> wide (24px), 1 -> tight (3px).
static inline float pitchPx(float density) {
    return mix(24.0, 3.0, clamp(density, 0.0, 1.0));
}

fragment float4 pv_fragment(VSOut in [[stage_in]],
                            constant PatternUniforms &u [[buffer(0)]]) {
    float2 px = in.uv * u.resolution;
    float pitch = pitchPx(u.density);
    float mask = 0.0;

    if (u.mode == 0) {
        // Vertical stripes: alternate dark columns.
        float col = floor(px.x / pitch);
        mask = fmod(col, 2.0);
    } else if (u.mode == 1) {
        // Horizontal lines.
        float row = floor(px.y / pitch);
        mask = fmod(row, 2.0);
    } else if (u.mode == 2) {
        // Checkerboard.
        float col = floor(px.x / pitch);
        float row = floor(px.y / pitch);
        mask = fmod(col + row, 2.0);
    } else if (u.mode == 3) {
        // Adaptive text: fine vertical stripes plus a subtle horizontal jitter
        // that makes small glyph strokes harder to resolve at an angle.
        float col = floor(px.x / max(pitch * 0.5, 1.5));
        float stripe = fmod(col, 2.0);
        float jitter = step(0.5, fract(sin(floor(px.y / 2.0) * 12.9898) * 43758.5453));
        mask = clamp(stripe * 0.85 + jitter * 0.15, 0.0, 1.0);
    } else {
        // Custom fallback: diagonal hatch.
        float diag = fmod(floor((px.x + px.y) / pitch), 2.0);
        mask = diag;
    }

    // Strength scales alpha. The overlay is black so it reads as "pixels off"
    // on the masked regions while the clear regions stay fully transparent.
    float alpha = mask * clamp(u.strength, 0.0, 1.0);
    return float4(0.0, 0.0, 0.0, alpha);
}
