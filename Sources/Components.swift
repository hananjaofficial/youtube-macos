import SwiftUI
import AppKit

/// Transluzenter Hintergrund über NSVisualEffectView (.hudWindow / .sidebar).
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}

/// Natives macOS-Suchfeld (NSSearchField).
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let f = NSSearchField()
        f.placeholderString = "Suchen oder Link einfügen"
        f.delegate = context.coordinator
        f.target = context.coordinator
        f.action = #selector(Coordinator.submit)
        f.sendsWholeSearchString = true
        f.focusRingType = .none
        return f
    }

    func updateNSView(_ f: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if f.stringValue != text { f.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField
        init(_ parent: SearchField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            if let f = obj.object as? NSSearchField { parent.text = f.stringValue }
        }

        @objc func submit() { parent.onSubmit() }
    }
}

/// Liefert das NSWindow, in dem die SwiftUI-View steckt.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let w = nsView.window { onWindow(w) }
        }
    }
}
