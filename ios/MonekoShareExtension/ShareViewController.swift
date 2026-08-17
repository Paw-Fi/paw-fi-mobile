import UIKit
import UniformTypeIdentifiers

private let appGroupId = "group.moneko.mobile"
private let hostBundleId = "com.moneko.mobile"
private let sharedMediaKey = "ShareKey"

private struct SharedImage: Codable {
    let path: String
    let mimeType: String
    let thumbnail: String? = nil
    let duration: Double? = nil
    let message: String? = nil
    let type = "image"
}

/// Receives photo shares without presenting the compose UI used by the plugin's
/// default controller. The Dart plugin reads this same App Group payload.
final class ShareViewController: UIViewController {
    private var hasStartedProcessing = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStartedProcessing else { return }
        hasStartedProcessing = true

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard !providers.isEmpty else {
            completeRequest()
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var sharedImages: [SharedImage] = []

        for provider in providers {
            group.enter()
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) {
                [weak self] url, _ in
                defer { group.leave() }
                guard let self, let url, let image = self.copyImage(from: url) else {
                    return
                }
                lock.lock()
                sharedImages.append(image)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.saveAndOpenHostApp(images: sharedImages)
        }
    }

    private func copyImage(from sourceURL: URL) -> SharedImage? {
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else {
            return nil
        }

        let extensionName = sourceURL.pathExtension.isEmpty
            ? "jpg"
            : sourceURL.pathExtension.lowercased()
        let destination = directory.appendingPathComponent(
            "shared_\(UUID().uuidString).\(extensionName)"
        )
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            let mimeType = UTType(filenameExtension: extensionName)?.preferredMIMEType
                ?? "image/jpeg"
            let path = destination.absoluteString.removingPercentEncoding
                ?? destination.absoluteString
            return SharedImage(path: path, mimeType: mimeType)
        } catch {
            return nil
        }
    }

    private func saveAndOpenHostApp(images: [SharedImage]) {
        guard !images.isEmpty,
              let data = try? JSONEncoder().encode(images) else {
            completeRequest()
            return
        }

        UserDefaults(suiteName: appGroupId)?.set(data, forKey: sharedMediaKey)
        UserDefaults(suiteName: appGroupId)?.synchronize()

        guard let url = URL(string: "ShareMedia-\(hostBundleId):share") else {
            completeRequest()
            return
        }

        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                if #available(iOS 18.0, *) {
                    application.open(url, options: [:], completionHandler: nil)
                } else {
                    let selector = sel_registerName("openURL:")
                    if current.responds(to: selector) {
                        _ = current.perform(selector, with: url)
                    }
                }
                break
            }
            responder = current.next
        }
        completeRequest()
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
