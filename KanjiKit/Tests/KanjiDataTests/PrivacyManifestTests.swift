import Foundation
import Testing

/// UserDefaults è un'API "a motivo obbligatorio": ogni bundle che la usa deve dichiararla
/// nel suo PrivacyInfo.xcprivacy, o App Store Connect rifiuta il caricamento. Il codice
/// che la usa sta qui in KanjiData, e il test sta qui con lui.
@Suite("Manifest della privacy")
struct PrivacyManifestTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// L'app legge i suoi UserDefaults (CA92.1) e scrive la timeline della complication
    /// nell'App Group (1C8F.1); l'estensione la legge dall'App Group.
    @Test(arguments: ["KanjiWatch Watch App", "KanjiWatch Complications"])
    func declaresUserDefaultsWithTheRightReasons(target: String) throws {
        let url = Self.root.appendingPathComponent(target).appendingPathComponent("PrivacyInfo.xcprivacy")
        let manifest = try #require(
            try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any]
        )

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = try #require(
            apis.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" })
        let reasons = Set(defaults["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? [])
        #expect(reasons == ["CA92.1", "1C8F.1"])
    }
}
