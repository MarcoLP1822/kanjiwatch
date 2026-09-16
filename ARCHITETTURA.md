# Kanji Watch — Architettura

App **watchOS standalone**. A intervalli configurabili arriva una notifica che mostra
un kanji; il carattere è già grande dentro la notifica, e se non te lo ricordi apri
l'app per vedere l'ordine dei tratti e le letture e la parola più comune con quel kanji.

Documento di design. Versione 2 — impianto a notifiche, niente widget, niente app iOS.

---

## 1. Scope

**MVP:**

- notifica a intervalli configurabili, con fasce orarie di silenzio
- il kanji è visibile **dentro la notifica**, senza aprire nulla
- tap → app: animazione dell'ordine dei tratti, poi on'yomi / kun'yomi / significato
- 100% offline, nessun account, nessun backend, nessun companion iOS
- deck fisso scelto a build time (~300 kanji più frequenti)

**Fuori scope, esplicitamente:** widget e complication, SRS, iCloud, audio,
riconoscimento della scrittura, statistiche, monetizzazione.

Il valore dell'app è il ripasso **passivo**. Se l'80% delle volte guardi la notifica e
non apri niente, l'app sta funzionando come deve.

---

## 2. Decisioni di piattaforma

**App watchOS indipendente**, non companion. In Xcode: template watchOS App, opzione
*Supports Running Without iOS App Installation*. Bundle ID proprio.

Il motivo è tecnico, non estetico. Se le notifiche le schedulasse un'app iOS, entrerebbe
in gioco l'inoltro automatico di Apple: la notifica arriva al Watch **solo se** l'iPhone
è bloccato e il Watch è al polso e sbloccato. Se stai usando il telefono, resta sul
telefono. Non è controllabile da codice. Schedulando sul Watch, la notifica nasce e muore
sul Watch, sempre.

**watchOS non permette a un'app di terze parti di accendere lo schermo a piacimento.**
L'unico canale che interrompe è la notifica locale. Ecco perché tutta l'architettura
gira intorno allo scheduler.

---

## 3. Struttura del progetto

```
KanjiWatch/
├── Scripts/                          pipeline dati (Python) + correzioni a mano
├── KanjiKit/                         Swift Package locale, un target per modulo
│   ├── Sources/
│   │   ├── KanjiDomain/              entità, regole pure, porte, use case
│   │   │                             dipende solo da Foundation
│   │   ├── KanjiData/                kanji.json nel bundle, UserDefaults,
│   │   │   └── Resources/            UNUserNotificationCenter → KanjiDomain
│   │   ├── DesignSystem/             nessuna dipendenza
│   │   │   ├── Tokens/               primitivi → semantici → di componente
│   │   │   ├── StrokeRendering/      SVGPathParser, StrokeGlyph
│   │   │   └── Components/           KanjiGlyphView, ...
│   │   ├── StudyFeature/             glifo → animazione → letture, long look
│   │   └── SettingsFeature/          intervallo, silenzio, permessi, fonti
│   └── Tests/                        un target di test per modulo (Swift Testing)
└── KanjiWatch Watch App/             unico target pubblicato: sola composizione
    ├── KanjiWatchApp.swift           App + WKNotificationScene + delegate
    └── AppContainer.swift            costruisce e collega tutto
```

**Perché moduli separati e non cartelle.** Il confine lo fa il compilatore, non la
buona volontà: `DesignSystem` non può importare il dominio, quindi non può nascondere
una regola dentro una view; `KanjiDomain` non può importare `UserNotifications`,
quindi la logica degli orari resta pura e si prova con `swift test` da terminale,
senza simulatore — che per `FireDates` e `DeckCycle`, con mezzanotte e cambio d'ora
in mezzo, è l'unico modo serio di verificarli. Le feature non si vedono tra loro:
l'unico che conosce tutti è il target app.

