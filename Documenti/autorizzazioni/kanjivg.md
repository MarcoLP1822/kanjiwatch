# Richiesta a Ulrich Apel (KanjiVG)

**A:** non esiste un indirizzo pubblico. I canali del progetto sono la mailing list
(`kanjivg@googlegroups.com`, gruppo <https://groups.google.com/g/kanjivg>) e le issue su
<https://github.com/KanjiVG/kanjivg>. Conviene mandarla alla mailing list e, se non
risponde nessuno in un paio di settimane, aprire una issue con lo stesso testo.
**Oggetto:** Permission request — Kanji Watch (watchOS app using KanjiVG)

Prima di inviare: sostituisci `<LINK AL REPOSITORY>` con l'indirizzo del repository
pubblico, oppure togli quella riga e la frase finale sul repository se resta privato.

---

Dear Ulrich Apel, dear KanjiVG maintainers,

I am an independent developer working on Kanji Watch, a standalone Apple Watch app for
reviewing the 2,136 jōyō kanji. It works entirely offline, and I plan to publish it on
the App Store with an optional paid subscription.

KanjiVG is the heart of the app: it animates each kanji stroke by stroke, in writing
order. I use the stroke paths and also the `kvg:type` attribute, which lets the app end
each stroke the way calligraphy does — a stop, a tapering sweep, a hook, a dot. Nothing
else I found gives Japanese stroke order at this quality.

I follow CC BY-SA 3.0 as follows:

- a screen named "Sources", reachable from the app's settings menu, credits KanjiVG,
  names you as the copyright holder, and links to kanjivg.tagaini.net and to the
  licence;
- the same credit appears in the project documentation and will appear in the App Store
  description;
- the data derived from KanjiVG remains under CC BY-SA 3.0;
- the data is regenerated from the current KanjiVG release at every release of the app.

I am writing about one point I could not settle by reading the licence. Apps sold
through the App Store are wrapped in Apple's FairPlay DRM, while section 4(a) of
CC BY-SA 3.0 says the work may not be distributed with technological measures that
control access or use in a manner inconsistent with the licence. Creative Commons
themselves note that distributing CC-licensed material through such stores may conflict
with the licence.

May I have your written permission to distribute the KanjiVG-derived data inside the
app through the Apple App Store, notwithstanding the technological measures Apple
applies to every app bundle? The derived data will also be available without any DRM in
a public repository: <LINK AL REPOSITORY>

If you would like the credit worded differently, please tell me and I will change it.

Thank you for KanjiVG, and for keeping it open all these years.

Kind regards,
Marco Luigi Palma
