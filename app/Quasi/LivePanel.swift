import AppKit
import SwiftUI

/// The small floating window that appears while the recorder is recording and then shows the transcript.
@MainActor
final class LivePanelController {
    private var panel: NSPanel?

    func show(model: AppModel) {
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
                                styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
                                backing: .buffered, defer: false)
            panel.title = "Quasi"
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isMovableByWindowBackground = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            // Top padding clears the transparent title bar.
            let content = LiveView()
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .padding(.top, 30)
                .frame(minWidth: 320, minHeight: 200)
                .environmentObject(model)
            panel.contentView = NSHostingView(rootView: content)
            if let screen = NSScreen.main {
                let frame = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: frame.maxX - 400, y: frame.maxY - 280))
            }
            self.panel = panel
        }
        panel?.orderFrontRegardless()
    }
}
