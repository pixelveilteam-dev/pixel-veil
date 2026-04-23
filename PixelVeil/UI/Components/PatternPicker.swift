//
//  PatternPicker.swift
//  Pixel Veil
//
//  A horizontal row of chip-style buttons for pattern selection. Mirrors the
//  look of the segmented control in the reference screenshot while giving each
//  option its own SF Symbol glyph.
//

import SwiftUI

struct PatternPicker: View {
    @Binding var selection: PatternMode
    var patterns: [PatternMode] = PatternMode.allCases
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(patterns) { p in
                PatternChip(pattern: p,
                            isSelected: p == selection,
                            compact: compact) {
                    selection = p
                }
            }
        }
    }
}

private struct PatternChip: View {
    let pattern: PatternMode
    let isSelected: Bool
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 5 : 7) {
                Image(systemName: pattern.symbol)
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                Text(shortName)
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, compact ? 9 : 11)
            .padding(.vertical, compact ? 7 : 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.14)
                          : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected
                                  ? Color.accentColor.opacity(0.45)
                                  : Color.black.opacity(0.08),
                                  lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private var shortName: String {
        switch pattern {
        case .verticalStripes: return "Vertical"
        case .horizontalLines: return "Horizontal"
        case .checkerboard:    return "Checker"
        case .adaptiveText:    return "Adaptive"
        case .custom:          return "Custom"
        }
    }
}
