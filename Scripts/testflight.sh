#!/bin/bash
# Archivia l'app e la carica su App Store Connect, pronta per TestFlight.
#
# Il numero di build lo assegna Xcode al caricamento, uno più dell'ultimo: nel
# progetto resta 1 e non serve toccarlo a mano. L'account è quello in Xcode ›
# Settings › Apple Accounts. Sul Mac Intel l'archivio ci mette una decina di minuti.
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
xcodebuild -project KanjiWatch.xcodeproj -scheme "KanjiWatch Watch App" -configuration Release \
  -destination "generic/platform=watchOS" -archivePath "$work/KanjiWatch.xcarchive" \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$work/KanjiWatch.xcarchive" \
  -exportOptionsPlist Scripts/ExportOptions.plist -exportPath "$work/export" \
  -allowProvisioningUpdates

echo
echo "Caricata. Fra 5-30 minuti compare in App Store Connect › TestFlight."
