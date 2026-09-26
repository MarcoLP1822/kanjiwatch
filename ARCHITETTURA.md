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

**Fuori scope, esplicitamente:** progressi e gamification, iCloud, audio,
riconoscimento della scrittura, statistiche, e ogni bottone «lo so / non lo so». Tre
voci stavano in questo elenco e sono rientrate: la monetizzazione (F7); la complication
(F8), che è esposizione passiva in più e non chiede impegno; e la ripetizione
distanziata (F13), ma **invisibile** — nessun arretrato da smaltire, nessun voto, solo
segnali che l'utente lascia senza fare niente.

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
- JMdict — http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz, le parole di esempio
- JPDB — dizionario di frequenza Yomitan, **solo per ordinare**: nel bundle finiscono
  le parole scelte, non la lista

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

**Fino a tre parole per kanji** (F16). La prima si sceglie come sempre, e resta
identica a quella di prima della F16 per tutti i 2.136 kanji: è la verifica che la
regola non è cambiata. Le altre due sono varietà, e la varietà vale solo se aggiunge
qualcosa, quindi devono essere composti veri che stanno sul quadrante (non il kanji
da solo, non oltre tre caratteri) e **non ripetere il significato** di una parola già
scelta — senza questo 大 prendeva 大きい e 大きな, tutte e due "big", e 食 prendeva 食べる
e 食う. Una grafia sola per kanji. `word_overrides.json` accetta una grafia o una
lista, e le scelte a mano stanno davanti nell'ordine dato, purché JMdict le conosca.
Risultato: 6.365 parole, 2.106 kanji con tre, 2 senza nessuna (且, 𠮟).

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
  "version": 3,
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
      "words": [
        { "w": "水曜日", "r": "すいようび", "g": ["Wednesday"] },
        { "w": "水着", "r": "みずぎ", "g": ["bathing suit", "swimsuit"] },
        { "w": "水面", "r": "すいめん", "g": ["water's surface"] }
      ],
      "grade": 1
    }
  ]
}
```

Lo schema 2 aveva `"word": {...}`, una parola sola: il decoder lo legge ancora e lo
trasforma in una lista da una.

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
    public let words: [Word]          // fino a tre: grafia, lettura, significati
                                      // commonWord è la prima
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

### Lo storico delle esposizioni

```swift
public struct AmbientState: Codable {
    public var records: [String: KanjiExposure]   // per codepoint, non per mazzo
}

