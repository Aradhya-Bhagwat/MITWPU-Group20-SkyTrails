import UIKit
import WebKit

final class TermsAndConditionsViewController: UIViewController {
    private let webView = WKWebView(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Terms & Conditions"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )

        setupWebView()
        loadTermsContent()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func setupWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadTermsContent() {
        if let url = Bundle.main.url(forResource: "terms_and_conditions", withExtension: "html", subdirectory: "Onboard/View") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            return
        }

        if let url = Bundle.main.url(forResource: "terms_and_conditions", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            return
        }

        webView.loadHTMLString(fallbackHTML(), baseURL: nil)
    }

    private func fallbackHTML() -> String {
        """
        <html><body style='font-family:-apple-system; padding:24px;'>
        <h2>Terms & Conditions</h2>
        <p>Unable to load terms document. Please try again after reinstalling the app.</p>
        </body></html>
        """
    }
}
