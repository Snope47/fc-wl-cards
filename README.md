# fc-wl-cards

Kartendaten für die App **FC WL TRACKER** – einmal täglich automatisch aktualisiert
und über GitHub Pages bereitgestellt:

- `meta.json` – Version/Zeitstempel (die App prüft nur diese kleine Datei)
- `cards.json` – alle Karten (Name, Wertung, Position, Version …)
- `img/<id>-<hash>.webp` – kompakte Kartenbilder ab Wertung 65

Der Job (`.github/workflows/cards.yml`) läuft täglich, holt nur neue Karten und
gleicht sonntags alles ab. Manuell starten: *Actions → Karten aktualisieren → Run workflow*.

Nicht mit EA verbunden. Kartenbilder und -namen gehören ihren jeweiligen Rechteinhabern.
