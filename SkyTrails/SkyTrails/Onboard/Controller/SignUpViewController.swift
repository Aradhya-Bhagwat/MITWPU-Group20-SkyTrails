import UIKit

class SignUpViewController: UIViewController {

    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var otpInputView: OTPInputView!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var resendButton: UIButton!

    private var isOTPRequired = false
    private var pendingEmail: String?
    private let otpLength = SupabaseAuthService.shared.otpLength
    private let resendCooldown = SupabaseAuthService.shared.otpResendCooldownSeconds
    private var resendSecondsRemaining = 0
    private var resendTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupFields()
        hideKeyboardWhenTapped()
    }

    private func setupFields() {
        otpInputView.digitCount = otpLength
        otpInputView.isHidden = true
        resendButton.isHidden = true
        resendButton.isEnabled = false
        actionButton.setTitle("Send OTP", for: .normal)
        actionButton.isEnabled = true
        actionButton.alpha = 1.0
        firstNameTextField.textContentType = .givenName
        firstNameTextField.autocapitalizationType = .words
        firstNameTextField.autocorrectionType = .no
        lastNameTextField.textContentType = .familyName
        lastNameTextField.autocapitalizationType = .words
        lastNameTextField.autocorrectionType = .no
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.autocorrectionType = .no
    }

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        Task { [weak self] in
            await self?.handleAction(button: sender)
        }
    }

    @IBAction func termsAndConditionsTapped(_ sender: UIButton) {
        let termsVC = TermsAndConditionsViewController()
        let nav = UINavigationController(rootViewController: termsVC)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func handleAction(button: UIButton) async {
        if isOTPRequired {
            await verifyOTP(button: button)
        } else {
            await sendOTP(button: button)
        }
    }

    private func sendOTP(button: UIButton) async {
        guard let firstName = firstNameTextField.text?.trimmingCharacters(in: .whitespaces),
              let lastName = lastNameTextField.text?.trimmingCharacters(in: .whitespaces),
              let email = emailTextField.text?.trimmingCharacters(in: .whitespaces),
              !firstName.isEmpty,
              !lastName.isEmpty,
              !email.isEmpty else {
            show("Please enter first name, last name and email")
            return
        }

        guard email.isValidEmail else {
            show("Invalid email address")
            return
        }

        let fullName = "\(firstName) \(lastName)"
        setLoading(true, button: button)

        do {
            try await SupabaseAuthService.shared.sendOTP(
                email: email,
                createUser: true,
                metadata: [
                    "name": fullName,
                    "first_name": firstName,
                    "last_name": lastName
                ]
            )
            pendingEmail = email
            isOTPRequired = true

            otpInputView.isHidden = false
            resendButton.isHidden = false
            actionButton.setTitle("Verify OTP", for: .normal)
            emailTextField.isEnabled = false
            firstNameTextField.isEnabled = false
            lastNameTextField.isEnabled = false
            otpInputView.clear()
            startResendCooldown()

            show("Email sent. Enter the OTP from your email or tap the sign-in link.")
        } catch {
            show(mappedSignupErrorMessage(error))
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
        guard token.count == otpLength else {
            show("Please enter the \(otpLength)-digit OTP")
            return
        }

        let firstName = firstNameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let lastName = lastNameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let fullName = [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        setLoading(true, button: button)

        do {
            let authResult = try await SupabaseAuthService.shared.verifyOTP(email: email, token: token)

            let user = User(
                id: authResult.userID,
                name: authResult.displayName ?? (fullName.isEmpty ? "User" : fullName),
                gender: authResult.gender ?? "Not Specified",
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
        guard resendSecondsRemaining == 0 else { return }
        Task { [weak self] in
            await self?.sendOTP(button: sender)
        }
    }

    private func startResendCooldown() {
        resendTimer?.invalidate()
        resendSecondsRemaining = resendCooldown
        resendButton.isEnabled = false
        updateResendButtonTitle()

        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.resendSecondsRemaining -= 1
            if self.resendSecondsRemaining <= 0 {
                self.resendSecondsRemaining = 0
                self.resendButton.isEnabled = true
                self.updateResendButtonTitle()
                timer.invalidate()
                self.resendTimer = nil
                return
            }

            self.updateResendButtonTitle()
        }
    }

    private func updateResendButtonTitle() {
        if resendSecondsRemaining > 0 {
            let title = "Didn't get OTP? Check spam • Resend in \(resendSecondsRemaining)s"
            resendButton.setTitle(title, for: .normal)
            if var config = resendButton.configuration {
                config.title = title
                resendButton.configuration = config
            }
        } else {
            let title = "Didn't get OTP? Check spam • Resend OTP"
            resendButton.setTitle(title, for: .normal)
            if var config = resendButton.configuration {
                config.title = title
                resendButton.configuration = config
            }
        }
    }

    private func mappedSignupErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("already") && (message.contains("registered") || message.contains("exists") || message.contains("signup")) {
            return "Account already exists. Please log in instead."
        }
        if (message.contains("email") && message.contains("already"))
            || message.contains("already registered")
            || message.contains("user already exists") {
            return "Account already exists. Please log in instead."
        }
        return error.localizedDescription
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

    deinit {
        resendTimer?.invalidate()
    }
}
