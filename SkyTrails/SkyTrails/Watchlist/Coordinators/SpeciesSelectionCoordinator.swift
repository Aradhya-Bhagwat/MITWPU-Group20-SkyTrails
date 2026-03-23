import UIKit

/// Coordinator responsible for handling the multi-step species selection and observation flow
@MainActor
final class SpeciesSelectionCoordinator {
    
    private weak var navigationController: UINavigationController?
    private let targetWatchlistId: UUID?
    private let shouldUseRuleMatching: Bool
    private let mode: WatchlistMode
    
    private var birdQueue: [Bird] = []
    private var processedBirds: [Bird] = []
    
    init(
        navigationController: UINavigationController?,
        targetWatchlistId: UUID?,
        shouldUseRuleMatching: Bool,
        mode: WatchlistMode
    ) {
        self.navigationController = navigationController
        self.targetWatchlistId = targetWatchlistId
        self.shouldUseRuleMatching = shouldUseRuleMatching
        self.mode = mode
    }
    
    /// Starts the detail loop for the selected birds
    func startDetailLoop(with birds: [Bird]) {
        self.birdQueue = birds
        self.processedBirds = []
        showNextInLoop()
    }
    
    private func showNextInLoop() {
        guard !birdQueue.isEmpty else {
            finalizeLoop()
            return
        }
        let bird = birdQueue.removeFirst()
        showBirdDetail(bird: bird)
    }
    
    private func finalizeLoop() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    private func showBirdDetail(bird: Bird) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        var nextVC: UIViewController?
        
        if mode == .unobserved {
            let vc = storyboard.instantiateViewController(withIdentifier: "UnobservedDetailVC") as! UnobservedDetailViewController
            vc.bird = bird
            vc.watchlistId = targetWatchlistId
            vc.shouldUseRuleMatching = shouldUseRuleMatching
            vc.onSave = { [weak self] savedBird in
                self?.handleSave(bird: savedBird)
            }
            nextVC = vc
        } else {
            let vc = storyboard.instantiateViewController(withIdentifier: "ObservedDetailVC") as! ObservedDetailViewController
            vc.bird = bird
            vc.watchlistId = targetWatchlistId
            vc.shouldUseRuleMatching = shouldUseRuleMatching
            vc.onSave = { [weak self] savedBird in
                self?.handleSave(bird: savedBird)
            }
            nextVC = vc
        }
        
        guard let vc = nextVC else { return }
        updateNavigationStack(pushing: vc)
    }
    
    private func handleSave(bird: Bird) {
        processedBirds.append(bird)
        showNextInLoop()
    }
    
    private func updateNavigationStack(pushing newVC: UIViewController) {
        guard let navigationController = navigationController else { return }
        
        var vcs = navigationController.viewControllers
        if let last = vcs.last, (last is ObservedDetailViewController || last is UnobservedDetailViewController) {
            vcs.removeLast()
        }
        
        vcs.append(newVC)
        navigationController.setViewControllers(vcs, animated: true)
    }
}
