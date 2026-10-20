import Foundation
import Testing

@testable import ComponentKit

#if canImport(CoreImage) && os(macOS)
  import CoreImage
#endif

// MARK: - Secrets and codes

@Test func secretMaskHidesLength() {
  #expect(KitSecretValue.mask.count == 16)
  #expect(KitSecretValue.mask == String(repeating: "•", count: KitSecretValue.maskLength))
}

@Test func oneTimeCodeCountdown() {
  // 30 s periods start on multiples of 30 since 1970.
  #expect(KitOneTimeCode.remaining(at: Date(timeIntervalSince1970: 60), period: 30) == 30)
  #expect(KitOneTimeCode.remaining(at: Date(timeIntervalSince1970: 71), period: 30) == 19)
  #expect(abs(KitOneTimeCode.remaining(at: Date(timeIntervalSince1970: 89.5), period: 30) - 0.5) < 0.0001)
  #expect(KitOneTimeCode.remaining(at: Date(timeIntervalSince1970: 61), period: 60) == 59)
  #expect(KitOneTimeCode.remaining(at: .now, period: 0) == 0)
}

@Test func oneTimeCodeGroups() {
  #expect(KitOneTimeCode.grouped("482913") == "482 913")
  #expect(KitOneTimeCode.grouped("12345678") == "1234 5678")
  #expect(KitOneTimeCode.grouped("12345") == "12345")
  #expect(KitOneTimeCode.grouped("1234567") == "1234567")
}

@Test func safetyCodeGroups() {
  let digits = "603919375512067304187729128814641028931722740519834062518874"
  let groups = KitSafetyCode.groups(digits)
  #expect(groups.count == 12)
  #expect(groups.first == "60391")
  #expect(groups.last == "18874")
  // Spaces and other characters are ignored; a short tail stays short.
  #expect(KitSafetyCode.groups("12345 67890-123") == ["12345", "67890", "123"])
  #expect(KitSafetyCode.groups("") == [])
}

@Test func wordGridRowsReadAcross() {
  #expect(KitWordGrid.rows(count: 24, columns: 4).count == 6)
  #expect(KitWordGrid.rows(count: 24, columns: 4)[1] == 4..<8)
  #expect(KitWordGrid.rows(count: 24, columns: 3).last == 21..<24)
  #expect(KitWordGrid.rows(count: 5, columns: 4) == [0..<4, 4..<5])
  #expect(KitWordGrid.rows(count: 3, columns: 0) == [0..<1, 1..<2, 2..<3])
}

// MARK: - Files

@Test func fileKinds() {
  #expect(KitFileCell.Kind.of("Receipts", isFolder: true) == .folder)
  #expect(KitFileCell.Kind.of("Photos.library", isFolder: true) == .folder)
  #expect(KitFileCell.Kind.of("Home office.HEIC") == .image)
  #expect(KitFileCell.Kind.of("IMG_2293.mov") == .video)
  #expect(KitFileCell.Kind.of("Accountant notes.md") == .text)
  #expect(KitFileCell.Kind.of("2025 Return.pdf") == .document)
  #expect(KitFileCell.Kind.of("backup.tar.gz") == .archive)
  #expect(KitFileCell.Kind.of(".gitignore") == .document)
  #expect(KitFileCell.Kind.of("README") == .document)
}

@Test func textConflictMarksChangedWords() {
  let mine = ["IMG_2201 cover", "IMG_2214 tram, cropped", "IMG_2230 night"]
  let theirs = ["IMG_2201 cover", "IMG_2214 tram", "IMG_2251 river"]
  let marks = TextConflict.changes(mine, theirs)
  #expect(marks.mine[0].isEmpty)
  #expect(marks.theirs[0].isEmpty)
  // "tram, cropped" is one run of changed words.
  #expect(marks.mine[1] == [9..<22])
  #expect(marks.theirs[1] == [9..<13])
  #expect(marks.mine[2] == [0..<14])
  #expect(marks.theirs[2] == [0..<14])
}

