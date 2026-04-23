//
//  OverlayWindow.swift
//  Pixel Veil
//
//  A transparent, click-through, always-on-top NSWindow that sits above every
//  other window on a single screen and hosts a Metal-backed pattern view.
//
//  Technical feasibility note
//  --------------------------
//  macOS user-space apps cannot turn individual physical pixels off. Samsung's
//  hardware privacy mode uses a switchable LC privacy layer in the panel that
//  *optically* narrows the viewing cone; no desktop OS exposes that. The best a
//  user-space app can do is composite a mask on top of the desktop. This window
//  does exactly that:
//    * `level = .screenSaver + 1` — sits above everything except screen
//      capture UI. On macOS we can't legally sit above system UI like Control
//      Center, so that's our ceiling.
//    * `ignoresMouseEvents = true` — clicks pass through to whatever is below.
//    * `collectionBehavior` — stays visible across Spaces and full-screen apps.
//
//  The actual pattern rendering happens in MetalPatternView; this file is just
//  the window chrome.
//

import AppKit

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        // NSWindow's designated initializer doesn't take a `screen:` argument
        // (the variant that does is a convenience and can't be called from a
        // subclass's super.init). We set the frame after init to anchor the
        // window onto the target display.
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = false

        // Screen-saver level is the only level that reliably honours
        // `.canJoinAllSpaces` — lower levels (including `.popUpMenu`) are
        // treated as Space-local by the window server and get dropped when
        // you swipe between desktops, no matter what collectionBehavior
        // you set. The trade-off is that our own Pixel Veil window also gets
        // veiled; that's intentional — you see exactly what a side viewer sees.
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))

        // Visible on every Space (including after swipe transitions), stays
        // put instead of animating alongside the active Space, never appears
        // in Cmd-Tab, and layers above full-screen apps.
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]

        self.setFrame(screen.frame, display: false)
        self.isReleasedWhenClosed = false
    }

    // Required for borderless windows to become key. We never want that —
    // this overlay must never steal focus from the user's work.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
