import Foundation

/// Decodes any value and discards it, so a list decoder can step over an element it could not read.
struct Skip: Decodable {}

/// A list that keeps the elements it can read and drops the rest (null, wrong shape), instead of failing as a whole.
public struct LossyArray<Element: Decodable>: Decodable {
    public var elements: [Element] = []
    public init(from decoder: Decoder) throws {
        guard var container = try? decoder.unkeyedContainer() else { return }
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) { elements.append(element) } else { _ = try? container.decode(Skip.self) }
        }
    }
}

extension KeyedDecodingContainer {
    /// A string, or a number written as text, or nil. Never throws.
    func lenientString(_ key: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Units.tidy(d) }
        return nil
    }
    func lenientInt(_ key: Key) -> Int? {
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return nil
    }
    func lenientBool(_ key: Key) -> Bool? { try? decodeIfPresent(Bool.self, forKey: key) }
}
