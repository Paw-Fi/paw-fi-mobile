import Flutter
import UIKit

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

    window.makeKeyAndVisible()
  }
}
