//
//  LoginViewController.swift
//  SkyTrails
//
//  Created by Aradhya Bhagwat on 11/01/26.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    @IBAction func loginButtonTapped(_ sender: UIButton) {
        validateAndLogin()
    }

    private func validateAndLogin() {
        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = passwordTextField.text,
              !email.isEmpty,
              !password.isEmpty else {
            showAlert(message: "Please enter email and password")
            return
        }

        guard email.isValidEmail else {
            showAlert(message: "Please enter a valid email address")
            return
        }

        goToMainApp()
    }

    private func goToMainApp() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let tabBar = storyboard.instantiateViewController(
            identifier: "RootTabBarController"
        ) as! RootTabBarController

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        window.rootViewController = tabBar
        window.makeKeyAndVisible()
    }

    private func showAlert(title: String = "Invalid Input", message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
extension String {
    var isValidEmail: Bool {
        let emailRegex =
        #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex)
            .evaluate(with: self)
    }
}
