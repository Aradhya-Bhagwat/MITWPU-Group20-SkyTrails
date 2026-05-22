import UIKit

@objc enum TourStep: Int {
    case none = -1
    // Member Flow
    case welcome = 0
    case homeViewMigration
    case watchlistDashboard
    case identificationWizard
    case profileLocation
    
    // Guest Flow
    case guestWelcome = 100
    case guestHomeMigration
    case guestHomeNews
    case guestSignupPrompt
    
    case completed = 1000
}

final class AppTourManager: NSObject {
    static let shared = AppTourManager()
    
    private(set) var currentStep: TourStep = .none
    private var activeOverlay: TourOverlayView?
    private weak var currentViewController: UIViewController?
    private var isTransitioning = false
    private var retryCount = 0
    
    private override init() {
        super.init()
        let onboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let guest = UserDefaults.standard.bool(forKey: "hasCompletedGuestTour")
        print("TOUR: Initialized. Onboarding completed: \(onboarding), Guest tour completed: \(guest)")
        
        if onboarding {
            currentStep = .completed
        } else {
            currentStep = .none
        }
    }
    
    var isTourActive: Bool {
        return currentStep != .none && currentStep != .completed
    }
    
    func startTour(from vc: UIViewController) {
        guard !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { 
            print("TOUR: Skipping member tour - already completed")
            return 
        }
        print("TOUR: Starting member tour from \(type(of: vc))")
        currentViewController = vc
        currentStep = .welcome
        showCurrentStep()
    }
    
    func startGuestTour(from vc: UIViewController) {
        guard !UserDefaults.standard.bool(forKey: "hasCompletedGuestTour") else { 
            print("TOUR: Skipping guest tour - already completed")
            return 
        }
        print("TOUR: Starting guest tour from \(type(of: vc))")
        currentViewController = vc
        currentStep = .guestWelcome
        showCurrentStep()
    }
    
    func skipTour() {
        print("TOUR: User skipped tour at step \(currentStep)")
        cleanup()
        if currentStep.rawValue >= 100 {
            UserDefaults.standard.set(true, forKey: "hasCompletedGuestTour")
        } else {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(false, forKey: "isNewSignUp")
        }
        currentStep = .completed
    }
    
    func completeTour() {
        print("TOUR: Tour completed!")
        cleanup()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "isNewSignUp")
        currentStep = .completed
        
        if let topVC = getTopMostViewController() {
            let alert = UIAlertController(
                title: "You're Ready to Fly! 🦅🎉",
                message: "Skippy says: 'Woot! You're an expert now!' 🦜✨\n\nGo explore the wonderful world of birds. Don't forget to check out the secret game in your profile when you need a break! Happy birding! 🌲🔭",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Let's Go! 🚀", style: .default))
            topVC.present(alert, animated: true)
        }
    }
    
