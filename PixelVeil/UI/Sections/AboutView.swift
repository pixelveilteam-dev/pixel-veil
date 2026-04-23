//
//  AboutView.swift
//  Pixel Veil
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            AppIconView(size: 112, cornerRadius: 24)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            VStack(spacing: 4) {
                Text("Pixel Veil")
                    .font(.system(size: 22, weight: .semibold))
                Text("Version \(AppInfo.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("A privacy-screen utility that composites a selective mask over your displays. Works on any Mac, no hardware required.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How it works").font(.system(size: 12, weight: .semibold))
                    Text("macOS does not expose per-pixel hardware control, and no software can narrow a panel's viewing cone the way hardware privacy layers do. Pixel Veil instead composites a mid-grey contrast-reduction veil on top of your displays. The direct viewer keeps enough dynamic range to read comfortably; side viewers, whose contrast is already degraded by the LCD's angle-dependent gamma, fall below the reading threshold. A selectable pattern (stripes, checkerboard, adaptive-text noise) rides on top to further scramble glyph edges at oblique angles.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("The effect is real but modest. It is not equivalent to a hardware privacy filter.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(.top, 10)
    }
}
