import UIKit

class LoginViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupPassword()
        hideKeyboardWhenTapped()
    }

    // MARK: - Password Setup

    private func setupPassword() {

        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType = .password
        passwordTextField.autocorrectionType = .no
        passwordTextField.autocapitalizationType = .none
        addEyeButton(to: passwordTextField)
    }

    private func addEyeButton(to textField: UITextField) {

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
        passwordTextField.isSecureTextEntry = !sender.isSelected
    }

    // MARK: - Login Button

    @IBAction func loginTapped(_ sender: UIButton) {
        Task { [weak self] in
            await self?.login(button: sender)
        }
    }

    // MARK: - Login Logic

    private func login(button: UIButton) async {

        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespaces),
              let password = passwordTextField.text,
              !email.isEmpty,
              !password.isEmpty else {

            showAlert("Enter email and password")
            return
        }

        guard email.isValidEmail else {
            showAlert("Invalid email")
            return
        }

        setLoading(true, button: button)
        defer { setLoading(false, button: button) }

        do {
            let authResult = try await SupabaseAuthService.shared.signIn(email: email, password: password)

            let displayName: String
            if let existingUser = UserSession.shared.currentUser, existingUser.email == email {
                displayName = existingUser.name
            } else {
                displayName = authResult.displayName ?? fallbackName(from: authResult.email)
            }

            let profilePhoto =
                authResult.profilePhoto
                ?? UserSession.shared.currentUser?.profilePhoto
                ?? "defaultProfile"

            let user = User(
                id: authResult.userID,
                name: displayName,
                gender: "Not Specified",
                email: authResult.email,
                profilePhoto: profilePhoto
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
            goToMain()
        } catch {
            showAlert(error.localizedDescription)
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

    private func showAlert(_ msg: String) {

        let alert = UIAlertController(
            title: "Alert",
            message: msg,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: .default)
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
