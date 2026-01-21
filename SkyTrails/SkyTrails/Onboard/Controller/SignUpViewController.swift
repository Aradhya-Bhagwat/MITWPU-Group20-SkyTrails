//
//  SignUpViewController.swift
//  SkyTrails
//
//  Created by Aradhya Bhagwat on 11/01/26.
//

import UIKit

class SignUpViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupPasswordFields()
    }

    private func setupPasswordFields() {
        passwordTextField.isSecureTextEntry = true
        confirmPasswordTextField.isSecureTextEntry = true

        addPasswordToggle(to: passwordTextField)
        addPasswordToggle(to: confirmPasswordTextField)
    }

    private func addPasswordToggle(to textField: UITextField) {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        button.setImage(UIImage(systemName: "eye"), for: .selected)
        button.tintColor = .gray
        button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        button.addTarget(self, action: #selector(togglePasswordVisibility(_:)), for: .touchUpInside)

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        button.center = container.center
        container.addSubview(button)

        textField.rightView = container
        textField.rightViewMode = .always
    }

    @objc private func togglePasswordVisibility(_ sender: UIButton) {
        sender.isSelected.toggle()
        if let textField = sender.superview as? UITextField {
            textField.isSecureTextEntry = !sender.isSelected
        }
    }
}