public struct KanjiExposure: Codable {
    public var firstSeenAt: Date
    public var lastPresentedAt: Date
    public var presentationCount: Int             // comparse: notifica, NEXT, avvio
    public var openedCount: Int                   // app aperta su questo kanji
    public var readingsViewedCount: Int           // arrivato fino a letture e parola
    public var lastEngagedAt: Date?
    public var nextDueAt: Date                    // chiave d'ordinamento, non scadenza
}
```

Per **codepoint**: spegnere un grado nelle impostazioni non cancella la storia dei suoi
kanji, e riaccenderlo la ritrova. Nessuno stadio salvato qui dentro: la familiarità si
ricalcola a ogni lettura (§6).

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

### Il ritmo della giornata: intervallo e due tetti

L'intervallo dà il ritmo, e i tetti sono **due cose diverse** da quando esiste
l'Ambient Engine:

- **`dailyLimit`, i promemoria al giorno** (default 10): quante volte l'app si fa
  viva, ripassi compresi. È quello che si sceglie dalle impostazioni.
- **`newKanjiPerDay`, i volti nuovi al giorno** (5, 3 senza abbonamento): quanti kanji
  mai visti può introdurre la giornata. Col Premium si sceglie anche questo, ma non
  può superare i promemoria: otto volti nuovi con tre promemoria sarebbe una promessa
  che la giornata non può mantenere.

Prima della F13 coincidevano — ogni notifica pescava un kanji diverso dal mazzo
mescolato — e per questo l'impostazione si chiamava «kanji nuovi al giorno». Adesso
alzare il primo aumenta gli incontri, non la roba da imparare.

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

### Scelta del kanji: l'Ambient Engine

Non è un mazzo mescolato che si consuma — lo era, fino alla F13 — perché la promessa
dell'app non è «ti faccio vedere tutti i 2.136 kanji», è «ti tengo in contatto col
giapponese durante la giornata». Cambia chi decide: non l'ordine di un mazzo, ma quello
che ti è già passato davanti.

**Lo storico.** Un record per ogni kanji incontrato (`AmbientState`, §5): quante volte è
comparso, quante volte hai aperto l'app su di lui, quante volte sei arrivato alle
letture, e da quando ha di nuovo senso riproporlo. Nessun "lo so / non lo so": chiederlo
sarebbe lavoro, e i segnali che bastano l'utente li lascia gratis.

**La familiarità si calcola, non si salva.** `fresh` → `reinforcing` → `familiar`, dai
conteggi e dal tempo. Salvarla vorrebbe dire poterla avere disallineata. E si ferma a
`familiar`, che vuol dire «ci sei passato davanti parecchie volte»: che tu *conosca* 水
non abbiamo nessun modo di saperlo, e fingere di saperlo sarebbe la bugia comoda su cui
poi si costruisce tutto storto. Ci si arriva per due strade: quattro comparse con due
visite alle letture in due giorni, **oppure** otto comparse in una settimana senza
toccare niente. La seconda è quella che conta: se l'esposizione passiva non valesse,
l'app tornerebbe a chiedere impegno.

**Il ritmo.** Ogni dieci contatti: cinque rinforzi, tre nuovi, due familiari. Un pattern
fisso, non una probabilità — il caso, su dieci estrazioni, regala giornate da sei kanji
nuovi, cioè l'opposto di quello che deve fare quest'app — e con un tetto ai volti nuovi
del giorno (cinque, tre senza abbonamento). Alzare la frequenza aumenta gli incontri,
non la roba da imparare: con trenta contatti al giorno restano cinque kanji nuovi e
venticinque ripassi.

**Chi vince.** Fra i già visti, quello più in ritardo su `nextDueAt` (che è una chiave
d'ordinamento, non una scadenza: il primo giorno sono tutti in anticipo e il kanji delle
8 torna alle 10). Fra i nuovi, la classe scolastica e poi la frequenza sui giornali.
Mai lo stesso kanji due volte di fila.

**Il punto delicato: prevedere senza contare.** watchOS tiene in coda fino a 64
notifiche mentre l'app non gira, quindi il motore deve decidere *adesso* anche cosa
mostrare fra tre giorni. Simula le esposizioni future su una copia dello storico — così
la coda alterna invece di ripetere — ma quella copia non si salva: un'esposizione conta
solo quando il suo momento arriva davvero, e lo registra `catchUp` guardando quali
notifiche sono passate.

```
storico esposizioni + mazzo attivo + momento
                  ↓
           Ambient Engine
                  ↓
     nuovo / rinforzo / familiare
                  ↓
    notifica, complication, schermata
```

Tutto deterministico: stesso storico e stesse date, stessa coda. Rischedulare non
"consuma" più niente, e non serve conservare i kanji delle notifiche mai arrivate. Se
invece nel frattempo hai aperto qualcosa, il piano cambia da sé — che è esattamente il
motivo per cui l'abbonamento ha un valore ricorrente: non il catalogo, il flusso.

### La micro-sequenza: come mostrarlo

Il motore decide due cose, e vanno tenute separate: **quale** kanji (nuovo, rinforzo,
familiare) e **come** mostrarlo.

| Forma | Cosa si vede | Perché |
|---|---|---|
| `introduce` | il kanji e il significato | 議 da solo non insegna niente: la prima volta si insegna |
| `recall` | solo il kanji | mezzo secondo per pensarci. Il simbolo è già la domanda: scriverla sarebbe rumore |
| `context` | 水曜日 / すいようび / Wednesday, col kanji acceso | smette di essere un carattere e diventa lingua |

La forma si ricava da quante volte il kanji è già comparso — prima volta, seconda,
terza, poi il giro `recall, context, recall, introduce` — e **non si salva da nessuna
parte**: un secondo contatore accanto a `presentationCount` sarebbe un secondo
contatore da tenere allineato, cioè il modo per finire a chiedere «ricordi?» a chi quel
kanji non l'ha mai visto. Senza parola d'esempio (JMdict non ne ha per tutti) `context`
ricade su `introduce`.

Le tre forme non stanno nella stessa giornata di proposito: si applicano quando il
kanji torna dovuto, quindi la sequenza si distende su giorni.

```
lun 09:00   水  water         lun 15:00   水          mar 10:00   水曜日
                                                                  すいようび
