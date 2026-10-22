import Foundation

/// How well a name heard by speech recognition fits a name in Contacts.
///
/// Speech recognition spells names as it pleases: "Franciska" for Franziska, "Toby" for Tobi.
/// A spelling that sounds the same, or is one letter off, is a close fit. A name that only
/// begins like the other ("Tobi" for Tobias, but also "Franciska" for Franz) is a short form,
/// and a short form alone is never enough to send a message without asking.
enum NameMatch {
    enum Fit: Int, Comparable {
        case none, shortForm, close, exact

        static func < (a: Fit, b: Fit) -> Bool { a.rawValue < b.rawValue }
    }

    /// How well one word heard fits one name. Both are expected folded: lowercase, no accents.
    static func fit(_ heard: String, _ name: String) -> Fit {
        if heard == name { return .exact }
        let a = sound(heard), b = sound(name)
        if a == b { return .close }
        // One name and more letters is a short form, however few the letters: "Franzi" is
        // Franziska as often as Franz.
        if b.hasPrefix(a) || a.hasPrefix(b) { return min(a.count, b.count) >= 2 ? .shortForm : .none }
        let longer = max(a.count, b.count)
        if longer >= 5, distance(a, b) <= (longer >= 9 ? 2 : 1) { return .close }
        let shared = zip(a, b).prefix { $0 == $1 }.count
        if shared >= 3, shared * 2 >= min(a.count, b.count) { return .shortForm }
        return .none
    }

    /// How well everything said fits a person with these names: every word has to fit one of
    /// them, and the person fits as well as their worst word.
    static func fit(words: [String], names: [String]) -> Fit {
        guard !words.isEmpty, !names.isEmpty else { return .none }
        return words.map { word in names.map { fit(word, $0) }.max() ?? .none }.min() ?? .none
    }

    /// The people who fit best, and how well. People who fit worse than the best are left out:
    /// with Franziska a close fit for "Franciska", Franz is not a candidate at all.
    static func best<Person>(_ spoken: String, among people: [Person], names: (Person) -> [String]) -> (fit: Fit, people: [Person]) {
        let words = spoken.split(whereSeparator: { !$0.isLetter && $0 != "-" }).map { fold(String($0)) }
        let scored = people.map { ($0, fit(words: words, names: names($0).map(fold))) }
        guard let top = scored.map(\.1).max(), top > .none else { return (.none, []) }
        return (top, scored.filter { $0.1 == top }.map(\.0))
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// The word as it sounds, roughly, across English and German spellings: Franziska and
    /// Franciska, Tobi and Toby, Philipp and Filip, Kathrin and Catrin come out the same.
    static func sound(_ word: String) -> String {
        let letters = Array(word.filter(\.isLetter))
        var out: [Character] = []
        var i = 0
        while i < letters.count {
            let c = letters[i]
            let next: Character? = i + 1 < letters.count ? letters[i + 1] : nil
            switch (c, next) {
            case ("p", "h"): out.append("f"); i += 2; continue
            case ("t", "h"): out.append("t"); i += 2; continue
            case ("c", "k"): out.append("k"); i += 2; continue
            case ("t", "z"): out.append("s"); i += 2; continue
            case ("c", "h"): out.append("k"); i += 2; continue
            case ("u", "e"), ("a", "e"), ("o", "e") where i > 0: out.append(c); i += 2; continue   // "Mueller" is Müller
            case ("i", "e") where i + 2 == letters.count || i > 0: out.append("i"); i += 2; continue
            default: break
            }
            switch c {
            case "c": out.append(next.map { "eiy".contains($0) } == true ? "s" : "k")
            case "z": out.append("s")
            case "y": out.append("i")
            case "w": out.append("v")
            case "q": out.append("k")
            case "x": out.append(contentsOf: "ks")
            case "h" where !out.isEmpty: break   // silent after a letter: "Johanna", "Sarah"
            default: out.append(c)
            }
            i += 1
        }
        // Double letters sound as one: "Anna" and "Ana", "Philipp" and "Filip".
        return String(out.enumerated().filter { $0.offset == 0 || out[$0.offset - 1] != $0.element }.map(\.element))
    }

    /// The number of single-letter edits between two words.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var previous = row[0]
            row[0] = i
            for j in 1...b.count {
                let above = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] == b[j - 1] ? 0 : 1))
                previous = above
            }
        }
        return row[b.count]
    }
}
