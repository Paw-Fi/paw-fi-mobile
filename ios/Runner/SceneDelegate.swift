import Flutter
import UIKit
import app_links
import receive_sharing_intent

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
    // Seed the sharing plugin's initial media before Dart subscribes; other
    // links still enter app_links' initial-link cache and uriLinkStream.
    for context in connectionOptions.urlContexts {
      forward(url: context.url, isInitial: true)
    }
    for userActivity in connectionOptions.userActivities {
      if let url = userActivity.webpageURL {
        forward(url: url, isInitial: true)
      }
    }

    window.makeKeyAndVisible()
  }

  // Deliver shares to the media stream and other custom schemes to app_links
  // when the app is already running or suspended.
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

  func forward(url: URL, isInitial: Bool = false) {
    let sharing = SwiftReceiveSharingIntentPlugin.instance
    if sharing.hasMatchingSchemePrefix(url: url) {
      if isInitial {
        _ = sharing.application(
          UIApplication.shared,
          didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: url]
        )
      } else {
        _ = sharing.application(UIApplication.shared, open: url, options: [:])
      }
      return
    }
    AppLinks.shared.handleLink(url: url)
  }
}
