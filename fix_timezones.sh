#!/bin/bash

# Dieses Script ersetzt alle toLocaleString/toLocaleDateString/toLocaleTimeString
# mit den Cambodia-timezone Versionen

# Liste der zu aktualisierenden Dateien
FILES=(
  "src/components/ChecklistReview.tsx"
  "src/components/CheckIn.tsx"
  "src/components/CheckInHistory.tsx"
  "src/components/DepartureRequestAdmin.tsx"
  "src/components/EmployeeManagement.tsx"
  "src/components/Leaderboard.tsx"
  "src/components/Notifications.tsx"
  "src/components/Notes.tsx"
  "src/components/NotesPopup.tsx"
  "src/components/Profile.tsx"
  "src/components/ShoppingList.tsx"
)

echo "Füge Import-Statement zu allen Dateien hinzu..."

for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    # Prüfe ob Import bereits existiert
    if ! grep -q "toLocaleStringCambodia" "$file"; then
      # Finde die letzte import-Zeile und füge darunter ein
      sed -i "/^import.*from.*;$/a import { toLocaleStringCambodia, toLocaleDateStringCambodia, toLocaleTimeStringCambodia } from '../lib/dateUtils';" "$file"
      echo "✓ Import hinzugefügt zu: $file"
    fi
  fi
done

echo "Fertig!"
