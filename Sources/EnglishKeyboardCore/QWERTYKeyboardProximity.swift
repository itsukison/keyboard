import Foundation

enum QWERTYKeyboardProximity {
    private static let positions: [Character: (x: Double, y: Double)] = [
        "q": (0, 0), "w": (1, 0), "e": (2, 0), "r": (3, 0), "t": (4, 0),
        "y": (5, 0), "u": (6, 0), "i": (7, 0), "o": (8, 0), "p": (9, 0),
        "a": (0.5, 1), "s": (1.5, 1), "d": (2.5, 1), "f": (3.5, 1), "g": (4.5, 1),
        "h": (5.5, 1), "j": (6.5, 1), "k": (7.5, 1), "l": (8.5, 1),
        "z": (1, 2), "x": (2, 2), "c": (3, 2), "v": (4, 2), "b": (5, 2),
        "n": (6, 2), "m": (7, 2),
    ]

    static func score(typed: String, candidate: String) -> Double {
        let typedChars = Array(typed.lowercased())
        let candidateChars = Array(candidate.lowercased())
        guard typedChars.count == candidateChars.count else { return 0 }

        var value = 0.0
        for (typedChar, candidateChar) in zip(typedChars, candidateChars) where typedChar != candidateChar {
            guard let typedPosition = positions[typedChar],
                  let candidatePosition = positions[candidateChar] else {
                value -= 0.5
                continue
            }
            let dx = typedPosition.x - candidatePosition.x
            let dy = typedPosition.y - candidatePosition.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance <= 1.15 {
                value += 1.25
            } else if distance <= 2.1 {
                value += 0.25
            } else {
                value -= min(2.0, distance * 0.35)
            }
        }
        return value
    }
}