@Test func textConflictUnpairedLinesChangeThroughout() {
  let marks = TextConflict.changes(["a", "b", "c"], ["a", "c", "d", "e"])
  #expect(marks.mine == [[], [0..<1], []])
  #expect(marks.theirs == [[], [], [0..<1], [0..<1]])
  // Words kept between changes split the runs.
  let words = TextConflict.changedWords("one two three four", "one 2 three 4")
  #expect(words.mine == [4..<7, 14..<18])
  #expect(words.theirs == [4..<5, 12..<13])
}

// MARK: - QR codes

@Test func qrGaloisField() {
  #expect(QRMatrix.multiply(0, 0x53) == 0)
  #expect(QRMatrix.multiply(1, 0x53) == 0x53)
  #expect(QRMatrix.multiply(2, 0x80) == 0x1D)
  // The degree-7 generator for version 1-L, from the standard (log form 0, 87, 229, 146, 149, 238, 102, 21).
  #expect(QRMatrix.reedSolomonDivisor(7) == [0x7F, 0x7A, 0x9A, 0xA4, 0x0B, 0x44, 0x75])
}

@Test func qrVersionsAndLayout() {
  let small = QRMatrix.encode(Array("HELLO".utf8), correction: .medium)
  #expect(small?.version == 1)
  #expect(small?.size == 21)
  // 14 bytes fill version 1-M; one more needs version 2.
  #expect(QRMatrix.encode(Array(repeating: 0x41, count: 14), correction: .medium)?.version == 1)
  #expect(QRMatrix.encode(Array(repeating: 0x41, count: 15), correction: .medium)?.version == 2)
  #expect(QRMatrix.alignmentPositions(7) == [6, 22, 38])
  #expect(QRMatrix.alignmentPositions(32) == [6, 34, 60, 86, 112, 138])
  // The data codewords of every version match the standard's totals at the two ends.
  #expect(QRMatrix.dataCodewords(1, 0) == 19)
  #expect(QRMatrix.dataCodewords(40, 3) == 1276)
  #expect(QRMatrix.encode(Array(repeating: 0, count: 3000), correction: .high) == nil)
  // Finder patterns sit in three corners.
  if let small {
    #expect(small[0, 0] && small[6, 0] && small[0, 6] && !small[1, 1] && small[2, 2])
    #expect(small[20, 0] && small[0, 20])
    #expect(!small[7, 7])
  }
}

#if canImport(CoreImage) && os(macOS)
  /// The text a QR detector reads from the matrix drawn at 8 pixels a module with a 4-module quiet zone.
  private func decoded(_ matrix: QRMatrix) -> String? {
    let scale = 8
    let side = (matrix.size + 8) * scale
    var pixels = [UInt8](repeating: 255, count: side * side)
    for y in 0..<matrix.size {
      for x in 0..<matrix.size where matrix[x, y] {
        for dy in 0..<scale {
          for dx in 0..<scale { pixels[((y + 4) * scale + dy) * side + (x + 4) * scale + dx] = 0 }
        }
      }
    }
    let image = CIImage(
      bitmapData: Data(pixels), bytesPerRow: side, size: CGSize(width: side, height: side), format: .L8,
      colorSpace: CGColorSpaceCreateDeviceGray())
    let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    return (detector?.features(in: image).first as? CIQRCodeFeature)?.messageString
  }

  @Test(arguments: [
    "HELLO",
    "v57vault://invite?id=v57id:Q2hhbmdlIHRoaXMgaW52aXRlIGlmIHlvdSByZWFkIGl0&name=Rafael",
    "otpauth://totp/Atlas:aiko?secret=JBSWY3DPEHPK3PXP&issuer=Atlas&digits=6&period=30",
    String(repeating: "abandon ability able about above absent absorb abstract ", count: 6),
    "Ünïcødé — 鍵 🔑",
  ])
  func qrCodesDecode(text: String) throws {
    for correction in KitQRCode.Correction.allCases {
      let matrix = try #require(QRMatrix.encode(Array(text.utf8), correction: correction))
      #expect(decoded(matrix) == text, "version \(matrix.version), \(correction)")
    }
  }
#endif
