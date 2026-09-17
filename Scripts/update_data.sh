#!/usr/bin/env bash
# Aggiorna i dati dalle versioni più recenti e rigenera i mazzi del bundle.
#
# Non è una comodità: la licenza EDRDG chiede "a procedure for regular updating of the
# data from the most recent versions available", e non aggiornare è una violazione.
# Si lancia a ogni rilascio dell'app, e comunque quando i dati sono vecchi di mesi.
#
#     Scripts/update_data.sh
#
# I file scaricati restano in Scripts/raw/, fuori dal repository: si riscaricano sempre.
set -euo pipefail
cd "$(dirname "$0")/.."
raw="Scripts/raw"
mkdir -p "$raw"

echo "[1/4] KANJIDIC2 <- edrdg.org"
curl -fL --progress-bar -o "$raw/kanjidic2.xml.gz" "http://www.edrdg.org/kanjidic/kanjidic2.xml.gz"

echo "[2/4] JMdict (solo inglese) <- ftp.edrdg.org"
curl -fL --progress-bar -o "$raw/JMdict_e.gz" "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz"

echo "[3/4] KanjiVG <- ultima release su GitHub"
asset=$(curl -fsSL https://api.github.com/repos/KanjiVG/kanjivg/releases/latest \
  | python3 -c "import json, sys; print(next(a['browser_download_url'] for a in json.load(sys.stdin)['assets'] if a['name'].endswith('-main.zip')))")
curl -fL --progress-bar -o "$raw/$(basename "$asset")" "$asset"

# La lista di frequenza JPDB non si ridistribuisce e non si scarica da qui: se c'è la
# usiamo per scegliere la parola d'esempio, altrimenti decidono i marcatori di JMdict.
jpdb=()
if [ -d "[Freq] JPDB (Recommended)" ]; then
  jpdb=(--jpdb "[Freq] JPDB (Recommended)")
else
  echo "    (lista JPDB assente: la parola d'esempio userà solo i marcatori di JMdict)"
fi

echo "[4/4] Rigenerazione dei mazzi"
python3 Scripts/build_kanji_data.py \
  --kanjivg "$raw/$(basename "$asset")" \
  --kanjidic "$raw/kanjidic2.xml.gz" \
  --jmdict "$raw/JMdict_e.gz" \
  ${jpdb[@]+"${jpdb[@]}"} \
  --grade-max 8 --require-meaning \
  -o KanjiKit/Sources/KanjiData/Resources/

echo
echo "Fatto. Controlla il diff dei mazzi e lancia i test:"
echo "    git diff --stat -- KanjiKit/Sources/KanjiData/Resources/"
echo "    swift test --package-path KanjiKit"
