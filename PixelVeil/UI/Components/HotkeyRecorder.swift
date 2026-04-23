//
//  HotkeyRecorder.swift
//  Pixel Veil
//
//  An NSView wrapped for SwiftUI that captures the next key-combo pressed and
//  writes it back as a HotkeySpec. Clicking the pill starts recording; pressing
//  Esc cancels; pressing any other non-modifier key commits.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotkeyRecorder: View {
    @Binding var hotkey: HotkeySpec
    @State private var recording = false

    var body: some View {
        HStack(spacing: 10) {
            _HotkeyRecorderView(hotkey: $hotkey, recording: $recording)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            Button {
                hotkey = HotkeySpec(keyCode: 0, modifiers: 0)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Clear shortcut")
        }
    }
}

// AppKit-backed recorder. SwiftUI doesn't give us raw key-down events from an
// arbitrary view reliably, so we use a tiny NSView.
private struct _HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: HotkeySpec
    @Binding var recording: Bool

    func makeNSView(context: Context) -> RecorderNSView {
        let v = RecorderNSView()
        v.onChange = { new in self.hotkey = new }
        v.onRecordingChange = { r in self.recording = r }
        return v
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.setHotkey(hotkey)
    }
}

final class RecorderNSView: NSView {
    var onChange: ((HotkeySpec) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?

    private var hotkey = HotkeySpec.defaultHotkey
    private var recording = false {
        didSet {
            onRecordingChange?(recording)
            needsDisplay = true
        }
    }
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) { nil }

    func setHotkey(_ spec: HotkeySpec) {
        self.hotkey = spec
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startRecording()
    }

    private func startRecording() {
        guard !recording else { return }
        recording = true
        // Swift can't always infer the optional return type from a multi-branch
        // closure, so we declare it explicitly.
        let handler: (NSEvent) -> NSEvent? = { [weak self] ev in
            guard let self = self, self.recording else { return ev }
            if ev.type == .keyDown {
                if ev.keyCode == 53 { // Esc cancels
                    self.stopRecording()
                    return nil
                }
                let mods = HotkeyTranslation.carbonModifiers(from: ev.modifierFlags)
                let spec = HotkeySpec(keyCode: UInt32(ev.keyCode), modifiers: mods)
                self.hotkey = spec
                self.onChange?(spec)
                self.stopRecording()
                return nil
            }
            return ev
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged],
            handler: handler
        )
    }

    private func stopRecording() {
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        localMonitor = nil
        recording = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let label = recording ? "Recording… press keys"
                              : HotkeyTranslation.displayString(hotkey)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: recording
                ? NSColor.secondaryLabelColor
                : NSColor.labelColor
        ]
        let s = NSAttributedString(string: label, attributes: attrs)
        let size = s.size()
        let point = NSPoint(x: (bounds.width - size.width) / 2,
                            y: (bounds.height - size.height) / 2)
        s.draw(at: point)
    }
}