```

**Quale parola, nel contesto** (F16). Ogni kanji ha fino a tre parole, e girano: la
prima volta che compare dentro una parola è 水曜日, la seconda 水着, la terza 水面, poi
di nuovo 水曜日. Lo decide `contextPresentationCount`, che conta solo le comparse in
forma `context` e non tocca nient'altro — né la familiarità, né il ritmo, né il
supporto. Il motore sceglie **prima** di segnare la comparsa simulata, come per la
forma, e la scelta viaggia in `ExposureReference` accanto a `ExposureContent`: la forma
dice *come*, il riferimento *con cosa*. Un indice che non c'è più — il mazzo
rigenerato con meno parole — ricade sulla più comune.

Il ritmo personale non ha bisogno di niente in più: un kanji che chiede supporto torna
più spesso e con più contesti, quindi incontra prima le sue altre parole.

**La forma viaggia col kanji.** `ReminderDestination` — codepoint, forma e parola — passa
dalla coda alla notifica (`ec` e `wi` nel payload), dalla notifica alla sessione, dalla
sessione al quadrante, e dal tocco all'app (`?content=…&wi=…` nel link della
complication). Le letture nell'app mostrano la parola della notifica che le ha aperte. Decisa dal
piano una volta sola e mai ricalcolata: altrimenti la notifica delle 15:00 mostrerebbe
la parola e il quadrante, dopo la prima rischedulazione, tornerebbe al significato.
Dove manca — notifiche già in coda, link vecchi, stati salvati — vale `introduce`.

Lo schermo dell'app **non cambia**: kanji → tratti → letture è già l'interazione da
pochi secondi che vogliamo, e chi arriva da una notifica col contesto tocca e trova lo
stesso giro di sempre.

### Il ritmo personale, col Premium

Il motore conosce due modi. `standard` è quello descritto fin qui, uguale per tutti.
`adaptive` guarda in più **quanto quel kanji sembra chiederti un appiglio**.

**Non è la sua difficoltà.** Di quella non sappiamo niente e non abbiamo modo di
saperla: quello che possiamo osservare è che, vedendo il kanji da solo, sei andato a
cercare il resto. Per questo il segnale conta **solo sulla forma `recall`**: aprire un
kanji che aveva già il significato scritto sotto è il comportamento normale di chi
guarda, non una richiesta. E ignorare una notifica non abbassa niente — non sappiamo
se lo sapevi o se non hai nemmeno alzato il polso.

| Gesto sul richiamo | Peso |
|---|---|
| apri l'app su quel kanji | +0,30 |
| arrivi fino a letture e parola | +0,25 |

Il punteggio sta fra 0 e 1, non si mostra mai, e **si dimezza ogni due settimane**: una
fatica di marzo non deve perseguitare un kanji a maggio. Sotto 0,25 è `low`, sotto 0,60
`medium`, oltre `high`.

**Cosa cambia.** Non `nextDueAt`, che resta la linea di base per tutti: il ritmo
personale è una lettura diversa dello stesso dato (`effectiveDueAt`), così quando
l'abbonamento finisce il ritmo di base è ancora lì intatto.

| Supporto | Attesa | Giro delle forme dalla quarta volta |
|---|---|---|
| `low` | invariata | richiamo, parola, richiamo, significato |
| `medium` | × 0,65 | parola, richiamo, significato, richiamo |
| `high` | × 0,40 | significato, parola, richiamo, parola |

Mai meno di sei ore dall'ultima comparsa: un kanji che costa fatica non deve diventare
una raffica. E il richiamo resta in tutti e tre i giri — trasformare tutto in risposte
pronte vorrebbe dire non far più ricordare niente. Le prime tre esposizioni non
cambiano mai: sono la grammatica dell'app.

**I segnali si raccolgono sempre, anche gratis**, e semplicemente non si usano. Chi
prova l'app per due settimane e poi si abbona trova un motore che lo conosce già,
invece di uno che riparte da zero il giorno del pagamento.

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
  (indaco), il gesto normale; NEXT è solo contornato e si chiama "Un altro adesso".
  Prima si chiamava "Avanti", e dopo DONE sembrava il modo di proseguire: chi aveva
  finito non sapeva se premerlo. Raggiunto il numero del giorno, al posto di NEXT c'è
  "Per oggi è tutto".
- **DONE** chiude il giro: la schermata d'attesa mostra il kanji appena fatto in
  piccolo, poi "Per ora è tutto" (o "Per oggi è tutto") e "Prossimo kanji alle HH:MM".
  La prima cosa da dire è che hai finito e puoi abbassare il polso; NEXT sta in fondo,
  per chi non vuole aspettare. All'ora della notifica il suo kanji compare da solo,
  senza lasciare a schermo un orario passato.
- **NEXT** mette subito in gioco il kanji della prossima notifica e rifà la coda da
  adesso (§6). Conta nel numero del giorno.
- **Il kanji in gioco** è salvato: riaprendo l'app lo ritrovi, anche chiuso con DONE.
  Una notifica arrivata nel frattempo prende il suo posto; toccarla lo riapre da capo.
  Se una notifica arriva *mentre* studi, DONE non chiude lei (non l'hai vista) e NEXT
  la mostra invece di anticiparne un'altra.
- Il glifo è un `Button` con lo stile `.dsTapArea`: la semantica del bottone per
  VoiceOver, senza lo sfondo di sistema che su watchOS si mangerebbe l'area utile. I
  due bottoni delle letture hanno lo stile del design system (`.dsPrimary`,
  `.dsSecondary`).
- `.digitalCrownRotation` legata al progresso dei tratti: scorrerli a mano con la corona
  è la cosa che rende l'app *tua* e non un esercizio da tutorial. Girarla interrompe
  l'animazione e vale come aver guardato i tratti: il tocco dopo porta alle letture.
- Una schermata nuova entra in dissolvenza, la vecchia sparisce di colpo. In una
  dissolvenza incrociata le due convivono per un attimo e watchOS toglie la corona
  anche alla nuova: le letture non scorrevano finché non toccavi lo schermo.
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
| `reminder.settings` | intervallo, fascia attiva, modalità discreta, gradi, promemoria al giorno, volti nuovi al giorno | 60 min, 8→22, spenta, 1-2, 10, 5 |
| `reminder.state` | coda programmata, kanji in gioco, conteggio del giorno, ancora dell'ultimo NEXT | coda vuota |

Due chiavi e non cinque: coda programmata, kanji in gioco e conteggio del giorno si
leggono e si scrivono **insieme**, ed è questo che evita di contare due volte una
notifica. Tenerli separati vorrebbe dire poterli disallineare. I campi aggiunti dopo si
decodificano con un default, e quelli spariti — la permutazione del mazzo, fino alla
F13 — si ignorano: aggiornare l'app non deve perdere il resto.

Lo storico delle esposizioni invece **non** sta in `UserDefaults`: è un file JSON,
`Application Support/ambient-state.json`, dietro lo stesso `ValueStore`. Cresce con
l'uso — un record per kanji incontrato — e non lo legge nessun altro, complication
compresa. Se il file manca o è illeggibile si riparte da vuoto: si perde la memoria del
motore, non la giornata.
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

KanjiVG è **CC BY-SA 3.0**; KANJIDIC2 e JMdict sono **CC BY-SA 4.0** dell'EDRDG.
Entrambe permettono l'uso commerciale — EDRDG scrive che i suoi file si possono
includere in un software venduto senza dover aprire il codice — a queste condizioni:

1. **Attribuzione dentro l'app.** EDRDG chiede il riconoscimento su ogni schermata solo
   ai server web che fanno da dizionario; per i programmi accetta *"a separate screen
   accessed from a menu, such as one labelled 'About', 'Sources'"*. È la voce
   Impostazioni › Fonti dati, che mostra `ATTRIBUTION.txt` dal bundle. Il file cita le
   pagine dei progetti che EDRDG indica, e dice cosa viene da quale fonte.
2. **Attribuzione nella documentazione.** Stessa richiesta per «documentation, publicity
   material, WWW site»: `README.md` e `NOTICE.md` nel repository, e la descrizione su
   App Store quando ci sarà.
3. **Dati aggiornati.** *"There must be a procedure for regular updating of the data"*, e
   non farlo è una violazione: `Scripts/update_data.sh` riscarica le fonti e rigenera i
   mazzi. Da lanciare a ogni rilascio.
4. **Share-alike sui dati derivati.** I `kanji-*.json` restano CC BY-SA. Il codice Swift
   no: unire dati e software in un prodotto è una raccolta, non un adattamento.

**Punto aperto: il DRM dell'App Store.** Le licenze Creative Commons — tutte, anche le
BY — vietano di applicare misure tecniche che impediscano a chi riceve l'opera di
esercitare i suoi diritti, e Creative Commons stessa scrive che distribuire materiale CC
via App Store, che applica FairPlay, «può costituire una violazione». Nella 4.0 la
"distribuzione parallela" è stata respinta, quindi pubblicare i dati anche altrove non
basta da sola. La via pulita è l'autorizzazione scritta dei due titolari, EDRDG e Ulrich
Apel: le richieste stanno in `Documenti/autorizzazioni/`.

Alternative senza vincoli, valutate e scartate: per letture e significati esiste Unihan
(licenza Unicode, permissiva), ma per i tracciati no — animCJK è LGPL con font Arphic e
forme cinesi. Rinunciare a KanjiVG vuol dire rinunciare all'ordine dei tratti, cioè
all'app.

Non è un parere legale.

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
| **F12** | Linee guida | ✅ manifest privacy, informativa nell'app, bottoni accessibili, Riduci movimento |
| **F13** | Ambient Engine | ✅ lo storico decide cosa ti passa davanti: nuovo, rinforzo, familiare |
| **F14** | Micro-sequenza | ✅ e decide anche come: il kanji, il richiamo, la parola |
| **F15** | Ritmo personale | ✅ col Premium ogni kanji si fa il suo ritmo, senza che tu dica niente |
| **F16** | Profondità di vocabolario | ✅ fino a tre parole per kanji, che girano un contesto dopo l'altro |

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
  promemoria al giorno, tre kanji nuovi al giorno, modalità discreta, tema Ai-zome.
  **Premium:** tutti i gradi, intervallo, fascia oraria e promemoria al giorno liberi,
  cinque kanji nuovi al giorno, e i temi sumi-e.
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

**Sulla F13.** È il cambio di direzione del prodotto, e quasi tutto sta nel dominio:
l'interfaccia non guadagna una schermata. Kanji Watch non deve sembrare un'app di
studio ma un contatto continuo col giapponese — «impara un po' di giapponese ogni volta
che guardi l'ora» — quindi ogni funzione nuova passa da una domanda sola: *si impara
qualcosa in meno di dieci secondi, senza decidere di mettersi a studiare?* Se serve
sedersi e fare esercizi, non è di quest'app.

Da qui anche la regola che vale più di tutte: **niente da recuperare.** Anki dice «hai
83 carte da ripassare», Duolingo «mantieni la serie»; qui non esiste un arretrato,
perché un arretrato è un debito, e un debito lo si abbandona. Guarda pure l'ora: al
resto pensa il motore.

L'abbonamento cambia di conseguenza: non vendiamo 2.136 kanji, vendiamo il flusso
personale che si aggiorna da solo. Per questo il motore c'è anche nella versione
gratuita — dimostrare un prodotto peggiore di quello che vendi è un modo sicuro di non
venderlo — e Premium allarga il mazzo e il controllo del ritmo.

**Sulla F16.** Primo pezzo della Fase 4, «dal kanji al giapponese»: per chi la usa l'app
funziona esattamente come prima, solo che dopo qualche giorno si accorge che lo stesso
kanji gli apre pezzi diversi della lingua. Un costo da tenere d'occhio: gli oggetti da
decodificare raddoppiano, e sul Mac la decodifica passa da 22 a 31 ms per il mazzo
gratuito e da 225 a 307 ms per tutti i jōyō (build di debug). Sul Watch va misurato; se
pesa, le parole si possono scrivere come array invece che come oggetti. Poi, in ordine:
micro-frasi, coppie da confondere, un focus JLPT dichiaratamente non ufficiale — il JLPT
non pubblica liste dal 2010.

**Sulla F15.** È la fase che dà un senso ricorrente all'abbonamento: non un catalogo
più grande, un flusso che continua a personalizzarsi. Il dominio resta ignorante di
RevenueCat — conosce `AmbientMode` e basta, e chi mette insieme l'app gliene passa uno
guardando l'abbonamento. Nel paywall il primo vantaggio diventa «Ripassi che si
adattano a te» e i temi scendono a bonus. Niente «intelligenza artificiale»: non lo è,
e non serve che lo sia.

**Sulla F14.** La micro-sequenza (§6) è il secondo passo dello stesso motore: prima
*cosa*, adesso *come*. Anche qui nessuna schermata nuova — cambiano la notifica e il
quadrante, cioè i due posti che guardi senza aprire niente. Le fasi successive, quando
questa avrà girato per qualche giorno: vocabolario più profondo, micro-frasi, e solo
molto dopo eventuali percorsi JLPT.

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

---

## 15. Privacy e accessibilità — quello che chiede Apple

**Privacy manifest.** Ogni bundle che finisce nell'app ne vuole uno:
`KanjiWatch Watch App/PrivacyInfo.xcprivacy` e `KanjiWatch Complications/PrivacyInfo.xcprivacy`
(RevenueCat porta il suo). Dentro: nessun tracciamento, nessun dominio, nessun dato
raccolto, e l'unica API a motivo obbligato che usiamo — `UserDefaults`, con i motivi
`CA92.1` (dati della sola app) e `1C8F.1` (dati condivisi col proprio App Group).
`PrivacyManifestTests` li legge e fallisce se un motivo sparisce.

**Informativa sulla privacy.** La 5.1.1 la vuole in due posti: nei metadati su App Store
Connect e dentro l'app. Nell'app sta in Impostazioni › Privacy, dal bundle
(`PrivacyPolicy.txt`, italiano e inglese). Lo stesso testo va pubblicato a un indirizzo
raggiungibile e messo in `AppConfiguration.privacyPolicyURL`: allora la schermata mostra
anche "Leggi online". Finché l'indirizzo manca, un `#warning` lo ricorda a ogni build.

