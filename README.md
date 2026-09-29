# OULAD Learning Analytics

SQL- und Python-Projekt zur Analyse des öffentlichen [OULAD-Datensatzes](https://analyse.kmi.open.ac.uk/open-dataset) (Open University Learning Analytics Dataset), im Rahmen einer Datenanalyse-Weiterbildung.

## Fragestellung
Was unterscheidet Studierende, die bestehen, von denen, die nicht bestehen – und welche Rolle spielen Modul, sozioökonomischer Hintergrund (IMD), Vorbildung und Aktivität auf der Lernplattform?

## Vorgehen
- **PostgreSQL**: Datenbankaufbau (Rohdaten → bereinigtes Schema → Analytics-Layer), Datenbereinigung/-audit, Analysen mit CTEs, JOINs, Window Functions, Views & Materialized Views
- **Python (statsmodels)**: logistische Regression in 4 Modellstufen zur Vorhersage der Bestehenswahrscheinlichkeit, inkl. Odds Ratios, Konfidenzintervalle und Visualisierung

## Module
Analysiert wurden drei Module (BBB, DDD, FFF), ausgewählt nach Gruppengröße, Datenqualität und Fachbereich-Mix (Auswahlbegründung siehe `oulad_modulauswahl_final.md`).

## Dateien
| Datei | Inhalt |
|---|---|
| `OULAD_1_aufbau.sql` | Datenbank-Setup, Rohdaten-Import, Audit, bereinigtes Schema, Foreign Keys |
| `OULAD_2_analysis.sql` | Analysefragen, Views/Materialized Views, Window Functions, Datenexport |
| `oulad_regression.ipynb` | Logistische Regression (4 Modelle) in Python/statsmodels |
| `oulad_datenwoerterbuch_final.md` | Datendokumentation |
| `oulad_modulauswahl_final.md` | Begründung der Modulauswahl |
| `oulad_ergebnisse_final.md` | Zusammenfassung der Kernbefunde |
| `OULAD_cleaned_FKs.png` | ER-Diagramm des bereinigten Schemas |

## Wichtigster Befund
Sozioökonomischer Hintergrund (IMD) und Vorbildung sagen die Bestehenswahrscheinlichkeit robust vorher, auch nach Kontrolle für Modul, Alter, Geschlecht und Aktivität auf der Plattform. Details siehe `oulad_ergebnisse_final.md`.