    func advanceStep(to nextStep: TourStep) {
        guard isTourActive, !isTransitioning else { return }
        print("TOUR: Advancing from \(currentStep) to \(nextStep)")
        currentStep = nextStep
        isTransitioning = true
        retryCount = 0
        
        // Give the UI a moment to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.isTransitioning = false
            self?.showCurrentStep()
        }
    }
    
    private func showCurrentStep() {
        guard isTourActive else { 
            print("TOUR: showCurrentStep cancelled - tour is inactive (step: \(currentStep))")
            return 
        }
        
        guard let window = getActiveWindow() else {
            if retryCount < 5 {
                retryCount += 1
                print("TOUR: Window not found, retrying in 0.5s... (Attempt \(retryCount))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showCurrentStep()
                }
            } else {
                print("TOUR: Error - Could not find active window after retries")
            }
            return
        }
        
        cleanup()
        print("TOUR: ---> Showing step \(currentStep)")
        
        switch currentStep {
        case .welcome: showWelcomeStep()
        case .homeViewMigration: showHomeViewMigrationStep()
        case .watchlistDashboard: showWatchlistDashboardStep()
        case .identificationWizard: showIdentificationWizardStep()
        case .profileLocation: showProfileLocationStep()
            
        case .guestWelcome: showGuestWelcomeStep()
        case .guestHomeMigration: showGuestHomeMigrationStep()
        case .guestHomeNews: showGuestHomeNewsStep()
        case .guestSignupPrompt: showGuestSignupPromptStep()
            
        case .completed, .none:
            cleanup()
        @unknown default:
            cleanup()
        }
    }
    
    private func cleanup() {
        if let active = activeOverlay {
            active.removeFromSuperview()
        }
        activeOverlay = nil
    }
    
    // MARK: - Member Flow Steps
    
    private func showWelcomeStep() {
        guard let window = getActiveWindow() else { return }
        let overlay = TourOverlayView(frame: window.bounds)
        activeOverlay = overlay
        window.addSubview(overlay)
        
        overlay.configure(
            title: "Welcome to SkyTrails! 🐦✨",
            text: "Hi, I'm Skippy! 🦜 Your personal birding buddy.\n\nI'm so excited to show you around! We'll explore migrations, watchlists, and some cool tools. It'll only take a minute!",
            stepIndex: 1, totalSteps: 5, targetView: nil, nextButtonTitle: "Let's Fly! 🚀",
            onNext: { [weak self] in self?.advanceStep(to: .homeViewMigration) },
            onSkip: { [weak self] in self?.skipTour() }
        )
    }
    
    private func showHomeViewMigrationStep() {
        guard let window = getActiveWindow() else { return }
        
        // Ensure we are on Home tab
        if let tabBar = getTabBarController() {
            tabBar.selectedIndex = 0
        }
        
        var targetView: UIView?
        if let nav = getTabBarController()?.viewControllers?[0] as? UINavigationController,
           let homeVC = nav.topViewController as? HomeViewController {
            self.currentViewController = homeVC
            homeVC.loadViewIfNeeded()
            let indexPath = IndexPath(item: 0, section: 0)
            targetView = homeVC.homeCollectionView?.cellForItem(at: indexPath)
        }
        
        let overlay = TourOverlayView(frame: window.bounds)
        activeOverlay = overlay
        window.addSubview(overlay)
        
        overlay.configure(
            title: "Live Migration Maps! 🗺️",
            text: "This is your Home base! These cards show real-time migration predictions specifically for your location.\n\nTap them to see detailed flight paths and peak arrival times for different species!",
            stepIndex: 2, totalSteps: 5, targetView: targetView, nextButtonTitle: "Next: Watchlists →",
            onNext: { [weak self] in self?.advanceStep(to: .watchlistDashboard) },
            onSkip: { [weak self] in self?.skipTour() }
        )
    }
    
    private func showWatchlistDashboardStep() {
        guard let tabBarController = getTabBarController() else { 
            advanceStep(to: .identificationWizard)
            return 
        }
        
        print("TOUR: Switching to Watchlist tab...")
        tabBarController.selectedIndex = 1
        
        // Wait for tab switch and view layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self, self.isTourActive else { return }
            guard let window = self.getActiveWindow() else { return }
            
            var targetView: UIView?
            if let nav = tabBarController.viewControllers?[1] as? UINavigationController {
                if let watchlistVC = nav.topViewController as? WatchlistHomeViewController {
                    print("TOUR: Found WatchlistHomeViewController")
                    self.currentViewController = watchlistVC
                    watchlistVC.loadViewIfNeeded()
                    targetView = watchlistVC.summaryCardCollectionView?.cellForItem(at: IndexPath(item: 0, section: 0))
                } else {
                    targetView = nil
                }
            }
            
            let overlay = TourOverlayView(frame: window.bounds)
            self.activeOverlay = overlay
            window.addSubview(overlay)
            
            overlay.configure(
                title: "Your Personal Watchlists! 📝🐦",
                text: "Never miss a rare bird again! Create watchlists for your favorite spots or species.\n\nWe'll send you a 'Skippy Alert' 🦜 whenever your tracked birds are predicted to arrive nearby!",
                stepIndex: 3, totalSteps: 5, targetView: targetView, nextButtonTitle: "Next: Species ID →",
                onNext: { [weak self] in self?.advanceStep(to: .identificationWizard) },
                onSkip: { [weak self] in self?.skipTour() }
            )
        }
    }
    
    private func showIdentificationWizardStep() {
        guard let tabBarController = getTabBarController() else { 
            advanceStep(to: .profileLocation)
            return 
        }
        
        print("TOUR: Switching to Identification tab...")
        tabBarController.selectedIndex = 2
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self, self.isTourActive else { return }
            guard let window = self.getActiveWindow() else { return }
            
            var targetView: UIView?
            if let nav = tabBarController.viewControllers?[2] as? UINavigationController {
                if let identVC = nav.topViewController as? IdentificationViewController {
                    print("TOUR: Found IdentificationViewController")
                    self.currentViewController = identVC
                    identVC.loadViewIfNeeded()
                    targetView = identVC.startButton
                } else {
                    targetView = nil
                }
            }
            
            let overlay = TourOverlayView(frame: window.bounds)
            self.activeOverlay = overlay
            window.addSubview(overlay)
            
            overlay.configure(
                title: "Smart Species Wizard! 🔍✨",
                text: "Mystery bird in sight? Use the Wizard! Filter by size, color, and habitat to identify it instantly.\n\nIt's like having a bird expert in your pocket! 🧠🦜",
                stepIndex: 4, totalSteps: 5, targetView: targetView, nextButtonTitle: "Next: Profile →",
                onNext: { [weak self] in self?.advanceStep(to: .profileLocation) },
                onSkip: { [weak self] in self?.skipTour() }
            )
        }
    }
    
    private func showProfileLocationStep() {
        guard let tabBarController = getTabBarController() else { 
            print("TOUR: Error - Could not find tab bar controller for profile step")
            completeTour()
            return 
        }
        
        print("TOUR: Switching back to Home for Profile explanation...")
        tabBarController.selectedIndex = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self, self.isTourActive else { return }
            guard let window = self.getActiveWindow() else { return }
            
            var targetView: UIView?
            if let nav = tabBarController.viewControllers?[0] as? UINavigationController,
               let homeVC = nav.topViewController as? HomeViewController {
                self.currentViewController = homeVC
                targetView = homeVC.navigationItem.rightBarButtonItem?.customView
            }
            
            let overlay = TourOverlayView(frame: window.bounds)
            self.activeOverlay = overlay
            window.addSubview(overlay)
            
            overlay.configure(
                title: "Settings & Secret Games! 👤🎮",
                text: "Tap your profile icon up here to change your location or manage your account.\n\n🎊 SURPRISE: You've just unlocked a secret migration mini-game! 🕹️🦜 Just tap on your email inside the Profile screen to play whenever you have some free time. Have fun!",
                stepIndex: 5, totalSteps: 5, targetView: targetView, nextButtonTitle: "Finish Tour! 🎊",
                onNext: { [weak self] in self?.completeTour() },
                onSkip: { [weak self] in self?.skipTour() }
            )
        }
    }
    
    // MARK: - Guest Flow Steps
    
    private func showGuestWelcomeStep() {
        guard let window = getActiveWindow() else { return }
        let overlay = TourOverlayView(frame: window.bounds)
        activeOverlay = overlay
        window.addSubview(overlay)
        
        overlay.configure(
            title: "Welcome to SkyTrails! 🐦✨",
            text: "Hi! I'm Skippy! 🦜 Your birding guide.\n\nI'll show you how we track bird migrations and how you can become part of our community. Let's take a quick look!",
            stepIndex: 1, totalSteps: 4, targetView: nil, nextButtonTitle: "Next →",
            onNext: { [weak self] in self?.advanceStep(to: .guestHomeMigration) },
            onSkip: { [weak self] in self?.skipTour() }
        )
    }
    
    private func showGuestHomeMigrationStep() {
        guard let window = getActiveWindow() else { return }
        
        var targetView: UIView?
        if let nav = getTabBarController()?.viewControllers?[0] as? UINavigationController,
           let homeVC = nav.topViewController as? HomeViewController {
            self.currentViewController = homeVC
            homeVC.loadViewIfNeeded()
            let indexPath = IndexPath(item: 0, section: 0)
            targetView = homeVC.homeCollectionView?.cellForItem(at: indexPath)
        }
        
        let overlay = TourOverlayView(frame: window.bounds)
        activeOverlay = overlay
        window.addSubview(overlay)
        
        overlay.configure(
            title: "Track Migrations 🗺️",
            text: "See those cards? They show real-time bird movements in your area based on AI predictions.\n\nYou can explore maps and peak arrival times for hundreds of species!",
            stepIndex: 2, totalSteps: 4, targetView: targetView, nextButtonTitle: "Next →",
            onNext: { [weak self] in self?.advanceStep(to: .guestHomeNews) },
            onSkip: { [weak self] in self?.skipTour() }
        )
    }
    
    private func showGuestHomeNewsStep() {
        guard let window = getActiveWindow() else { return }
        
        if let nav = getTabBarController()?.viewControllers?[0] as? UINavigationController,
           let homeVC = nav.topViewController as? HomeViewController {
            self.currentViewController = homeVC
            homeVC.loadViewIfNeeded()
            
            let newsIndexPath = IndexPath(item: 0, section: 3)
            homeVC.homeCollectionView?.scrollToItem(at: newsIndexPath, at: .centeredVertically, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self, self.isTourActive else { return }
                let cell = homeVC.homeCollectionView?.cellForItem(at: newsIndexPath)
                
                let overlay = TourOverlayView(frame: window.bounds)
                self.activeOverlay = overlay
                window.addSubview(overlay)
                
                overlay.configure(
                    title: "Stay Updated 📰",
                    text: "We keep you informed with the latest birding news and conservation updates.\n\nThere's always something new to discover in the world of birds!",
                    stepIndex: 3, totalSteps: 4, targetView: cell, nextButtonTitle: "Next →",
                    onNext: { [weak self] in self?.advanceStep(to: .guestSignupPrompt) },
                    onSkip: { [weak self] in self?.skipTour() }
                )
            }
            return
        }
        
        let overlay = TourOverlayView(frame: window.bounds)
        activeOverlay = overlay
        window.addSubview(overlay)
        overlay.configure(
            title: "Stay Updated 📰",
            text: "We keep you informed with the latest birding news and conservation updates.\n\nThere's always something new to discover in the world of birds!",
            stepIndex: 3, totalSteps: 4, targetView: nil, nextButtonTitle: "Next →",
            onNext: { [weak self] in self?.advanceStep(to: .guestSignupPrompt) },
            onSkip: { [weak self] in self?.skipTour() }
        )
    }
    
    private func showGuestSignupPromptStep() {
        guard let window = getActiveWindow() else { return }
        let overlay = TourOverlayView(frame: window.bounds)
        activeOverlay = overlay
        window.addSubview(overlay)
        
        overlay.configure(
            title: "Unlock Full Access! 🚀",
            text: "Ready to take flight? Sign up now to:\n\n📝 Create custom Watchlists\n🔍 Use the Smart Species Wizard\n👥 Join our global birding community\n🎮 Unlock a secret migration mini-game!\n\nIt's free and only takes a minute! ✨",
            stepIndex: 4, totalSteps: 4, targetView: nil, nextButtonTitle: "Sign Up Now! 🚀",
            onNext: { [weak self] in
                self?.completeGuestTourAndPresentAuth()
            },
            onSkip: { [weak self] in
                self?.completeGuestTourAndExplore()
            }
        )
    }
    
    func completeGuestTourAndExplore() {
        cleanup()
        UserDefaults.standard.set(true, forKey: "hasCompletedGuestTour")
        currentStep = .completed
    }
    
    func completeGuestTourAndPresentAuth() {
        cleanup()
        UserDefaults.standard.set(true, forKey: "hasCompletedGuestTour")
        currentStep = .completed
        
        if let window = getActiveWindow(),
           let rootTabBar = window.rootViewController as? RootTabBarController {
            rootTabBar.presentAuthenticationFlow()
        }
    }
    
    // MARK: - Helpers
    
    private func getActiveWindow() -> UIWindow? {
        // Try to get key window first
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return window
        }
        
        // Fallback to any window in the first scene
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first
    }
    
    private func getTabBarController() -> UITabBarController? {
        guard let window = getActiveWindow() else { return nil }
        
        if let tab = window.rootViewController as? UITabBarController {
            return tab
        }
        
        // Handle case where root might be a navigation controller containing the tab bar (unusual but possible)
        if let nav = window.rootViewController as? UINavigationController,
           let tab = nav.viewControllers.first as? UITabBarController {
            return tab
        }
        
        // Recursive search for the active tab bar controller
        return findTabBarController(in: window.rootViewController)
    }
    
    private func findTabBarController(in vc: UIViewController?) -> UITabBarController? {
        guard let vc = vc else { return nil }
        if let tab = vc as? UITabBarController { return tab }
        for child in vc.children {
            if let tab = findTabBarController(in: child) { return tab }
        }
        return nil
    }
    
    private func getTopMostViewController() -> UIViewController? {
        guard let window = getActiveWindow(),
              var topVC = window.rootViewController else { return nil }
        while let presented = topVC.presentedViewController { topVC = presented }
        if let nav = topVC as? UINavigationController { return nav.topViewController ?? topVC }
        if let tab = topVC as? UITabBarController, let selected = tab.selectedViewController {
            if let nav = selected as? UINavigationController { return nav.topViewController ?? selected }
            return selected
        }
        return topVC
    }
    
    func trackViewControllerAppeared(_ vc: UIViewController) {
        guard isTourActive else { return }
        currentViewController = vc
        print("TOUR: VC appeared: \(type(of: vc)), current step: \(currentStep)")
    }
}

