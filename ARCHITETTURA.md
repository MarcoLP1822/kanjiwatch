# Kanji Watch — Architettura

App **watchOS standalone**. A intervalli configurabili arriva una notifica che mostra
un kanji; il carattere è già grande dentro la notifica, e se non te lo ricordi apri
l'app per vedere l'ordine dei tratti e le letture e la parola più comune con quel kanji.

Documento di design. Versione 3 — impianto a notifiche con una complication, niente app iOS.

---

## 1. Scope

**MVP:**

- notifica a intervalli configurabili, con fasce orarie di silenzio
- il kanji è visibile **dentro la notifica**, senza aprire nulla
- tap → app: animazione dell'ordine dei tratti, poi on'yomi / kun'yomi / significato
- 100% offline, nessun account, nessun backend, nessun companion iOS
- tutti i 2.136 jōyō, in mazzi per grado scolastico; le prime due classi sono gratis

**Fuori scope, esplicitamente:** SRS, progressi e gamification, iCloud, audio,
riconoscimento della scrittura, statistiche. Due voci stavano in questo elenco e sono
rientrate dopo: la monetizzazione (F7) e la complication (F8), che è esposizione
passiva in più e non chiede impegno.

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
│   │   │   ├── Tokens/               temi → semantici → di componente
│   │   │   ├── StrokeRendering/      SVGPathParser, StrokeGlyph
│   │   │   └── Components/           KanjiGlyphView, ...
│   │   ├── KanjiPurchases/           RevenueCat, e nient'altro → KanjiDomain
│   │   ├── StudyFeature/             kanji → tratti → letture → DONE/NEXT, long look
│   │   ├── SettingsFeature/          mazzi, intervallo, silenzio, permessi, fonti
│   │   ├── PaywallFeature/           i tre piani, prova, ripristino acquisti
│   │   ├── ComplicationFeature/      il kanji sul quadrante, senza WidgetKit
│   │   └── KanjiTestSupport/         rendering e conteggio pixel, solo per i test
│   └── Tests/                        un target di test per modulo (Swift Testing)
├── KanjiWatch Watch App/             target pubblicato: sola composizione
│   ├── KanjiWatchApp.swift           App + WKNotificationScene + delegate
│   └── AppContainer.swift            costruisce e collega tutto
└── KanjiWatch Complications/         estensione WidgetKit: sola composizione
    └── KanjiComplications.swift      quale vista su quale formato del quadrante
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

**Un App Group, ma solo per la complication.** Notifiche e app girano nello stesso
contenitore e usano `UserDefaults.standard`. La complication invece è un processo
separato: l'app le prepara la timeline nel contenitore condiviso
`group.com.marcolp.KanjiWatch` dopo ogni rischedulazione, e l'estensione la legge e
basta, senza caricare il mazzo. Così notifica e quadrante mostrano sempre lo stesso
kanji.

---

## 4. Pipeline dati

Offline, una volta, sul Mac. Script: `Scripts/build_kanji_data.py`.
Le sorgenti stanno in `Scripts/raw/`, ignorata da git: sono tutte riscaricabili.

```
KanjiVG (zip di SVG)  ─┐
KANJIDIC2 (xml.gz)     ├─→ build_kanji_data.py ─→ catalogo + un file per grado
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
  --grade-max 8 --require-meaning \
  -o KanjiKit/Sources/KanjiData/Resources/
```

**Perché serve JPDB.** Il rank `nfXX` di JMdict misura i giornali: per 日 sceglie
日米 ("Giappone e Stati Uniti") invece di 日本. JPDB misura l'uso reale della lingua
e mette 日本 a 1228 contro 48538. Due filtri sono comunque necessari perché il suo
corpus è di anime e light novel: le parole che JMdict marca `uk` (si scrivono in
kana: 貴方, 勿論, 何所) e una dozzina di casi in `Scripts/word_overrides.json`
(王国 → 外国, 野郎 → 野球). Senza JPDB lo script funziona lo stesso, con `nfXX`.

Il self-check della selezione: `python3 Scripts/test_build_kanji_data.py`.

