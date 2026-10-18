# Sammlung

Verzeichnisse für Musikalben, Bücher, Filme, Spiele oder eigene Typen. Alle Daten liegen lokal auf dem Gerät.

## Einrichtung

```
flutter create sammlung       # einmalig, erzeugt android/ und ios/
```
Dann `pubspec.yaml`, `lib/`, `assets/` und `tool/` in das neue Projekt kopieren (vorhandene Dateien ersetzen) und im Projektordner ausführen:
```
flutter pub get
./tool/apply_branding.sh      # App-Name und Icon (Windows: powershell -ExecutionPolicy Bypass -File .\tool\apply_branding.ps1)
flutter run --release
```

## Bedienung

- **Verzeichnisse:** Auf der Startseite mit „Verzeichnis" aus Vorlagen (Musikalben, Bücher, Filme, Spiele) oder als „Eigener Typ" anlegen. Beim eigenen Typ legst du Bezeichnungen fest (z. B. Interpret/Titel/Jahr), ob es Gruppierung und Jahr gibt, und beliebige Zusatzfelder. Alles lässt sich später über „Bearbeiten" ändern.
- **Alle:** Gesamtliste, sortiert nach Gruppe (z. B. Interpret). Links die Buchstabenleiste zum Springen (Ziffern und Symbole unter „#"), oben der Filter. Mehrere Wörter im Filter müssen alle vorkommen („dads about"). Ein Tipp auf den Titel öffnet die Seite des Eintrags, ein Tipp auf den Interpreten die Interpretenseite. Innerhalb eines Interpreten wird nach Jahr sortiert, über das Menü lässt sich auf Titel umstellen.
- **Interpreten:** Liste aller Gruppen mit Anzahl, ebenfalls mit Buchstabenleiste und Filter. Die Gruppenseite zeigt alle Einträge und ein Histogramm über die Jahre (Balken antippen zeigt die Anzahl).
- **Eintragsseite:** Bewertungen per Sterne vergeben (erneut auf den Stern tippen löscht), und „Jetzt gehört" (bzw. gelesen, gesehen …) einträgt mit aktuellem Zeitpunkt. „Anderer Zeitpunkt" erlaubt Datum und Uhrzeit. Die Einträge lassen sich einzeln löschen.
- **Statistik:** Histogramm über die Jahre, Interpreten mit den meisten Einträgen, Durchschnitt je Bewertung und die zuletzt gehörten Einträge.
- **Bewertungen:** Beliebig viele Arten mit Name, Buchstabe und Farbe, jeweils 1 bis 5 Sterne. Anlegen kannst du sie unter „Verzeichnis bearbeiten" (Abschnitt Bewertungen), im Menü „Bewertungen verwalten", auf der Statistikseite, beim Anlegen eines eigenen Typs oder beim Bearbeiten eines Eintrags. Beim Anlegen und Ändern eines Eintrags setzt du die Sterne direkt mit. In der Liste erscheinen sie als farbige Marken wie „R★3".
- **Hörzähler:** In der Liste steht neben dem Jahr, wie oft ein Eintrag benutzt wurde (nur wenn mindestens einmal). Die Statistik zeigt die Meistgehörten.
- **Jahre:** Ein Tipp auf einen Balken im Histogramm zeigt die Anzahl, „Anzeigen" listet alle Einträge dieses Jahres.

## Excel-Import und -Export

Menü des Verzeichnisses (oben rechts):
- **Importieren:** Excel-Datei (.xlsx), CSV/TSV/TXT oder direkt aus der Zwischenablage (in Excel Zellen kopieren, in der App einfügen). Vor dem Import zeigt die App, wie die Spalten zugeordnet werden.
- **Spaltenreihenfolge:** Interpret, Titel, Jahr (bei Verzeichnissen ohne Gruppierung oder Jahr entfallen die entsprechenden Spalten). Alles danach sind Bewertungen. Mit Kopfzeile entstehen die Bewertungen aus den Spaltennamen, der Anfangsbuchstabe wird zur Kennzeichnung („Redaktion" wird R, „Leser" wird L). Ohne Kopfzeile heißen sie „Bewertung 1, 2 …" mit den Buchstaben A, B … und lassen sich danach umbenennen. Eine Spalte, deren Kopfzeile wie ein Zusatzfeld heißt, wird als dieses Zusatzfeld gelesen.
- **Kopfzeile:** Wird automatisch erkannt, wenn die Jahr-Zelle der ersten Zeile kein Jahr ist oder die erste Zelle wie die Spaltenbezeichnung heißt.
- **Doppelte Einträge:** Gleicher Name, Titel und Jahr wird nicht doppelt angelegt, sondern um die Bewertungen ergänzt. Ein erneuter Import ist daher gefahrlos.
- **Exportieren:** Als Excel (.xlsx) mit Kopfzeile, Bewertungsspalten als „Redaktion (R)" und den Zusatzfeldern am Ende. Das lässt sich wieder importieren. Außerdem „Als Text kopieren" (Tab-getrennt).
- Nur .xlsx wird gelesen, nicht das alte .xls. Dann in Excel als .xlsx speichern.
- Farben der Bewertungen und die Hör-Zeitpunkte sind nicht in der Excel-Datei. Dafür gibt es auf der Startseite im Menü „Komplette Sicherung exportieren" und „Sicherung wiederherstellen" (ersetzt alle Daten).

## Hinweise

- Das Speichern erfolgt kurz nach jeder Änderung und sofort beim Verlassen der App. Wird die App deinstalliert, sind die Daten weg. Exportiere vorher eine Sicherung.
- Die Schrift Lato lädt `google_fonts` beim ersten Start aus dem Netz und speichert sie danach.
