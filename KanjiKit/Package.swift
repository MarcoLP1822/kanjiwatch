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
        .library(name: "StudyFeature", targets: ["StudyFeature"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
        .library(name: "KanjiPurchases", targets: ["KanjiPurchases"]),
        .library(name: "PaywallFeature", targets: ["PaywallFeature"]),
    ],
    dependencies: [
        // L'unica dipendenza esterna del progetto, richiesta esplicitamente: gli
        // abbonamenti.
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.89.0")
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

        // Le schermate: glifo → animazione → letture, e la long look della notifica.
        // Vede il dominio e il design system, mai i dati: chi costruisce i
        // repository è il target app.
        .target(
            name: "StudyFeature",
            dependencies: ["KanjiDomain", "DesignSystem"],
            resources: [.process("Resources")],
            swiftSettings: ui
        ),

        .testTarget(name: "KanjiDomainTests", dependencies: ["KanjiDomain"], swiftSettings: base),
        .testTarget(name: "KanjiDataTests", dependencies: ["KanjiData"], swiftSettings: base),
        // Dipende da KanjiData solo nei test: il parser va verificato sui tratti veri
        // di tutti e 300 i kanji, non su tre stringhe scelte da me.
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem", "KanjiData"], swiftSettings: ui),
        // L'SDK RevenueCat vive solo qui. È pesante, e nessun altro modulo deve sapere
        // che esiste: il dominio parla con la porta SubscriptionGateway.
        .target(
            name: "KanjiPurchases",
            dependencies: [
                "KanjiDomain",
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ],
            swiftSettings: base
        ),

        // Il paywall. Parla con la porta SubscriptionGateway e non sa che dietro c'è
        // RevenueCat: nei test e nelle preview c'è un finto gateway.
        .target(
            name: "PaywallFeature",
            dependencies: ["KanjiDomain", "DesignSystem"],
            resources: [.process("Resources")],
            swiftSettings: ui
        ),

        .testTarget(name: "PaywallFeatureTests", dependencies: ["PaywallFeature"], swiftSettings: base),

        // Intervallo, fasce di silenzio, permessi, fonti dei dati. Come StudyFeature
        // vede solo dominio e design system.
        .target(
            name: "SettingsFeature",
            dependencies: ["KanjiDomain", "DesignSystem"],
            resources: [.process("Resources")],
            swiftSettings: ui
        ),

        // Senza isolamento MainActor di default: i finti adattatori implementano
        // porte nonisolated, e con il doppio isolamento non compilano.
        .testTarget(name: "SettingsFeatureTests", dependencies: ["SettingsFeature"], swiftSettings: base),

        // DesignSystem serve solo qui nei test, per renderizzare le schermate coi
        // token veri invece che con valori inventati.
        .testTarget(
            name: "StudyFeatureTests",
            dependencies: ["StudyFeature", "DesignSystem"],
            swiftSettings: ui
        ),
    ]
)
