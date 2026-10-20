import SwiftUI

// MARK: - View

/// A QR code on a white plate: scanners need the light ground, so the plate stays white in dark mode too. Invites,
/// pairing links, a recovery kit. The code is made in the kit (byte mode, versions 1–40), so it needs no platform
/// framework.
///
/// ```swift
/// KitQRCode(invite.link)
/// KitQRCode(recoveryKit.text, size: 180, correction: .high)
/// ```
public struct KitQRCode: View {
  /// How much of the code can be damaged and still read: more correction makes a denser code.
  public enum Correction: Int, Hashable, Sendable, CaseIterable {
    /// About 7%.
    case low
    /// About 15%: the default.
    case medium
    /// About 25%.
    case quartile
    /// About 30%: for printed codes.
    case high
  }

  var text: String
  var size: CGFloat
  var matrix: QRMatrix?

  /// - Parameters:
  ///   - text: what the code says (UTF-8, at most about 2,300 bytes at `.medium`).
  ///   - size: the code's side without the plate; the modules snap to whole points, so it may come out a little
  ///     smaller.
  ///   - correction: the error correction level.
  public init(_ text: String, size: CGFloat = 132, correction: Correction = .medium) {
    self.text = text
    self.size = size
    self.matrix = QRMatrix.encode(Array(text.utf8), correction: correction)
  }

  public var body: some View {
    let count = CGFloat(matrix?.size ?? 21)
    let module = max(1, (size / count).rounded(.down))
    let side = module * count
    Canvas { context, _ in
      guard let matrix else { return }
      var path = Path()
      for y in 0..<matrix.size {
        // One rectangle per run of dark modules, so neighbours leave no seams.
        var x = 0
        while x < matrix.size {
          guard matrix[x, y] else {
            x += 1
            continue
          }
          let start = x
          while x < matrix.size, matrix[x, y] { x += 1 }
          path.addRect(
            CGRect(x: CGFloat(start) * module, y: CGFloat(y) * module, width: CGFloat(x - start) * module, height: module))
        }
      }
      context.fill(path, with: .style(KitColor.qrInk))
    }
    .frame(width: side, height: side)
    // The quiet zone: the design's 10pt, and never under two modules.
    .padding(max(10, module * 2))
    .background(KitColor.qrPlate, in: RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous))
    .shadow(color: .black.opacity(0.08), radius: 1.5, y: 1)
    .overlay {
      if matrix == nil {
        Text("Too long for a QR code").kitFont(.caption).multilineTextAlignment(.center).padding()
      }
    }
    .accessibilityElement()
    .accessibilityLabel("QR code")
    .accessibilityAddTraits(.isImage)
  }
}

extension KitColor {
  /// A QR code's plate and modules: white and black in both appearances, since scanners need them.
  static let qrPlate = KitColor(RGBA(0xffffff), RGBA(0xffffff))
  static let qrInk = KitColor(RGBA(0x000000), RGBA(0x000000))
}

// MARK: - Encoder

/// A QR code's modules (ISO/IEC 18004), made from bytes in byte mode at the smallest version that holds them, with
/// the mask of the lowest penalty. `true` is dark.
struct QRMatrix: Hashable, Sendable {
  let version: Int
  let size: Int
  private(set) var modules: [Bool]
  private var isFunction: [Bool]

  subscript(x: Int, y: Int) -> Bool { modules[y * size + x] }

  /// The code for `bytes`, or `nil` when they don't fit in version 40.
  static func encode(_ bytes: [UInt8], correction: KitQRCode.Correction = .medium) -> QRMatrix? {
    let level = correction.rawValue
    guard
      let version = (1...40).first(where: { version in
        4 + countBits(version) + bytes.count * 8 <= dataCodewords(version, level) * 8
          && bytes.count < 1 << countBits(version)
      })
    else { return nil }

    // Mode, count, bytes, terminator, then pad to whole codewords with 0xEC 0x11.
    var bits: [Bool] = []
    func append(_ value: Int, _ count: Int) {
      for i in stride(from: count - 1, through: 0, by: -1) { bits.append((value >> i) & 1 == 1) }
    }
    append(0b0100, 4)
    append(bytes.count, countBits(version))
    for byte in bytes { append(Int(byte), 8) }
    let capacity = dataCodewords(version, level) * 8
    append(0, min(4, capacity - bits.count))
    append(0, (8 - bits.count % 8) % 8)
    var pad = 0xEC
    while bits.count < capacity {
      append(pad, 8)
      pad ^= 0xEC ^ 0x11
    }
    var data = [UInt8](repeating: 0, count: bits.count / 8)
    for (i, bit) in bits.enumerated() where bit { data[i >> 3] |= 1 << (7 - UInt8(i & 7)) }

    var matrix = QRMatrix(version: version)
    matrix.drawFunctionPatterns(level: level)
    matrix.drawCodewords(addCorrection(data, version: version, level: level))
    var best = 0
    var lowest = Int.max
    for mask in 0..<8 {
      matrix.applyMask(mask)
      matrix.drawFormatBits(level: level, mask: mask)
      let penalty = matrix.penalty()
      if penalty < lowest {
        lowest = penalty
        best = mask
      }
      matrix.applyMask(mask)
    }
    matrix.applyMask(best)
    matrix.drawFormatBits(level: level, mask: best)
    return matrix
  }

