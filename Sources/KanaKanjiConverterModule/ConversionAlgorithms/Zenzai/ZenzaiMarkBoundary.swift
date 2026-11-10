import Foundation

/// azuki patch: a (han)dakuten mark must not complete a Zenzai prefix
/// constraint.
///
/// Zenzai turns the model's preferred continuation into a byte-prefix
/// constraint (一休ロ) and accepts any lattice path whose text starts with
/// those bytes. A path that continues with a (han)dakuten mark right at the
/// constraint's end (一休ロ゜, from the system entry ロ=ロ゜) passes that test
/// although the mark rewrites the constrained character, and it reached the
/// top when nothing better satisfied the constraint (after BackSpace from
/// いっきゅうろぐ to いっきゅうろ). The same holds when the constraint ends inside
/// a character (ロ + E3 82 is also completed by ゜ = E3 82 9C). Upstream only
/// rejects the combining marks U+3099/U+309A on its retry path
/// (`heuristicRetryValidation`); this rule covers U+3099...U+309C wherever a
/// constraint is matched. Design 2026-11-10, Codex thread 01a1c369.
///
/// The rule applies to nonempty constraints without EOS, to candidates that
/// match the constraint bytes, and looks only at the scalar that straddles the
/// constraint's end or starts right at it. EOS constraints are exact matches
/// and stay as they are; a constraint that itself spells the mark is fine.
@_spi(AzukiTesting) public enum ZenzaiMarkBoundary {
    /// U+3099 combining dakuten ... U+309C spacing handakuten, all E3 82 99...9C.
    @inline(__always)
    static func isMark(_ bytes: [UInt8], at start: Int) -> Bool {
        start >= 0 && start + 2 < bytes.count
            && bytes[start] == 0xE3 && bytes[start + 1] == 0x82
            && (0x99 ... 0x9C).contains(bytes[start + 2])
    }

    /// Whether the scalar of `bytes` that contains byte `offset`, or starts at
    /// it, is a (han)dakuten mark.
    public static func markAt(_ bytes: [UInt8], offset: Int) -> Bool {
        guard offset >= 0, offset < bytes.count else {
            return false
        }
        var start = offset
        while start > 0, bytes[start] & 0xC0 == 0x80 {
            start -= 1
        }
        return isMark(bytes, at: start)
    }

    /// For one lexical word placed at byte offset `wordStart` of a path:
    /// whether the constraint boundary falls inside this word on a mark. A
    /// scalar never spans two words, so exactly one word of a path can hold
    /// the boundary scalar (the next word when the boundary is at a word end).
    public static func word(_ word: String, startingAt wordStart: Int, marksBoundary boundary: Int) -> Bool {
        guard boundary > 0, boundary >= wordStart, boundary < wordStart + word.utf8.count else {
            return false
        }
        return markAt(Array(word.utf8), offset: boundary - wordStart)
    }

    /// For a whole candidate text: true when it matches `constraint` (nonempty,
    /// no EOS) and a mark completes the constraint's end.
    public static func text(_ text: String, marksBoundaryOf constraint: [UInt8]) -> Bool {
        guard !constraint.isEmpty else {
            return false
        }
        let bytes = Array(text.utf8)
        guard bytes.count > constraint.count, bytes.starts(with: constraint) else {
            return false
        }
        return markAt(bytes, offset: constraint.count)
    }
}
