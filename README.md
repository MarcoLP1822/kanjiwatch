# Kanji Watch

App watchOS indipendente per il ripasso **passivo** dei kanji. A intervalli arriva una
notifica con il kanji grande, che si legge alzando il polso senza aprire niente.
Toccandola si apre l'app: un tocco mostra l'ordine dei tratti animato, un altro le
letture, il significato e una parola d'esempio. Poi Fatto, che chiude il giro, o
Avanti, che passa subito al prossimo.

Quale kanji ti arriva lo decide un motore che guarda cosa ti è già passato davanti:
qualcosa di nuovo, qualcosa da rivedere, qualcosa che conosci di vista. E decide anche
come: la prima volta col significato, poi il kanji da solo — mezzo secondo per
ricordartelo — e più avanti dentro una parola vera. Nessun voto e nessun «lo so / non
lo so»: bastano i segnali che lasci aprendo l'app. Con l'abbonamento fa un passo in
più — i kanji che vai ad aprire quando li vedi da soli tornano un po' prima e con
qualcosa a cui aggrapparsi, senza che tu abbia configurato niente.

Tutti i 2.136 jōyō, in mazzi per classe scolastica. Niente account, niente rete,
niente arretrati da smaltire.

Le decisioni di progetto, l'architettura e la roadmap stanno in
[ARCHITETTURA.md](ARCHITETTURA.md).

## Compilare ed eseguire

- Xcode 26.5 o successivo; target minimo watchOS 26.
- Progetto `KanjiWatch.xcodeproj`, schema **KanjiWatch Watch App**.
- Test della libreria, senza simulatore: `swift test --package-path KanjiKit`

## Aggiornare i dati

```
Scripts/update_data.sh
```

Riscarica KANJIDIC2, JMdict e KanjiVG dalle versioni più recenti e rigenera i mazzi nel
bundle. **Va eseguito a ogni rilascio:** la licenza EDRDG chiede una procedura di
aggiornamento regolare, e non aggiornare è una violazione della licenza d'uso.

## Licenze

- **Codice dell'app:** © 2026 Marco Luigi Palma. Tutti i diritti riservati.
- **Dati dei kanji nel bundle:** opere derivate da KanjiVG (CC BY-SA 3.0) e da
  KANJIDIC2 e JMdict dell'Electronic Dictionary Research and Development Group
  (CC BY-SA 4.0), e distribuite alle stesse condizioni.

Le attribuzioni complete sono in [NOTICE.md](NOTICE.md) e, dentro l'app, in
Impostazioni › Fonti dati.
