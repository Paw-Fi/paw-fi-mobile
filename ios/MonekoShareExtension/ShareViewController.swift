import UIKit
import UniformTypeIdentifiers

private let appGroupId = "group.moneko.mobile"
private let hostBundleId = "com.moneko.mobile"
private let sharedMediaKey = "ShareKey"

struct SharedInputFile: Codable {
    let path: String
    let mimeType: String
    let type: String
}

enum SharedInputLoader {
    private static let formats = [
        "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
        "heic": "image/heic", "heif": "image/heif", "webp": "image/webp",
        "pdf": "application/pdf", "csv": "text/csv",
        "xls": "application/vnd.ms-excel",
        "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ]

    static func load(providers: [NSItemProvider], directory: URL,
                     completion: @escaping ([SharedInputFile]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var files = [SharedInputFile?](repeating: nil, count: providers.count)
        for (index, provider) in providers.enumerated() {
            group.enter()
            load(provider: provider, directory: directory) { file in
                lock.lock()
                files[index] = file
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(files.compactMap { $0 }) }
    }

    static func load(provider: NSItemProvider, directory: URL,
                     completion: @escaping (SharedInputFile?) -> Void) {
        // Prefer the actual content type over a generic public.data/file-url.
        let identifier = provider.registeredTypeIdentifiers.first { identifier in
            guard let type = UTType(identifier) else { return false }
            return type.conforms(to: .image) || type.preferredFilenameExtension.flatMap { formats[$0.lowercased()] } != nil
        }
        if let identifier, let type = UTType(identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, _ in
                if let url {
                    completion(copy(from: url, type: type, directory: directory))
                } else {
                    provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, _ in
                        completion(data.flatMap { write(data: $0, type: type, directory: directory) })
                    }
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = item as? URL, url.isFileURL else { completion(nil); return }
                completion(copy(from: url, type: nil, directory: directory))
            }
        } else {
            completion(nil)
        }
    }

    private static func copy(from source: URL, type: UTType?, directory: URL) -> SharedInputFile? {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let sourceExtension = source.pathExtension.lowercased()
        let ext = formats[sourceExtension] != nil ? sourceExtension : type?.preferredFilenameExtension
        guard let ext, let mime = formats[ext.lowercased()] else {
            guard type?.conforms(to: .image) == true,
                  let data = UIImage(contentsOfFile: source.path)?.pngData() else { return nil }
            return write(data: data, type: .png, directory: directory)
        }
        let destination = directory.appendingPathComponent("shared_\(UUID().uuidString).\(ext)")
        do {
            // Provider file representations are valid only during this callback.
            try FileManager.default.copyItem(at: source, to: destination)
            return SharedInputFile(path: destination.absoluteString, mimeType: mime,
                                   type: mime.hasPrefix("image/") ? "image" : "file")
        } catch { return nil }
    }

    private static func write(data: Data, type: UTType, directory: URL) -> SharedInputFile? {
        guard let ext = type.preferredFilenameExtension, let mime = formats[ext] else {
            guard type.conforms(to: .image), let png = UIImage(data: data)?.pngData() else { return nil }
            return write(data: png, type: .png, directory: directory)
        }
        let destination = directory.appendingPathComponent("shared_\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: destination, options: .atomic)
            return SharedInputFile(path: destination.absoluteString, mimeType: mime,
                                   type: mime.hasPrefix("image/") ? "image" : "file")
        } catch { return nil }
    }
}

/// Receives supported image/document shares without the compose UI used by the plugin's
/// default controller. The Dart plugin reads this same App Group payload.
final class ShareViewController: UIViewController {
    private var hasStartedProcessing = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStartedProcessing else { return }
        hasStartedProcessing = true

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty,
              let directory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId
              ) else {
            completeRequest()
            return
        }

        SharedInputLoader.load(providers: providers, directory: directory) { [weak self] files in
            self?.saveAndOpenHostApp(files: files)
        }
    }

    private func saveAndOpenHostApp(files: [SharedInputFile]) {
        guard !files.isEmpty,
              let data = try? JSONEncoder().encode(files) else {
            completeRequest()
            return
        }

        UserDefaults(suiteName: appGroupId)?.set(data, forKey: sharedMediaKey)
        UserDefaults(suiteName: appGroupId)?.removeObject(forKey: "ShareMessageKey")
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
