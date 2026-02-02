import UIKit

class SignUpViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!

    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPasswords()
    }

    private func setupPasswords() {

        passwordTextField.isSecureTextEntry = true
        confirmPasswordTextField.isSecureTextEntry = true

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
            action: #selector(toggle(_:)),
            for: .touchUpInside
        )

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))

        button.center = container.center
        container.addSubview(button)

        textField.rightView = container
        textField.rightViewMode = .always
    }

    @objc private func toggle(_ sender: UIButton) {

        sender.isSelected.toggle()

        if let container = sender.superview,
           let field = container.superview as? UITextField {

            field.isSecureTextEntry = !sender.isSelected
        }
    }

    // MARK: - Signup

    @IBAction func signupTapped(_ sender: UIButton) {
        register()
    }

    private func register() {

        guard let name = nameTextField.text, !name.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let pass = passwordTextField.text,
              let confirm = confirmPasswordTextField.text else {

            show("Fill all fields")
            return
        }

        guard email.isValidEmail else {
            show("Invalid email")
            return
        }

        guard pass == confirm else {
            show("Passwords do not match")
            return
        }

        let saved = KeychainManager.shared.save(
            email: email,
            password: pass
        )

        if saved {

            show("Account created!") {
                self.dismiss(animated: true)
            }

        } else {
            show("Signup failed")
        }
    }

    private func show(_ msg: String,
                      completion: (() -> Void)? = nil) {

        let alert = UIAlertController(
            title: "Alert",
            message: msg,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })

        present(alert, animated: true)
    }
}
