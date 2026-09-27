#!/usr/bin/env python3
"""
jev_review.py
Chiede a Jev (TypeSafe, https://docs.typesafe.ai) due cose che poi build_kanji_data.py
legge da jev_decisions.json, senza chiave e senza rete:
  - quali parole d'esempio non mostrare al polso: volgari, sessuali, offensive;
  - quale significato mettere sotto il kanji: 一 "one", non "one, one radical (no.1)".

Jev non scrive niente: sceglie fra i significati del dizionario e dà una probabilità.
Il file conserva le risposte grezze; le soglie le applica la build.

Rifà solo quello che nel file manca: rilanciarlo non costa niente se i dati non sono
cambiati. Una domanda per richiesta: con quaranta parole nello stesso stato Jev
confondeva gli indici e dava 酪農家 ("dairy farmer") inadatta a 0,90; da sola, 0,02.

  python3 Scripts/jev_review.py

La chiave sta in TYPESAFE_API_KEY o in ~/.config/typesafe/api_key: mai nel repository.
Il primo passaggio completo, su 2.136 kanji e le loro parole, costa pochi centesimi.
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from build_kanji_data import (
    JEV_PATH,
    OVERRIDES_PATH,
    blocked_words,
    load_jmdict_candidates,
    load_jpdb_ranks,
    pick_words,
    shown_meanings,
)

ROOT = Path(__file__).resolve().parent.parent
DECK = ROOT / "KanjiKit/Sources/KanjiData/Resources"
JMDICT = ROOT / "Scripts/raw/JMdict_e.gz"
JPDB = ROOT / "[Freq] JPDB (Recommended)"
# Richieste in parallelo: abbastanza per finire in pochi minuti, poche per non
# sbattere contro il limite del servizio (che risponde 429, e allora si aspetta).
WORKERS = 6


def api_key() -> str:
    key = os.environ.get("TYPESAFE_API_KEY") or ""
    path = Path.home() / ".config/typesafe/api_key"
    if not key and path.exists():
        key = path.read_text().strip()
    if not key:
        sys.exit("Manca la chiave: TYPESAFE_API_KEY o ~/.config/typesafe/api_key")
    return key


KEY = api_key()


def ask(state, questions: dict) -> dict:
    body = json.dumps({"model": "jev-latest", "state": state, "questions": questions}).encode()
    for attempt in range(8):
        request = urllib.request.Request(
            "https://api.typesafe.ai/v1/systemone",
            data=body,
            headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)["answers"]
        except urllib.error.HTTPError as error:
            if error.code in (429, 529):
                time.sleep(2**attempt)
                continue
            sys.exit(f"TypeSafe HTTP {error.code}: {error.read().decode()[:300]}")
        except urllib.error.URLError:
            time.sleep(2**attempt)
    sys.exit("TypeSafe non risponde")


# ---------------------------------------------------------------- significati

def judge_meaning(kanji: dict) -> dict:
    meanings = list(dict.fromkeys(kanji["meanings"]["en"]))
    words = [{"word": w["w"], "reading": w["r"], "meaning": ", ".join(w["g"][:2])} for w in kanji.get("words", [])]
    state = {"kanji": kanji["c"], "dictionary_meanings": meanings, "common_words_with_this_kanji": words}
    primary = ask(state, {"meaning": {
        "type": "choice",
        "instructions": (
            "A beginner learning Japanese sees the kanji `kanji` for three seconds on a watch "
            "notification, with a short English meaning under it. Which of the dictionary "
            "meanings should be shown, so that they learn what this kanji most commonly means in "
            "everyday modern Japanese? Prefer a common, concrete meaning over a rare, archaic, "
            "technical or radical-name sense, and over a meaning with notes in parentheses when a "
            "plainer one says the same thing."
        ),
        "criteria": {m: f"Dictionary meaning: {m}" for m in meanings},
    }})["meaning"]
    rest = [m for m in meanings if m != primary["choice"]]
    second = ask({**state, "chosen_meaning": primary["choice"], "other_dictionary_meanings": rest}, {"second": {
        "type": "choice",
        "instructions": (
            "Under the kanji `kanji` a watch shows `chosen_meaning`. Should a second meaning be shown "
            "next to it? Pick the other dictionary meaning that adds the most for a beginner: a "
            "different sense that is common in everyday Japanese. Pick none if `chosen_meaning` alone "
            "is enough, or if the other meanings are rare, technical, archaic, or just repeat it."
        ),
        "criteria": {**{m: f"Also show: {m}" for m in rest}, "none": "Show only the chosen meaning"},
    }})["second"]
    return {
        "primary": primary["choice"],
        "primaryConfidence": round(primary["confidence"], 2),
        "second": None if second["choice"] == "none" else second["choice"],
        "secondConfidence": round(second["confidence"], 2),
    }


# ---------------------------------------------------------------- parole

def judge_word(word: dict) -> float:
    state = {"word": word["w"], "reading": word["r"], "meaning": ", ".join(word["g"])}
    answer = ask(state, {"unfit": {
        "type": "noul",
        "instructions": (
            "Is the word `word` vulgar, sexual, a slur, offensive, or otherwise embarrassing to "
            "flash on someone's wrist in public as a vocabulary example?"
        ),
        "criteria": {
            "true": "Crude, sexual, insulting, discriminatory or shocking as shown",
            "false": "An ordinary word that is fine to show anyone",
        },
    }})
    return round(answer["unfit"]["noul"], 2)


SEXUAL = {
    "true": "Sexual, or easily read as sexual by a Japanese or English speaker",
    "false": "No sexual reading in ordinary use",
}


def judge_sexual(word: dict) -> float:
    """Solo il sesso, esplicito o allusivo: la regola che l'utente vuole senza eccezioni."""
    state = {"word": word["w"], "reading": word["r"], "meaning": ", ".join(word["g"])}
    answer = ask(state, {"sexual": {
        "type": "noul",
        "instructions": (
            "Could the Japanese word `word` be read as sexual, explicitly or ambiguously: a sexual "
            "act, sexual body part, desire, nudity, prostitution, infidelity, or a common double "
            "meaning, slang or innuendo, in Japanese or in its English meaning?"
        ),
        "criteria": SEXUAL,
    }})
    return round(answer["sexual"]["noul"], 2)


