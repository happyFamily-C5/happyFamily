import SwiftUI
import UIKit

/// Minimal `UIActivityViewController` wrapper used to share the invocation
/// URL returned by a successful `operations:publish_event`.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
