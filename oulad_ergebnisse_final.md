# OULAD — Ergebnisse

**Datensatz:** Open University Learning Analytics Dataset (Kuzilek et al., 2017), anonymisierte Daten der britischen Open University. **Ausgewählte Module:** BBB, DDD, FFF (Begründung: `oulad_modulauswahl_final.md`). Die Modulnamen sind im Datensatz anonymisiert, die Kursinhalte daher nicht bekannt. Die Datensatzbeschreibung ordnet die Module nur einem Fachbereich zu: BBB den Sozialwissenschaften, DDD und FFF den MINT-Fächern (Details: `oulad_datenwoerterbuch_final.md`). **Zähleinheit:** Einschreibung (eine Zeile in `student_info`), nicht Person. Wer ein Modul wiederholt, zählt mehrfach (BBB 7.909 Einschreibungen für 7.692 Personen, DDD 6.272 für 5.848, FFF 7.762 für 7.397).

**Definitionen:** bestanden = Pass + Distinction, durchgefallen = Fail, abgebrochen = Withdrawn.

## Vorgehen

Rohdaten (`raw`, alles Text) → Audit → bereinigte Tabellen mit Typen, Primär- und Fremdschlüsseln (`cleaned`, ER-Diagramm: `oulad_er_diagramm.png`) → Auswertung und Report (`analytics`).

**Befunde aus dem Audit** (in `cleaned` als NULL belassen, nichts geraten):
- 148 ungültige `score`-Werte in den drei Modulen
- fehlende IMD-Werte (BBB 63, DDD 280, FFF 367), Platzhalter `?`
- Band `10-20` ohne %-Zeichen, vereinheitlicht zu `10-20%`
- 5 Exam-Einträge ohne Datum (laut Datensatzbeschreibung liegt der Termin dann am Ende der letzten Präsentationswoche)
- 6 Klickwerte über 2.000 an einem Tag, vermutlich technische Artefakte, nicht entfernt
- `student_vle`: mehrere Zeilen pro Person, Material und Tag, Klicks werden aufsummiert

## Kernbefunde

**1. Die Module unterscheiden sich vor allem im Abbruch.**

| | BBB | DDD | FFF |
|---|---|---|---|
| bestanden, alle Einschreibungen | 47,5 % | 41,6 % | 47,0 % |
| Abbruchquote | 30,2 % | 35,9 % | 31,0 % |
| bestanden, ohne Abbrecher | 68,0 % | 64,9 % | 68,1 % |

Fail liegt in allen Modulen bei etwa 22 %. Der Rückstand von DDD schrumpft ohne Abbrecher von rund 6 auf rund 3 Prozentpunkte.

**2. Mit angegebener Behinderung wird seltener bestanden, vor allem wegen häufigerer Abbrüche.**

| | BBB | DDD | FFF |
|---|---|---|---|
| bestanden mit / ohne disability | 38,5 % / 48,4 % | 31,7 % / 42,9 % | 35,4 % / 48,2 % |
| Abbruch mit / ohne disability | 35,8 % / 29,6 % | 48,0 % / 34,2 % | 42,9 % / 29,7 % |
| Abstand bestanden ohne Abbrecher (Punkte) | 8,6 | 4,3 | 6,7 |

**3. Je höher der Vorabschluss, desto höher die Bestehensquote** (ohne Abbrecher; BBB / DDD / FFF): unter A-Level 58,8 / 53,0 / 59,8 %, A-Level 74,5 / 69,0 / 72,4 %, Studium 77,1 / 74,7 / 77,2 %. Der Unterschied besteht auch bei denen, die durchgehalten haben.

**4. Je weniger benachteiligt das Wohngebiet (IMD), desto häufiger bestanden und desto seltener abgebrochen.** Von IMD 0–10 % zu 90–100 %: bestanden BBB 34,0 → 61,5 %, DDD 31,1 → 51,7 %, FFF 32,9 → 56,9 %; Abbruch BBB 35,9 → 25,5 %, DDD 43,2 → 27,7 %, FFF 39,1 → 25,8 %. IMD und Vorabschluss hängen zusammen: Der Anteil mit Abschluss unter A-Level sinkt von 51,1 % (IMD 0–10 %) auf 32,3 % (IMD 90–100 %). Die beiden Effekte lassen sich deshalb mit diesen Vergleichen nicht trennen.

**5. Bestandene klicken in allen Materialtypen mehr als Durchgefallene** (Verhältnis 1,5 bis 3,5; ohne Abbrecher, ab Kursbeginn). Am größten bei `oucontent` in BBB (3,48) und FFF (3,45) sowie bei `forumng` in DDD (3,03), am kleinsten bei `oucontent` in DDD (1,47). Meistgenutzt sind in BBB und DDD Forum und Startseite, in FFF `oucontent` und `quiz`. Weil alle Typen höhere Werte zeigen, spiegelt das vor allem die Gesamtaktivität wider, nicht einzelne Materialien.

