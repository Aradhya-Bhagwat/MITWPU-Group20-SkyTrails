import UIKit

class LoginViewController: UIViewController {

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
        setupOTPField()
        hideKeyboardWhenTapped()
    }

    private func setupOTPField() {
        otpInputView.digitCount = otpLength
        otpInputView.isHidden = true
        resendButton.isHidden = true
        resendButton.isEnabled = false
        actionButton.setTitle("Send OTP", for: .normal)
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

    private func handleAction(button: UIButton) async {
        if isOTPRequired {
            await verifyOTP(button: button)
        } else {
            await sendOTP(button: button)
        }
    }

    private func sendOTP(button: UIButton) async {
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else {
            showAlert("Please enter your email")
            return
        }

        guard email.isValidEmail else {
            showAlert("Invalid email")
            return
        }

        setLoading(true, button: button)

        do {
            let exists = try await SupabaseAuthService.shared.userExists(email: email)
            guard exists else {
                showAlert("No account found. Please sign up first.")
                setLoading(false, button: button)
                return
            }

            try await SupabaseAuthService.shared.sendOTP(email: email, createUser: false)
            pendingEmail = email
            isOTPRequired = true

            otpInputView.isHidden = false
            resendButton.isHidden = false
            actionButton.setTitle("Verify OTP", for: .normal)
            emailTextField.isEnabled = false
            otpInputView.clear()
            startResendCooldown()

            showAlert("OTP sent. Enter the \(otpLength)-digit OTP from your email.")
        } catch {
            showAlert(mappedLoginErrorMessage(error))
        }

        setLoading(false, button: button)
    }

    private func verifyOTP(button: UIButton) async {
        guard let email = pendingEmail ?? emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else {
            showAlert("Email is required")
            return
        }

        let token = otpInputView.text.trimmingCharacters(in: .whitespaces)
        guard token.count == otpLength else {
            showAlert("Please enter the \(otpLength)-digit OTP")
            return
        }

        setLoading(true, button: button)

        do {
            let authResult = try await SupabaseAuthService.shared.verifyOTP(email: email, token: token)
            let serverProfile = try? await fetchServerProfile(
                userID: authResult.userID,
                accessToken: authResult.accessToken
            )
            let cachedUser = UserSession.shared.getUser()

            let displayName: String
            if let existingUser = cachedUser, existingUser.email == email {
                displayName = existingUser.name
            } else if let authDisplayName = authResult.displayName, !authDisplayName.trimmingCharacters(in: .whitespaces).isEmpty {
                displayName = authDisplayName
            } else if let serverDisplayName = serverProfile?.name, !serverDisplayName.trimmingCharacters(in: .whitespaces).isEmpty {
                displayName = serverDisplayName
            } else {
                displayName = fallbackName(from: authResult.email)
            }

            let profilePhoto = authResult.profilePhoto
                ?? serverProfile?.profilePhoto
                ?? cachedUser?.profilePhoto
                ?? "defaultProfile"

            let user = User(
                user_id: authResult.userID,
                name: displayName,
                gender: authResult.gender
                    ?? serverProfile?.gender
                    ?? cachedUser?.gender
                    ?? "Not Specified",
                email: authResult.email,
                profilePhoto: profilePhoto
            )

            UserSession.shared.saveAuthenticatedUser(
                user,
                accessToken: authResult.accessToken,
                refreshToken: authResult.refreshToken
            )
            do {
                _ = try await InitialSyncService.shared.performInitialSync(userId: user.user_id)
            } catch {
            }
            do {
                try await IdentificationSyncService.shared.performSync(userId: user.user_id)
            } catch {
            }

            Task {
                try? await UserSyncService.shared.upsertUser(user)
            }

            await WatchlistManager.shared.bindCurrentUserOwnership()
            goToMain()
        } catch {
            showAlert(error.localizedDescription)
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

    private func setLoading(_ isLoading: Bool, button: UIButton) {
        button.isEnabled = !isLoading
        button.alpha = isLoading ? 0.6 : 1.0
    }

    private func fallbackName(from email: String) -> String {
        let username = email.split(separator: "@").first.map(String.init) ?? "User"
        return username.isEmpty ? "User" : username
    }

    private func fetchServerProfile(userID: UUID, accessToken: String?) async throws -> (name: String?, gender: String?, profilePhoto: String?)? {
        guard let accessToken, !accessToken.isEmpty else { return nil }

        let config = try SupabaseConfig.load()
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = "/rest/v1/users"
        components.percentEncodedQuery = "user_id=eq.\(userID.uuidString)&select=name,gender,profile_photo"

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return nil
        }

        struct NameRow: Decodable {
            let name: String?
            let gender: String?
            let profilePhoto: String?

            enum CodingKeys: String, CodingKey {
                case name
                case gender
                case profilePhoto = "profile_photo"
            }
        }
        let rows = try JSONDecoder().decode([NameRow].self, from: data)
        return (rows.first?.name, rows.first?.gender, rows.first?.profilePhoto)
    }

    private func mappedLoginErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("not found")
            || (message.contains("user") && message.contains("invalid"))
            || message.contains("email not found")
            || message.contains("no user")
            || message.contains("user not found")
            || message.contains("not registered")
            || message.contains("invalid login credentials") {
            return "No account found. Please sign up first."
        }
        if message.contains("signup")
            && (message.contains("disabled") || message.contains("required")) {
            return "No account found. Please sign up first."
        }
        return error.localizedDescription
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

    private func showAlert(_ msg: String) {
        let alert = UIAlertController(title: "Alert", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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