// MARK: - TourOverlayView (Glassmorphism overlay with touch passthrough on cutout)

fileprivate class TourOverlayView: UIView {
    
    private var targetView: UIView?
    private var onNext: (() -> Void)?
    private var onSkip: (() -> Void)?
    private var cutoutRect: CGRect = .zero
    
    private let maskLayer = CAShapeLayer()
    private let bubbleCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    
    private let characterLabel = UILabel()
    private let titleLabel = UILabel()
    private let textLabel = UILabel()
    private let progressView = UIView()
    private let progressFill = UIView()
    private let stepLabel = UILabel()
    private let skipButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .custom)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let bubblePoint = bubbleCard.convert(point, from: self)
        if bubbleCard.bounds.contains(bubblePoint) { return super.hitTest(point, with: event) }
        if cutoutRect != .zero && cutoutRect.contains(point) { return nil }
        return super.hitTest(point, with: event)
    }
    
    private func setupOverlay() {
        self.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        maskLayer.fillRule = .evenOdd
        self.layer.mask = maskLayer
        
        bubbleCard.layer.cornerRadius = 24
        bubbleCard.clipsToBounds = true
        bubbleCard.layer.borderWidth = 1.5
        bubbleCard.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
        self.addSubview(bubbleCard)
        
        characterLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        characterLabel.textColor = UIColor.systemBlue
        bubbleCard.contentView.addSubview(characterLabel)
        
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        bubbleCard.contentView.addSubview(titleLabel)
        
        textLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        textLabel.textColor = UIColor.secondaryLabel
        textLabel.numberOfLines = 0
        bubbleCard.contentView.addSubview(textLabel)
        
        progressView.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        progressView.layer.cornerRadius = 3
        bubbleCard.contentView.addSubview(progressView)
        
        progressFill.backgroundColor = UIColor.systemBlue
        progressFill.layer.cornerRadius = 3
        progressView.addSubview(progressFill)
        
        stepLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        stepLabel.textColor = UIColor.tertiaryLabel
        bubbleCard.contentView.addSubview(stepLabel)
        
        skipButton.setTitle("Skip Tour", for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        skipButton.tintColor = UIColor.secondaryLabel
        skipButton.addTarget(self, action: #selector(didTapSkip), for: .touchUpInside)
        bubbleCard.contentView.addSubview(skipButton)
        
        nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.backgroundColor = .systemBlue
        nextButton.layer.cornerRadius = 14
        nextButton.layer.shadowColor = UIColor.systemBlue.cgColor
        nextButton.layer.shadowOpacity = 0.4
        nextButton.layer.shadowRadius = 8
        nextButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        nextButton.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
        bubbleCard.contentView.addSubview(nextButton)
    }
    
    func configure(
        title: String,
        text: String,
        stepIndex: Int,
        totalSteps: Int,
        targetView: UIView?,
        nextButtonTitle: String?,
        onNext: (() -> Void)?,
        onSkip: (() -> Void)?
    ) {
        self.targetView = targetView
        self.onNext = onNext
        self.onSkip = onSkip
        
        characterLabel.text = "🦜 Skippy Says:"
        titleLabel.text = title
        textLabel.text = text
        stepLabel.text = "Step \(stepIndex) of \(totalSteps)"
        
        if let nextTitle = nextButtonTitle {
            nextButton.setTitle(nextTitle, for: .normal)
            nextButton.isHidden = false
        } else {
            nextButton.isHidden = true
        }
        
        updateCutoutMask()
        layoutBubbleCard(stepIndex: stepIndex, totalSteps: totalSteps)
        
        bubbleCard.transform = CGAffineTransform(scaleX: 0.9, y: 0.9).translatedBy(x: 0, y: 20)
        bubbleCard.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            self.bubbleCard.transform = .identity
            self.bubbleCard.alpha = 1
        }, completion: nil)
    }
    
    private func updateCutoutMask() {
        let path = UIBezierPath(rect: self.bounds)
        if let target = targetView, target.window != nil {
            let targetFrame = target.convert(target.bounds, to: nil)
            let isTooLarge = targetFrame.width >= self.bounds.width * 0.85 || targetFrame.height >= self.bounds.height * 0.85
            
            if !isTooLarge && targetFrame.width > 5 && targetFrame.height > 5 {
                let paddedRect = targetFrame.insetBy(dx: -8, dy: -6)
                cutoutRect = paddedRect
                let cutout = UIBezierPath(roundedRect: paddedRect, cornerRadius: 14)
                path.append(cutout)
                drawPulsingRing(around: paddedRect)
            } else {
                cutoutRect = .zero
            }
        } else {
            cutoutRect = .zero
        }
        maskLayer.path = path.cgPath
    }
    
    private func drawPulsingRing(around rect: CGRect) {
        let ring = CAShapeLayer()
        ring.path = UIBezierPath(roundedRect: rect, cornerRadius: 14).cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = UIColor.systemBlue.cgColor
        ring.lineWidth = 2.5
        self.layer.addSublayer(ring)
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0; scale.toValue = 1.08
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1.0; opacity.toValue = 0.0
        let group = CAAnimationGroup()
        group.animations = [scale, opacity]; group.duration = 1.6; group.repeatCount = .infinity
        ring.add(group, forKey: "pulse")
    }
    
    private func layoutBubbleCard(stepIndex: Int, totalSteps: Int) {
        let width = min(400, self.bounds.width - 32)
        let padding: CGFloat = 20; let spacing: CGFloat = 10
        let titleSize = titleLabel.sizeThatFits(CGSize(width: width - 40, height: .infinity))
        let textSize = textLabel.sizeThatFits(CGSize(width: width - 40, height: .infinity))
        let totalHeight = padding + 20 + spacing + titleSize.height + spacing + textSize.height + spacing + 6 + spacing + 10 + 44 + padding
        
        var cardY: CGFloat = (self.bounds.height - totalHeight) / 2
        if let target = targetView, target.window != nil {
            let targetFrame = target.convert(target.bounds, to: nil)
            if targetFrame.midY > self.bounds.height / 2 {
                cardY = targetFrame.minY - totalHeight - 20
            } else {
                cardY = targetFrame.maxY + 20
            }
        }
        
        let minY = self.safeAreaInsets.top + 20
        let maxY = self.bounds.height - totalHeight - self.safeAreaInsets.bottom - 20
        cardY = max(minY, min(cardY, maxY))
        
        bubbleCard.frame = CGRect(x: (self.bounds.width - width)/2, y: cardY, width: width, height: totalHeight)
        let cardWidth = bubbleCard.contentView.bounds.width
        var y: CGFloat = padding
        characterLabel.frame = CGRect(x: 20, y: y, width: cardWidth - 40, height: 20); y += 20 + spacing
        titleLabel.frame = CGRect(x: 20, y: y, width: cardWidth - 40, height: titleSize.height); y += titleSize.height + spacing
        textLabel.frame = CGRect(x: 20, y: y, width: cardWidth - 40, height: textSize.height); y += textSize.height + spacing + 6
        progressView.frame = CGRect(x: 20, y: y, width: cardWidth - 40, height: 6)
        progressFill.frame = CGRect(x: 0, y: 0, width: (cardWidth - 40) * (CGFloat(stepIndex) / CGFloat(totalSteps)), height: 6); y += 6 + spacing + 10
        stepLabel.frame = CGRect(x: 20, y: y, width: 100, height: 44)
        let skipWidth: CGFloat = 80; let nextWidth: CGFloat = nextButton.isHidden ? 0 : 140
        skipButton.frame = CGRect(x: cardWidth - 20 - skipWidth - (nextButton.isHidden ? 0 : nextWidth + 8), y: y, width: skipWidth, height: 44)
        if !nextButton.isHidden { nextButton.frame = CGRect(x: cardWidth - 20 - nextWidth, y: y + 4, width: nextWidth, height: 36) }
    }
    
    @objc private func didTapNext() { onNext?() }
    @objc private func didTapSkip() { onSkip?() }
}