**Target iOS di sviluppo — opzionale.** Il simulatore watchOS è lento e lo schermo
minuscolo. Se il parser SVG ti dà filo da torcere, un target iOS buttato lì che disegna
solo `StrokeOrderView` ti fa risparmiare ore. Non si pubblica, non ha notifiche, non ha
impostazioni. Se il parser fila liscio, saltalo.

**Non serve un App Group.** Notifiche e app girano nello stesso container:
`UserDefaults.standard` basta.

---

## 4. Pipeline dati

Offline, una volta, sul Mac. Script: `Scripts/build_kanji_data.py`.
Le sorgenti stanno in `Scripts/raw/`, ignorata da git: sono tutte riscaricabili.

```
KanjiVG (zip di SVG)  ─┐
KANJIDIC2 (xml.gz)     ├─→ build_kanji_data.py ─→ kanji.json + ATTRIBUTION.txt
JMdict (gz)            │   + word_overrides.json
JPDB (freq, Yomitan)  ─┘
```

- KanjiVG — https://github.com/KanjiVG/kanjivg/releases (`*-main.zip`), tracciati
- KANJIDIC2 — http://www.edrdg.org/kanjidic/kanjidic2.xml.gz, letture e significati
- JMdict — http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz, la parola di esempio
- JPDB — dizionario di frequenza Yomitan, **solo per ordinare**: nel bundle finiscono
  le 300 parole scelte, non la lista

```bash
python3 Scripts/build_kanji_data.py \
  --kanjivg Scripts/raw/kanjivg-20250816-main.zip \
  --kanjidic Scripts/raw/kanjidic2.xml.gz \
  --jmdict Scripts/raw/JMdict_e.gz \
  --jpdb '[Freq] JPDB (Recommended)' \
  --freq-max 300 --require-meaning \
  -o KanjiKit/Sources/KanjiData/Resources/
```

**Perché serve JPDB.** Il rank `nfXX` di JMdict misura i giornali: per 日 sceglie
日米 ("Giappone e Stati Uniti") invece di 日本. JPDB misura l'uso reale della lingua
e mette 日本 a 1228 contro 48538. Due filtri sono comunque necessari perché il suo
corpus è di anime e light novel: le parole che JMdict marca `uk` (si scrivono in
kana: 貴方, 勿論, 何所) e una dozzina di casi in `Scripts/word_overrides.json`
(王国 → 外国, 野郎 → 野球). Senza JPDB lo script funziona lo stesso, con `nfXX`.

Il self-check della selezione: `python3 Scripts/test_build_kanji_data.py`.

`kanji.json` va nel bundle. Non si parsa mai XML a runtime.

**Nota su `jlptOld`:** KANJIDIC2 espone la scala JLPT **vecchia** (4 = più facile,
1 = più difficile), che non mappa 1:1 su N5–N1. Per costruire un deck usa `freq` o
`grade`, sono più affidabili.

---

## 5. Schema dati

```json
{
  "version": 1,
  "viewBox": 109,
  "count": 300,
  "attribution": "This app includes data derived from: ...",
  "kanji": [
    {
      "c": "水", "cp": "06c34",
      "strokes": ["M52.77,15.08c1.08,1.08,1.67,2.49...", "..."],
      "on": ["スイ"], "kun": ["みず"],
      "meanings": { "en": ["water"] },
      "word": { "w": "水曜日", "r": "すいようび", "g": ["Wednesday"] },
      "nanori": [], "grade": 1, "strokeCount": 4,
      "freq": 300, "jlptOld": 4
    }
  ]
}
```

Tutti i tracciati KanjiVG vivono in un sistema di coordinate **109 × 109**.
È l'unico numero magico del progetto e sta in `viewBox`.

L'attribuzione viaggia dentro il JSON invece che in un secondo file del bundle:
CC BY-SA obbliga a mostrarla in app, e così non può separarsi dai dati.

Nel codice lo schema del file e l'entità dell'app sono due tipi diversi:

```swift
// KanjiDomain/Kanji.swift — quello che usano le schermate, coi nomi per esteso
public struct Kanji: Identifiable, Hashable, Sendable {
    public let character: String      // "水"
    public let codepoint: String      // "06c34": l'id che viaggia nelle notifiche
    public let strokes: [String]      // tracciati SVG in ordine di scrittura
    public let onReadings: [String]
    public let kunReadings: [String]
    public let meanings: [String]     // inglese: KANJIDIC2 non ha l'italiano
    public let commonWord: Word?      // grafia, lettura, significati
    public let grade: Int?
    public let frequencyRank: Int?
}

// KanjiData/DeckFile.swift — lo schema del file, coi nomi corti dello script
struct DeckFile: Decodable { /* c, cp, strokes, on, kun, meanings, word... */ }
```

Il dominio non è `Codable` di proposito: se cambia il formato dei dati si tocca
`DeckFile` e basta, le schermate non se ne accorgono. `nanori` e `jlptOld` restano
nel file ma non entrano nel dominio: non li mostra nessuno.

**Performance.** 300 kanji ≈ 400 KB, decode istantaneo. I 2136 jōyō sono 3–5 MB e il
`JSONDecoder` sul Watch ci mette centinaia di ms all'avvio. Se cresci oltre ~500 kanji,
separa `index.json` (leggero, sempre caricato) da `strokes/<cp>.json` (on demand).
Non prima: è ottimizzazione prematura.

---

## 6. Lo scheduler — il cuore dell'app

### Vincoli reali

- **Massimo 64 notifiche pending** per app. È un limite di sistema, non aggirabile.
- Un trigger con `repeats: true` riusa **sempre lo stesso contenuto**, quindi per far
  variare il kanji servono N notifiche one-shot distinte.
- Il background refresh di watchOS è budgetato e non garantito. **Non è un piano B.**

### Il ciclo che si autoalimenta

```
notifica → la tocchi → si apre l'app → l'app cancella tutto e rischedula le prossime 60
```

Finché usi l'app, la coda non si svuota mai. Rischedula in tre punti:
all'avvio, al ritorno in foreground, e alla gestione di una notifica toccata.

### Il caso "la ignoro per due giorni"

Se non apri mai l'app, la coda si esaurisce e l'app smette silenziosamente di esistere.
Mitigazione senza background task: delle 64 notifiche, le ultime 4 non seguono
l'intervallo ma sono distanziate a **12h, 24h, 48h, 96h**. Anche dopo giorni di silenzio
resta un promemoria di recupero che rimette in moto il ciclo.

### Fasce di silenzio — nell'MVP, non nella fase 5

Senza filtro orario l'app ti sveglia alle 3 di notte e la disinstalli il secondo giorno.
Default **08:00–22:00**: nel calcolo degli orari si scartano i timestamp fuori fascia e
si riprende dall'inizio della finestra successiva.

```swift
public enum FireDates {
    /// Prossimi `count` orari, ancorati all'inizio della finestra attiva.
    public static func next(count: Int,
                            after start: Date,
                            everyMinutes: Int,
                            activeHours: ActiveHours,   // 8→22, oppure 22→6
                            calendar: Calendar = .current) -> [Date]
}
```

Due cose sono cambiate rispetto alla prima stesura, e nessuna delle due è estetica.

`ClosedRange<Int>` non regge: una finestra che attraversa la mezzanotte si
scriverebbe `22...6`, che va in crash alla costruzione. Da qui `ActiveHours`, dove
il caso è esplicito.

Gli orari sono **ancorati** all'inizio della finestra e non calcolati "da adesso".
Con orari relativi, siccome l'app rischedula tutto a ogni apertura, ogni sguardo
all'app sposterebbe in avanti la notifica successiva: aprendola ogni tanto, non
arriverebbe mai. Ancorata, la griglia è la stessa a ogni ricalcolo — e c'è un test
che lo verifica.

Casi limite da testare, perché è qui che si rompe: mezzanotte, cambio dell'ora legale,
finestra che attraversa la mezzanotte (22–6), `everyMinutes` più grande della finestra.