## Vorbehalte

- **Deskriptiv, nicht kausal.** Es gibt keine Signifikanztests, und die Merkmale (IMD, Vorabschluss, Alter, disability) sind nicht gegeneinander kontrolliert.
- **Kleine Gruppen:** `No Formal quals`, `Post Graduate` und Altersband 55+ sind zu klein für belastbare Aussagen.
- **Fehlende IMD-Werte** haben die niedrigste Abbruch- und die höchste Bestehensquote, fehlen also vermutlich nicht zufällig (Ursache unbekannt, Gruppe klein).
- **Klicks** messen Häufigkeit, nicht Dauer oder Qualität. Motivation und Zeitbudget sind nicht erfasst. `quiz`-Klicks hängen vermutlich an den Prüfungen selbst und wurden nicht gedeutet.
- **`score`** ist vermutlich nicht intervallskaliert, die Auswertung läuft deshalb über `final_result`.
- **B- und J-Präsentationen** wurden zusammengefasst, obwohl die Datensatzbeschreibung empfiehlt, sie getrennt zu betrachten.
- **Fachbereich und Modul sind vermengt:** BBB ist das einzige sozialwissenschaftliche Modul der Auswahl, DDD und FFF sind MINT-Fächer. Unterschiede zwischen BBB und den beiden anderen können am Fachbereich liegen, das lässt sich hier nicht trennen.

## Techniken im Projekt

- **Analytics-Schema** mit `v_zentrumsbericht` (View, eine Zeile pro Einschreibung mit Demografie, Ergebnis, Klicks, Abgaben) und `mv_zentrumsbericht` (Materialized View mit Unique Index). Abfragezeit für denselben Durchschnitt: View 0,824 s, Materialized View 0,01 s.
- **Window Functions** in drei Formen: `SUM() OVER` (Prozentanteile), `ROW_NUMBER() OVER` (Rangfolge der Materialtypen), `AVG() OVER` (Abstand zum Modulschnitt).
- Weitere: CTEs, JOIN und LEFT JOIN, bedingte Aggregation mit `FILTER`, `CASE WHEN`, `COALESCE`, `NULLIF`.

## Logistische Regression (Ausblick, in Python/statsmodels)

**Frage:** Was sagt das Bestehen am besten voraus, wenn Vorabschluss, IMD, Alter, disability, Geschlecht und Modul gleichzeitig kontrolliert werden? Basis: `oulad_zentrumsbericht.csv`, ohne Withdrawn und ohne fehlenden IMD-Wert (n = 14.336). Vorabschluss in drei Stufen wie in B3 (unter A-Level als Referenz), IMD als Zahl 1–10 (Band-Schritt), Klickvariablen logarithmiert und je Modul standardisiert (z-Wert), weil sich die Klickmengen zwischen den Modulen stark unterscheiden (Befund C1a). Berichtet werden Odds Ratios (OR) mit 95 %-Konfidenzintervall (KI); ein KI, das die 1 nicht enthält, gilt als statistisch abgesichert (p < .05). Zur Einordnung der Effektgröße: OR < 1,68 sehr klein, 1,68–3,47 klein, 3,47–6,71 mittel, ≥ 6,71 groß (Chen, Cohen & Chen, 2010); Pseudo-R² (McFadden) zwischen 0,2 und 0,4 gilt als guter Modellfit (McFadden, 1974).

Vier Modelle, jeweils mit denselben demografischen Merkmalen, unterschiedlicher Aktivitätsvariable:

| Merkmal (Referenz) | M1: nur Demografie | M2: + Klicks gesamtes Semester | M3: + Klicks erste 4 Wochen | M4: + oucontent & forumng |
|---|---|---|---|---|
| Vorabschluss A-Level (vs. unter A-Level) | 1,94 [1,80–2,10]*** | 2,05 [1,85–2,26]*** | 2,02 [1,86–2,19]*** | 2,03 [1,85–2,23]*** |
| Vorabschluss Studium (vs. unter A-Level) | 2,21 [1,97–2,48]*** | 2,04 [1,76–2,36]*** | 2,26 [2,00–2,56]*** | 2,16 [1,87–2,48]*** |
| IMD (pro Band-Schritt) | 1,10 [1,09–1,11]*** | 1,08 [1,06–1,10]*** | 1,09 [1,08–1,11]*** | 1,08 [1,07–1,10]*** |
| Alter 35+ (vs. 0–35) | 1,35 [1,24–1,46]*** | 0,80 [0,72–0,89]*** | 1,14 [1,04–1,24]** | 0,93 [0,84–1,03] n.s. |
| disability (vs. nein) | 0,86 [0,76–0,97]* | 0,84 [0,72–0,98]* | 0,86 [0,75–0,98]* | 0,88 [0,76–1,02] n.s. |
| weiblich (vs. männlich) | 1,26 [1,15–1,38]*** | 0,81 [0,72–0,91]*** | 1,11 [1,00–1,22]* | 0,88 [0,79–0,98]* |
| Modul DDD (vs. BBB) | 0,83 [0,75–0,92]*** | 0,54 [0,47–0,62]*** | 0,73 [0,65–0,81]*** | 0,51 [0,45–0,58]*** |
| Modul FFF (vs. BBB) | 1,10 [0,99–1,22] n.s. | 0,64 [0,56–0,74]*** | 0,94 [0,84–1,06] n.s. | 0,67 [0,59–0,77]*** |
| Aktivität (pro SD, je Modul) | – | 12,72 [11,55–14,00]*** | 2,34 [2,24–2,45]*** | oucontent 3,02 [2,85–3,20]***, forumng 2,80 [2,65–2,96]*** |
| Pseudo-R² (McFadden) | 0,041 | 0,370 | 0,138 | 0,307 |