Nel bundle vanno `kanji-catalog.json` e un `kanji-grade-N.json` per grado. Non si
parsa mai XML a runtime.

**Perché i mazzi usano `grade` e non il JLPT.** KANJIDIC2 espone la scala JLPT
**vecchia** (4 = più facile, 1 = più difficile), che non mappa 1:1 su N5–N1: per
questo `jlptOld` non viene nemmeno più esportato.

---

## 5. Schema dati

```json
// kanji-catalog.json — meno di 1 KB, si legge sempre
{
  "version": 2,
  "viewBox": 109,
  "count": 2136,
  "attribution": "This app includes data derived from: ...",
  "levels": [{ "grade": 1, "count": 80 }, { "grade": 2, "count": 160 }, "..."]
}

// kanji-grade-1.json — si legge solo se il grado è attivo
{
  "kanji": [
    {
      "c": "水", "cp": "06c34",
      "strokes": ["M52.77,15.08c1.08,1.08,1.67,2.49...", "..."],
      "ends": "hwww",
      "on": ["スイ"], "kun": ["みず"],
      "meanings": { "en": ["water"] },
      "word": { "w": "水曜日", "r": "すいようび", "g": ["Wednesday"] },
      "grade": 1
    }
  ]
}
```

Tutti i tracciati KanjiVG vivono in un sistema di coordinate **109 × 109**.
È l'unico numero magico del progetto e sta in `viewBox`.

`ends` dice come finisce ogni tratto, una lettera per tratto: `s` fermo (tome), `w`
spazzata (harai), `h` uncino (hane), `d` punto. Viene dall'attributo `kvg:type` di
KanjiVG e serve al tratto a pennello: dedurlo dalla forma del tracciato sbagliava un
tratto su tre.

L'attribuzione viaggia dentro il JSON invece che in un secondo file del bundle:
CC BY-SA obbliga a mostrarla in app, e così non può separarsi dai dati.

Nel codice lo schema del file e l'entità dell'app sono due tipi diversi:

```swift
// KanjiDomain/Kanji.swift — quello che usano le schermate, coi nomi per esteso
public struct Kanji: Identifiable, Hashable, Sendable {
    public let character: String      // "水"
    public let codepoint: String      // "06c34": l'id che viaggia nelle notifiche
    public let strokes: [String]      // tracciati SVG in ordine di scrittura
    public let strokeEnds: [StrokeEnd] // come si chiude ogni tratto: stop, sweep, hook, dot
    public let onReadings: [String]
    public let kunReadings: [String]
    public let meanings: [String]     // inglese: KANJIDIC2 non ha l'italiano
    public let commonWord: Word?      // grafia, lettura, significati
    public let grade: Int?
    public let frequencyRank: Int?
}

// KanjiData/DeckFile.swift — lo schema del file, coi nomi corti dello script
struct CatalogFile: Decodable { /* viewBox, attribution, levels */ }
struct LevelFile: Decodable { /* kanji: c, cp, strokes, on, kun, meanings, word... */ }
```

Il dominio non è `Codable` di proposito: se cambia il formato dei dati si tocca
`DeckFile.swift` e basta, le schermate non se ne accorgono. `nanori`, `jlptOld` e
`strokeCount` non vengono più esportati: non li mostrava nessuno, e con duemila
kanji ogni campo in più è tempo di decodifica sul Watch.

**Performance, misurata invece che stimata.** Su un Mac Intel tutti i 2.136 jōyō in
un unico file si decodificano in 159 ms; togliendo i soli tratti in 112, perché il
costo sta nel numero di voci e non nei byte. Divisi per grado, il mazzo gratuito
(catalogo più gradi 1 e 2, 240 kanji) si decodifica in 34 ms. Sul Watch vanno
moltiplicati per 3-5: all'avvio si carica solo quello che l'utente ripassa, e chi
accende tutti i gradi paga il costo pieno. Se sull'orologio si sente, il passo
successivo è caricare i gradi fuori dal thread principale — non prima di averlo
misurato lì.

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

