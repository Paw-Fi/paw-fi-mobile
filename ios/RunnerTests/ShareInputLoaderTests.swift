import UIKit
import UniformTypeIdentifiers
import XCTest

class ShareInputLoaderTests: XCTestCase {
  func testDocumentsAndImagesAreCopiedWithPluginCompatibleMetadata() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    for (ext, mime) in [
      ("jpg", "image/jpeg"), ("png", "image/png"), ("heic", "image/heic"),
      ("pdf", "application/pdf"), ("csv", "text/csv"),
      ("xls", "application/vnd.ms-excel"),
      ("xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
    ] {
      let provider = NSItemProvider()
      let type = try XCTUnwrap(UTType(filenameExtension: ext))
      let bytes = Data("旅行 €12,50".utf8)
      provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) {
        reply in reply(bytes, nil); return nil
      }
      let done = expectation(description: ext)
      SharedInputLoader.load(provider: provider, directory: directory) { file in
        defer { done.fulfill() }
        do {
          let file = try XCTUnwrap(file)
          let url = try XCTUnwrap(URL(string: file.path))
          XCTAssertEqual(try Data(contentsOf: url), bytes)
          XCTAssertEqual(file.mimeType, mime)
          XCTAssertEqual(file.type, mime.hasPrefix("image/") ? "image" : "file")
          XCTAssertEqual(url.pathExtension, type.preferredFilenameExtension)
          let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode([file])) as? [[String: Any]]
          XCTAssertEqual(json?.first?["type"] as? String, file.type)
        } catch { XCTFail("\(error)") }
      }
      wait(for: [done], timeout: 5)
    }
  }

  func testFileURLProviderAndRepeatedNamesKeepIndependentCopies() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("明細.pdf")
    try Data("statement".utf8).write(to: source)
    let provider = NSItemProvider(item: source as NSURL, typeIdentifier: UTType.fileURL.identifier)
    let done = expectation(description: "two shares")
    done.expectedFulfillmentCount = 2
    var paths = Set<String>()
    let lock = NSLock()
    for _ in 0..<2 {
      SharedInputLoader.load(provider: provider, directory: directory) { file in
        lock.lock()
        if let file { paths.insert(file.path); XCTAssertEqual(file.mimeType, "application/pdf") }
        else { XCTFail("File URL must be copied") }
        lock.unlock()
        done.fulfill()
      }
    }
    wait(for: [done], timeout: 5)
    XCTAssertEqual(paths.count, 2)
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
  }

  func testMixedAttachmentsKeepSourceOrderDespiteAsynchronousLoading() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let providers = [UTType.pdf, UTType.png].enumerated().map { index, type in
      let provider = NSItemProvider()
      provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { reply in
        DispatchQueue.global().asyncAfter(deadline: .now() + (index == 0 ? 0.1 : 0)) {
          reply(Data("\(index)".utf8), nil)
        }
        return nil
      }
      return provider
    }
    let done = expectation(description: "ordered batch")
    SharedInputLoader.load(providers: providers, directory: directory) { files in
      XCTAssertEqual(files.map(\.type), ["file", "image"])
      XCTAssertEqual(files.map(\.mimeType), ["application/pdf", "image/png"])
      done.fulfill()
    }
    wait(for: [done], timeout: 5)
  }

  func testUnsupportedAndUnreadableInputsDoNotInventAnImage() throws {
    let directory = FileManager.default.temporaryDirectory
    for provider in [NSItemProvider(object: "plain text" as NSString), NSItemProvider()] {
      let done = expectation(description: "unsupported")
      SharedInputLoader.load(provider: provider, directory: directory) { file in
        XCTAssertNil(file)
        done.fulfill()
      }
      wait(for: [done], timeout: 5)
    }
  }

  func testGenericImageRepresentationIsNormalizedToASupportedImage() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    let data = try XCTUnwrap(image.pngData())
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.image.identifier, visibility: .all) { reply in
      reply(data, nil)
      return nil
    }
    let done = expectation(description: "generic image")
    SharedInputLoader.load(provider: provider, directory: directory) { file in
      XCTAssertEqual(file?.mimeType, "image/png")
      XCTAssertEqual(file?.type, "image")
      done.fulfill()
    }
    wait(for: [done], timeout: 5)
  }
}