**VoiceOver.** Tutto ciò che si tocca è un `Button` vero, mai un `onTapGesture`: il glifo
usa `DSTapAreaStyle` (semantica del bottone, nessuno sfondo di sistema) e annuncia kanji
e significato; le righe dei piani nel paywall sono bottoni con il tratto `.isSelected`.
Un `onTapGesture` VoiceOver non lo annuncia e non lo attiva: è il motivo per cui non c'è.

**Riduci movimento.** `@Environment(\.accessibilityReduceMotion)` spegne le animazioni di
passo e il disegno progressivo: i tratti compaiono interi, uno alla volta, al ritmo di
prima. Le dissolvenze restano, non spostano niente.

### Prima della review

| Cosa | Stato |
|---|---|
| Privacy manifest nei due bundle | ✅ |
| Informativa dentro l'app, italiano e inglese | ✅ |
| Indirizzo pubblico dell'informativa in `AppConfiguration` e su App Store Connect | ❌ serve un hosting |
| Indirizzo di assistenza su App Store Connect | ❌ da decidere |
| Autorizzazioni EDRDG e KanjiVG per il DRM (§12) | ❌ mail pronte, non inviate |
| Programma Sviluppatori, prodotti e RevenueCat (§13) | ❌ |
| Modello di abbonamento: solo abbonamenti o anche acquisto una tantum | ❌ decisione |
| Prova a mano: VoiceOver, Testo grande, Grassetto, Distingui senza colore | ❌ solo sul Watch |

L'ultima riga è l'unica che il simulatore non copre: `simctl ui content_size` risponde
*"Runtime does not support dynamic text"* su watchOS, e l'ispettore di accessibilità non
legge le app del Watch. Riduci movimento invece si prova, scrivendo la preferenza nel
simulatore:

```
xcrun simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
```
