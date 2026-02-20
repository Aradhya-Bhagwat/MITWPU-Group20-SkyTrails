import UIKit

class SignUpViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!

    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupPasswords()
        hideKeyboardWhenTapped()
    }

    // MARK: - Password Setup

    private func setupPasswords() {

        passwordTextField.isSecureTextEntry = true
        confirmPasswordTextField.isSecureTextEntry = true

        passwordTextField.textContentType = .newPassword
        confirmPasswordTextField.textContentType = .oneTimeCode

        passwordTextField.autocorrectionType = .no
        confirmPasswordTextField.autocorrectionType = .no
        passwordTextField.autocapitalizationType = .none
        confirmPasswordTextField.autocapitalizationType = .none

        addEye(to: passwordTextField)
        addEye(to: confirmPasswordTextField)
    }

    private func addEye(to textField: UITextField) {

        let button = UIButton(type: .custom)

        button.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        button.setImage(UIImage(systemName: "eye"), for: .selected)

        button.tintColor = .gray
        button.frame = CGRect(x: 0, y: 0, width: 25, height: 25)

        button.addTarget(
            self,
            action: #selector(togglePassword(_:)),
            for: .touchUpInside
        )

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))

        button.center = container.center
        container.addSubview(button)

        textField.rightView = container
        textField.rightViewMode = .always
    }

    @objc private func togglePassword(_ sender: UIButton) {

        sender.isSelected.toggle()

        if let container = sender.superview,
           let field = container.superview as? UITextField {

            field.isSecureTextEntry = !sender.isSelected
        }
    }

    // MARK: - Signup Button

    @IBAction func signupTapped(_ sender: UIButton) {
        Task { [weak self] in
            await self?.register(button: sender)
        }
    }

    // MARK: - Register Logic

    private func register(button: UIButton) async {

        guard let name = nameTextField.text?.trimmingCharacters(in: .whitespaces),
              let email = emailTextField.text?.trimmingCharacters(in: .whitespaces),
              let pass = passwordTextField.text,
              let confirm = confirmPasswordTextField.text,
              !name.isEmpty,
              !email.isEmpty,
              !pass.isEmpty,
              !confirm.isEmpty else {

            show("Please fill all fields")
            return
        }

        guard email.isValidEmail else {
            show("Invalid email address")
            return
        }

        guard pass.count >= 6 else {
            show("Password must be at least 6 characters")
            return
        }

        guard pass == confirm else {
            show("Passwords do not match")
            return
        }

        setLoading(true, button: button)
        defer { setLoading(false, button: button) }

        do {
            let authResult = try await SupabaseAuthService.shared.signUp(
                name: name,
                email: email,
                password: pass
            )

            if authResult.hasSession {
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
            } else {
                show("Account created. Please verify your email before logging in.")
            }
        } catch {
            show(error.localizedDescription)
        }
    }

    private func setLoading(_ isLoading: Bool, button: UIButton) {
        button.isEnabled = !isLoading
        button.alpha = isLoading ? 0.6 : 1.0
    }

    // MARK: - Navigation

    private func goToMain() {

        guard let scene =
                UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window =
                scene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        let mainVC = storyboard.instantiateViewController(
            withIdentifier: "RootTabBarController"
        )

        window.rootViewController = mainVC

        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionFlipFromRight,
            animations: nil
        )
    }

    // MARK: - Alert

    private func show(_ msg: String,
                      completion: (() -> Void)? = nil) {

        let alert = UIAlertController(
            title: "Alert",
            message: msg,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { _ in
                completion?()
            }
        )

        present(alert, animated: true)
    }

    // MARK: - Keyboard

    private func hideKeyboardWhenTapped() {

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )

        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}
