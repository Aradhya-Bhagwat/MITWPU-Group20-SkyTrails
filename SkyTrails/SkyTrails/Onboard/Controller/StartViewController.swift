
import UIKit

class StartViewController: UIViewController {

    @IBOutlet weak var segmentOutlet: UISegmentedControl!
    @IBOutlet weak var loginSegmentView: UIView!
    @IBOutlet weak var signupSegmentView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.bringSubviewToFront(signupSegmentView)
        setupCloseButtonIfNeeded()
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {

        if sender.selectedSegmentIndex == 0 {
            view.bringSubviewToFront(signupSegmentView)
        } else {
            view.bringSubviewToFront(loginSegmentView)
        }
    }
    
    private func setupCloseButtonIfNeeded() {
        // Show close button if presented modally
        guard presentingViewController != nil else { return }
        
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = UIColor.white.withAlphaComponent(0.6)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        
        view.addSubview(closeButton)
        view.bringSubviewToFront(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        closeButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
}
