import UIKit
import CoreText
import Foundation

enum RoundedSystemFont {
  static func payload() -> [String: [String: Any]] {
    let weights: [UIFont.Weight] = [
      .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black,
    ]
    var faces: [String: [String: Any]] = [:]
    var fontDataByName: [String: Data] = [:]
    for (index, weight) in weights.enumerated() {
      guard let descriptor = UIFont.systemFont(ofSize: 36, weight: weight)
        .fontDescriptor.withDesign(.rounded) else { continue }
      let font = UIFont(descriptor: descriptor, size: 36) as CTFont
      let graphicsFont = CTFontCopyGraphicsFont(font, nil)
      let name = CTFontCopyTable(font, 0x66766172, []) == nil
        ? graphicsFont.postScriptName! as String
        : CTFontCopyFamilyName(font) as String
      // Current iOS weights share one variable font; assemble its tables once.
      guard let data = fontDataByName[name] ?? fontData(font) else { continue }
      fontDataByName[name] = data
      var variations: [String: Double] = [:]
      if let axes = CTFontCopyVariation(font) as? [NSNumber: NSNumber] {
        for (tag, value) in axes {
          let bytes = (0..<4).reversed().map { UInt8((tag.uint32Value >> ($0 * 8)) & 0xff) }
          variations[String(bytes: bytes, encoding: .ascii)!] = value.doubleValue
        }
      }
      faces[String((index + 1) * 100)] = ["data": data, "variations": variations]
    }
    return faces
  }

  // Reassemble public CoreText tables for Flutter, in memory only.
  // No Apple font file is copied into the app bundle or persisted.
  static func fontData(_ font: CTFont) -> Data? {
    guard let tags = CTFontCopyAvailableTables(font, []) else { return nil }
    let head: UInt32 = 0x68656164
    // CoreText returns unboxed table tags, not CFNumber objects.
    let tables: [(tag: UInt32, data: Data)] = (0..<CFArrayGetCount(tags)).compactMap { index in
      let tag = UInt32(UInt(bitPattern: CFArrayGetValueAtIndex(tags, index)))
      guard tag != 0x44534947, // DSIG is invalid after rebuilding the container.
            let table = CTFontCopyTable(font, tag, []) else { return nil }
      // CoreText can expose read-only mapped memory. Own the bytes before editing head.
      var data = Data(bytes: CFDataGetBytePtr(table), count: CFDataGetLength(table))
      if tag == head {
        guard data.count >= 12 else { return nil }
        data.replaceSubrange(8..<12, with: [UInt8](repeating: 0, count: 4))
      }
      return (tag, data)
    }.sorted { $0.tag < $1.tag }
    guard !tables.isEmpty, tables.contains(where: { $0.tag == head }) else { return nil }

    func append(_ value: UInt32, to data: inout Data, bytes: Int = 4) {
      for shift in (0..<bytes).reversed() { data.append(UInt8((value >> (shift * 8)) & 0xff)) }
    }
    func checksum(_ data: Data) -> UInt32 {
      data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
        var sum: UInt32 = 0
        for offset in stride(from: 0, to: bytes.count, by: 4) {
          var word: UInt32 = 0
          for byte in 0..<4 {
            word = (word << 8) | (offset + byte < bytes.count ? UInt32(bytes[offset + byte]) : 0)
          }
          sum = sum &+ word
        }
        return sum
      }
    }

    let count = tables.count
    let selector = Int(floor(log2(Double(count))))
    let searchRange = (1 << selector) * 16
    var output = Data()
    append(tables.contains(where: { $0.tag == 0x43464620 || $0.tag == 0x43464632 })
      ? 0x4f54544f : 0x00010000, to: &output)
    for value in [count, searchRange, selector, count * 16 - searchRange] {
      append(UInt32(value), to: &output, bytes: 2)
    }
    var offset = 12 + count * 16
    var headOffset = 0
    for table in tables {
      if table.tag == head { headOffset = offset }
      for value in [table.tag, checksum(table.data), UInt32(offset), UInt32(table.data.count)] {
        append(value, to: &output)
      }
      offset += (table.data.count + 3) & ~3
    }
    for table in tables {
      output.append(table.data)
      output.append(contentsOf: [UInt8](repeating: 0, count: (4 - table.data.count % 4) % 4))
    }
    var adjustment = Data()
    append(0xb1b0afba &- checksum(output), to: &adjustment)
    output.replaceSubrange((headOffset + 8)..<(headOffset + 12), with: adjustment)
    return output
  }
}
