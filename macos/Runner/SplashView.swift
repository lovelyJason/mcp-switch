import Cocoa

/// Splash screen transition effect type
enum SplashTransitionType {
    case fadeOut        // Simple fade out
    case crossDissolve  // Cross dissolve with Flutter view
}

/// Native splash screen view for macOS
/// Displays amber-themed logo with rolling animation and optional progress bar
/// while Flutter engine initializes
///
/// Design:
/// - Background: Amber light color (#FFF8E1)
/// - Logo: squirrel_walk.gif with walking animation
/// - Progress bar: Optional, shows loading indicator
///
/// Usage:
/// 1. Create SplashView and add to window
/// 2. Call startAnimation() to begin
/// 3. Call hide() when Flutter is ready (first frame rendered)
class SplashView: NSView {

    // MARK: - Configuration

    /// Transition type: .fadeOut or .crossDissolve
    /// Change this to compare different effects
    static var transitionType: SplashTransitionType = .fadeOut

    /// Transition duration in seconds
    static var transitionDuration: TimeInterval = 0.3

    /// Whether to show progress bar
    static var showProgressBar: Bool = true

    // MARK: - Colors

    /// Background color (Amber light #FFF8E1)
    private let backgroundColor = NSColor(red: 1.0, green: 0.973, blue: 0.882, alpha: 1.0)

    /// Progress bar track color (Amber lighter #F5E0B2)
    private let progressTrackColor = NSColor(red: 0.961, green: 0.878, blue: 0.698, alpha: 1.0)

    /// Progress bar fill color (Amber main #F5A623)
    private let progressTintColor = NSColor(red: 0.961, green: 0.651, blue: 0.137, alpha: 1.0)

    // MARK: - UI Components

    private var logoImageView: NSImageView!
    private var progressContainer: NSView?

    // MARK: - State

    private var isAnimating = false
    private var breathingTimer: Timer?
    private var progressTimer: Timer?
    private var currentProgress: Double = 0

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = backgroundColor.cgColor

        setupLogo()

