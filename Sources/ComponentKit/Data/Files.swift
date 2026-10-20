import SwiftUI

// MARK: - File cell

/// A file's or folder's name in a table cell or a row: a glyph for its kind (folders teal, files quiet), then the
/// name, shortened in the middle so the extension stays. The kind comes from the name's extension.
///
/// ```swift
/// KitGridColumn<FileItem>("Name", width: 300) { KitFileCell($0.name, isFolder: $0.isFolder) }
/// KitFileCell("Moodboard.fig")
/// ```
public struct KitFileCell: View {
  /// What a file is, for its glyph.
  public enum Kind: Hashable, Sendable {
    case folder, document, text, image, video, audio, archive

    /// The kind of a file named `name` (`isFolder` wins over the extension: "Photos.library" is a folder).
    nonisolated public static func of(_ name: String, isFolder: Bool = false) -> Kind {
      if isFolder { return .folder }
      guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return .document }
      let ext = name[name.index(after: dot)...].lowercased()
      if images.contains(ext) { return .image }
      if videos.contains(ext) { return .video }
      if sounds.contains(ext) { return .audio }
      if archives.contains(ext) { return .archive }
      if texts.contains(ext) { return .text }
      return .document
    }

    static let images: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "gif", "tif", "tiff", "webp", "bmp", "svg", "raw", "dng", "psd"]
    static let videos: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]
    static let sounds: Set<String> = ["mp3", "m4a", "wav", "aif", "aiff", "flac", "aac", "ogg"]
    static let archives: Set<String> = ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "dmg"]
    static let texts: Set<String> = [
      "txt", "md", "markdown", "rtf", "csv", "tsv", "json", "yaml", "yml", "xml", "html", "css", "js", "ts", "swift",
      "py", "rb", "go", "rs", "c", "h", "m", "cpp", "java", "kt", "sh", "toml", "ini", "log", "sql", "fig",
    ]

    public var systemImage: String {
      switch self {
      case .folder: "folder"
      case .document: "doc"
      case .text: "doc.text"
      case .image: "photo"
      case .video: "film"
      case .audio: "waveform"
      case .archive: "doc.zipper"
      }
    }
  }

  var name: String
  var kind: Kind
  var systemImage: String?
  @Environment(\.kitIdiom) private var idiom

  /// - Parameters:
  ///   - isFolder: a folder (its glyph is teal).
  ///   - systemImage: a glyph of the app's own, in place of the kind's (a locked folder, a package).
  public init(_ name: String, isFolder: Bool = false, systemImage: String? = nil) {
    self.name = name
    self.kind = Kind.of(name, isFolder: isFolder)
    self.systemImage = systemImage
  }

  public var body: some View {
    HStack(spacing: 8) {
      Image(systemName: systemImage ?? kind.systemImage)
        .font(.system(size: idiom.isTouch ? 15 : 13))
        .foregroundStyle(kind == .folder ? AnyShapeStyle(Hue.teal.fill) : AnyShapeStyle(.kitSecondary))
        .frame(width: idiom.isTouch ? 20 : 16)
        .accessibilityHidden(true)
      Text(name)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(kind == .folder ? "\(name), folder" : name)
  }
}

// MARK: - Text conflict

/// Two copies of a text file that changed in two places, side by side: each in a group with its label chip (Mine
/// orange, Remote blue), where and when it changed, and its numbered lines with the changed words in bold. Unlike
/// `ConflictCard` it holds no choice: put it in a `KitSection` whose header carries the actions ("Keep Mine",
/// "Revert to Remote"). One copy over the other where there's no room for two.
///
/// ```swift
/// KitSection("Selects.txt", meta: ["changed here and on MacBook Air"], systemImage: "exclamationmark.triangle", hue: .purple) {
///   TextConflict(mine: ConflictSide("Mine", ref: "Studio Mac · 10:12 AM", code: mine),
///                theirs: ConflictSide("Remote", ref: "Jonas · MacBook Air · 10:40 AM", code: remote))
/// } actions: { … }
/// ```
public struct TextConflict: View {
  var mine: ConflictSide
  var theirs: ConflictSide
  var mineHue: Hue
  var theirsHue: Hue
  @Environment(\.kitIdiom) private var idiom

  public init(mine: ConflictSide, theirs: ConflictSide, mineHue: Hue = .orange, theirsHue: Hue = .blue) {
    self.mine = mine
    self.theirs = theirs
    self.mineHue = mineHue
    self.theirsHue = theirsHue
  }

