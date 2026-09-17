# Attribuzioni e licenze dei dati

I mazzi dei kanji nel bundle dell'app —
`KanjiKit/Sources/KanjiData/Resources/kanji-catalog.json` e `kanji-grade-*.json` —
sono generati da `Scripts/build_kanji_data.py` a partire dalle tre fonti qui sotto, e
ne restano **opere derivate**.

## KanjiVG — tracciati e tipo di ogni tratto

Copyright © Ulrich Apel — <https://kanjivg.tagaini.net>
Licenza: [Creative Commons Attribution-ShareAlike 3.0](https://creativecommons.org/licenses/by-sa/3.0/)

Da KanjiVG vengono i tracciati SVG di ogni tratto, nel loro ordine di scrittura, e
l'attributo `kvg:type` da cui ricaviamo come finisce il tratto (fermo, spazzata,
uncino, punto).

## KANJIDIC2 — letture, significati, classe scolastica

Copyright © Electronic Dictionary Research and Development Group (EDRDG)
Progetto: <https://www.edrdg.org/wiki/index.php/KANJIDIC_Project>

## JMdict — la parola d'esempio e la sua lettura

Copyright © Electronic Dictionary Research and Development Group (EDRDG)
Progetto: <https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project>

I file KANJIDIC2 e JMdict sono proprietà dell'Electronic Dictionary Research and
Development Group e sono usati in conformità alla licenza del gruppo:
<https://www.edrdg.org/edrdg/licence.html>
Licenza: [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

La licenza EDRDG chiede che i dati vengano tenuti aggiornati: `Scripts/update_data.sh`
li riscarica dalle versioni più recenti e rigenera i mazzi. Va eseguito a ogni rilascio
dell'app.

## Lista di frequenza JPDB — solo in fase di generazione

<https://jpdb.io> — generata con <https://github.com/MarvNC/jpdb-freq-list>

Serve soltanto a scegliere, tra le parole che contengono un kanji, quella davvero
comune. Non entra nell'app e non è ridistribuita in questo repository.

## Cosa copre cosa

- **I dati generati** (`kanji-*.json`) restano sotto CC BY-SA, come le fonti: chiunque
  può riusarli alle stesse condizioni, citando gli autori qui sopra.
- **Il codice dell'app** non è un'opera derivata dei dati: unire dati e software in un
  prodotto è una raccolta, non un adattamento. Le sue condizioni stanno nel README.
- **Dentro l'app** l'attribuzione è raggiungibile da Impostazioni › Fonti dati, come
  chiede la licenza EDRDG per i programmi: il testo è `ATTRIBUTION.txt`, generato dalla
  stessa pipeline e incluso nel bundle.