### Scelta del kanji: ciclo mescolato

Senza widget non serve alcuna funzione deterministica del tempo: c'è un solo processo,
quindi lo stato può semplicemente essere salvato.

```swift
public struct DeckCycle {
    /// Permutazione del deck; quando finisce, rimescola.
    /// Garantisce che ogni kanji esca una volta prima che se ne ripeta uno.
    public mutating func next() -> Kanji
}
```

Salvi in `UserDefaults` la permutazione corrente e la posizione. Meglio del random puro:
niente doppioni ravvicinati, e copertura completa del deck garantita.

Il carattere viaggia dentro la notifica:

```swift
content.title = kanji.c                       // il kanji È il titolo
content.body  = "Tocca per l'ordine dei tratti"
content.userInfo = ["cp": kanji.cp]
content.categoryIdentifier = "KANJI_REVIEW"
content.sound = nil
```

Il kanji nel **titolo**, non nel body: sul Watch il titolo è ciò che leggi alzando il
polso per mezzo secondo. Con `sound = nil` niente audio; il tocco aptico dipende dalle
impostazioni di sistema dell'utente e non è controllabile dall'app.

Opzione "modalità discreta": `content.interruptionLevel = .passive` — la notifica non
accende lo schermo e si accumula nella lista, da guardare quando ti va. Per un ripasso
passivo è una scelta legittima, mettila in Impostazioni.

---

## 7. La notifica personalizzata — la feature vera

watchOS permette una **long look** in SwiftUI. Il kanji si vede grande dentro la
notifica, senza aprire l'app. È letteralmente il ripasso passivo che vuoi.

```swift
@main
struct KanjiWatchApp: App {
    var body: some Scene {
        WindowGroup { RootView() }

        WKNotificationScene(controller: KanjiNotificationController.self,
                            category: "KANJI_REVIEW")
    }
}

final class KanjiNotificationController:
    WKUserNotificationHostingController<KanjiNotificationView> {

    private var kanji: Kanji?

    override func didReceive(_ notification: UNNotification) {
        let cp = notification.request.content.userInfo["cp"] as? String
        kanji = cp.flatMap { KanjiDeck.shared.kanji(cp: $0) }
    }

    override var body: KanjiNotificationView {
        KanjiNotificationView(kanji: kanji)
    }
}
```

La view mostra il carattere a tutta larghezza e, sotto, una riga piccola con il
significato. **Niente letture nella notifica**: se te le dà subito, non provi a
ricordarle e il ripasso non avviene.

Toccare il corpo della notifica apre l'app. Per sapere su quale kanji atterrare:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse) async {
    let cp = response.notification.request.content.userInfo["cp"] as? String
    AppState.shared.open(cp: cp)
    NotificationScheduler.shared.rescheduleAll()
}
```

Il delegate si registra con `WKApplicationDelegateAdaptor`. Va impostato **prima** che
arrivi la prima risposta, quindi nell'init dell'app, non in `onAppear` di una view.

---

## 8. Interazione nell'app

```
        ┌──────────┐   tap    ┌───────────┐   tap / fine   ┌──────────┐
   ┌───▶│  static  │─────────▶│ animating │───────────────▶│ readings │
   │    └──────────┘          └───────────┘                └──────────┘
   │                                │  tap durante l'animazione            │
   │                                └──────── salta alla fine              │
   └──────────────────────────── tap ─────────────────────────────────────┘
