# OULAD — Datenwörterbuch

## 📖 Was ist OULAD?

Das **Open University Learning Analytics Dataset (OULAD)** enthält anonymisierte Daten von Studierenden der britischen Open University — einer Fernuniversität mit reinem Online-/Fernstudienbetrieb. Erfasst werden Kursbelegungen, Interaktionen mit der Lernplattform (VLE) und Prüfungsergebnisse für 7 ausgewählte Kursmodule.

**Quelle:** Kuzilek, J., Hlosta, M., Zdrahal, Z. (2017). *Open University Learning Analytics dataset*. Scientific Data 4, 170171.
Offizielle Seite: https://analyse.kmi.open.ac.uk/open_dataset

### Ablauf eines Kursdurchlaufs (am Beispiel `2013J`)

```
2013J (Start: Oktober 2013 – Ende: ca. Juni 2014)
├── Woche 1–30: Studierende nutzen VLE-Material laufend (studentVle)
├── Zwischendurch: mehrere TMAs/CMAs fällig (assessments, mit eigenem date-Feld)
├── Am Ende: die Abschlussprüfung (ebenfalls ein Eintrag in assessments)
└── Endergebnis: final_result in studentInfo (Distinction / Pass / Fail / Withdrawn)
```

Ein Kursmodul (`code_module`, z.B. "DDD") wird nicht nur einmal angeboten, sondern in mehreren solcher Durchläufe wiederholt — jeder Durchlauf ist eine eigene `code_presentation` (z.B. `2013J`, `2014B`). Die Tabellen sind über `id_student`, `id_assessment`, `id_site` sowie die Kombination `code_module + code_presentation` miteinander verknüpft.

### Warum das für die Datenanalyse relevant ist

Jede Interaktion einer/eines Studierenden mit dem Kurs — jeder Klick, jede Abgabe, jede An-/Abmeldung — erzeugt einen strukturierten, zeitbezogenen Datensatz. Dieses Projekt nutzt diese Aufzeichnungen, um Fragen zu Lernverhalten, Erfolg und Chancengleichheit (z.B. nach sozioökonomischem Hintergrund oder Behinderungsstatus) zu beantworten.

---

## 📚 Referenzübersicht — Die 7 Tabellen

---

## 1. `courses`
*Eine Zeile = ein Kursmodul zu einem bestimmten Semestertermin*

| Spalte | Bedeutung | Werte/Format |
|---|---|---|
| `code_module` | Kurs-/Modulkennung | 7 Codes: AAA, BBB, CCC, DDD, EEE, FFF, GGG |
| `code_presentation` | Kennung des **gesamten Semesterdurchlaufs** dieses Moduls (nicht ein einzelner Prüfungstermin!) — bezeichnet den kompletten Zeitraum von Semesterstart bis Abschlussprüfung, typischerweise mehrere Monate | Jahr + B/J (z.B. `2013J` = Durchlauf beginnend im Oktober 2013, `2014B` = Durchlauf beginnend im Februar 2014) |
| `module_presentation_length` | Länge der Präsentation in Tagen | Ganzzahl |

**Hinweis zu den Modulen:** Die Modulnamen sind im Datensatz durch bedeutungslose Kürzel ersetzt (Anonymisierung), die Kursinhalte sind daher unbekannt. Laut Datensatzbeschreibung (Kuzilek et al., 2017) gehören AAA, BBB und GGG zu den Sozialwissenschaften und CCC, DDD, EEE und FFF zu den MINT-Fächern (STEM). In der Publikation steht diese Zuordnung in Tabelle 1; sie ist in den CSV-Dateien selbst nicht enthalten.

---

## 2. `assessments`
*Eine Zeile = eine einzelne Prüfung/Aufgabe innerhalb eines Kursmoduls*

| Spalte | Bedeutung | Werte/Format |
|---|---|---|
| `code_module` | Kurs-/Modulkennung (FK zu `courses`) | siehe oben |
| `code_presentation` | Semestertermin (FK zu `courses`) | siehe oben |
| `id_assessment` | Eindeutige ID der Prüfung (PK) | Ganzzahl |
| `assessment_type` | Art der Prüfung | TMA (Tutor-bewertete Einsendeaufgabe), CMA (automatisch bewerteter Test), Exam (Abschlussprüfung) |
| `date` | Fälligkeitstag, Tage seit Semesterstart (Tag 0 = Beginn) | Ganzzahl, **kann fehlen** (v.a. bei Exam; laut offizieller Beschreibung liegt der Termin dann am Ende der letzten Präsentationswoche) |
| `weight` | Gewichtung an der Gesamtnote, in % | 0–100; alle TMA/CMA einer Präsentation summieren sich auf 100%, Exam separat oft 100% |

---

## 3. `vle` (Virtual Learning Environment — Lernplattform-Materialien)
*Eine Zeile = ein einzelnes Lernmaterial/eine Seite auf der Plattform*

| Spalte | Bedeutung | Werte/Format |
|---|---|---|
| `id_site` | Eindeutige ID des Materials (PK) | Ganzzahl |
| `code_module` | Kurs-/Modulkennung (FK zu `courses`) | siehe oben |
| `code_presentation` | Semestertermin (FK zu `courses`) | siehe oben |
| `activity_type` | Materialtyp | u.a. resource, oucontent, url, forumng, quiz, subpage, homepage, glossary |
| `week_from` | Woche, ab der das Material genutzt werden soll | Ganzzahl, bei manchen Typen leer (z.B. forumng, oucollaborate: nicht an eine feste Woche gebunden) |
| `week_to` | Woche, bis zu der das Material genutzt werden soll | Ganzzahl, bei manchen Typen leer |

