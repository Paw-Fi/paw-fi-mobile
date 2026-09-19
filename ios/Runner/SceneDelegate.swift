import Flutter
import UIKit
import app_links

@objc class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  private var flutterEngine: FlutterEngine?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let engine = FlutterEngine(name: "moneko_flutter_engine")
    guard engine.run() else { return }

    let controller = FlutterViewController(
      engine: engine,
      nibName: nil,
      bundle: nil
    )
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = controller
    self.window = window
    flutterEngine = engine

    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.window = window
      GeneratedPluginRegistrant.register(with: appDelegate)
      appDelegate.setupFlutterChannels(binaryMessenger: controller.binaryMessenger)
    } else {
      GeneratedPluginRegistrant.register(with: engine)
    }

    // A custom UISceneDelegate bypasses UIApplicationDelegate URL callbacks.
    // Forward cold-start links to app_links after plugin registration so its
    // initial-link cache and uriLinkStream both receive the OAuth callback.
    for context in connectionOptions.urlContexts {
      forward(url: context.url, source: "cold-start")
    }
    for userActivity in connectionOptions.userActivities {
      if let url = userActivity.webpageURL {
        forward(url: url, source: "cold-start-activity")
      }
    }

    window.makeKeyAndVisible()
  }

  // Forward custom URL schemes, including Supabase OAuth callbacks, to the
  // app_links plugin when the app is already running or suspended.
  func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      forward(url: context.url, source: "scene-url")
    }
  }

  // Forward universal links to the same app_links stream.
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let url = userActivity.webpageURL {
      forward(url: url, source: "scene-activity")
    }
  }

  private func forward(url: URL, source: String) {
    var description = "scheme=\(url.scheme ?? ""), host=\(url.host ?? ""), path=\(url.path)"
    if url.query != nil || url.fragment != nil {
      description += ", hasQueryOrFragment=true"
    }
    print("[GoogleOAuth] iOS scene URL received (\(source)): \(description)")
    AppLinks.shared.handleLink(url: url)
  }
}