        if SplashView.showProgressBar {
            setupProgressBar()
        }
    }

    // MARK: - Setup

    private func setupLogo() {
        logoImageView = NSImageView()
        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.animates = true // Enable GIF animation

        // Load logo
        if let logoImage = loadLogoImage() {
            logoImageView.image = logoImage
        }

        addSubview(logoImageView)

        // Center logo with size constraints
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            logoImageView.widthAnchor.constraint(equalToConstant: 280),
            logoImageView.heightAnchor.constraint(equalToConstant: 280)
        ])
    }

    private func setupProgressBar() {
        // Use custom progress bar for amber theme
        progressContainer = NSView()
        guard let progressContainer = progressContainer else { return }

        progressContainer.wantsLayer = true
        progressContainer.layer?.backgroundColor = progressTrackColor.cgColor
        progressContainer.layer?.cornerRadius = 3
        progressContainer.translatesAutoresizingMaskIntoConstraints = false

        addSubview(progressContainer)

        // Position below logo
        NSLayoutConstraint.activate([
            progressContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressContainer.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 60),
            progressContainer.widthAnchor.constraint(equalToConstant: 200),
            progressContainer.heightAnchor.constraint(equalToConstant: 6)
        ])

        // Progress fill view
        let progressFill = NSView()
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = progressTintColor.cgColor
        progressFill.layer?.cornerRadius = 3
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.identifier = NSUserInterfaceItemIdentifier("progressFill")

        progressContainer.addSubview(progressFill)

        NSLayoutConstraint.activate([
            progressFill.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            progressFill.widthAnchor.constraint(equalToConstant: 0)  // Start at 0
        ])
    }

    private func loadLogoImage() -> NSImage? {
        let bundle = Bundle.main

        // Flutter assets are located in App.framework, not Resources
        // Path: Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/
        let flutterAssetsPath: String? = {
            if let bundlePath = bundle.bundlePath as String? {
                let appFrameworkPath = "\(bundlePath)/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets"
                if FileManager.default.fileExists(atPath: appFrameworkPath) {
                    return appFrameworkPath
                }
                // Fallback: try resourcePath (older Flutter versions)
                if let resourcePath = bundle.resourcePath {
                    let legacyPath = "\(resourcePath)/flutter_assets"
                    if FileManager.default.fileExists(atPath: legacyPath) {
                        return legacyPath
                    }
                }
            }
            return nil
        }()

        // 1. Try Flutter assets GIF first (Asset Catalog doesn't support GIF animation)
        if let assetsPath = flutterAssetsPath {
            let gifPath = "\(assetsPath)/assets/images/squirrel_walk.gif"
            if FileManager.default.fileExists(atPath: gifPath) {
                return NSImage(contentsOfFile: gifPath)
            }
        }

        // 2. Try native asset "SplashLogo" (static PNG fallback)
        if let image = NSImage(named: "SplashLogo") {
            return image
        }

        return createPlaceholderLogo()
    }

    /// Create a simple placeholder logo if no image is found
    private func createPlaceholderLogo() -> NSImage {
        let size = NSSize(width: 120, height: 120)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw amber circle
        let circleRect = NSRect(x: 10, y: 10, width: 100, height: 100)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        progressTintColor.setFill()
        circlePath.fill()

        // Draw simple placeholder circle
        NSColor.white.setFill()
        let innerRect = NSRect(x: 30, y: 30, width: 60, height: 60)
        let innerPath = NSBezierPath(ovalIn: innerRect)
        innerPath.fill()

        image.unlockFocus()

        return image
    }

    // MARK: - Animation

    /// Start splash animations (rolling logo + progress bar)
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        // GIF animates automatically

        // Start progress animation if enabled
        if SplashView.showProgressBar {
            startProgressAnimation()
        }
    }

    private func startProgressAnimation() {
        // Animate progress from 0 to ~80% over time
        // The remaining 20% will complete when Flutter is ready
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Slow down as we approach 80%
            let increment = (80 - self.currentProgress) * 0.02
            self.currentProgress = min(80, self.currentProgress + max(0.5, increment))

            self.updateProgressBar(progress: self.currentProgress / 100)
        }
    }

    private func updateProgressBar(progress: Double) {
        guard let progressContainer = subviews.first(where: { $0.subviews.contains(where: { $0.identifier?.rawValue == "progressFill" }) }),
              let progressFill = progressContainer.subviews.first(where: { $0.identifier?.rawValue == "progressFill" }) else {
            return
        }

        // Update width constraint
        let targetWidth = progressContainer.bounds.width * CGFloat(progress)

        // Find and update width constraint
        for constraint in progressFill.constraints {
            if constraint.firstAttribute == .width {
                constraint.constant = targetWidth
                break
            }
        }

        progressFill.needsLayout = true
    }

    // MARK: - Hide

    /// Hide splash screen with transition effect
    /// - Parameter completion: Called when transition completes
    func hide(completion: (() -> Void)? = nil) {
        // Stop timers
        breathingTimer?.invalidate()
        breathingTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil

        // Complete progress bar to 100%
        if SplashView.showProgressBar {
            updateProgressBar(progress: 1.0)
        }

        // Perform transition
        switch SplashView.transitionType {
        case .fadeOut:
            performFadeOut(completion: completion)
        case .crossDissolve:
            performCrossDissolve(completion: completion)
        }
    }

    private func performFadeOut(completion: (() -> Void)?) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = SplashView.transitionDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.removeFromSuperview()
            completion?()
        })
    }

    private func performCrossDissolve(completion: (() -> Void)?) {
        // For cross dissolve, we also fade out but the Flutter view
        // should already be visible underneath
        performFadeOut(completion: completion)
    }

    // MARK: - Cleanup

    deinit {
        breathingTimer?.invalidate()
        progressTimer?.invalidate()
    }
}
