import Foundation
import KanjiDomain
import Testing

@testable import KanjiData

@Suite("Storico su file")
struct JSONFileStoreTests {
    private let url = URL.temporaryDirectory.appending(path: "ambient-\(UUID().uuidString)/state.json")

    private var store: JSONFileStore<AmbientState> {
        JSONFileStore(url: url, default: .empty)
    }

    private func sampleState() -> AmbientState {
        var state = AmbientState.empty
        state.record(.presented, codepoint: "06c34", at: Date(timeIntervalSince1970: 1_800_000_000))
        state.record(.readingsViewed, codepoint: "06c34", at: Date(timeIntervalSince1970: 1_800_000_060))
        return state
    }

    @Test func savesAndLoadsBack() {
        let saved = sampleState()
        store.save(saved)
        #expect(store.load() == saved)
    }

    /// Prima installazione: la cartella non esiste nemmeno.
    @Test func withoutAFileItStartsEmpty() {
        #expect(store.load() == .empty)
    }

    /// Un file rotto non deve né bloccare l'app né sparire sotto il primo
    /// salvataggio: è l'unica copia di una storia lunga mesi.
    @Test func aBrokenFileIsSetAsideInsteadOfOverwritten() throws {
        store.save(sampleState())
        try Data("{ non è json".utf8).write(to: url)

        #expect(store.load() == .empty)

        let broken = url.appendingPathExtension("broken")
        #expect(FileManager.default.fileExists(atPath: broken.path))
        #expect(try String(contentsOf: broken, encoding: .utf8) == "{ non è json")
        // E da lì in poi si riparte pulito.
        store.save(sampleState())
        #expect(store.load() == sampleState())
    }
}
