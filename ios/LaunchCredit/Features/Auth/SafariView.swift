import SwiftUI
import SafariServices

/// An in-app browser, tinted to match. Used for the web checkout so signing up
/// never backgrounds the app — the member comes straight back to the sign-in
/// screen when they close it, instead of having to find their way back from
/// Safari.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(Brand.green)
        controller.preferredBarTintColor = UIColor(Brand.bg)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