*** p < .001, ** p < .01, * p < .05, n.s. nicht signifikant (KI enthält 1)

**Befunde:**
- **Vorabschluss und IMD sind robust:** Ihre OR bleiben über alle vier Modelle fast unverändert (Vorabschluss ~2, IMD ~1,08–1,10 pro Band). Sie wirken also auch dann, wenn die Aktivität in der Lernplattform kontrolliert wird — der stärkste belastbare Einzelbefund des Projekts.
- **Aktivität ist der stärkste Zusammenhang, aber die Größe hängt stark von der Messung ab.** Über das ganze Semester gemessen (M2) ist die OR riesig (12,7) und erklärt allein einen Großteil des Modells (Pseudo-R² 0,041 → 0,370). Nur in den ersten vier Wochen gemessen (M3), also zeitlich vor dem Ergebnis, ist der Effekt viel kleiner (2,34), aber weiterhin der stärkste im Modell. Der Unterschied stützt den Vorbehalt: Ein großer Teil des M2-Effekts ist vermutlich Folge des Bestehens (wer durchhält, klickt bis zum Ende), nicht dessen Ursache.
- **Alter, Geschlecht und disability liefern kein einheitliches Bild.** In M1 wirken Alter 35+ und weiblich positiv, in M2 kehrt sich die Richtung um. Grund: Beide Gruppen klicken im Schnitt mehr (Alter 35+: z = 0,19 vs. −0,08; weiblich: z = 0,07 vs. −0,07) — ihr scheinbarer Vorteil in M1 lief über die Aktivität. disability bleibt in M1–M3 ein kleiner, aber signifikanter Effekt (OR 0,84–0,86), in M4 nicht mehr abgesichert.
- **Materialtyp (M4):** `oucontent` (OR 3,02) und `forumng` (OR 2,80) wirken beide eigenständig, wenn man nur diese zwei Typen gemeinsam ins Modell nimmt. Alle sechs Typen gleichzeitig ließen sich nicht schätzen (Modell nicht identifizierbar, "Singular Matrix"), weil sie stark miteinander korrelieren (r bis 0,89 zwischen homepage und subpage) — wer ein Material viel nutzt, nutzt meist auch die anderen viel. `quiz` musste zusätzlich ausgeschlossen werden: In DDD hat niemand `quiz` genutzt (Streuung 0), was das Modell technisch verhindert — zugleich ein Beleg, dass DDD offenbar keine Quiz-Materialien hat. **M4 beantwortet nicht zuverlässig, welches einzelne Material am wichtigsten ist**, nur dass `oucontent` und `forumng` nicht austauschbar sind.

**Vorbehalte der Regression:**
- Deskriptiv/prädiktiv, nicht kausal — keine der Variablen ist experimentell zugewiesen.
- Region, `num_of_prev_attempts`, `studied_credits` und `code_presentation` sind nicht im Modell (im Zentrumsbericht nicht enthalten bzw. nie ausgewertet).
- Wegen der Korrelation der Klick-Typen lässt sich mit diesem Ansatz nicht robust bestimmen, welches einzelne Material für das Bestehen am wichtigsten ist; dafür wäre ein anderes Design nötig (z. B. Regularisierung wie Lasso, oder eine zeitliche Abfolge der Materialnutzung).

## Ausblick

Weitere offene Fragen: Region und weitere `student_info`-Merkmale ins Modell aufnehmen; Konsistenz des Bestehens über einzelne Prüfungen; Bestehensquote nach Region.

## Dateien

`OULAD_1_aufbau.sql` (Setup, Audit, Bereinigung, Schlüssel) · `OULAD_2_analysis.sql` (Analyse, Views, Techniken, Export-Abfragen für die Regression) · `oulad_er_diagramm.png` · `oulad_zentrumsbericht.csv` (21.943 Zeilen) · `oulad_klicks_frueh.csv` (Klicks erste 4 Wochen, für M3) · `oulad_klicks_typ.csv` (Klicks je Materialtyp, für M4) · `oulad_regression.py` (Python-Skript, alle vier Modelle) · `oulad_datenwoerterbuch_final.md` · `oulad_modulauswahl_final.md`
