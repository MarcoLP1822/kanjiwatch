// swift-tools-version: 6.2
import PackageDescription

// Un solo posto per le impostazioni di compilazione, così non divergono tra moduli.
// I moduli di UI girano sul main actor per default (SE-0466); dominio e dati no,
// devono restare chiamabili da qualsiasi contesto (delegate delle notifiche incluso).
let base: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]
let ui: [SwiftSetting] = base + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "KanjiKit",
    defaultLocalization: "en",
    // macOS c'è solo per far girare `swift test` senza simulatore.
    platforms: [.watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "KanjiDomain", targets: ["KanjiDomain"]),
        .library(name: "KanjiData", targets: ["KanjiData"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        // Entità, regole pure e porte. Dipende solo da Foundation: è la regola
        // che tiene in piedi tutto il resto, non aggiungere import qui.
        .target(name: "KanjiDomain", swiftSettings: base),

        // Adattatori: JSON nel bundle, UserDefaults, UNUserNotificationCenter.
        .target(
            name: "KanjiData",
            dependencies: ["KanjiDomain"],
            resources: [.process("Resources")],
            swiftSettings: base
        ),

        // Token e componenti. Non conosce il dominio: prende dati primitivi,
        // così resta riusabile e testabile da solo.
        .target(name: "DesignSystem", swiftSettings: ui),

        .testTarget(name: "KanjiDomainTests", dependencies: ["KanjiDomain"], swiftSettings: base),
        .testTarget(name: "KanjiDataTests", dependencies: ["KanjiData"], swiftSettings: base),
        // Dipende da KanjiData solo nei test: il parser va verificato sui tratti veri
        // di tutti e 300 i kanji, non su tre stringhe scelte da me.
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem", "KanjiData"], swiftSettings: ui),
    ]
)