Finché usi l'app, la coda non si svuota mai. Rischedula in quattro punti:
all'avvio, al ritorno in foreground, alla gestione di una notifica toccata e dopo
ogni NEXT. Una rischedulazione alla volta: all'apertura da una notifica ne partono
due insieme, e due code rifatte in parallelo mescolerebbero le loro notifiche.

### Il ritmo della giornata: intervallo e tetto

L'intervallo dà il ritmo, il **numero di kanji nuovi al giorno** il tetto (default 10).
Contano le notifiche arrivate e i NEXT; raggiunto il numero, le notifiche di quel
giorno si fermano e riprendono il giorno dopo. Il conteggio è per giorno di
calendario e sta nello stato salvato: prima di rifare la coda si contano le notifiche
già arrivate, altrimenti il tetto non saprebbe quante ne sono passate.

NEXT non inventa un kanji in più: **anticipa** quello della prossima notifica, che
esce dalla coda, e fa ripartire l'intervallo da quel minuto. L'ancora vale solo per
la finestra in cui l'hai premuto; dal giorno dopo la griglia torna agganciata
all'inizio della fascia.

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
                            anchor: Date? = nil,        // l'ultimo NEXT
                            dailyLimit: Int? = nil,
                            usedToday: Int = 0,         // notifiche arrivate e NEXT di oggi
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
  kanji ──tocco──▶ tratti ──tocco──▶ letture ──DONE──▶ attesa ──NEXT──┐
                     │                  │                  │           │
                     │                  └──NEXT────────────┴──────────▶ kanji successivo
                     └─ tocco durante il disegno: lo completa, non salta avanti
