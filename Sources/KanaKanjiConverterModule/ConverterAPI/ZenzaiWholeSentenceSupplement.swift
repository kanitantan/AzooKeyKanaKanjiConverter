import Foundation
import SwiftUtils

/// azuki patch: dictionary-ranked whole-sentence candidates shown below the
/// Zenzai ones.
///
/// With Zenzai the whole-sentence results are only its pick and the
/// alternatives zenz proposes, so when zenz accepts a reading as-is (a learned
/// もんで) no dictionary conversion of the whole input (揉んで, 門で) is offered
/// at all. `KanaKanjiConverter.convertToLattice` re-runs a small plain N-best
/// search on the lattice Zenzai already built and `processResult` merges the
/// result with `merge`. The rules live here, apart from the converter, so they
/// can be tested without a model.
@_spi(AzukiTesting) public enum ZenzaiWholeSentenceSupplement {
    /// N-best of the extra lattice search. 5 and above cost a p95 regression
    /// out of proportion to what they add (measured 2026-10-23).
    public static let nBest = 3
    /// Longest reading (in kana) the search runs for. Longer inputs are where
    /// the extra search costs most, and their dictionary-ranked whole
    /// sentences are mostly noise (今日は貼れですね for 今日は晴れですね).
    public static let maxSurfaceCount = 8
    /// How many new candidates are added after filtering and dedup.
    public static let displayLimit = 3

    public static func shouldCollect(surfaceCount: Int) -> Bool {
        (1...maxSurfaceCount).contains(surfaceCount)
    }

    /// Whether the candidate consumes the whole composition (decided on the
    /// input, not on the ruby length, so a partial candidate is never taken
    /// for a whole-input one).
    public static func readsWholeInput(_ candidate: Candidate, of inputData: ComposingText) -> Bool {
        var rest = inputData
        rest.prefixComplete(composingCount: candidate.composingCount)
        return rest.convertTarget.isEmpty
    }

    /// Inserts the supplement into the finished candidate list.
    ///
    /// `list[..<wholeSentenceCount]` are the converter's whole-sentence
    /// results. The supplement goes right after the contiguous run of
    /// candidates from there on that read the whole input (with Zenzai those
    /// are single dictionary words and kana pass-throughs such as 呼んで,
    /// ヨンデ), i.e. before the first partial candidate; every existing
    /// candidate keeps its relative order. A supplement candidate is kept only
    /// if it reads the whole input with exactly the input's reading, its text
    /// is not listed yet, and it has no ASCII letters (roman leftovers like
    /// 今de and English entries read as kana like 家族ALBUM; existing
    /// candidates are not filtered). At most `displayLimit` are added.
    public static func merge(
        _ list: [Candidate],
        wholeSentenceCount: Int,
        supplement: [Candidate],
        inputData: ComposingText
    ) -> [Candidate] {
        let reading = inputData.convertTarget.toKatakana()
        var seen = Set(list.map(\.text))
        var added: [Candidate] = []
        for candidate in supplement where added.count < displayLimit {
            guard candidate.data.reduce(into: "", { $0 += $1.ruby }) == reading,
                  readsWholeInput(candidate, of: inputData),
                  !candidate.text.unicodeScalars.contains(where: { $0.isASCII && $0.properties.isAlphabetic }),
                  seen.insert(candidate.text).inserted else {
                continue
            }
            added.append(candidate)
        }
        guard !added.isEmpty else {
            return list
        }
        let start = min(max(wholeSentenceCount, 0), list.endIndex)
        let position = list[start...].firstIndex { !readsWholeInput($0, of: inputData) } ?? list.endIndex
        var result = list
        result.insert(contentsOf: added, at: position)
        return result
    }
}