**Hinweis zu `activity_type`:** Die offizielle Beschreibung definiert die Typen nicht einzeln, sie nennt `activity_type` nur "the role associated with the module material". Die folgenden Erklärungen sind daher eine **Lesart**, nicht offiziell dokumentiert:

| Typ | Lesart |
|---|---|
| `oucontent` | Inhalte der Open University, d.h. die interaktiven Lernseiten des Kurses |
| `forumng` | Diskussionsforum ("Forum Next Generation", das Forensystem der Plattform) |
| `homepage` | vermutlich die Startseite des Moduls (Vermutung, aus der Nutzung abgeleitet: fast alle Studierenden klicken sie) |

---

## 4. `studentInfo`
*Eine Zeile = ein/e Studierende/r in einem bestimmten Kursmodul-Durchlauf*

| Spalte | Bedeutung | Werte/Format |
|---|---|---|
| `code_module` | Kurs-/Modulkennung (FK zu `courses`) | siehe oben |
| `code_presentation` | Semestertermin (FK zu `courses`) | siehe oben |
| `id_student` | Eindeutige Studierenden-ID | Ganzzahl |
| `gender` | Geschlecht | M / F |
| `region` | Wohnregion während des Kurses | diverse UK-Regionen |
| `highest_education` | Höchster Bildungsabschluss bei Kursbeginn | u.a. No Formal quals, Lower Than A Level, A Level or Equivalent, HE Qualification, Post Graduate Qualification |
| `imd_band` | Index of Multiple Deprivation (SES-Proxy der Wohngegend) | Bänder in %-Schritten, z.B. 0-10%, 10-20% ... 90-100% |
| `age_band` | Altersband | 0-35, 35-55, 55<= |
| `num_of_prev_attempts` | Anzahl vorheriger Versuche dieses Moduls | Ganzzahl |
| `studied_credits` | Gesamtzahl aktuell belegter Credits | Ganzzahl |
| `disability` | Behinderung angegeben | Y / N |
| `final_result` | Endergebnis im Modul | Distinction, Pass, Fail, Withdrawn |

---

## 5. `studentRegistration`
*Eine Zeile = die An-/Abmeldung eines/einer Studierenden zu einem Kursmodul-Durchlauf*

| Spalte | Bedeutung | Werte/Format |
|---|---|---|
| `code_module` | Kurs-/Modulkennung (FK zu `courses`) | siehe oben |
| `code_presentation` | Semestertermin (FK zu `courses`) | siehe oben |
| `id_student` | Studierenden-ID (FK zu `studentInfo`) | Ganzzahl |
| `date_registration` | Anmeldedatum, Tage relativ zu Semesterstart | Ganzzahl (negativ = vor Semesterstart, z.B. -30) |
| `date_unregistration` | Abmeldedatum, Tage relativ zu Semesterstart | Ganzzahl, **leer wenn abgeschlossen**; nur befüllt, wenn `final_result = Withdrawn` |

---

## 6. `studentAssessment`
*Eine Zeile = die Abgabe eines/einer Studierenden zu einer bestimmten Prüfung*

| Spalte | Bedeutung | Werte/Format |
|---|---|---|
| `id_assessment` | Prüfungs-ID (FK zu `assessments`) | Ganzzahl |
| `id_student` | Studierenden-ID (FK zu `studentInfo`) | Ganzzahl |
| `date_submitted` | Abgabedatum, Tage seit Semesterstart | Ganzzahl |
| `is_banked` | Ergebnis aus vorheriger Präsentation übernommen | 0 / 1 |
| `score` | Erreichte Punktzahl | 0–100; < 40 gilt als Fail |

---

## 7. `studentVle`
*Klickaktivität eines/einer Studierenden an einem Material an einem Tag*

| Spalte | Bedeutung | Werte/Format |
|---|---|---|
| `code_module` | Kurs-/Modulkennung (FK zu `courses`) | siehe oben |
| `code_presentation` | Semestertermin (FK zu `courses`) | siehe oben |
| `id_student` | Studierenden-ID (FK zu `studentInfo`) | Ganzzahl |
| `id_site` | Material-ID (FK zu `vle`) | Ganzzahl |
| `date` | Tag der Interaktion, Tage seit Semesterstart (negativ = vor Kursbeginn) | Ganzzahl |
| `sum_click` | Anzahl Klicks in dieser Zeile auf dieses Material | Ganzzahl |

**Hinweis:** Für dieselbe Kombination aus Studierende/r, Material und Tag kommen **mehrere Zeilen** vor (z.B. dieselbe `id_site` an Tag -1 dreimal). Klicks pro Person müssen daher aufsummiert werden (`SUM(sum_click)`), und die Zahl aktiver Tage ergibt sich aus `COUNT(DISTINCT date)`, nicht aus der Zeilenzahl.

---

## Beziehungen im Überblick

```
courses (1) ─── (n) assessments
courses (1) ─── (n) vle
courses (1) ─── (n) studentInfo
courses (1) ─── (n) studentRegistration
courses (1) ─── (n) studentVle

studentInfo (1) ─── (n) studentRegistration
studentInfo (1) ─── (n) studentAssessment
studentInfo (1) ─── (n) studentVle

assessments (1) ─── (n) studentAssessment
vle (1) ─── (n) studentVle
```

**Hinweis zu `date`-Feldern:** Alle Datumsangaben im Datensatz sind **relative Tageszahlen** (Tage seit Semesterstart), keine echten Kalenderdaten — Tag 0 markiert jeweils den Start der Kurspräsentation.