```

```swift
// StudyFeature/StudyState.swift: la macchina sta fuori dalla view e si prova
// senza SwiftUI e senza orologi.
enum Phase { case glyph, readings }
```

Due fasi bastano: "statico" e "in disegno" sono lo stesso stato con un progresso
diverso (da 0 a `strokeCount`), ed è quel singolo numero ad animare tutto.

Dettagli che fanno la differenza:

- Un tap **durante** l'animazione la completa istantaneamente, non passa alle letture.
  Chi tocca due volte veloce non vuole saltare il contenuto. Il passaggio alle letture
  resta quello normale: fine del disegno, mezzo secondo di pausa sul glifo intero, poi
  le letture.
- `.onTapGesture` su una `ZStack`, **non** `Button`: su watchOS `Button` impone lo stile
  di sistema e si mangia l'area utile.
- `.digitalCrownRotation` legata al progresso dei tratti: scorrerli a mano con la corona
  è la cosa che rende l'app *tua* e non un esercizio da tutorial. Girare la corona
  interrompe l'animazione e **non** rivela le letture: lì comandi tu.
- Swipe verticale sul glifo → kanji successivo o precedente. **Dalle letture no**, al
  contrario di quanto diceva la prima stesura: lì c'è una `ScrollView`, e un gesto
  verticale che significa due cose diverse a seconda di quanto testo c'è è un gesto
  rotto. In fondo alle letture c'è un bottone esplicito.

---

## 9. Rendering dell'ordine dei tratti

La tecnica è `trim` su una `Shape`:

```swift
struct KanjiShape: Shape {
    let d: String
    let viewBox: Double

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / viewBox
        return SVGPathParser.path(from: d)
            .applying(CGAffineTransform(scaleX: s, y: s))
    }
}

struct StrokeOrderView: View {
    let kanji: Kanji
    @Binding var drawn: Int        // tratti già completi
    @Binding var current: CGFloat  // 0...1 sul tratto in corso

