import Flutter
import UIKit
import app_links

@objc class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let engine = appDelegate.flutterEngine else { return }

    let controller = FlutterViewController(
      engine: engine,
      nibName: nil,
      bundle: nil
    )
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = controller
    self.window = window
    appDelegate.window = window

    // A custom UISceneDelegate bypasses UIApplicationDelegate URL callbacks.
    // Forward cold-start links to app_links after plugin registration so its
    // initial-link cache and uriLinkStream both receive the OAuth callback.
    for context in connectionOptions.urlContexts {
      forward(url: context.url)
    }
    for userActivity in connectionOptions.userActivities {
      if let url = userActivity.webpageURL {
        forward(url: url)
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
      forward(url: context.url)
    }
  }

  // Forward universal links to the same app_links stream.
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let url = userActivity.webpageURL {
      forward(url: url)
    }
  }

  private func forward(url: URL) {
    AppLinks.shared.handleLink(url: url)
  }
}
