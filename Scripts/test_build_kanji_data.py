#!/usr/bin/env python3
"""Self-check della scelta delle parole: python3 Scripts/test_build_kanji_data.py"""

import gzip
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

from build_kanji_data import MAX_WORDS, load_jmdict_words, stroke_end, word_record

SAMPLE = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE JMdict [
<!ENTITY n "noun (common) (futsuumeishi)">
<!ENTITY rK "rarely used kanji form">
<!ENTITY arch "archaic">
]>
<JMdict>
<entry><k_ele><keb>水</keb><ke_pri>nf01</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>みず</reb></r_ele><sense><pos>&n;</pos><gloss>water</gloss></sense></entry>
<entry><k_ele><keb>水道工事</keb><ke_pri>nf01</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>すいどうこうじ</reb></r_ele><sense><gloss>plumbing work</gloss></sense></entry>
<entry><k_ele><keb>水泳</keb><ke_pri>nf07</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>すいえい</reb></r_ele><sense><gloss>swimming</gloss></sense></entry>
<entry><k_ele><keb>水泳</keb></k_ele>
  <r_ele><reb>すいおよぎ</reb></r_ele>
  <sense><misc>&arch;</misc><gloss>swimming (archaic)</gloss></sense></entry>
<entry><k_ele><keb>水道</keb><ke_pri>nf06</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <k_ele><keb>水導</keb><ke_inf>&rK;</ke_inf><ke_pri>nf01</ke_pri></k_ele>
  <r_ele><reb>すいどう</reb><re_restr>水道</re_restr></r_ele>
  <r_ele><reb>みずみち</reb><re_restr>水導</re_restr></r_ele>
  <sense><stagk>水導</stagk><gloss>wrong sense</gloss></sense>
  <sense><gloss>water supply</gloss><gloss>tap water</gloss></sense></entry>
<entry><k_ele><keb>日米</keb><ke_pri>nf01</ke_pri><ke_pri>news1</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>にちべい</reb></r_ele><sense><gloss>Japan and the United States</gloss></sense></entry>
<entry><k_ele><keb>一日</keb><ke_pri>nf01</ke_pri><ke_pri>news1</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>いちにち</reb></r_ele><sense><gloss>one day</gloss></sense></entry>
<entry><k_ele><keb>日本</keb><ke_pri>nf25</ke_pri><ke_pri>news2</ke_pri><ke_pri>spec1</ke_pri></k_ele>
  <r_ele><reb>にほん</reb></r_ele><sense><gloss>Japan</gloss></sense></entry>
<entry><k_ele><keb>日々</keb><ke_pri>nf01</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>ひび</reb></r_ele><sense><gloss>daily</gloss></sense></entry>
<entry><k_ele><keb>アルカリ性</keb><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>アルカリせい</reb></r_ele><sense><gloss>alkalinity</gloss></sense></entry>
<entry><k_ele><keb>性別</keb><ke_pri>news1</ke_pri><ke_pri>nf12</ke_pri></k_ele>
  <r_ele><reb>せいべつ</reb></r_ele><sense><gloss>sex</gloss><gloss>gender</gloss></sense></entry>
<entry><k_ele><keb>木</keb><ke_pri>nf01</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>き</reb></r_ele><sense><gloss>tree</gloss></sense></entry>
<entry><k_ele><keb>木曜日</keb><ke_pri>nf02</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>もくようび</reb></r_ele><sense><gloss>Thursday</gloss></sense></entry>
<entry><k_ele><keb>木材</keb><ke_pri>nf03</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>もくざい</reb></r_ele><sense><gloss>lumber</gloss></sense></entry>
<entry><k_ele><keb>木材</keb><ke_pri>nf40</ke_pri></k_ele>
  <r_ele><reb>きざい</reb></r_ele><sense><gloss>lumber (other reading)</gloss></sense></entry>
