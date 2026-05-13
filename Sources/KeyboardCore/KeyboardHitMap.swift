import Foundation

public struct KeyboardHitPoint: Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct KeyboardHitRect: Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }

    public func contains(_ point: KeyboardHitPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    func verticalDistance(to point: KeyboardHitPoint) -> Double {
        if point.y < minY { return minY - point.y }
        if point.y > maxY { return point.y - maxY }
        return 0
    }

    func edgeDistance(to point: KeyboardHitPoint) -> Double {
        let dx = max(minX - point.x, max(0, point.x - maxX))
        let dy = max(minY - point.y, max(0, point.y - maxY))
        return (dx * dx + dy * dy).squareRoot()
    }
}

public struct KeyboardHitMap<Key: Hashable> {
    public struct KeyFrame: Equatable {
        public var key: Key
        public var rect: KeyboardHitRect

        public init(key: Key, rect: KeyboardHitRect) {
            self.key = key
            self.rect = rect
        }
    }

    public struct Row: Equatable {
        public var rect: KeyboardHitRect
        public var keys: [KeyFrame]

        public init(rect: KeyboardHitRect, keys: [KeyFrame]) {
            self.rect = rect
            self.keys = keys
        }
    }

    public struct Resolution: Equatable {
        public var key: Key
        public var isDirectHit: Bool
        public var rowDistance: Double
        public var centerDistance: Double
        public var edgeDistance: Double

        public init(
            key: Key,
            isDirectHit: Bool,
            rowDistance: Double,
            centerDistance: Double,
            edgeDistance: Double
        ) {
            self.key = key
            self.isDirectHit = isDirectHit
            self.rowDistance = rowDistance
            self.centerDistance = centerDistance
            self.edgeDistance = edgeDistance
        }
    }

    private var bounds: KeyboardHitRect
    private var rows: [Row]

    public init(bounds: KeyboardHitRect, rows: [Row]) {
        self.bounds = bounds
        self.rows = rows
    }

    public func resolve(_ point: KeyboardHitPoint) -> Resolution? {
        guard bounds.contains(point) else { return nil }
        guard let row = rows.min(by: {
            $0.rect.verticalDistance(to: point) < $1.rect.verticalDistance(to: point)
        }) else {
            return nil
        }
        guard let key = row.keys.min(by: {
            abs(point.x - $0.rect.midX) < abs(point.x - $1.rect.midX)
        }) else {
            return nil
        }

        let dx = point.x - key.rect.midX
        let dy = point.y - key.rect.midY
        let centerDistance = (dx * dx + dy * dy).squareRoot()
        return Resolution(
            key: key.key,
            isDirectHit: key.rect.contains(point),
            rowDistance: row.rect.verticalDistance(to: point),
            centerDistance: centerDistance,
            edgeDistance: key.rect.edgeDistance(to: point)
        )
    }
}
