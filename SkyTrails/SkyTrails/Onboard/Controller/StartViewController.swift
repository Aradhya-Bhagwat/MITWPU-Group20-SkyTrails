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
        ) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("Google Error:", error.localizedDescription)
                self.showAlert("Google login failed")
                return
            }

            guard let googleUser = result?.user else {
                self.showAlert("Login Failed")
                return
            }

            guard let idToken = googleUser.idToken?.tokenString else {
                self.showAlert("Google token missing")
                return
            }

            let email = googleUser.profile?.email ?? ""
            let name = googleUser.profile?.name ?? ""
            let accessToken = googleUser.accessToken.tokenString

            // Get Google profile image URL
            let imageURL =
                googleUser.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""

            Task { @MainActor in
                do {
                    let authResult = try await SupabaseAuthService.shared.signInWithGoogle(
                        idToken: idToken,
                        accessToken: accessToken,
                        fallbackEmail: email,
                        fallbackName: name,
                        fallbackProfilePhoto: imageURL
                    )

                    let user = User(
                        id: authResult.userID,
                        name: authResult.displayName ?? name,
                        gender: "Not Specified",
                        email: authResult.email.isEmpty ? email : authResult.email,
                        profilePhoto: authResult.profilePhoto ?? (imageURL.isEmpty ? "defaultProfile" : imageURL)
                    )

                    UserSession.shared.saveAuthenticatedUser(
                        user,
                        accessToken: authResult.accessToken,
                        refreshToken: authResult.refreshToken
                    )

                    Task {
                        try? await UserSyncService.shared.upsertUser(user)
                    }

                } catch {
                    self.showAlert(error.localizedDescription)
                    return
                }

                await WatchlistManager.shared.bindCurrentUserOwnership()
                self.goToMain()
            }
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