```

```swift
// StudyFeature/StudyState.swift: la macchina dei tocchi, senza SwiftUI né orologi.
enum Phase { case kanji, strokes, readings }
// KanjiDomain/StudyLoop.swift: DONE, NEXT e il kanji in gioco, sullo stato salvato.
```

Ogni passo è un tocco e **niente avanza da solo**: la prima stesura passava alle
letture mezzo secondo dopo la fine del disegno, e toccare le letture riportava ai
tratti — chi toccava lo schermo per scorrere si ritrovava indietro.

- **Letture.** I tocchi non fanno niente: si esce solo con i due bottoni. DONE è pieno
  (indaco), il gesto normale; NEXT è solo contornato. Raggiunto il numero del giorno,
  al posto di NEXT c'è "Per oggi è tutto".
- **DONE** chiude il giro: la schermata d'attesa mostra il kanji appena fatto in
  piccolo, "Prossimo kanji alle HH:MM" e NEXT per non aspettare. All'ora della
  notifica il suo kanji compare da solo, senza lasciare a schermo un orario passato.
- **NEXT** mette subito in gioco il kanji della prossima notifica e rifà la coda da
  adesso (§6). Conta nel numero del giorno.
- **Il kanji in gioco** è salvato: riaprendo l'app lo ritrovi, anche chiuso con DONE.
  Una notifica arrivata nel frattempo prende il suo posto; toccarla lo riapre da capo.
  Se una notifica arriva *mentre* studi, DONE non chiude lei (non l'hai vista) e NEXT
  la mostra invece di anticiparne un'altra.
- `.onTapGesture` sul glifo, **non** `Button`: su watchOS `Button` impone lo stile di
  sistema e si mangia l'area utile. I due bottoni delle letture sono invece bottoni
  veri, con lo stile del design system (`.dsPrimary`, `.dsSecondary`).
- `.digitalCrownRotation` legata al progresso dei tratti: scorrerli a mano con la corona
  è la cosa che rende l'app *tua* e non un esercizio da tutorial. Girarla interrompe
  l'animazione e vale come aver guardato i tratti: il tocco dopo porta alle letture.
- Niente swipe per cambiare kanji: con NEXT sarebbero due modi per la stessa cosa, e
  un gesto verticale sopra una `ScrollView` è un gesto rotto.

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

### I temi e il tratto a pennello

Un tema è una scelta sola: palette, famiglia dei caratteri, modo di disegnare i tratti,
sigillo. Tre temi, in `DSTheme`:

| Tema | Carta e inchiostro | Tratti | Caratteri | Accesso |
|---|---|---|---|---|
| Ai-zome | notte, bianco freddo, indaco | linea fine con alone | SF Pro | gratis |
| Sumi-e washi | carta washi, sumi, rosso shu | pennello, sigillo 画 | serif | Premium |
| Sumi-e senape | carta senape, sumi, rosso shu | pennello, sigillo 画 | serif | Premium |

I token semantici (`.dsInk`, `.dsBackground`…) sono `ShapeStyle` che si risolvono dal
tema dell'ambiente: le schermate non sanno quale tema c'è, e `.dsTheme(_:)` lo applica
alla radice dello studio. La notifica lo riceve come parametro, perché la mostra il
sistema fuori dalla gerarchia dell'app. Impostazioni e paywall restano Ai-zome: sono
controlli di sistema, sempre scuri su watchOS, e l'inchiostro scuro lì non si leggerebbe.
Il contrasto WCAG si verifica per ogni tema, sul fondo e sulle superfici.

Il pennello parte dagli stessi tracciati di KanjiVG. Il parser li campiona a passo
costante; `BrushStroke` costruisce un solo poligono con spessore variabile e punte
arrotondate: il pennello entra leggero, preme, e chiude come dice `ends` (§5) — pieno
sul fermo, in punta sulla spazzata, di scatto sull'uncino, a goccia sul punto. Niente
sfocature né unioni di forme: durante l'animazione si ricalcola a ogni fotogramma.
L'inchiostro che sbava è una copia più larga e trasparente sotto il tratto.

Sui temi chiari l'ora in alto, che watchOS disegna sempre bianca e non lascia
ricolorare, sparirebbe sulla carta: `DSTopWash` le mette dietro un velo d'inchiostro
sfumato. Chiedere a watchOS l'aspetto chiaro non cambia l'ora e scurisce i bottoni.

---

## 10. Persistenza

`UserDefaults.standard` dietro la porta `ValueStore`, non `@AppStorage`: le
impostazioni le legge anche lo scheduler, che non è una view. App e notifiche girano
nello stesso contenitore; l'unico App Group serve alla complication (§3). Nessun
database.

| Chiave | Contenuto | Default |
|---|---|---|
| `reminder.settings` | intervallo, fascia attiva, modalità discreta, gradi, kanji al giorno | 60 min, 8→22, spenta, 1-2, 10 |
| `reminder.state` | permutazione del mazzo, posizione, coda programmata, kanji in gioco, conteggio del giorno, ancora dell'ultimo NEXT | mazzo mescolato, coda vuota |

Due chiavi e non sei: posizione nel mazzo, coda programmata e conteggio del giorno
si leggono e si scrivono **insieme**, ed è proprio questo che evita di bruciare il
mazzo a ogni rischedulazione o di contare due volte una notifica. Tenerli separati
vorrebbe dire poterli disallineare. I campi aggiunti dopo si decodificano con un
default, così un aggiornamento dell'app non perde il punto del giro.
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
| **F7** | Abbonamenti | ✅ jōyō per grado, paywall, RevenueCat — manca solo l'account |
| **F8** | Complication | ✅ il kanji in gioco sul quadrante, tocco → app |
| **F9** | Loop di studio | ✅ un tocco per passo, DONE/NEXT, attesa, kanji al giorno |
| **F10** | Pronta per la prova | ✅ icona, negozio simulato, flussi verificati sul simulatore |
| **F11** | Temi | ✅ Ai-zome gratis; sumi-e washi e senape Premium, col pennello e il sigillo |

F2 è già un'app che usi a mano. F5 è il momento in cui diventa quello che avevi in
mente. Non invertire: se parti dalle notifiche, debugghi lo scheduler prima di aver
visto un solo tratto disegnato sullo schermo.

**Sulla F4.** Il permesso notifiche si concede solo con un tocco, e da riga di
comando non si può dare: sul simulatore le notifiche inviate con `simctl push`
restano silenziose finché il permesso non c'è. La prova vera è sul Watch, oppure
toccando "Attiva le notifiche" nelle impostazioni del simulatore.

**Sulla F7.** La monetizzazione era fuori scope nel §1 ed è rientrata per richiesta
successiva, portandosi dietro l'allargamento del mazzo: 300 kanji non reggono un
abbonamento, 2.136 sì.

- **Gratis:** classi 1 e 2 (240 kanji), un promemoria all'ora dalle 8 alle 22, 10
  kanji al giorno, modalità discreta, tema Ai-zome. **Premium:** tutti i gradi,
  intervallo, fascia oraria e numero di kanji al giorno liberi, e i temi sumi-e.
- La regola sta in `AccessPolicy`, nel dominio. Scheduler e caricamento del mazzo
  leggono le impostazioni *effettive*; quelle scelte restano salvate intatte, così
  se l'abbonamento scade e poi si rinnova le scelte tornano da sole.
- RevenueCat vive solo nel modulo `KanjiPurchases`; il paywall (`PaywallFeature`)
  parla con la porta `SubscriptionGateway` e nei test usa un finto gateway.
- Prezzi: 6,99 a settimana con 3 giorni di prova, 12,99 al mese, 99,99 all'anno.
  Rispetto al settimanale il mensile costa il 57% in meno, l'annuale il 72%, e il
  paywall lo dice.

Cosa manca, tutto fuori dal codice:

1. Il Programma Sviluppatori Apple a pagamento.
2. Su App Store Connect, un gruppo di abbonamenti con i tre prodotti e la prova di
   3 giorni sul settimanale.
3. Su RevenueCat, un entitlement `premium` e un'offering corrente con i pacchetti
   settimanale, mensile e annuale collegati a quei prodotti.
4. La chiave pubblica in `AppConfiguration.revenueCatAPIKey` e l'indirizzo della
   privacy policy in `AppConfiguration.privacyPolicyURL`. Finché mancano, due
   `#warning` lo ricordano a ogni build e l'app gira gratuita.