def judge_sexual_kanji(item: tuple[dict, str]) -> dict:
    kanji, shown = item
    state = {"kanji": kanji["c"], "meaning_shown": shown, "dictionary_meanings": kanji["meanings"]["en"]}
    answer = ask(state, {"sexual": {
        "type": "noul",
        "instructions": (
            "A watch shows the kanji `kanji` with the meaning `meaning_shown` under it. Is what it "
            "shows sexual, explicitly or ambiguously: a sexual act, sexual body part, desire, nudity, "
            "prostitution, or a common double meaning?"
        ),
        "criteria": SEXUAL,
    }})
    return {"shown": shown, "p": round(answer["sexual"]["noul"], 2)}


# ---------------------------------------------------------------- giro

def save(decisions: dict) -> None:
    """In ordine alfabetico, per diff leggibili. Una copia: i dizionari di `decisions`
    restano quelli in cui `run` sta scrivendo."""
    stores = ("words", "sexual", "meanings", "kanjiSexual")
    ordered = {**decisions, **{key: dict(sorted(decisions[key].items())) for key in stores}}
    JEV_PATH.write_text(json.dumps(ordered, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def run(jobs: list, judge, store: dict, label: str, decisions: dict) -> None:
    """Chiede in parallelo e salva ogni tanto: un'interruzione non butta via il lavoro."""
    with ThreadPoolExecutor(WORKERS) as pool:
        for done, (key, answer) in enumerate(zip([k for k, _ in jobs], pool.map(judge, [j for _, j in jobs])), 1):
            store[key] = answer
            if done % 200 == 0 or done == len(jobs):
                save(decisions)
                print(f"      {label}: {done}/{len(jobs)}")


def main() -> int:
    kanji = [k for path in sorted(DECK.glob("kanji-grade-*.json")) for k in json.loads(path.read_text())["kanji"]]
    decisions = json.loads(JEV_PATH.read_text()) if JEV_PATH.exists() else {}
    for key, empty in (
        ("allowed", []), ("blocked", []), ("blockedKanji", []), ("shortOverrides", {}),
        ("words", {}), ("sexual", {}), ("meanings", {}), ("kanjiSexual", {}),
    ):
        decisions.setdefault(key, empty)

    todo = [(k["c"], k) for k in kanji if len(set(k["meanings"]["en"])) > 1 and k["c"] not in decisions["meanings"]]
    print(f"[1/2] significati da scegliere: {len(todo)}")
    run(todo, judge_meaning, decisions["meanings"], "significati", decisions)

    print("[2/3] parole d'esempio")
    chars = {k["c"] for k in kanji}
    overrides = json.loads(OVERRIDES_PATH.read_text(encoding="utf-8")) if OVERRIDES_PATH.exists() else {}
    candidates = load_jmdict_candidates(JMDICT, chars, load_jpdb_ranks(JPDB, chars), overrides)
    # Togliere una parola ne fa entrare un'altra, che va giudicata a sua volta: si
    # ripete finché le parole scelte sono tutte già giudicate.
    while True:
        blocked = blocked_words(decisions)
        chosen = {
            w["w"]: w
            for ch, ranked in candidates.items()
            for w in pick_words(ch, [c for c in ranked if c[1]["w"] not in blocked])
        }
        todo = [(text, word) for text, word in chosen.items() if text not in decisions["words"]]
        sexual = [(text, word) for text, word in chosen.items() if text not in decisions["sexual"]]
        if not todo and not sexual:
            break
        print(f"      parole da giudicare: {len(todo)}, e sul sesso: {len(sexual)}")
        run(todo, judge_word, decisions["words"], "parole", decisions)
        run(sexual, judge_sexual, decisions["sexual"], "sesso", decisions)

    # Il significato sotto il kanji: si rigiudica quando cambia quello che si mostra.
    shown = {k["c"]: ", ".join(shown_meanings(decisions, k["c"], k["meanings"]["en"])) for k in kanji}
    todo = [
        (k["c"], (k, shown[k["c"]])) for k in kanji
        if decisions["kanjiSexual"].get(k["c"], {}).get("shown") != shown[k["c"]]
    ]
    print(f"[3/3] significati da controllare sul sesso: {len(todo)}")
    run(todo, judge_sexual_kanji, decisions["kanjiSexual"], "kanji", decisions)

    save(decisions)
    every = {word["w"]: word for ranked in candidates.values() for _, word in ranked}
    for title, store in (("inadatte", decisions["words"]), ("sessuali", decisions["sexual"])):
        flagged = sorted((p, w) for w, p in store.items() if p >= 0.3)
        print(f"\nParole {title} da 0,3 in su ({len(flagged)}):")
        for p, w in reversed(flagged):
            word = every.get(w, {})
            print(f"  {p:.2f} {w} {word.get('r', '')} — {', '.join(word.get('g', []))}")
    flagged = sorted((v["p"], c, v["shown"]) for c, v in decisions["kanjiSexual"].items() if v["p"] >= 0.3)
    print(f"\nKanji col significato forse sessuale ({len(flagged)}): si decidono a mano.")
    for p, c, s in reversed(flagged):
        print(f"  {p:.2f} {c} — {s}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
