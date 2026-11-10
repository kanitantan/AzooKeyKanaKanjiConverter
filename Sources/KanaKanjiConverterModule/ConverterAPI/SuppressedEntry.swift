import Foundation
import SwiftUtils

/// azuki patch: a (reading, word) pair that must never be offered.
///
/// A suppressed pair is removed where dictionary entries become lattice nodes
/// (`DicdataStore.lookupDicdata`), so ordinary conversion, Zenzai's constrained
/// searches and the whole-sentence supplement all pick surviving paths instead
/// of losing a candidate after the fact. Prediction and user shortcuts bypass
/// the lattice and are filtered separately.
///
/// This is dictionary-entry suppression: the reading is compared with an
/// entry's ruby (katakana) and the word with its surface. Another reading of
/// the same word (ケッシテ=決して for ケシテ=決して) is untouched, and learned
/// entries stay in memory while hidden. It does not block a surface as such:
/// another segmentation can still produce the same text (suppressing
/// ケッシテ=決して lets ケッシ=決し + テ=て rebuild 決して, and 消して for ケシテ
/// is 消し + て to begin with), so each pair must be verified on the real
/// dictionary before relying on it.
public struct SuppressedEntry: Sendable, Hashable {
    public var reading: String
    public var word: String

    public init(reading: String, word: String) {
        self.reading = reading
        self.word = word
    }
}

extension SuppressedEntry {
    /// The policy as stored by `DicdataStoreState`: katakana ruby -> words.
    /// Readings are normalized once here so lookups compare plain strings.
    static func policy(from entries: [SuppressedEntry]) -> [String: Set<String>] {
        var policy: [String: Set<String>] = [:]
        for entry in entries where !entry.reading.isEmpty && !entry.word.isEmpty {
            policy[entry.reading.toKatakana(), default: []].insert(entry.word)
        }
        return policy
    }
}
