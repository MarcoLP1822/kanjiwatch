#!/usr/bin/env python3
"""Self-check della scelta della parola: python3 Scripts/test_build_kanji_data.py"""

import gzip
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

from build_kanji_data import load_jmdict_words, stroke_end, word_record

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
</JMdict>
"""

# Rank JPDB veri, presi dal dizionario: sono quelli che decidono.
RANKS = {
    "水": 492, "水道": 13173, "水泳": 10980, "水道工事": 500,
    "日本": 1228, "日米": 48538, "一日": 1425, "日々": 1443,
    "性別": 5384, "アルカリ性": 4000,
}

with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp) / "JMdict_e.gz"
    path.write_bytes(gzip.compress(SAMPLE.encode()))
    words = load_jmdict_words(path, {"水", "日", "性", "火"}, RANKS)
    corrected = load_jmdict_words(path, {"水"}, RANKS, {"水": "水泳"})

# 水 da solo ripeterebbe il kun'yomi e 水道工事 è una frase (rank ottimo, ma fuori):
# resta il composto col rank migliore, nella lettura non arcaica.
assert words["水"] == {"w": "水泳", "r": "すいえい", "g": ["swimming"]}, words["水"]
# 日々 esce per il segno di ripetizione, e tra 日本 (1228), 一日 (1425) e 日米 (48538)
# decide l'uso reale della lingua, non il corpus dei giornali.
assert words["日"]["w"] == "日本", words["日"]
# i prestiti in katakana non insegnano il kanji, anche col rank migliore
assert words["性"]["w"] == "性別", words["性"]
assert "火" not in words
# la correzione a mano vince, ma la seconda entrata con la stessa grafia — quella
# arcaica — non deve scavalcarla: è così che 国民 diventava くにたみ.
assert corrected["水"] == {"w": "水泳", "r": "すいえい", "g": ["swimming"]}, corrected["水"]

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
