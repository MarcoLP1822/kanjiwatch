#!/usr/bin/env python3
"""
build_kanji_data.py

Estrae KanjiVG (tracciati degli stroke) + KANJIDIC2 (letture e significati)
+ JMdict (parola più comune per kanji, opzionale) e produce un singolo
kanji.json pronto per essere messo nel bundle dell'app.

Sorgenti da scaricare a mano (una volta), in Scripts/raw/ (ignorata da git):
  KanjiVG   https://github.com/KanjiVG/kanjivg/releases
            -> kanjivg-YYYYMMDD-main.zip   (consigliato)
            -> oppure kanjivg-YYYYMMDD.xml.gz
  KANJIDIC2 http://www.edrdg.org/kanjidic/kanjidic2.xml.gz
  JMdict    http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz

Esempi:
  # MVP dell'app (comando canonico)
  python3 Scripts/build_kanji_data.py \
      --kanjivg Scripts/raw/kanjivg-20250816-main.zip \
      --kanjidic Scripts/raw/kanjidic2.xml.gz \
      --jmdict Scripts/raw/JMdict_e.gz \
      --freq-max 300 --require-meaning \
      -o KanjiKit/Sources/KanjiData/Resources/

  # tutti i jōyō (grade 1-8)
  python3 build_kanji_data.py --kanjivg kanjivg-main.zip --kanjidic kanjidic2.xml.gz \
      --grade-max 8 -o out/

  # set esplicito
  python3 build_kanji_data.py ... --chars 水火木金土 -o out/

Nessuna dipendenza esterna: solo standard library.
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

VIEWBOX = 109  # KanjiVG usa sempre viewBox="0 0 109 109"

STROKE_ID_RE = re.compile(r"-s(\d+)$")
KANJI_ID_RE = re.compile(r"kanji_([0-9a-fA-F]+)")
SVG_NAME_RE = re.compile(r"([0-9a-fA-F]{4,6})(-.+)?\.svg$")

# Mostrato in-app (Impostazioni › Fonti dati): viaggia dentro kanji.json.
# In inglese perché è testo di licenza; l'intestazione in-app è localizzata.
ATTRIBUTION = """\
This app includes data derived from:

• KanjiVG © Ulrich Apel — https://kanjivg.tagaini.net
  Licence: Creative Commons Attribution-ShareAlike 3.0
  https://creativecommons.org/licenses/by-sa/3.0/

• KANJIDIC2 and JMdict © Electronic Dictionary Research and Development Group (EDRDG)
  https://www.edrdg.org/edrdg/licence.html
  Licence: Creative Commons Attribution-ShareAlike 4.0
  https://creativecommons.org/licenses/by-sa/4.0/

