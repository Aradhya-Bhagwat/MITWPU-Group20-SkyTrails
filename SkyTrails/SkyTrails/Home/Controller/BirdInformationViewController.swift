import MapKit
import SafariServices
import SwiftData
import UIKit

final class BirdInformationViewController: UIViewController {
    var speciesCode: String?
    var commonName: String?
    var scientificName: String?
    var imageName: String?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let scientificNameLabel = UILabel()
    private let rangeMapView = MKMapView()
    private let rangeStatusLabel = UILabel()
    private var rangeOverlays: [MKOverlay] = []

    private var referenceInfo: BirdReferenceInfo?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Bird Info"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeTapped)
        )

        setupLayout()
        loadReferenceInfo()
        renderContent()
        loadImage()
        loadRangeMapIfPossible()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 28, right: 20)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func loadReferenceInfo() {
        guard let code = speciesCode, !code.isEmpty else { return }
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<BirdReferenceInfo>(
            predicate: #Predicate { $0.speciesCode == code }
        )
        referenceInfo = try? context.fetch(descriptor).first
    }

    private func renderContent() {
        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let displayName = referenceInfo?.commonName ?? commonName ?? "Unknown Bird"
        let latinName = referenceInfo?.scientificName ?? scientificName

        contentStack.addArrangedSubview(makeHeader(displayName: displayName, scientificName: latinName))

        let taxonomyRows = [
            ("Family", referenceInfo?.family),
            ("Order", referenceInfo?.orderName),
            ("Genus", referenceInfo?.genus),
            ("Size", referenceInfo?.size),
            ("Weight", referenceInfo?.weight)
        ].compactMap { title, value in
            normalized(value).map { (title, $0) }
        }
        if !taxonomyRows.isEmpty {
            contentStack.addArrangedSubview(makeKeyValueSection(title: "Profile", rows: taxonomyRows))
        }

        contentStack.addArrangedSubview(makeTextSection(
            title: "Field Marks",
            text: normalized(referenceInfo?.fieldMarks) ?? "Field marks are not available offline for this species yet."
        ))

        addOptionalTextSection(title: "Habitat", text: referenceInfo?.habitat)
        addOptionalTextSection(title: "Behavior", text: referenceInfo?.behavior)
        addOptionalTextSection(title: "Similar Species", text: referenceInfo?.similarSpecies)
        addOptionalTextSection(title: "Notes", text: referenceInfo?.notes)

        contentStack.addArrangedSubview(makeRangeSection())

        if let sourceURL = referenceInfo?.sourceURL, URL(string: sourceURL) != nil {
            contentStack.addArrangedSubview(makeSourceButton(sourceURL: sourceURL))
        }
    }

    private func makeHeader(displayName: String, scientificName: String?) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 12

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .secondarySystemBackground
        imageView.image = UIImage(systemName: "bird.fill")
        imageView.tintColor = .secondaryLabel

        titleLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle).withWeight(.bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.text = displayName

        scientificNameLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        scientificNameLabel.textColor = .secondaryLabel
        scientificNameLabel.numberOfLines = 0
        scientificNameLabel.text = scientificName

        container.addArrangedSubview(imageView)
        container.addArrangedSubview(titleLabel)
        if normalized(scientificName) != nil {
            container.addArrangedSubview(scientificNameLabel)
        }

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 240)
        ])

        return container
    }

    private func makeKeyValueSection(title: String, rows: [(String, String)]) -> UIView {
        let stack = makeSectionStack(title: title)
        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .firstBaseline
            rowStack.spacing = 12

            let keyLabel = UILabel()
            keyLabel.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
            keyLabel.textColor = .secondaryLabel
            keyLabel.text = row.0
            keyLabel.setContentHuggingPriority(.required, for: .horizontal)
            keyLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 74).isActive = true

            let valueLabel = UILabel()
            valueLabel.font = UIFont.preferredFont(forTextStyle: .body)
            valueLabel.textColor = .label
            valueLabel.numberOfLines = 0
            valueLabel.text = row.1

            rowStack.addArrangedSubview(keyLabel)
            rowStack.addArrangedSubview(valueLabel)
            stack.addArrangedSubview(rowStack)
        }
        return wrapSection(stack)
    }

    private func makeTextSection(title: String, text: String) -> UIView {
        let stack = makeSectionStack(title: title)
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.numberOfLines = 0
        label.text = text
        stack.addArrangedSubview(label)
        return wrapSection(stack)
    }

    private func makeRangeSection() -> UIView {
        let stack = makeSectionStack(title: "Range Map")

        rangeMapView.delegate = self
        rangeMapView.translatesAutoresizingMaskIntoConstraints = false
        rangeMapView.layer.cornerRadius = 8
        rangeMapView.clipsToBounds = true
        rangeMapView.isRotateEnabled = false
        rangeMapView.isPitchEnabled = false

        rangeStatusLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        rangeStatusLabel.textColor = .secondaryLabel
        rangeStatusLabel.numberOfLines = 0
        rangeStatusLabel.text = speciesCode == nil
            ? "Range map needs an eBird species code."
            : "Loading online range map..."

        stack.addArrangedSubview(rangeMapView)
        stack.addArrangedSubview(rangeStatusLabel)

        NSLayoutConstraint.activate([
            rangeMapView.heightAnchor.constraint(equalToConstant: 220)
        ])

        return wrapSection(stack)
    }

    private func makeSourceButton(sourceURL: String) -> UIView {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "safari")
        configuration.title = "Wikipedia Source"
        configuration.imagePadding = 8

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.addAction(UIAction { [weak self] _ in
            guard let self, let url = URL(string: sourceURL) else { return }
            self.present(SFSafariViewController(url: url), animated: true)
        }, for: .touchUpInside)
        return button
    }

    private func addOptionalTextSection(title: String, text: String?) {
        guard let value = normalized(text) else { return }
        contentStack.addArrangedSubview(makeTextSection(title: title, text: value))
    }

    private func makeSectionStack(title: String) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.text = title

        stack.addArrangedSubview(label)
        return stack
    }

    private func wrapSection(_ stack: UIStackView) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])

        return container
    }

    private func loadImage() {
        guard let imageName else { return }
        Task { @MainActor in
            if let image = await ImageService.shared.image(for: imageName) {
                imageView.image = image
            }
        }
    }

    private func loadRangeMapIfPossible() {
        guard let speciesCode, !speciesCode.isEmpty else { return }

        Task {
            do {
                let week = Calendar.current.component(.weekOfYear, from: Date())
                guard let geoJSONString = try await SkyTrailsAPIService.shared.fetchSpeciesRange(
                    ebirdSpeciesCode: speciesCode,
                    weekNumber: week
                ) else {
                    await MainActor.run {
                        rangeStatusLabel.text = "No online range map is available for the current week."
                    }
                    return
                }

                guard let data = geoJSONString.data(using: .utf8) else { return }
                let features = try MKGeoJSONDecoder().decode(data)

                await MainActor.run {
                    self.addRangeFeatures(features)
                    self.rangeStatusLabel.text = "Online range map for week \(week)."
                }
            } catch {
                await MainActor.run {
                    self.rangeStatusLabel.text = "Range map is unavailable offline."
                }
            }
        }
    }

    private func addRangeFeatures(_ features: [MKGeoJSONObject]) {
        rangeMapView.removeOverlays(rangeOverlays)
        rangeOverlays.removeAll()

        for feature in features {
            guard let feature = feature as? MKGeoJSONFeature else { continue }
            for geometry in feature.geometry {
                guard let overlay = geometry as? MKOverlay else { continue }
                rangeMapView.addOverlay(overlay, level: .aboveRoads)
                rangeOverlays.append(overlay)
            }
        }

        let rect = rangeOverlays.reduce(MKMapRect.null) { partial, overlay in
            partial.union(overlay.boundingMapRect)
        }
        if !rect.isNull {
            rangeMapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
                animated: false
            )
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: pointSize, weight: weight)
    }
}

extension BirdInformationViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.3)
            renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9)
            renderer.lineWidth = 2.5
            return renderer
        }
        if let multiPolygon = overlay as? MKMultiPolygon {
            let renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)
            renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.3)
            renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9)
            renderer.lineWidth = 2.5
            return renderer
        }
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9)
            renderer.lineWidth = 2.5
            return renderer
        }
        if let multiPolyline = overlay as? MKMultiPolyline {
            let renderer = MKMultiPolylineRenderer(multiPolyline: multiPolyline)
            renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9)
            renderer.lineWidth = 2.5
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}