<entry><k_ele><keb>並木</keb><ke_pri>nf04</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>なみき</reb></r_ele><sense><gloss>row of trees</gloss></sense></entry>
<entry><k_ele><keb>大木</keb><ke_pri>nf05</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>たいぼく</reb></r_ele><sense><gloss>large tree</gloss></sense></entry>
<entry><k_ele><keb>樹木</keb><ke_pri>nf06</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>じゅもく</reb></r_ele><sense><gloss>tree</gloss></sense></entry>
<entry><k_ele><keb>木造建築</keb><ke_pri>nf01</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>もくぞうけんちく</reb></r_ele><sense><gloss>wooden building</gloss></sense></entry>
</JMdict>
"""

# Rank JPDB veri, presi dal dizionario: sono quelli che decidono. Per 木 sono
# inventati, per avere un ordine che i marcatori di JMdict da soli non darebbero.
RANKS = {
    "水": 492, "水道": 13173, "水泳": 10980, "水道工事": 500,
    "日本": 1228, "日米": 48538, "一日": 1425, "日々": 1443,
    "性別": 5384, "アルカリ性": 4000,
    "木": 300, "木造建築": 100, "樹木": 1500, "大木": 2000, "並木": 3000, "木曜日": 4000, "木材": 5000,
}

with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp) / "JMdict_e.gz"
    path.write_bytes(gzip.compress(SAMPLE.encode()))
    words = load_jmdict_words(path, {"水", "日", "性", "火", "木"}, RANKS)
    corrected = load_jmdict_words(path, {"水"}, RANKS, {"水": "水泳"})
    ordered = load_jmdict_words(path, {"木"}, RANKS, {"木": ["木材", "並木"]})
    skipped = load_jmdict_words(path, {"木"}, RANKS, {"木": ["木星", "木曜日"]})
    no_jpdb = load_jmdict_words(path, {"木"}, {})
    again = load_jmdict_words(path, {"水", "日", "性", "火", "木"}, RANKS)
    tree = load_jmdict_words(path, {"木"}, RANKS, {"木": "木"})


def texts(found):
    return [w["w"] for w in found]


# 水 da solo ripeterebbe il kun'yomi e 水道工事 è una frase (rank ottimo, ma fuori):
# in testa il composto col rank migliore, nella lettura non arcaica. Dietro solo
# composti veri: né il kanji da solo né la frase entrano come varietà.
assert words["水"][0] == {"w": "水泳", "r": "すいえい", "g": ["swimming"]}, words["水"]
assert texts(words["水"]) == ["水泳", "水道"], words["水"]
# 日々 esce per il segno di ripetizione, e tra 日本 (1228), 一日 (1425) e 日米 (48538)
# decide l'uso reale della lingua, non il corpus dei giornali. Una parola con due
# kanji del mazzo vale per tutti e due: 木曜日 (4000) passa davanti a 日米.
assert texts(words["日"]) == ["日本", "一日", "木曜日"], words["日"]
# i prestiti in katakana non insegnano il kanji, anche col rank migliore
assert texts(words["性"]) == ["性別"], words["性"]
assert "火" not in words
# la correzione a mano vince, ma la seconda entrata con la stessa grafia — quella
# arcaica — non deve scavalcarla: è così che 国民 diventava くにたみ.
assert corrected["水"][0] == {"w": "水泳", "r": "すいえい", "g": ["swimming"]}, corrected["水"]

# Mai più di tre, nell'ordine dell'uso reale. 木造建築 ha il rank migliore di tutti
# ma è una frase, e 木 da solo è il kun'yomi: nessuno dei due vale come varietà.
# 樹木 (1500) passa davanti, e resta: vuol dire "tree" come 木, ma 木 non è entrato.
assert len(words["木"]) == MAX_WORDS
assert texts(words["木"]) == ["樹木", "大木", "並木"], words["木"]
# Stesso input, stesso risultato: niente dipende dall'ordine di un set.
assert again == words
# Una grafia sola per kanji: 木材 ha due entrate, e vince la lettura con la chiave
# migliore — quella che JPDB conosce.
assert texts(ordered["木"]).count("木材") == 1
assert next(w for w in ordered["木"] if w["w"] == "木材")["r"] == "もくざい"
# Le scelte a mano stanno davanti, nell'ordine in cui sono scritte, e il resto lo
# riempie la regola.
assert texts(ordered["木"]) == ["木材", "並木", "樹木"], ordered["木"]
# Una scelta a mano che JMdict non conosce si salta, senza portarsi via uno slot.
assert texts(skipped["木"]) == ["木曜日", "樹木", "大木"], skipped["木"]
# Senza JPDB decidono i marcatori dei giornali: nf02 prima di nf03, nf04, nf05.
assert texts(no_jpdb["木"]) == ["木曜日", "木材", "並木"], no_jpdb["木"]

# Due parole con lo stesso significato sono uno slot sprecato: 樹木 e 木 vogliono dire
# "tree", e con 木 già scelto a mano 樹木 non entra.
assert texts(tree["木"]) == ["木", "大木", "並木"], tree["木"]

# re_restr e stagk: lettura e senso devono essere quelli della grafia giusta
entry = next(e for e in ET.fromstring(SAMPLE) if e.findtext("k_ele/keb") == "水道")
assert word_record(entry, "水道") == {
    "w": "水道", "r": "すいどう", "g": ["water supply", "tap water"]
}, word_record(entry, "水道")

# Come finisce un tratto, dai tipi veri di KanjiVG: 水 e 字.
assert "".join(stroke_end(t) for t in ["㇚", "㇇", "㇒", "㇏"]) == "hwww"
assert "".join(stroke_end(t) for t in ["㇑a", "㇔", "㇖b", "㇖", "㇁", "㇐"]) == "sdhhhs"
# alternative e tipi mancanti: conta il primo carattere, e senza tipo è un fermo
assert stroke_end("㇔/㇀") == "d" and stroke_end(None) == "s"

print("ok")
