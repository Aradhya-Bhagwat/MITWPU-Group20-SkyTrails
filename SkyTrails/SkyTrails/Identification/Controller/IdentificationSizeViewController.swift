import UIKit

class IdentificationSizeViewController: UIViewController {

    @IBOutlet weak var smallBirdImage: UIImageView!
    @IBOutlet weak var birdSlider: UISlider!
    @IBOutlet weak var birdLabel: UILabel!
    @IBOutlet weak var largeBirdImage: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var largeBirdNameLabel: UILabel!
    @IBOutlet weak var smallBirdNameLabel: UILabel!

    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        birdSlider.minimumValue = 0
        birdSlider.maximumValue = 4
        birdSlider.isContinuous = false
        applySemanticAppearance()
        
        // Load existing selected size from viewModel if available
        let initialSize = viewModel.selectedSizeCategory ?? 0
        birdSlider.value = Float(initialSize)
        updateBirdDisplay(for: initialSize)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        applySemanticAppearance()
    }

    private func applySemanticAppearance() {
        birdLabel.textColor = .label
        smallBirdNameLabel.textColor = .secondaryLabel
        largeBirdNameLabel.textColor = .secondaryLabel
        birdSlider.minimumTrackTintColor = .systemBlue
        birdSlider.maximumTrackTintColor = .systemGray4
        birdSlider.thumbTintColor = .systemBlue
    }
 
    @IBAction func sliderChanged(_ sender: UISlider) {
        let steppedValue = Int(round(sender.value))
        sender.value = Float(steppedValue)
        updateBirdDisplay(for: steppedValue)
        
       
        viewModel.updateSize(steppedValue)
    }

    private func updateBirdDisplay(for index: Int) {
        switch index {
        case 0:
            birdLabel.text = "Flowerpecker–Sparrow sized"
        case 1:
            birdLabel.text = "Munia–Bulbul sized"
        case 2:
            birdLabel.text = "Myna–Peahen sized"
        case 3:
            birdLabel.text = "House Crow–Pond Heron sized"
        case 4:
            birdLabel.text = "Cattle Egret–Sarus Crane sized"
        default:
            birdLabel.text = ""
        }

        let names = sizeImageNames(for: index)
        smallBirdImage.image = UIImage(named: names.small)
        largeBirdImage.image = UIImage(named: names.large)
        
        smallBirdNameLabel.text = extractBirdName(from: names.small)
        largeBirdNameLabel.text = extractBirdName(from: names.large)
    }

    func sizeImageNames(for index: Int) -> (small: String, large: String) {
        switch index {
        case 0: return ("id_size_0_small_flowerpecker", "id_size_0_large_house_sparrow")
        case 1: return ("id_size_1_small_munia", "id_size_1_large_bulbul")
        case 2: return ("id_size_2_small_myna", "id_size_2_large_peahen")
        case 3: return ("id_size_3_small_house_crow", "id_size_3_large_pond_heron")
        case 4: return ("id_size_4_small_cattle_egret", "id_size_4_large_greater_flamingo")
        default: return ("", "")
        }
    }

    private func extractBirdName(from filename: String) -> String {
        let components = filename.components(separatedBy: "_")
        if let smallIndex = components.firstIndex(of: "small") {
            return components.suffix(from: smallIndex + 1).joined(separator: " ").capitalized
        } else if let largeIndex = components.firstIndex(of: "large") {
            return components.suffix(from: largeIndex + 1).joined(separator: " ").capitalized
        }
        return filename.replacingOccurrences(of: "_", with: " ").capitalized
    }

    @IBAction func checkmarkButtonTapped(_ sender: UIBarButtonItem) {
        let selectedIndex = Int(round(birdSlider.value))
        
     
        viewModel.updateSize(selectedIndex)
        
    
        delegate?.didFinishStep()
    }
    
    @IBAction func backButtonTapped(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func infoButtonTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(
            title: "Bird Size Guide",
            message: """
            Compare the bird you saw to these common birds:
            
            • Flowerpecker–Sparrow: Less than 6 inches
            • Munia–Bulbul: 6–14 inches
            • Myna–Peahen: 14–25 inches
            • House Crow–Pond Heron: 25–59 inches
            • Cattle Egret–Sarus Crane: 59 inches and over
            
            Use the slider to select the size category.
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension IdentificationSizeViewController: IdentificationProgressUpdatable {
    func updateProgress(current: Int, total: Int) {
        let percent = Float(current) / Float(total)
        progressView.setProgress(percent, animated: true)
    }
}
