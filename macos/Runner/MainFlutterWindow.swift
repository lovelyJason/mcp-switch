import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Splash view displayed during Flutter engine initialization
  private var splashView: SplashView?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Add splash view on top of Flutter view
    setupSplashView()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register method channel for splash screen control
    setupSplashChannel(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  /// Setup splash view overlay
  private func setupSplashView() {
    guard let contentView = self.contentView else { return }

    // Create splash view covering the entire window
    splashView = SplashView(frame: contentView.bounds)
    splashView?.autoresizingMask = [.width, .height]

    // Add splash view on top
    contentView.addSubview(splashView!, positioned: .above, relativeTo: nil)

    // Start animation
    splashView?.startAnimation()
  }

  /// Setup Platform Channel for splash control from Flutter
  private func setupSplashChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.mcpswitch.splash",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "hideSplash":
        self?.hideSplash()
        result(nil)
      case "showSplash":
        // Debug: Show splash screen again
        var duration = 3000
        if let args = call.arguments as? [String: Any],
           let dur = args["duration"] as? Int {
          duration = dur
        }
        self?.showSplash(duration: duration)
        result(nil)
      case "configureSplash":
        // Allow Flutter to configure splash options
        if let args = call.arguments as? [String: Any] {
          if let transitionType = args["transitionType"] as? String {
            SplashView.transitionType = transitionType == "crossDissolve" ? .crossDissolve : .fadeOut
          }
          if let duration = args["transitionDuration"] as? Double {
            SplashView.transitionDuration = duration
          }
          if let showProgress = args["showProgressBar"] as? Bool {
            SplashView.showProgressBar = showProgress
          }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Hide splash screen with transition
  private func hideSplash() {
    splashView?.hide { [weak self] in
      self?.splashView = nil
    }
  }

  /// Show splash screen (for debugging)
  /// - Parameter duration: Duration in milliseconds before auto-hide
  private func showSplash(duration: Int) {
    // If splash already visible, skip
    if splashView != nil {
      print("[Splash] Splash already visible, skipping")
      return
    }

    guard let contentView = self.contentView else { return }

    // Create new splash view
    splashView = SplashView(frame: contentView.bounds)
    splashView?.autoresizingMask = [.width, .height]

    // Add splash view on top
    contentView.addSubview(splashView!, positioned: .above, relativeTo: nil)

    // Start animation
    splashView?.startAnimation()

    print("[Splash] Splash created and showing, duration: \(duration)ms")

    // Auto hide after duration
    if duration > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration) / 1000.0) { [weak self] in
        print("[Splash] Auto-hide timer fired")
        self?.hideSplash()
      }
    }
  }
}
