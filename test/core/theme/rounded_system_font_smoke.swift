import UIKit
import CoreText
import Foundation

// Run against the real iOS implementation without launching financial services.
@main
enum RoundedSystemFontSmoke {
  static func main() {
    let start = Date()
    let faces = RoundedSystemFont.payload()
    precondition(faces.count == 9, "All nine SF Rounded weights must load")
    for (weight, face) in faces.sorted(by: { $0.key < $1.key }) {
      let data = face["data"] as! Data
      let provider = CGDataProvider(data: data as CFData)!
      let font = CGFont(provider)!
      precondition((font.postScriptName! as String).contains("Rounded"))
      precondition(data.count % 4 == 0)
      let restored = CTFontCreateWithGraphicsFont(font, 36, nil, nil)
      var characters = Array("0123456789.,-%".utf16)
      var glyphs = [CGGlyph](repeating: 0, count: characters.count)
      precondition(CTFontGetGlyphsForCharacters(restored, &characters, &glyphs, characters.count))
      precondition(glyphs.allSatisfy { $0 != 0 })
      print("SF Rounded \(weight): \(font.postScriptName!), \(data.count) bytes, variations \(face["variations"]!)")
    }
    print("PASS: Nine native rounded faces and number glyphs in \(Date().timeIntervalSince(start))s")
  }
}
