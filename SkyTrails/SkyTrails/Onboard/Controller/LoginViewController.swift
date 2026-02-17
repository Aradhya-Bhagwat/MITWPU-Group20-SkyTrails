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
        login()
    }

    // MARK: - Login Logic

    private func login() {

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

        // Get password from Keychain
        guard let savedPassword =
                KeychainManager.shared.getPassword(email: email) else {

            showAlert("Account not found")
            return
        }

        guard savedPassword == password else {
            showAlert("Wrong password")
            return
        }

        // Load user data
        let user = User(
            name: "User",
            gender: "Not Specified",
            email: email,
            profilePhoto: "defaultProfile"
        )

        // Save session
        UserSession.shared.saveUser(user)

        goToMain()
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