Nelle build di sviluppo senza chiave il negozio è simulato
(`SimulatedSubscriptionGateway`): gli stessi tre piani e prezzi, acquisto e ripristino
che riescono sempre, stato ricordato tra un avvio e l'altro. Serve a provare paywall e
Premium sul simulatore; per tornare gratuiti si cancella e si reinstalla l'app. Nelle
build di rilascio non esiste.

**Sulla F10.** Verificato sul simulatore Watch, in italiano: paywall con acquisto
simulato che si chiude da solo e sblocca le impostazioni; coda rifatta con intervallo e
tetto giornaliero nuovi; notifica personalizzata e tocco che apre l'app su quel kanji;
notifica arrivata durante lo studio, che DONE non chiude; schermata d'attesa che all'ora
della notifica passa da sola al kanji nuovo; complication rettangolare su un quadrante
Modulare Duo, col kanji in gioco, che al tocco apre l'app su quel kanji; notifica
programmata davvero (intervallo di 15 minuti) consegnata con l'app in background, e la
complication che all'ora della notifica passa da sola al nuovo kanji. L'icona si
genera dai token e dai tratti di 字 con `AppIconTests` (variabile `APP_ICON_OUTPUT`),
non si ritocca a mano.

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
- **Mac Intel.** Xcode 27 gira solo su Apple silicon: qui si compila con Xcode 26.5
  (SDK 26.5), che per ora basta anche per TestFlight. Quando App Store chiederà l'SDK
  27, per pubblicare servirà un Mac Apple silicon.
- **Installare sul Watch.** Xcode abbina il Watch attraverso l'iPhone collegato col
  cavo; senza cavo (porta dell'iPhone rotta) l'abbinamento non si rifà. Via Wi-Fi
  l'iPhone deve annunciare il servizio `_remotepairing`, e non lo fa finché non è stato
  riabbinato col cavo. L'alternativa senza cavo è TestFlight.
- **Temi chiari sul Watch.** Sullo schermo OLED la carta a tutto schermo consuma più
  della notte, e alzando il polso al buio abbaglia. Per questo Ai-zome resta il tema di
  base. Il pennello si ricalcola a ogni fotogramma dell'animazione: sul simulatore è
  fluido, sul Watch vero va verificato.
- **Tempo reale sul polso.** Il simulatore mente sulle notifiche e sulle performance.
  Prova sul Watch vero già in F2, non in F6.
