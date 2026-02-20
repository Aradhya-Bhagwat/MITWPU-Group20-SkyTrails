import UIKit

class SignUpViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var otpInputView: OTPInputView!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var resendButton: UIButton!

    private var isOTPRequired = false
    private var pendingEmail: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupFields()
        hideKeyboardWhenTapped()
    }

    private func setupFields() {
        otpInputView.isHidden = true
        resendButton.isHidden = true
        actionButton.setTitle("Send OTP", for: .normal)
    }

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        Task { [weak self] in
            await self?.handleAction(button: sender)
        }
    }

    private func handleAction(button: UIButton) async {
        if isOTPRequired {
            await verifyOTP(button: button)
        } else {
            await sendOTP(button: button)
        }
    }

    private func sendOTP(button: UIButton) async {
        guard let name = nameTextField.text?.trimmingCharacters(in: .whitespaces),
              let email = emailTextField.text?.trimmingCharacters(in: .whitespaces),
              !name.isEmpty,
              !email.isEmpty else {
            show("Please enter name and email")
            return
        }

        guard email.isValidEmail else {
            show("Invalid email address")
            return
        }

        setLoading(true, button: button)

        do {
            try await SupabaseAuthService.shared.sendOTP(email: email)
            pendingEmail = email
            isOTPRequired = true

            otpInputView.isHidden = false
            resendButton.isHidden = false
            actionButton.setTitle("Verify OTP", for: .normal)
            emailTextField.isEnabled = false
            nameTextField.isEnabled = false

            show("OTP sent to your email (Prototype: Use 123456)")
        } catch {
            show(error.localizedDescription)
        }

        setLoading(false, button: button)
    }

    private func verifyOTP(button: UIButton) async {
        guard let email = pendingEmail ?? emailTextField.text?.trimmingCharacters(in: .whitespaces),
              !email.isEmpty else {
            show("Email is required")
            return
        }

        let token = otpInputView.text.trimmingCharacters(in: .whitespaces)
        guard token.count == 6 else {
            show("Please enter the 6-digit OTP")
            return
        }

        let name = nameTextField.text?.trimmingCharacters(in: .whitespaces) ?? "User"

        setLoading(true, button: button)

        do {
            let authResult = try await SupabaseAuthService.shared.verifyOTP(email: email, token: token)

            let user = User(
                id: authResult.userID,
                name: authResult.displayName ?? name,
                gender: "Not Specified",
                email: authResult.email,
                profilePhoto: authResult.profilePhoto ?? "defaultProfile"
            )

            UserSession.shared.saveAuthenticatedUser(
                user,
                accessToken: authResult.accessToken,
                refreshToken: authResult.refreshToken
            )

            Task {
                try? await UserSyncService.shared.upsertUser(user)
            }

            await WatchlistManager.shared.bindCurrentUserOwnership()
            show("Account created successfully!") {
                self.goToMain()
            }
        } catch {
            show(error.localizedDescription)
        }

        setLoading(false, button: button)
    }

    @IBAction func resendTapped(_ sender: UIButton) {
        Task { [weak self] in
            await self?.sendOTP(button: sender)
        }
    }

    private func setLoading(_ isLoading: Bool, button: UIButton) {
        button.isEnabled = !isLoading
        button.alpha = isLoading ? 0.6 : 1.0
    }

    private func goToMain() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mainVC = storyboard.instantiateViewController(withIdentifier: "RootTabBarController")
        window.rootViewController = mainVC

        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionFlipFromRight,
            animations: nil
        )
    }

    private func show(_ msg: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: "Alert", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }

    private func hideKeyboardWhenTapped() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}
