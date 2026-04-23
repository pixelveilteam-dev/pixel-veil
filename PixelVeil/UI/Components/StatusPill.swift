//
//  StatusPill.swift
//  Pixel Veil
//
//  Small coloured pill used next to "Privacy Mode • Active", "Granted", etc.
//

import SwiftUI

struct StatusDot: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.35), lineWidth: 2).blur(radius: 1))
    }
}

struct StatusLabel: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            StatusDot(color: color)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
