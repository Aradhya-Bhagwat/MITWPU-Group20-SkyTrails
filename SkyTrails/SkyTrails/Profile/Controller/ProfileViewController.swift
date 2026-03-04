//
//  ProfileViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 11/02/26.
//

import UIKit
import Photos
import AVFoundation

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - Outlets

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailButton: UIButton!
    @IBOutlet weak var genderLabel: UILabel!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadUser()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        profileImageView.layer.cornerRadius = profileImageView.bounds.width / 2
    }

    // MARK: - UI Setup

    private func setupUI() {
        profileImageView.layer.cornerRadius = profileImageView.frame.width / 2
        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.isUserInteractionEnabled = true
        navigationItem.title = "Profile"
        addProfileImageTap()
    }

    // MARK: - Load User Data

    private func loadUser() {

        guard let user = UserSession.shared.getUser() else {

            logout()
            return
        }

        nameLabel.text = user.name
        genderLabel.text = "Gender: \(user.gender)"
        emailButton.setTitle(user.email, for: .normal)
        emailButton.configuration?.title = user.email

        if user.profilePhoto.starts(with: "http") {

            loadImage(from: user.profilePhoto)

        } else if user.profilePhoto.starts(with: "file://") || FileManager.default.fileExists(atPath: user.profilePhoto) {
            loadLocalImage(from: user.profilePhoto)

        } else {

            profileImageView.image =
                UIImage(named: user.profilePhoto)
        }
    }

    // MARK: - Logout

    @IBAction func logoutTapped(_ sender: UIButton) {
        logout()
    }

    private func logout() {
        if let accessToken = UserSession.shared.getAccessToken() {
            Task {
                try? await SupabaseAuthService.shared.signOut(accessToken: accessToken)
            }
        }

        UserSession.shared.logout()
        goToLogin()
    }

    // MARK: - Navigation

    private func goToLogin() {

        guard let scene =
                UIApplication.shared.connectedScenes.first
                    as? UIWindowScene,
              let window =
                scene.windows.first(where: { $0.isKeyWindow })
        else { return }

        let storyboard = UIStoryboard(name: "Onboard", bundle: nil)

        let startVC = storyboard.instantiateViewController(
            withIdentifier: "StartViewController"
        )

        window.rootViewController = startVC

        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionFlipFromLeft,
            animations: nil
        )
    }

    private func loadImage(from urlString: String) {

        guard let url = URL(string: urlString) else { return }

        DispatchQueue.global().async {

            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {

                DispatchQueue.main.async {
                    self.profileImageView.image = image
                }
            }
        }
    }

    private func loadLocalImage(from pathOrURLString: String) {
        let fileURL: URL?
        if pathOrURLString.starts(with: "file://") {
            fileURL = URL(string: pathOrURLString)
        } else {
            fileURL = URL(fileURLWithPath: pathOrURLString)
        }

        guard let fileURL, let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else {
            return
        }
        profileImageView.image = image
    }

    private func addProfileImageTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(profileImageTapped))
        profileImageView.addGestureRecognizer(tap)
    }

    @objc private func profileImageTapped() {
        let sheet = UIAlertController(title: "Profile Photo", message: "Choose a source", preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
            self?.openCameraFlow()
        })
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.openPhotoLibraryFlow()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = profileImageView
            popover.sourceRect = profileImageView.bounds
        }

        present(sheet, animated: true)
    }

    private func openCameraFlow() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showMessage("Camera is not available on this device.")
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            presentImagePicker(source: .camera)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentImagePicker(source: .camera)
                    } else {
                        self?.openSystemSettings()
                    }
                }
            }
        case .denied, .restricted:
            openSystemSettings()
        @unknown default:
            openSystemSettings()
        }
    }

    private func openPhotoLibraryFlow() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            presentImagePicker(source: .photoLibrary)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    switch newStatus {
                    case .authorized, .limited:
                        self?.presentImagePicker(source: .photoLibrary)
                    default:
                        self?.openSystemSettings()
                    }
                }
            }
        case .denied, .restricted:
            openSystemSettings()
        @unknown default:
            openSystemSettings()
        }
    }

    private func presentImagePicker(source: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let pickedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            guard let self, let image = pickedImage else { return }
            self.profileImageView.image = image
            self.persistSelectedProfileImage(image)
        }
    }

    private func persistSelectedProfileImage(_ image: UIImage) {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        guard let currentUser = UserSession.shared.getUser() else { return }

        let fileName = "profile_\(currentUser.id.uuidString).jpg"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)

        do {
            try jpeg.write(to: fileURL, options: .atomic)

            var updatedUser = currentUser
            updatedUser.profilePhoto = fileURL.absoluteString
            UserSession.shared.saveUser(updatedUser)
            NotificationCenter.default.post(name: UserSession.authStateDidChangeNotification, object: nil)

            Task {
                try? await UserSyncService.shared.upsertUser(updatedUser)
                if let remoteURL = try? await uploadProfileImageToStorage(data: jpeg, userID: currentUser.id) {
                    var remoteUpdatedUser = updatedUser
                    remoteUpdatedUser.profilePhoto = remoteURL
                    UserSession.shared.saveUser(remoteUpdatedUser)
                    NotificationCenter.default.post(name: UserSession.authStateDidChangeNotification, object: nil)
                    try? await UserSyncService.shared.upsertUser(remoteUpdatedUser)
                }
            }
        } catch {
            showMessage("Failed to save profile photo.")
        }
    }

    private func uploadProfileImageToStorage(data: Data, userID: UUID) async throws -> String {
        let config = try SupabaseConfig.load()
        guard let token = UserSession.shared.getAccessToken() else {
            throw NSError(domain: "ProfileUpload", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing auth token"])
        }

        let fileName = "avatar_\(Int(Date().timeIntervalSince1970)).jpg"
        let path = "\(userID.uuidString)/\(fileName)"

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "ProfileUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid project URL"])
        }
        components.path = "/storage/v1/object/photos/\(path)"

        guard let url = components.url else {
            throw NSError(domain: "ProfileUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")

        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 409 else {
            throw NSError(domain: "ProfileUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Profile upload failed"])
        }

        return config.projectURL
            .appendingPathComponent("storage/v1/object/public/photos/\(path)")
            .absoluteString
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            showMessage("Unable to open settings.")
            return
        }
        UIApplication.shared.open(url)
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "Profile", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
