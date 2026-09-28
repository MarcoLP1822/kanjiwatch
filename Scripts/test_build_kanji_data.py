#!/usr/bin/env python3
"""Self-check della scelta delle parole: python3 Scripts/test_build_kanji_data.py"""

import gzip
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import json

from build_kanji_data import (
    MAX_WORDS,
    blocked_words,
    clear_words,
    load_jmdict_words,
    load_jpdb_ranks,
    short_meanings,
    shown_glosses,
    shown_meanings,
    stroke_end,
    word_record,
)

SAMPLE = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE JMdict [
<!ENTITY n "noun (common) (futsuumeishi)">
<!ENTITY rK "rarely used kanji form">
<!ENTITY arch "archaic">
<!ENTITY vulg "vulgar expression or word">
<!ENTITY uk "word usually written using kana alone">
]>
<JMdict>
<entry><k_ele><keb>水</keb><ke_pri>nf01</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>みず</reb></r_ele><sense><pos>&n;</pos><gloss>water</gloss></sense></entry>
<entry><k_ele><keb>水棒</keb><ke_pri>nf01</ke_pri><ke_pri>ichi1</ke_pri></k_ele>
  <r_ele><reb>みずぼう</reb></r_ele><sense><misc>&vulg;</misc><gloss>crude word</gloss></sense></entry>
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
<entry><k_ele><keb>一寸</keb></k_ele>
  <r_ele><reb>ちょっと</reb></r_ele><sense><misc>&uk;</misc><gloss>a little</gloss></sense></entry>
<entry><k_ele><keb>一寸</keb></k_ele>
  <r_ele><reb>いっすん</reb></r_ele><sense><gloss>one sun (approx. 3 cm)</gloss></sense></entry>
<entry><k_ele><keb>一緒</keb></k_ele>
  <r_ele><reb>いっしょ</reb></r_ele><sense><gloss>(doing) together</gloss></sense></entry>
<entry><k_ele><keb>一緒に</keb></k_ele>
  <r_ele><reb>いっしょに</reb></r_ele><sense><gloss>together (with)</gloss></sense></entry>
<entry><k_ele><keb>十分</keb></k_ele>
  <r_ele><reb>じゅうぶん</reb></r_ele><sense><gloss>enough</gloss><gloss>sufficient</gloss></sense></entry>
<entry><k_ele><keb>十分</keb></k_ele>
  <r_ele><reb>じっぷん</reb></r_ele><r_ele><reb>じゅっぷん</reb></r_ele>
  <sense><gloss>ten minutes</gloss></sense></entry>
<entry><k_ele><keb>少年</keb></k_ele>
  <r_ele><reb>しょうねん</reb></r_ele><sense><gloss>boy</gloss></sense></entry>
<entry><k_ele><keb>今年</keb></k_ele>
  <r_ele><reb>ことし</reb></r_ele><sense><gloss>this year</gloss></sense></entry>
<entry><k_ele><keb>年齢</keb></k_ele>
  <r_ele><reb>ねんれい</reb></r_ele><sense><gloss>age</gloss><gloss>years</gloss></sense></entry>
<entry><k_ele><keb>白い</keb></k_ele>
  <r_ele><reb>しろい</reb></r_ele><sense><gloss>white</gloss></sense></entry>
<entry><k_ele><keb>面白い</keb></k_ele>
  <r_ele><reb>おもしろい</reb></r_ele><sense><gloss>interesting</gloss></sense></entry>
<entry><k_ele><keb>大丈夫</keb></k_ele>
  <r_ele><reb>だいじょうぶ</reb></r_ele>
  <sense><gloss>safe</gloss><gloss>secure</gloss><gloss>sound</gloss><gloss>all right</gloss><gloss>OK</gloss></sense></entry>
