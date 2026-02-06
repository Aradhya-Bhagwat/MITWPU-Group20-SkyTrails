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
import AuthenticationServices

class StartViewController: UIViewController,
                           ASAuthorizationControllerDelegate,
                           ASAuthorizationControllerPresentationContextProviding {

    // MARK: - Outlets

    @IBOutlet weak var segmentOutlet: UISegmentedControl!

    @IBOutlet weak var loginSegmentView: UIView!
    @IBOutlet weak var signupSegmentView: UIView!
    @IBOutlet weak var appleImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.bringSubviewToFront(signupSegmentView)
        setupAppleLogin()
    }


    @IBAction func segmentChanged(_ sender: UISegmentedControl) {

        switch sender.selectedSegmentIndex {

        case 0:
            view.bringSubviewToFront(signupSegmentView)

        case 1:
            view.bringSubviewToFront(loginSegmentView)

        default:
            break
        }
    }


    // MARK: - Apple Login Setup (ImageView)

    private func setupAppleLogin() {
        appleImageView.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(appleLoginTapped)
        )

        appleImageView.addGestureRecognizer(tap)
    }


    // MARK: - Apple Login Action

    @objc private func appleLoginTapped() {

        let provider = ASAuthorizationAppleIDProvider()

        let request = provider.createRequest()

        // Ask for user info
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(
            authorizationRequests: [request]
        )

        controller.delegate = self
        controller.presentationContextProvider = self

        controller.performRequests()
    }


    // MARK: - Apple Login Success / Failure

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {

        guard let credential =
                authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        let userID = credential.user
        let email = credential.email ?? "apple_user"

        // Save login session
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(email, forKey: "userEmail")
        UserDefaults.standard.set(userID, forKey: "appleUserID")

        goToMain()
    }


    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {

        showAlert("Apple Login Failed")
        print("Apple SignIn Error:", error.localizedDescription)
    }


    // MARK: - Apple Presentation

    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {

        return self.view.window!
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
            identifier: "RootTabBarController"
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
