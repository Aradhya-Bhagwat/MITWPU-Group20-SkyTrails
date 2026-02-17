//
//  OnboardViewController.swift
//  SkyTrails
//
//  Created by Aradhya Bhagwat on 11/01/26.
//

//
//  StartViewController.swift
//  SkyTrails
//

//
//  StartViewController.swift
//  SkyTrails
//

import UIKit
import GoogleSignIn

class StartViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var segmentOutlet: UISegmentedControl!
    @IBOutlet weak var loginSegmentView: UIView!
    @IBOutlet weak var signupSegmentView: UIView!
    @IBOutlet weak var googleImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.bringSubviewToFront(signupSegmentView)

        setupGoogleLogin()
    }

    // MARK: - Segment Control

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {

        if sender.selectedSegmentIndex == 0 {
            view.bringSubviewToFront(signupSegmentView)
        } else {
            view.bringSubviewToFront(loginSegmentView)
        }
    }

    // MARK: - Google Setup

    private func setupGoogleLogin() {

        googleImageView.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(googleLoginTapped)
        )

        googleImageView.addGestureRecognizer(tap)
    }

    // MARK: - Google Login

    @objc private func googleLoginTapped() {

        guard let clientID =
            Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
        else {
            showAlert("Google Client ID missing")
            return
        }

        let config = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(
            withPresenting: self
        ) { result, error in

            if let error = error {
                print("Google Error:", error.localizedDescription)
                self.showAlert("Google Login Failed")
                return
            }

            guard let user = result?.user else {
                self.showAlert("Login Failed")
                return
            }

            let email = user.profile?.email ?? ""
            let name = user.profile?.name ?? ""

            // Get Google profile image URL
            let imageURL =
                user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""

            print("Google Photo:", imageURL)

            // Create User model
            let googleUser = User(
                name: name,
                gender: "Not Specified",
                email: email,
                profilePhoto: imageURL
            )

            // Save session
            UserSession.shared.saveUser(googleUser)

            self.goToMain()
        }
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
}