Example words were ranked with the JPDB frequency list (https://jpdb.io).
The list itself is not included in this app.

The bundled kanji data is a derivative work and is distributed under the same licences.
"""


# ---------------------------------------------------------------- utilities

def read_maybe_gzip(path: Path) -> bytes:
    data = path.read_bytes()
    if data[:2] == b"\x1f\x8b":
        data = gzip.decompress(data)
    return data


def strip_doctype(data: bytes) -> bytes:
    """
    KanjiVG e KANJIDIC2 hanno un DOCTYPE con subset interno.
    ElementTree (expat) esplode sulle entity dichiarate lì dentro,
    quindi lo togliamo prima del parsing. Non serve a nulla per noi.
    """
    start = data.find(b"<!DOCTYPE")
    if start == -1:
        return data
    bracket = data.find(b"[", start)
    gt = data.find(b">", start)
    if bracket != -1 and (gt == -1 or bracket < gt):
        close = data.find(b"]>", bracket)
        if close == -1:
            return data
        end = close + 2
    else:
        if gt == -1:
            return data
        end = gt + 1
    return data[:start] + data[end:]


def parse_xml(data: bytes) -> ET.Element:
    return ET.fromstring(strip_doctype(data))


def localname(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def codepoint_hex(ch: str) -> str:
    return f"{ord(ch):05x}"


def write_json(path: Path, payload, pretty: bool) -> int:
    """Scrive e ritorna i KB, così il riepilogo non deve rifare i conti."""
    with path.open("w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False,
                  indent=2 if pretty else None,
                  separators=None if pretty else (",", ":"))
    return path.stat().st_size // 1024


# ---------------------------------------------------------------- KanjiVG

def extract_paths(root: ET.Element) -> list[str]:
    """
    Ritorna i tracciati 'd' in ordine di stroke.
    L'ordine del documento è già corretto, ma ci fidiamo dell'id -sN
    quando c'è, perché è la fonte autoritativa.
    """
    found: list[tuple[int, str]] = []
    for el in root.iter():
        if localname(el.tag) != "path":
            continue
        d = el.get("d")
        if not d:
            continue
        pid = el.get("id", "")
        m = STROKE_ID_RE.search(pid)
        order = int(m.group(1)) if m else len(found) + 1
        found.append((order, " ".join(d.split())))
    found.sort(key=lambda t: t[0])
    return [d for _, d in found]


KVG_NS = b'xmlns:kvg="http://kanjivg.tagaini.net"'


def parse_kanjivg(data: bytes) -> ET.Element:
    """
    KanjiVG dichiara il prefisso kvg: dentro il DOCTYPE (ATTLIST #FIXED).
    Togliendo il DOCTYPE expat non lo conosce più e muore con "unbound prefix",
    quindi lo ridichiariamo sul tag radice. Gli attributi kvg: non ci servono,
    ma devono essere legali perché il file si parsi.
    """
    data = strip_doctype(data)
    if b"kvg:" in data and KVG_NS not in data:
        data = re.sub(rb"<(svg|kanjivg)\b", rb"<\1 " + KVG_NS, data, count=1)
    return ET.fromstring(data)


def load_kanjivg(src: Path, keep_variants: bool = False) -> dict[str, list[str]]:
    """
    Accetta: cartella di .svg, zip di .svg, oppure kanjivg.xml(.gz) monolitico.
    Ritorna {codepoint_hex: [path_d, ...]}
    """
    out: dict[str, list[str]] = {}

    def add_svg(name: str, blob: bytes) -> None:
        m = SVG_NAME_RE.search(name)
        if not m:
            return
        cp, variant = m.group(1).lower(), m.group(2)
        if variant and not keep_variants:
            return
        cp = cp.zfill(5)
        if cp in out:
            return
        try:
            paths = extract_paths(parse_kanjivg(blob))
        except ET.ParseError as e:
            print(f"  ! parse fallito su {name}: {e}", file=sys.stderr)
            return
        if paths:
            out[cp] = paths

    if src.is_dir():
        for f in sorted(src.rglob("*.svg")):
            add_svg(f.name, f.read_bytes())
        return out

    if zipfile.is_zipfile(src):
        with zipfile.ZipFile(src) as z:
            for info in z.infolist():
                if info.is_dir() or not info.filename.endswith(".svg"):
                    continue
                add_svg(Path(info.filename).name, z.read(info))
        return out

    # XML monolitico
    root = parse_kanjivg(read_maybe_gzip(src))
    for kanji in root.iter():
        if localname(kanji.tag) != "kanji":
            continue
        m = KANJI_ID_RE.search(kanji.get("id", ""))
        if not m:
            continue
        cp = m.group(1).lower().zfill(5)
        paths = extract_paths(kanji)
        if paths:
            out.setdefault(cp, paths)
    return out


# ---------------------------------------------------------------- KANJIDIC2

def to_int(value: str | None) -> int | None:
    try:
        return int(value) if value is not None else None
    except ValueError:
        return None


def load_kanjidic(src: Path, meaning_langs: list[str]) -> dict[str, dict]:
    root = parse_xml(read_maybe_gzip(src))
    out: dict[str, dict] = {}

    for ch in root.iter("character"):
        literal = ch.findtext("literal")
        if not literal or len(literal) != 1:
            continue

        misc = ch.find("misc")
        grade = stroke_count = freq = jlpt = None
        if misc is not None:
            grade = to_int(misc.findtext("grade"))
            stroke_count = to_int(misc.findtext("stroke_count"))
            freq = to_int(misc.findtext("freq"))
            jlpt = to_int(misc.findtext("jlpt"))

        on: list[str] = []
        kun: list[str] = []
        meanings: dict[str, list[str]] = {lang: [] for lang in meaning_langs}
        nanori: list[str] = []

        rm = ch.find("reading_meaning")
        if rm is not None:
            for group in rm.findall("rmgroup"):
                for r in group.findall("reading"):
                    rt = r.get("r_type")
                    text = (r.text or "").strip()
                    if not text:
                        continue
                    if rt == "ja_on" and text not in on:
                        on.append(text)
                    elif rt == "ja_kun" and text not in kun:
                        kun.append(text)
                for m in group.findall("meaning"):
                    lang = m.get("m_lang") or "en"
                    if lang in meanings:
                        text = (m.text or "").strip()
                        if text and text not in meanings[lang]:
                            meanings[lang].append(text)
            for n in rm.findall("nanori"):
                if n.text:
                    nanori.append(n.text.strip())

        out[literal] = {
            "on": on,
            "kun": kun,
            "meanings": {k: v for k, v in meanings.items() if v},
            "nanori": nanori,
            "grade": grade,
            "strokeCount": stroke_count,
            "freq": freq,
            "jlptOld": jlpt,  # scala VECCHIA 4..1 (4 = più facile), NON N5..N1
        }

    return out


# ---------------------------------------------------------------- JMdict

# Solo hiragana + kanji: restano fuori i prestiti in katakana (アルカリ性 per 性) e
# le parole col segno di ripetizione (日々, 年々, 国々), che ripetono il kanji senza
# insegnare nulla. Su 300 kanji frequenti un candidato valido resta sempre.
JAPANESE_WORD_RE = re.compile(r"^[぀-ゟ一-鿿]+$")
# Oltre i 3 caratteri non è una parola da ripasso ma una frase ("手当たり次第",
# "いい加減にしろ"), e sul quadrante non ci sta comunque.
MAX_WORD_LENGTH = 3
# Correzioni a mano. Nessuna formula azzecca tutti e 300 i kanji: dopo un certo
# punto è gusto, non algoritmo, e il gusto si scrive in un file rivedibile.
OVERRIDES_PATH = Path(__file__).with_name("word_overrides.json")
IRREGULAR_FORMS = ("rarely used", "irregular", "out-dated", "search-only")
# Sensi che non valgono come esempio, presi dai marcatori di JMdict:
# - "kana alone": nei testi si scrive in kana (貴方, 勿論, 何所), quindi quel kanji
#   scrivendo non lo usa nessuno, per quanto in alto stia nei rank di JPDB;
# - arcaici e obsoleti: 国民 ha due entrate, こくみん e くにたみ, e la seconda è
#   marcata "archaic". Senza filtro entra quella.
REJECTED_SENSES = ("kana alone", "archaic", "obsolete", "obscure", "rare term")


def word_record(entry: ET.Element, keb: str) -> dict | None:
    """
    Prima lettura e primo senso che valgono per questa grafia (re_restr / stagk).
    None se la parola si scrive di norma in kana: vedi KANA_ONLY.
    """
    applicable = [
        r for r in entry.findall("r_ele")
        if r.find("re_nokanji") is None
        and (not r.findall("re_restr") or keb in [x.text for x in r.findall("re_restr")])
    ]
    # Fra più letture vince quella coi tag di priorità: per 国民 la prima in ordine
    # di documento è くにたみ, arcaica, mentre quella che si usa è こくみん.
    reading = next(
        (r.findtext("reb") for r in applicable if r.findall("re_pri")),
        applicable[0].findtext("reb") if applicable else None,
    )
    sense = next(
        (s for s in entry.findall("sense")
         if not s.findall("stagk") or keb in [x.text for x in s.findall("stagk")]),
        None,
    )
    if reading is None or sense is None:
        return None
    misc = " ".join(m.text or "" for m in sense.findall("misc"))
    if any(marker in misc for marker in REJECTED_SENSES):
        return None
    glosses = [g.text for g in sense.findall("gloss") if g.text]
    if not glosses:
        return None
    return {"w": keb, "r": reading, "g": glosses[:3]}


def load_jpdb_ranks(src: Path, chars: set[str]) -> dict[str, int]:
    """
    Dizionario di frequenza Yomitan "rank-based" (JPDB): {parola: posizione}, dove 1
    è la parola più comune. Accetta la cartella del dizionario o un singolo
    term_meta_bank. Tiene solo le parole che contengono un kanji del mazzo, il resto
    è zavorra. Serve unicamente in build per ordinare i candidati: nel bundle
    finiscono le parole scelte, non la lista.
    """
    files = sorted(src.glob("term_meta_bank_*.json")) if src.is_dir() else [src]
    ranks: dict[str, int] = {}
    for path in files:
        for term, kind, payload in json.loads(path.read_text(encoding="utf-8")):
            if kind != "freq" or not chars.intersection(term):
                continue
            value = payload.get("value") if isinstance(payload, dict) else payload
            if value is None and isinstance(payload, dict):
                nested = payload.get("frequency")
                value = nested.get("value") if isinstance(nested, dict) else nested
            if isinstance(value, int) and value < ranks.get(term, 10**9):
                ranks[term] = value
    return ranks


def load_jmdict_words(
    src: Path, chars: set[str], ranks: dict[str, int], overrides: dict[str, str] | None = None
) -> dict[str, dict]:
    """
    Per ogni kanji di `chars`, la parola più comune che lo contiene.
    L'ordine lo dà `ranks` (JPDB), che misura l'uso reale della lingua; il rank nfXX
    di JMdict misura solo i giornali e da solo, per 日, sceglierebbe 日米.
    Restano indietro il kanji da solo — ripeterebbe il kun'yomi — e le frasi troppo
    lunghe per il quadrante. `overrides` ({kanji: grafia}) scavalca tutto.
    Qui niente strip_doctype: le entity della DTD (&n; ecc.) le espande expat.
    """
    overrides = overrides or {}
    best: dict[str, tuple[tuple, dict]] = {}
    with gzip.open(src) as fh:
        for _, entry in ET.iterparse(fh, events=("end",)):
            if entry.tag != "entry":
                continue
            for k_ele in entry.findall("k_ele"):
                keb = k_ele.findtext("keb") or ""
                pri = [p.text for p in k_ele.findall("ke_pri")]
                inf = " ".join(i.text or "" for i in k_ele.findall("ke_inf"))
                hits = chars.intersection(keb)
                # Serve un segnale di comunanza: i tag di JMdict o un rank JPDB.
                if not ((pri or keb in ranks) and hits and JAPANESE_WORD_RE.match(keb)):
                    continue
                if any(t in inf for t in IRREGULAR_FORMS):
                    continue
                word = word_record(entry, keb)
                if word is None:
                    continue
                # Senza JPDB si ripiega sul rank dei giornali, dietro a tutte le
                # parole che un rank vero ce l'hanno.
                nf = min((int(p[2:]) for p in pri if p.startswith("nf")), default=99)
                rank = ranks.get(keb, 10**6 + nf)
                too_long = len(keb) > MAX_WORD_LENGTH
                for ch in hits:
                    if overrides.get(ch) == keb:
                        # La tupla vuota è più piccola di qualsiasi punteggio, ma la
                        # stessa grafia può comparire in più entrate (国民 è こくみん
                        # in una e くにたみ in un'altra): vale la prima, non l'ultima.
                        if best.get(ch, (None,))[0] != ():
                            best[ch] = ((), word)
                        continue
                    key = (keb == ch, too_long, rank, len(keb), keb)
                    if ch not in best or key < best[ch][0]:
                        best[ch] = (key, word)
            entry.clear()
    return {ch: word for ch, (_, word) in best.items()}


# ---------------------------------------------------------------- filtri

def passes(entry: dict, args) -> bool:
    if args.grade_max is not None:
        g = entry["grade"]
        if g is None or g > args.grade_max:
            return False
    if args.jlpt_old is not None:
        if entry["jlptOld"] != args.jlpt_old:
            return False
    if args.freq_max is not None:
        f = entry["freq"]
        if f is None or f > args.freq_max:
            return False
    if args.require_meaning and not entry["meanings"]:
        return False
    return True


def sort_key(item: dict) -> tuple:
    # più frequenti prima, poi per grado, poi per numero di tratti
    freq = item.get("freq") or 10**6
    grade = item.get("grade") or 99
    strokes = len(item.get("strokes") or []) or 99
    return (freq, grade, strokes, item["c"])


# ---------------------------------------------------------------- main

def main() -> int:
    p = argparse.ArgumentParser(
        description="KanjiVG + KANJIDIC2 -> kanji.json per l'app watchOS"
    )
    p.add_argument("--kanjivg", required=True, type=Path,
                   help="zip / cartella di SVG / kanjivg.xml(.gz)")
    p.add_argument("--kanjidic", required=True, type=Path,
                   help="kanjidic2.xml(.gz)")
    p.add_argument("--jmdict", type=Path, default=None,
                   help="JMdict_e.gz: aggiunge la parola più comune per ogni kanji")
    p.add_argument("--jpdb", type=Path, default=None,
                   help="dizionario di frequenza Yomitan (JPDB): ordina le parole per uso reale")
    p.add_argument("-o", "--out", type=Path, default=Path("out"),
                   help="cartella di output (default: ./out)")
    p.add_argument("--grade-max", type=int, default=None,
                   help="tiene solo i kanji con grade <= N (8 = jōyō)")
    p.add_argument("--jlpt-old", type=int, default=None,
                   help="filtra sulla scala JLPT vecchia di KANJIDIC (4..1)")
    p.add_argument("--freq-max", type=int, default=None,
                   help="tiene solo i kanji con rank di frequenza <= N")
    p.add_argument("--chars", default=None,
                   help="set esplicito di kanji, es. 水火木 (o un path a file .txt)")
    p.add_argument("--limit", type=int, default=None,
                   help="tronca al numero massimo di kanji (dopo l'ordinamento)")
    p.add_argument("--langs", default="en",
                   help="lingue dei significati, csv. es. 'en,it,fr'")
    p.add_argument("--require-meaning", action="store_true",
                   help="scarta i kanji senza significato nelle lingue richieste")
    p.add_argument("--variants", action="store_true",
                   help="include le varianti KanjiVG (Kaisho ecc.), di norma inutili")
    p.add_argument("--pretty", action="store_true",
                   help="JSON indentato (file ~2x più grande)")
    args = p.parse_args()

    langs = [s.strip() for s in args.langs.split(",") if s.strip()]

    explicit: set[str] | None = None
    if args.chars:
        maybe = Path(args.chars)
        raw = maybe.read_text(encoding="utf-8") if maybe.is_file() else args.chars
        explicit = {c for c in raw if "\u4e00" <= c <= "\u9fff"}
        if not explicit:
            print("! --chars non contiene nessun kanji", file=sys.stderr)
            return 2

    print(f"[1/5] KanjiVG   <- {args.kanjivg}")
    vg = load_kanjivg(args.kanjivg, keep_variants=args.variants)
    print(f"      {len(vg)} caratteri con tracciati")

    print(f"[2/5] KANJIDIC2 <- {args.kanjidic}")
    dic = load_kanjidic(args.kanjidic, langs)
    print(f"      {len(dic)} caratteri con metadati")

    print("[3/5] merge + filtri")
    records: list[dict] = []
    missing_paths = 0
    mismatches: list[str] = []

    for literal, entry in dic.items():
        if explicit is not None and literal not in explicit:
            continue
        if explicit is None and not passes(entry, args):
            continue

        cp = codepoint_hex(literal)
        paths = vg.get(cp)
        if not paths:
            missing_paths += 1
            continue

        if entry["strokeCount"] and entry["strokeCount"] != len(paths):
            mismatches.append(
                f"{literal} kanjidic={entry['strokeCount']} kanjivg={len(paths)}"
            )

        records.append({
            "c": literal,
            "cp": cp,
            "strokes": paths,
            "on": entry["on"],
            "kun": entry["kun"],
            "meanings": entry["meanings"],
            # nanori, jlptOld e strokeCount non li legge nessuno: con 2.136 kanji
            # ogni campo in più è tempo di decodifica sul Watch.
            "grade": entry["grade"],
            "freq": entry["freq"],
        })

    records.sort(key=sort_key)
    if args.limit:
        records = records[: args.limit]

    if explicit is not None:
        got = {r["c"] for r in records}
        for c in sorted(explicit - got):
            print(f"      ! richiesto ma non prodotto: {c}", file=sys.stderr)

    if args.jmdict:
        print(f"[4/5] JMdict    <- {args.jmdict}")
        chars = {r["c"] for r in records}
        ranks = load_jpdb_ranks(args.jpdb, chars) if args.jpdb else {}
        if args.jpdb:
            print(f"      JPDB: {len(ranks)} parole con un rank")
        overrides = json.loads(OVERRIDES_PATH.read_text(encoding="utf-8")) if OVERRIDES_PATH.exists() else {}
        words = load_jmdict_words(args.jmdict, chars, ranks, overrides)
        for r in records:
            r["word"] = words.get(r["c"])
        applied = sum(1 for c, w in overrides.items() if words.get(c, {}).get("w") == w)
        print(f"      {len(words)} parole trovate, {applied}/{len(overrides)} correzioni a mano")
    else:
        print("[4/5] JMdict    <- saltato (--jmdict non passato)")

    print("[5/5] scrittura")
    args.out.mkdir(parents=True, exist_ok=True)

    # Un file per grado scolastico, tratti compresi, più un catalogo minuscolo.
    # Misurato su un Mac Intel: togliere i soli tratti da un indice unico portava la
    # decodifica dei jōyō da 159 a 112 ms, perché il costo sta nel numero di voci e
    # non nei byte. Per grado si decodifica solo il mazzo che si ripassa davvero.
    by_grade: dict[int, list[dict]] = {}
    for record in records:
        by_grade.setdefault(record["grade"] or 0, []).append(record)

    levels = []
    for grade, level_records in sorted(by_grade.items()):
        size = write_json(args.out / f"kanji-grade-{grade}.json", {"kanji": level_records}, args.pretty)
        levels.append({"grade": grade, "count": len(level_records), "kb": size})

    catalog = {
        "version": 2,
        "viewBox": VIEWBOX,
        "count": len(records),
        # L'attribuzione viaggia dentro il catalogo: l'app la mostra in Impostazioni ›
        # Fonti dati senza imbarcare un secondo file nel bundle.
        "attribution": ATTRIBUTION,
        "levels": [{"grade": level["grade"], "count": level["count"]} for level in levels],
    }
    size_kb = write_json(args.out / "kanji-catalog.json", catalog, args.pretty)
    out_json = args.out / "kanji-catalog.json"

    (args.out / "ATTRIBUTION.txt").write_text(ATTRIBUTION, encoding="utf-8")

    print()
    print(f"  kanji prodotti : {len(records)}")
    print(f"  con parola     : {sum(1 for r in records if r.get('word'))}")
    for level in levels:
        print(f"      grado {level['grade']}: {level['count']:4d} kanji, {level['kb']:4d} KB")
    print(f"  senza tracciati: {missing_paths} (scartati)")
    print(f"  stroke count in disaccordo: {len(mismatches)}")
    for m in mismatches[:10]:
        print(f"      {m}")
    if len(mismatches) > 10:
        print(f"      ... e altri {len(mismatches) - 10}")
    print()
    print(f"  -> {out_json}  ({size_kb:.0f} KB)")
    print(f"  -> {args.out / 'ATTRIBUTION.txt'}  (obbligatorio nel bundle)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
