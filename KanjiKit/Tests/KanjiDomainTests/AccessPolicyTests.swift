import Testing

@testable import KanjiDomain

@Suite("Cosa è gratis")
struct AccessPolicyTests {
    private let chosen = ReminderSettings(
        intervalMinutes: 30,
        activeHours: ActiveHours(startHour: 6, endHour: 23),
        isPassive: true,
        grades: [1, 3, 8]
    )

    @Test func premiumKeepsEveryChoice() {
        #expect(AccessPolicy.effective(chosen, for: .premium) == chosen)
    }

    @Test func freeUsesTheDefaultRhythmButKeepsDiscreetMode() {
        let effective = AccessPolicy.effective(chosen, for: .free)
        #expect(effective.intervalMinutes == ReminderSettings.default.intervalMinutes)
        #expect(effective.activeHours == ReminderSettings.default.activeHours)
        #expect(effective.isPassive)
    }

    @Test func freeKeepsOnlyTheFreeGradesAmongTheChosenOnes() {
        #expect(AccessPolicy.effective(chosen, for: .free).grades == [1])
    }

    /// Chi aveva scelto solo gradi a pagamento non deve ritrovarsi senza niente da
    /// ripassare quando l'abbonamento scade.
    @Test func freeNeverEndsUpWithAnEmptyDeck() {
        var onlyPaid = chosen
        onlyPaid.grades = [3, 8]
        #expect(AccessPolicy.effective(onlyPaid, for: .free).grades == KanjiLevel.freeGrades)
    }

    /// Le scelte salvate restano intatte: è questo che le fa tornare al rinnovo.
    @Test func applyingThePolicyNeverChangesWhatWasSaved() {
        let saved = chosen
        _ = AccessPolicy.effective(saved, for: .free)
        #expect(saved == chosen)
    }

    /// Lo scheduler legge le impostazioni effettive, ma chi salva scrive le scelte
    /// vere: al rinnovo tornano senza che l'utente rifaccia niente.
    @Test func policyAppliedSettingsReadEffectiveAndWriteChosen() {
        let store = InMemoryStore(chosen)
        var status = SubscriptionStatus.free
        let applied = PolicyAppliedSettings(base: store, status: { status })

        #expect(applied.load().grades == [1])
        status = .premium
        #expect(applied.load() == chosen)

        applied.save(.default)
        #expect(store.value == .default)
    }
}