  private init(version: Int) {
    self.version = version
    size = version * 4 + 17
    modules = Array(repeating: false, count: size * size)
    isFunction = Array(repeating: false, count: size * size)
  }

  // MARK: Tables

  /// Error correction codewords per block, by level (L, M, Q, H) and version.
  static let eccPerBlock: [[Int]] = [
    [-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
    [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
    [-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
    [-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
  ]

  /// Error correction blocks, by level (L, M, Q, H) and version.
  static let blocks: [[Int]] = [
    [-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
    [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
    [-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
    [-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81],
  ]

  /// The format's level bits: L 01, M 00, Q 11, H 10.
  static let levelBits = [1, 0, 3, 2]

  /// The byte-mode character count's width.
  static func countBits(_ version: Int) -> Int { version <= 9 ? 8 : 16 }

  /// Modules that hold data (codewords and remainder bits), after the function patterns.
  static func rawDataModules(_ version: Int) -> Int {
    var result = (16 * version + 128) * version + 64
    if version >= 2 {
      let alignments = version / 7 + 2
      result -= (25 * alignments - 10) * alignments - 55
      if version >= 7 { result -= 36 }
    }
    return result
  }

  static func dataCodewords(_ version: Int, _ level: Int) -> Int {
    rawDataModules(version) / 8 - eccPerBlock[level][version] * blocks[level][version]
  }

  static func alignmentPositions(_ version: Int) -> [Int] {
    guard version > 1 else { return [] }
    let count = version / 7 + 2
    let step = (version * 8 + count * 3 + 5) / (count * 4 - 4) * 2
    var result = [6]
    var position = version * 4 + 17 - 7
    var tail: [Int] = []
    for _ in 1..<count {
      tail.insert(position, at: 0)
      position -= step
    }
    result += tail
    return result
  }

  // MARK: Error correction

  /// Splits the data into blocks, appends each block's Reed–Solomon codewords and interleaves them.
  static func addCorrection(_ data: [UInt8], version: Int, level: Int) -> [UInt8] {
    let blockCount = blocks[level][version]
    let eccLength = eccPerBlock[level][version]
    let raw = rawDataModules(version) / 8
    let shortBlocks = blockCount - raw % blockCount
    let shortLength = raw / blockCount
    let divisor = reedSolomonDivisor(eccLength)
    var split: [[UInt8]] = []
    var offset = 0
    for i in 0..<blockCount {
      let length = shortLength - eccLength + (i < shortBlocks ? 0 : 1)
      var block = Array(data[offset..<offset + length])
      offset += length
      let ecc = reedSolomonRemainder(block, divisor)
      if i < shortBlocks { block.append(0) }
      split.append(block + ecc)
    }
    var result: [UInt8] = []
    for i in 0..<split[0].count {
      for (j, block) in split.enumerated() where i != shortLength - eccLength || j >= shortBlocks {
        result.append(block[i])
      }
    }
    return result
  }

  static func reedSolomonDivisor(_ degree: Int) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: degree)
    result[degree - 1] = 1
    var root: UInt8 = 1
    for _ in 0..<degree {
      for j in 0..<degree {
        result[j] = multiply(result[j], root)
        if j + 1 < degree { result[j] ^= result[j + 1] }
      }
      root = multiply(root, 0x02)
    }
    return result
  }

  static func reedSolomonRemainder(_ data: [UInt8], _ divisor: [UInt8]) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: divisor.count)
    for byte in data {
      let factor = byte ^ result.removeFirst()
      result.append(0)
      for i in result.indices { result[i] ^= multiply(divisor[i], factor) }
    }
    return result
  }

  /// Multiplication in GF(2^8) modulo x^8 + x^4 + x^3 + x^2 + 1.
  static func multiply(_ x: UInt8, _ y: UInt8) -> UInt8 {
    var z = 0
    for i in stride(from: 7, through: 0, by: -1) {
      z = (z << 1) ^ ((z >> 7) * 0x11D)
      z ^= Int((y >> UInt8(i)) & 1) * Int(x)
    }
    return UInt8(z & 0xFF)
  }

  // MARK: Drawing

  private mutating func set(_ x: Int, _ y: Int, _ dark: Bool, function: Bool = true) {
    modules[y * size + x] = dark
    if function { isFunction[y * size + x] = true }
  }

  private mutating func drawFunctionPatterns(level: Int) {
    for i in 0..<size {
      set(6, i, i % 2 == 0)
      set(i, 6, i % 2 == 0)
    }
    drawFinder(3, 3)
    drawFinder(size - 4, 3)
    drawFinder(3, size - 4)
    let positions = Self.alignmentPositions(version)
    let last = positions.count - 1
    for (i, x) in positions.enumerated() {
      for (j, y) in positions.enumerated() where !((i == 0 && j == 0) || (i == 0 && j == last) || (i == last && j == 0)) {
        for dy in -2...2 {
          for dx in -2...2 { set(x + dx, y + dy, max(abs(dx), abs(dy)) != 1) }
        }
      }
    }
    drawFormatBits(level: level, mask: 0)
    drawVersion()
  }

  private mutating func drawFinder(_ x: Int, _ y: Int) {
    for dy in -4...4 {
      for dx in -4...4 {
        let distance = max(abs(dx), abs(dy))
        let xx = x + dx
        let yy = y + dy
        if (0..<size).contains(xx), (0..<size).contains(yy) { set(xx, yy, distance != 2 && distance != 4) }
      }
    }
  }

  private mutating func drawFormatBits(level: Int, mask: Int) {
    let data = Self.levelBits[level] << 3 | mask
    var remainder = data
    for _ in 0..<10 { remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537) }
    let bits = (data << 10 | remainder) ^ 0x5412
    func bit(_ i: Int) -> Bool { (bits >> i) & 1 == 1 }
    for i in 0...5 { set(8, i, bit(i)) }
    set(8, 7, bit(6))
    set(8, 8, bit(7))
    set(7, 8, bit(8))
    for i in 9..<15 { set(14 - i, 8, bit(i)) }
    for i in 0..<8 { set(size - 1 - i, 8, bit(i)) }
    for i in 8..<15 { set(8, size - 15 + i, bit(i)) }
    set(8, size - 8, true)
  }

  private mutating func drawVersion() {
    guard version >= 7 else { return }
    var remainder = version
    for _ in 0..<12 { remainder = (remainder << 1) ^ ((remainder >> 11) * 0x1F25) }
    let bits = version << 12 | remainder
    for i in 0..<18 {
      let dark = (bits >> i) & 1 == 1
      let a = size - 11 + i % 3
      let b = i / 3
      set(a, b, dark)
      set(b, a, dark)
    }
  }

  private mutating func drawCodewords(_ data: [UInt8]) {
    var i = 0
    var right = size - 1
    while right >= 1 {
      if right == 6 { right = 5 }
      for vertical in 0..<size {
        for j in 0..<2 {
          let x = right - j
          let upward = (right + 1) & 2 == 0
          let y = upward ? size - 1 - vertical : vertical
          if !isFunction[y * size + x], i < data.count * 8 {
            set(x, y, (data[i >> 3] >> (7 - UInt8(i & 7))) & 1 == 1, function: false)
            i += 1
          }
        }
      }
      right -= 2
    }
  }

  private mutating func applyMask(_ mask: Int) {
    for y in 0..<size {
      for x in 0..<size where !isFunction[y * size + x] {
        let invert: Bool =
          switch mask {
          case 0: (x + y) % 2 == 0
          case 1: y % 2 == 0
          case 2: x % 3 == 0
          case 3: (x + y) % 3 == 0
          case 4: (x / 3 + y / 2) % 2 == 0
          case 5: x * y % 2 + x * y % 3 == 0
          case 6: (x * y % 2 + x * y % 3) % 2 == 0
          default: ((x + y) % 2 + x * y % 3) % 2 == 0
          }
        if invert { modules[y * size + x].toggle() }
      }
    }
  }

  // MARK: Penalty

  func penalty() -> Int {
    var result = 0
    for line in 0..<size {
      for horizontal in [true, false] {
        var color = false
        var run = 0
        var history = [Int](repeating: 0, count: 7)
        for i in 0..<size {
          let dark = horizontal ? self[i, line] : self[line, i]
          if dark == color {
            run += 1
            if run == 5 { result += 3 } else if run > 5 { result += 1 }
          } else {
            addHistory(run, &history)
            if !color { result += finderPatterns(history) * 40 }
            color = dark
            run = 1
          }
        }
        if color {
          addHistory(run, &history)
          run = 0
        }
        addHistory(run + size, &history)
        result += finderPatterns(history) * 40
      }
    }
    for y in 0..<size - 1 {
      for x in 0..<size - 1 {
        let c = self[x, y]
        if c == self[x + 1, y], c == self[x, y + 1], c == self[x + 1, y + 1] { result += 3 }
      }
    }
    let dark = modules.reduce(0) { $0 + ($1 ? 1 : 0) }
    let total = size * size
    let k = (abs(dark * 20 - total * 10) + total - 1) / total - 1
    result += k * 10
    return result
  }

  private func addHistory(_ run: Int, _ history: inout [Int]) {
    var run = run
    if history[0] == 0 { run += size }
    history.removeLast()
    history.insert(run, at: 0)
  }

  private func finderPatterns(_ h: [Int]) -> Int {
    let n = h[1]
    let core = n > 0 && h[2] == n && h[3] == n * 3 && h[4] == n && h[5] == n
    return (core && h[0] >= n * 4 && h[6] >= n ? 1 : 0) + (core && h[6] >= n * 4 && h[0] >= n ? 1 : 0)
  }
}