    var body: some View {
        ZStack {
            ForEach(Array(kanji.strokes.enumerated()), id: \.offset) { i, d in
                KanjiShape(d: d, viewBox: 109)
                    .trim(from: 0, to: i < drawn ? 1 : (i == drawn ? current : 0))
                    .stroke(style: StrokeStyle(lineWidth: 4,
                                               lineCap: .round,
                                               lineJoin: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

Scalare la `Path` dentro `path(in:)` e **non** con `.scaleEffect`: `scaleEffect`
scalerebbe anche lo spessore del tratto, e su un quadrante piccolo si vede.

L'animazione avanza un tratto per volta, con durata proporzionale alla lunghezza del
tratto: uno lungo deve metterci di più, altrimenti sembra sbagliata.

**Il pezzo di lavoro vero: `SVGPathParser`.** SwiftUI non sa leggere una stringa `d`.
KanjiVG usa un sottoinsieme ristretto — `M/m`, `C/c`, `S/s`, `L/l`, raramente `Z`.
Un parser per quel sottoinsieme sono ~120 righe. Scrivila una volta, testala con 10
kanji noti, non toccarla più.

Piano B se ti impantani: aggiungi allo script Python un passo di normalizzazione che
converte tutto in comandi assoluti `M`/`C`/`L`, e il parser Swift scende a ~40 righe.
Costo: il JSON non è più identico all'upstream.

---

## 10. Persistenza

`UserDefaults.standard` dietro la porta `ValueStore`, non `@AppStorage`: le
impostazioni le legge anche lo scheduler, che non è una view. Nessun App Group —
app e notifiche girano nello stesso contenitore — e nessun database.

| Chiave | Contenuto | Default |
|---|---|---|
| `reminder.settings` | intervallo, fascia attiva, modalità discreta | 60 min, 8→22, spenta |
| `reminder.state` | permutazione del mazzo, posizione, coda programmata | mazzo mescolato, coda vuota |

Due chiavi e non sei: posizione nel mazzo e coda programmata si leggono e si
scrivono **insieme**, ed è proprio quella coppia che evita di bruciare il mazzo a
ogni rischedulazione. Tenerle separate vorrebbe dire poterle disallineare.
I significati restano in inglese: KANJIDIC2 non ha l'italiano (solo en/fr/es/pt),
quindi non c'è nessuna impostazione di lingua da salvare.

Niente SwiftData finché non aggiungi SRS o preferiti. Un database per sette chiavi è
over-engineering.

---

## 11. Permessi

L'app senza permesso notifiche è inutile, ma **non chiederlo al primo avvio**. Prima
schermata: un kanji, tocchi, vedi l'animazione, capisci cosa fa l'app. *Poi* chiedi.

Se l'utente nega, l'app deve restare usabile come ripasso manuale — e dirlo, con un
link a `WKApplication.shared().openSystemURL` verso le impostazioni. Un'app che mostra
solo un vicolo cieco viene disinstallata.

Controlla lo stato a ogni avvio con `getNotificationSettings`: il permesso si può
revocare da fuori, e in quel caso lo scheduler gira a vuoto senza dire niente.

---

## 12. Licenze — non opzionale

KanjiVG e KANJIDIC2 sono entrambi **CC BY-SA**. Due obblighi concreti:

1. **Attribuzione visibile dentro l'app.** Una voce "Fonti dati" in Impostazioni con il
   contenuto di `ATTRIBUTION.txt`. Non nascosta nella descrizione App Store.
2. **Share-alike sui dati derivati.** `kanji.json` è un'opera derivata, e metterlo nel
   bundle è ridistribuirlo: resta sotto CC BY-SA. Il tuo codice Swift può restare tuo;
   i dati no.

Non è un parere legale. Se pensi di monetizzare, leggi le licenze per intero prima.

---

## 13. Roadmap

| Fase | Obiettivo | Stato |
|---|---|---|
| **F0** | Dati | ✅ 300 kanji con tratti, letture, significato e parola |
| **F1** | Rendering | ✅ parser SVG su tutti i tratti del mazzo, glifo verificato a immagine |
| **F2** | App | ✅ tap→animazione→letture, gira sul simulatore watchOS |
| **F3** | Scheduler | ✅ orari e ciclo del mazzo, coi casi limite sotto test |
| **F4** | Notifiche | ✅ programmate e instradate — la consegna vera va provata sul Watch |
| **F5** | Long look | ✅ il kanji si vede grande **dentro** la notifica |
| **F6** | Impostazioni | ✅ intervallo, fascia attiva, modalità discreta, permessi, fonti |
| **F7** | Abbonamenti | RevenueCat: 6,99 settimana / 12,99 mese / 99,99 anno |

F2 è già un'app che usi a mano. F5 è il momento in cui diventa quello che avevi in
mente. Non invertire: se parti dalle notifiche, debugghi lo scheduler prima di aver
visto un solo tratto disegnato sullo schermo.

**Sulla F4.** Il permesso notifiche si concede solo con un tocco, e da riga di
comando non si può dare: sul simulatore le notifiche inviate con `simctl push`
restano silenziose finché il permesso non c'è. La prova vera è sul Watch, oppure
toccando "Attiva le notifiche" nelle impostazioni del simulatore.

**Sulla F7.** La monetizzazione era esplicitamente fuori scope nel §1 e ci rientra
per richiesta successiva. Gli acquisti stanno dietro una porta di dominio, con
l'SDK confinato nel layer dati e un modulo `PaywallFeature` a parte: serve il
Programma Sviluppatori a pagamento e i prodotti su App Store Connect, altrimenti
non è nemmeno testabile.

---

## 14. Rischi noti

- **Il parser SVG è l'unico collo di bottiglia tecnico.** Se dopo due sessioni non
  anima bene, passa al piano B del §9. Non intestardirti.
- **Profilo di provisioning gratuito: l'app scade dopo 7 giorni** e va reinstallata.
  Per usarla davvero tutti i giorni servono i 99 €/anno. Questa app vive di
  continuità: se si spegne ogni settimana, non ripassi niente.
- **Debug delle notifiche.** Xcode permette di consegnare una notifica di test con un
  payload JSON senza aspettare il trigger. Prepara quel file in F4, prima di scoprire
  che aspetti un'ora per ogni prova.
- **Tempo reale sul polso.** Il simulatore mente sulle notifiche e sulle performance.
  Prova sul Watch vero già in F2, non in F6.
