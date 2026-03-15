import UIKit

final class ProfileSettingsViewController: UIViewController {

    private enum Keys {
        static let profileVisibility = "profile_visibility"
        static let colorMode = "profile_color_mode"
    }

    private let contentStack = UIStackView()
    private let visibilityValueLabel = UILabel()
    private let colorModeValueLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private weak var profileRowView: UIView?
    private weak var colorModeRowView: UIView?

    private var selectedVisibility: String = "Public"
    private var selectedColorMode: String = "System Default"

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        loadStoredValues()
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Profile"

        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentStack)

        let profileRow = makeSelectionRow(title: "Profile", valueLabel: visibilityValueLabel, action: #selector(profileTapped))
        let colorModeRow = makeSelectionRow(title: "Color Mode", valueLabel: colorModeValueLabel, action: #selector(colorModeTapped))
        profileRowView = profileRow
        colorModeRowView = colorModeRow
        contentStack.addArrangedSubview(profileRow)
        contentStack.addArrangedSubview(colorModeRow)
        contentStack.addArrangedSubview(makeActionRow(title: "Manage Permissions", systemImage: "lock.shield", action: #selector(managePermissionsTapped)))
        contentStack.addArrangedSubview(makeResetRow(title: "Clear My Watchlist", action: #selector(clearMyWatchlistTapped)))

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.backgroundColor = .systemBlue
        saveButton.layer.cornerRadius = 12
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),

            saveButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            saveButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func makeSelectionRow(title: String, valueLabel: UILabel, action: Selector) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = .secondarySystemBackground
        row.layer.cornerRadius = 16
        row.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = .systemBlue
        valueLabel.textAlignment = .right

        let chevron = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = .systemBlue
        chevron.contentMode = .scaleAspectFit

        row.addSubview(titleLabel)
        row.addSubview(valueLabel)
        row.addSubview(chevron)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14),
            valueLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -6),
            valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])

        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        row.isUserInteractionEnabled = true
        return row
    }

    private func makeActionRow(title: String, systemImage: String, action: Selector) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = .secondarySystemBackground
        row.layer.cornerRadius = 16
        row.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let icon = UIImageView(image: UIImage(systemName: systemImage))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .systemBlue

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = .systemBlue

        row.addSubview(icon)
        row.addSubview(label)
        row.addSubview(chevron)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 16)
        ])

        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        row.isUserInteractionEnabled = true
        return row
    }

    private func makeResetRow(title: String, action: Selector) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = .secondarySystemBackground
        row.layer.cornerRadius = 18
        row.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .systemRed

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = .systemRed

        row.addSubview(label)
        row.addSubview(chevron)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 16)
        ])

        row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        row.isUserInteractionEnabled = true
        return row
    }

    private func loadStoredValues() {
        selectedVisibility = UserDefaults.standard.string(forKey: Keys.profileVisibility) ?? "Public"
        selectedColorMode = UserDefaults.standard.string(forKey: Keys.colorMode) ?? "System Default"
        visibilityValueLabel.text = selectedVisibility
        colorModeValueLabel.text = selectedColorMode
    }

    @objc private func profileTapped() {
        presentSingleChoice(
            title: "Profile",
            options: ["Public", "Private"],
            currentValue: selectedVisibility,
            sourceView: profileRowView
        ) { [weak self] value in
            self?.selectedVisibility = value
            self?.visibilityValueLabel.text = value
        }
    }

    @objc private func colorModeTapped() {
        presentSingleChoice(
            title: "Color Mode",
            options: ["System Default", "Light", "Dark"],
            currentValue: selectedColorMode,
            sourceView: colorModeRowView
        ) { [weak self] value in
            self?.selectedColorMode = value
            self?.colorModeValueLabel.text = value
        }
    }

    @objc private func managePermissionsTapped() {
        openSystemSettings()
    }

    @objc private func clearMyWatchlistTapped() {
        presentResetConfirmation(
            title: "Clear My Watchlist",
            message: "Are you sure you want to clear My Watchlist? This action cannot be undone."
        ) { [weak self] in
            self?.clearMyWatchlist()
        }
    }

    @objc private func saveTapped() {
        UserDefaults.standard.set(selectedVisibility, forKey: Keys.profileVisibility)
        UserDefaults.standard.set(selectedColorMode, forKey: Keys.colorMode)
        ThemeService.applyTheme(named: selectedColorMode)
        navigationController?.popViewController(animated: true)
    }

    private func presentSingleChoice(
        title: String,
        options: [String],
        currentValue: String,
        sourceView: UIView?,
        onSelect: @escaping (String) -> Void
    ) {
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            let actionTitle = option == currentValue ? "\(option) ✓" : option
            sheet.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
                onSelect(option)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView ?? view
            popover.sourceRect = sourceView?.bounds ?? CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func presentResetConfirmation(title: String, message: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            onConfirm()
        })
        present(alert, animated: true)
    }

    private func clearMyWatchlist() {
        Task { @MainActor in
            do {
                let manager = WatchlistManager.shared
                let customWatchlists = try manager.fetchWatchlists(type: .custom)
                let target = customWatchlists.first(where: { ($0.title ?? "").caseInsensitiveCompare("My Watchlist") == .orderedSame })
                guard let watchlist = target else {
                    self.showMessage("My Watchlist not found.")
                    return
                }
                let observed = try manager.fetchEntries(watchlistID: watchlist.watchlist_id, status: .observed)
                let toObserve = try manager.fetchEntries(watchlistID: watchlist.watchlist_id, status: .to_observe)
                for entry in observed + toObserve {
                    try manager.deleteEntry(entryId: entry.id)
                }
                self.showMessage("My Watchlist cleared.")
            } catch {
                self.showMessage("Could not clear My Watchlist.")
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "Settings", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