</JMdict>
"""

# Rank JPDB veri, presi dal dizionario: sono quelli che decidono. Per 木 sono
# inventati, per avere un ordine che i marcatori di JMdict da soli non darebbero.
# Valgono per grafia e lettura, come nel dizionario.
RANKS = {
    ("水", "みず"): 492, ("水棒", "みずぼう"): 1, ("水道", "すいどう"): 13173,
    ("水泳", "すいえい"): 10980, ("水道工事", "すいどうこうじ"): 500,
    ("日本", "にほん"): 1228, ("日米", "にちべい"): 48538, ("一日", "いちにち"): 1425, ("日々", "ひび"): 1443,
    ("性別", "せいべつ"): 5384, ("アルカリ性", "アルカリせい"): 4000,
    ("木", "き"): 300, ("木造建築", "もくぞうけんちく"): 100, ("樹木", "じゅもく"): 1500,
    ("大木", "たいぼく"): 2000, ("並木", "なみき"): 3000, ("木曜日", "もくようび"): 4000,
    ("木材", "もくざい"): 5000,
    # 一寸 ha un rank solo come ちょっと, che JMdict dà per scritta in kana.
    ("一寸", "ちょっと"): 93, ("一緒", "いっしょ"): 100, ("一緒に", "いっしょに"): 200,
    ("十分", "じゅうぶん"): 672,
    ("少年", "しょうねん"): 861, ("今年", "ことし"): 1770, ("年齢", "ねんれい"): 2000,
    ("大丈夫", "だいじょうぶ"): 146,
    ("白い", "しろい"): 300, ("面白い", "おもしろい"): 400,
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
    without = load_jmdict_words(path, {"水"}, RANKS, blocked={"水泳"})
    year = load_jmdict_words(path, {"年"}, RANKS)
    clearly = load_jmdict_words(path, {"年"}, RANKS, clear={"年": {"今年"}})
    ones = load_jmdict_words(path, {"一", "十"}, RANKS)
    white = load_jmdict_words(path, {"白"}, RANKS)

    # Il rank vale per grafia e lettura, e quello della parola scritta in kana (㋕)
    # non vale per la grafia coi kanji.
    bank = Path(tmp) / "term_meta_bank_1.json"
    bank.write_text(json.dumps([
        ["大丈夫", "freq", {"reading": "だいじょうぶ", "frequency": {"value": 146, "displayValue": "146"}}],
        ["大丈夫", "freq", {"reading": "だいじょうぶ", "frequency": {"value": 5, "displayValue": "5㋕"}}],
        ["十分", "freq", {"reading": "じゅうぶん", "frequency": {"value": 672, "displayValue": "672"}}],
        ["十分", "freq", {"reading": "じっぷん", "frequency": {"value": 9000, "displayValue": "9000"}}],
        ["の", "freq", {"value": 1, "displayValue": "1㋕"}],
    ]), encoding="utf-8")
    jpdb = load_jpdb_ranks(bank, {"大", "十"})


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

# Una parola che JMdict marca volgare non entra, nemmeno col rank migliore di tutti:
# il Watch la mostrerebbe al polso.
assert "水棒" not in texts(words["水"]), words["水"]
# Una parola tolta da Jev lascia il posto alla successiva: 水泳 via, 水道 in testa.
assert texts(without["水"]) == ["水道"], without["水"]

# 一寸 non prende il rank di ちょっと: letto いっすん non è comune, e non entra. Fra
# 一緒 e 一緒に, una dentro l'altra, resta la prima.
assert texts(ones["一"]) == ["一緒", "一日"], ones["一"]
# 十分 è una grafia sola con due entrate: vince la lettura che JPDB conosce.
assert ones["十"][0]["r"] == "じゅうぶん", ones["十"]
# Una dentro l'altra vale solo all'inizio: 面白い contiene 白い, ma è un'altra parola.
assert texts(white["白"]) == ["白い", "面白い"], white["白"]
assert jpdb == {("大丈夫", "だいじょうぶ"): 146, ("十分", "じゅうぶん"): 672, ("十分", "じっぷん"): 9000}, jpdb

# In testa la parola che fa vedere il kanji, se Jev ne ha trovata una: 今年 "this
# year" davanti a 少年 "boy", che pure è più comune. Senza giudizio, decide il rank.
assert texts(year["年"]) == ["少年", "今年", "年齢"], year["年"]
assert texts(clearly["年"]) == ["今年", "少年", "年齢"], clearly["年"]
# Il giudizio vale per il significato che il Watch mostra adesso.
judged = {"clear": {"年/今年": {"shown": "year", "p": 0.9}, "年/少年": {"shown": "year", "p": 0.1}}}
assert clear_words(judged, {"年": "year"}) == {"年": {"今年"}}
assert clear_words(judged, {"年": "year, counter for years"}) == {}

# Il significato della parola: quello d'uso comune, se Jev è sicuro e se è fra le voci
# del senso; altrimenti le prime tre.
daijoubu = {"w": "大丈夫", "r": "だいじょうぶ", "g": ["safe", "secure", "sound", "all right", "OK"]}
everyday = {"primary": "all right", "primaryConfidence": 0.8, "second": "OK", "secondConfidence": 0.6}
assert shown_glosses({"wordMeanings": {"大丈夫": everyday}}, daijoubu) == ["all right", "OK"]
assert shown_glosses({"wordMeanings": {"大丈夫": {**everyday, "primaryConfidence": 0.3}}}, daijoubu) == [
    "safe", "secure", "sound"]
assert shown_glosses({"wordMeanings": {"大丈夫": {**everyday, "primary": "fine"}}}, daijoubu) == [
    "safe", "secure", "sound"]
assert shown_glosses({}, daijoubu) == ["safe", "secure", "sound"]
# La correzione a mano vince su tutto.
assert shown_glosses({"wordMeaningOverrides": {"大丈夫": ["all right"]}, "wordMeanings": {"大丈夫": everyday}}, daijoubu) == [
    "all right"]

# Le soglie di Jev. Parole: da 0,5 in su fuori, salvo le riammesse a mano; quelle
# tolte a mano restano fuori comunque.
assert blocked_words({"words": {"a": 0.97, "b": 0.6, "c": 0.2}, "allowed": ["b"], "blocked": ["c"]}) == {"a", "c"}
assert blocked_words({}) == set()
# Sul sesso la riammissione a mano non vale: la regola è senza eccezioni.
assert blocked_words({"sexual": {"x": 0.65, "y": 0.4}, "allowed": ["x"]}) == {"x"}
# E vale anche per il significato scelto per il polso, giudicato a parte.
assert blocked_words({"wordMeanings": {"x": {**everyday, "sexual": 0.7}, "y": {**everyday, "sexual": 0.1}}}) == {"x"}
# Sotto il kanji: prima la correzione a mano, poi Jev, poi i primi due del dizionario.
chosen = {"meanings": {"一": {"primary": "one", "primaryConfidence": 1.0, "second": None, "secondConfidence": 0.9}}}
assert shown_meanings(chosen, "一", ["one", "one radical (no.1)"]) == ["one"]
assert shown_meanings({**chosen, "shortOverrides": {"一": ["unity"]}}, "一", ["one"]) == ["unity"]
assert shown_meanings({}, "日", ["day", "sun", "Japan"]) == ["day", "sun"]
# Significati: il secondo solo se è sicuro anche lui; senza sicurezza, niente scelta.
one = {"primary": "one", "primaryConfidence": 1.0, "second": None, "secondConfidence": 0.9}
assert short_meanings(one) == ["one"]
assert short_meanings({**one, "second": "unit", "secondConfidence": 0.7}) == ["one", "unit"]
assert short_meanings({**one, "second": "unit", "secondConfidence": 0.4}) == ["one"]
assert short_meanings({**one, "primaryConfidence": 0.4}) is None
assert short_meanings(None) is None

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