  public var body: some View {
    let marks = Self.changes(mine.lines.map { String($0.characters) }, theirs.lines.map { String($0.characters) })
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 8) {
        panel(mine, hue: mineHue, marks: marks.mine)
        panel(theirs, hue: theirsHue, marks: marks.theirs)
      }
      .frame(minWidth: 420)
      VStack(spacing: 8) {
        panel(mine, hue: mineHue, marks: marks.mine)
        panel(theirs, hue: theirsHue, marks: marks.theirs)
      }
    }
  }

  private func panel(_ side: ConflictSide, hue: Hue, marks: [[Range<Int>]]) -> some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusLarge, style: .continuous)
    let digits = max(2, String(side.lines.count).count)
    return VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Chip(side.label, hue: hue).controlSize(.small)
        if let ref = side.ref { Text(ref).kitFont(.caption).lineLimit(1) }
      }
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(side.lines.enumerated()), id: \.offset) { index, line in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(index + 1)")
              .foregroundStyle(.kitTertiary)
              .frame(width: CGFloat(digits) * 7.5, alignment: .trailing)
            Text(Self.marked(line, index < marks.count ? marks[index] : []))
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .frame(minHeight: idiom.isTouch ? 22 : 18)
        }
      }
      .font(.system(size: idiom.isTouch ? 14 : 12, design: .monospaced))
      .textSelection(.enabled)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.kitFillSoft, in: shape)
    .overlay(shape.strokeBorder(.kitSeparator, lineWidth: 0.5))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(side.label)
  }

  /// `line` with the character ranges in `ranges` in bold.
  nonisolated static func marked(_ line: AttributedString, _ ranges: [Range<Int>]) -> AttributedString {
    var line = line
    let count = line.characters.count
    for range in ranges where range.lowerBound < count {
      let start = line.index(line.startIndex, offsetByCharacters: range.lowerBound)
      let end = line.index(line.startIndex, offsetByCharacters: min(range.upperBound, count))
      line[start..<end].inlinePresentationIntent = .stronglyEmphasized
    }
    return line
  }

  // MARK: Changed words (pure, tested)

  /// The changed parts of each line, as character ranges, for both copies. Lines are matched by a longest common
  /// subsequence; between two matched lines, the copies' lines pair up in order and their changed words are
  /// marked (a run of changed words, with the spaces between them, is one range); a line with no partner is
  /// changed throughout.
  nonisolated static func changes(_ mine: [String], _ theirs: [String]) -> (mine: [[Range<Int>]], theirs: [[Range<Int>]]) {
    var mineMarks = Array(repeating: [Range<Int>](), count: mine.count)
    var theirMarks = Array(repeating: [Range<Int>](), count: theirs.count)
    var i = 0
    var j = 0
    for (a, b) in lcs(mine, theirs) + [(mine.count, theirs.count)] {
      // The gap before this match: pair its lines in order.
      let pairs = min(a - i, b - j)
      for k in 0..<pairs {
        let words = changedWords(mine[i + k], theirs[j + k])
        mineMarks[i + k] = words.mine
        theirMarks[j + k] = words.theirs
      }
      for k in (i + pairs)..<a where !mine[k].isEmpty { mineMarks[k] = [0..<mine[k].count] }
      for k in (j + pairs)..<b where !theirs[k].isEmpty { theirMarks[k] = [0..<theirs[k].count] }
      i = a + 1
      j = b + 1
    }
    return (mineMarks, theirMarks)
  }

  /// The changed words of two versions of a line, as character ranges in each.
  nonisolated static func changedWords(_ mine: String, _ theirs: String) -> (mine: [Range<Int>], theirs: [Range<Int>]) {
    let a = words(mine)
    let b = words(theirs)
    let matches = lcs(a.map(\.word), b.map(\.word))
    let keptA = Set(matches.map(\.0))
    let keptB = Set(matches.map(\.1))
    return (runs(a, kept: keptA), runs(b, kept: keptB))
  }

  /// Words (runs of non-space characters) with their character ranges.
  nonisolated static func words(_ line: String) -> [(word: String, range: Range<Int>)] {
    var result: [(String, Range<Int>)] = []
    var start: Int?
    var current = ""
    for (offset, character) in line.enumerated() {
      if character.isWhitespace {
        if let s = start { result.append((current, s..<offset)) }
        start = nil
        current = ""
      } else {
        if start == nil { start = offset }
        current.append(character)
      }
    }
    if let s = start { result.append((current, s..<line.count)) }
    return result
  }

  /// The ranges of the words not kept, a run of neighbouring ones joined into one range.
  nonisolated private static func runs(_ words: [(word: String, range: Range<Int>)], kept: Set<Int>) -> [Range<Int>] {
    var result: [Range<Int>] = []
    var previous: Int?
    for (index, item) in words.enumerated() where !kept.contains(index) {
      if let last = result.last, previous == index - 1 {
        result[result.count - 1] = last.lowerBound..<item.range.upperBound
      } else {
        result.append(item.range)
      }
      previous = index
    }
    return result
  }

  /// The index pairs of a longest common subsequence of `a` and `b`, in order.
  nonisolated static func lcs(_ a: [String], _ b: [String]) -> [(Int, Int)] {
    guard !a.isEmpty, !b.isEmpty else { return [] }
    var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for x in stride(from: a.count - 1, through: 0, by: -1) {
      for y in stride(from: b.count - 1, through: 0, by: -1) {
        table[x][y] = a[x] == b[y] ? table[x + 1][y + 1] + 1 : max(table[x + 1][y], table[x][y + 1])
      }
    }
    var result: [(Int, Int)] = []
    var x = 0
    var y = 0
    while x < a.count, y < b.count {
      if a[x] == b[y] {
        result.append((x, y))
        x += 1
        y += 1
      } else if table[x + 1][y] >= table[x][y + 1] {
        x += 1
      } else {
        y += 1
      }
    }
    return result
  }
}
