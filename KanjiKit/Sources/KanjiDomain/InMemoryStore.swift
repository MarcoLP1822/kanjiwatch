import Foundation

/// La seconda implementazione di `ValueStore`, in memoria: la usano i test di tutti i
/// moduli, invece di riscriverla ciascuno per conto suo.
public final class InMemoryStore<Value>: ValueStore {
    public var value: Value

    public init(_ value: Value) {
        self.value = value
    }

    public func load() -> Value { value }

    public func save(_ value: Value) {
        self.value = value
    }
}
