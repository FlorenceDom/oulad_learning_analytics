-- Voraussetzung: Schema cleaned aus OULAD_1_aufbau.sql (Teil 1-11)

-- ============================================================
-- TEIL 12: ANALYSEFRAGEN
-- ============================================================
-- Definitionen:
--   bestanden       = final_result IN ('Pass', 'Distinction')
--   durchgefallen   = 'Fail'
--   abgebrochen     = 'Withdrawn' (wird getrennt ausgewiesen)
--
-- Vorbehalte:
--   - score vermutlich nicht intervallskaliert 
--	   (Abstaende um die Fail-Grenze 40 bedeutsamer) 
--    -> Auswertung ueber final_result (kategorial). 
--     Mittelwert nur beschreibend im Report
--     (score_durchschnitt), nicht in Vergleichen verwendet.
--   - Subgruppengroessen vor jedem Vergleich pruefen
--   - Klicks: Zusammenhang mit Erfolg ist korrelativ, nicht kausal
--     (Motivation/Zeitbudget nicht erfasst). In C1b ohne Withdrawn
--     (Filter, nicht geloescht) und nur Klicks ab Kursbeginn (date >= 0);
--     C1a zaehlt alle Klicks inkl. Vorlauf und Withdrawn.
--   - Klicks messen Nutzungshaeufigkeit, nicht Dauer oder Qualitaet der
--     Nutzung (keine Verweilzeit im Datensatz). 
--     "Reichweite" = mindestens einmal genutzt.

-- FRAGENUEBERSICHT
-- Block A: Modulvergleich BBB / DDD / FFF (deskriptiv)
--   A1 Gruppengroesse
--   A2 Verteilung final_result
--   A3 Abbruchquote
--   A4 Demografie
--			a)imd_band b) age_band c) highest_education d) region
--   A4e (Zusatz). Zusammenhang imd_band und Vorabschluss (alle 3 Module)
--   A5 Anteil disability
-- Block B: Wer besteht?
--   B1 Bestehensquote pro Modul (Referenz, mit und ohne Abbrecher)
--   B2 Bestehensquote nach disability
--   B3 nach highest_education (Kategorien in Reihenfolge)
--   B4 nach imd_band
-- Block C: Materialnutzung
--   C1 a) Meistgenutzte activity_types 
--      b) Bestandene vs. Durchgefallene
-- Ausblick
--   D1 Logistische Regression (Python)
--   D2 Weitere Ideen: Konsistenz ueber Pruefungen, Bestehen je Pruefung,
--      Bestehensquote nach Region

-- Techniken: siehe Abschnitt TECHNIKEN am Ende

--------------------------------------------
-- Block A: Modulvergleich BBB / DDD / FFF (deskriptiv)
--------------------------------------------

-- A1. Gruppengroesse
SELECT code_module,
       COUNT(*) AS einschreibungen,
       COUNT(DISTINCT id_student) AS personen
FROM cleaned.student_info
GROUP BY code_module
ORDER BY code_module;

--> Einschreibungen > Personen (BBB 217, DDD 424, FFF 365): 
--  Wiederholer (meist nach Withdrawn/Fail). 
--  Zaehleinheit im Folgenden: Einschreibung,
--  d.h. Wiederholer zaehlen mehrfach.

SELECT code_module, id_student, COUNT(*) AS n_praesentationen
FROM cleaned.student_info
GROUP BY code_module, id_student
HAVING COUNT(*) > 1
LIMIT 10;

--> hier sieht man: Personen kommen bei einem Modul zweimal vor
--  (Wiederholer in einer weiteren Praesentation, z.B. 25629 in BBB:
--  2013J und 2014B, beide Withdrawn). Deshalb: Einschreibungen > Personen.

SELECT code_module, code_presentation, id_student,
       final_result, num_of_prev_attempts
FROM cleaned.student_info
WHERE id_student IN (25629, 27891, 34431)
  AND code_module = 'BBB'
ORDER BY id_student, code_presentation;

--> Stichprobe der Mehrfachbelegungen (BBB): 
--  Erstversuch jeweils Withdrawn, Zweitversuch Withdrawn oder Fail 
-- -> Wiederholung nach Abbruch.
--  num_of_prev_attempts kann auf fruehere Versuche vor 2013 verweisen.
--  Konsequenz: Wiederholer zaehlen mehrfach, 
--  Abbruchquote ist pro Einschreibung, nicht pro Person.

-----------------------------------------
-- A2/A3 final_result-Verteilung inkl. Abbruchquote
SELECT code_module, final_result,
       COUNT(*) AS anzahl,
       ROUND(100.0 * COUNT(*) /
             SUM(COUNT(*)) OVER (PARTITION BY code_module), 1) AS prozent
FROM cleaned.student_info
GROUP BY code_module, final_result
ORDER BY code_module, final_result;
-- --> Zeile 'Withdrawn' = Abbruchquote
-- --> 'Distinction' = besonders gutes Ergebnis, Steigerung von 'Pass'

--> Verteilung aehnlich, Fail in allen Modulen ~22%.
--  DDD faellt auf: hoechste Abbruchquote (35.9% vs. ~30-31%) 
--  und niedrigster Anteil Distinction (6.1% vs. 8.6%) 
-- -> bestanden 41.6% vs. ~47%. 
--  Unter denen, die nicht abgebrochen haben, ist der Unterschied
--  klein (~65% vs. ~68% bestanden): DDD unterscheidet sich vor allem
--  durch Abbrueche, nicht durch mehr Durchfaller.

------------------------------------------
-- A4 Demografie: gleiche Abfrage, Spalte austauschen
--    a) imd_band b) age_band c) highest_education d) region

-- Muster fuer alle "Module nebeneinander"-Abfragen (A4, B3, B4):
--   COUNT(*) FILTER (WHERE code_module = 'BBB')
--     = zaehlt nur die Zeilen von BBB (bedingte Zaehlung)
--   Eine Spalte je Modul und Kennzahl -> die Module stehen nebeneinander
--   / (SELECT COUNT(*) ... WHERE code_module = 'BBB')
--     = teilt durch die Modulgroesse -> Prozent vom ganzen Modul

--   NULLIF(x, 0) verhindert Division durch 0
--   COALESCE(imd_band, 'fehlend') zeigt NULL als Text 'fehlend'

SELECT code_module, imd_band,
       COUNT(*) AS anzahl,
       ROUND(100.0 * COUNT(*) /
             SUM(COUNT(*)) OVER (PARTITION BY code_module), 1) AS prozent
FROM cleaned.student_info
GROUP BY code_module, imd_band
ORDER BY code_module, imd_band;
-- --> NULL = fehlende IMD-Werte (siehe Audit), bewusst mit ausgewiesen

--> Output so herum schwer lesbar, Zeilen und Spalten vertauschen 
-- für besseren Gruppenvergleich auf einen Blick

-- A4a: Demografie a) imd_band, Module nebeneinander
SELECT COALESCE(imd_band, 'fehlend') AS imd_band,
       COUNT(*) FILTER (WHERE code_module = 'BBB') AS bbb_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'BBB'), 1) AS bbb_prozent,
       COUNT(*) FILTER (WHERE code_module = 'DDD') AS ddd_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'DDD'), 1) AS ddd_prozent,
       COUNT(*) FILTER (WHERE code_module = 'FFF') AS fff_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'FFF'), 1) AS fff_prozent
FROM cleaned.student_info
GROUP BY imd_band
ORDER BY 1;

--> BBB hat mehr Studierende aus stark benachteiligten Gebieten
--  (0-10%: 13.1% vs. 90-100%: 5.8%); DDD fast gleichverteilt,
--  FFF dazwischen. Fehlende IMD-Werte: BBB 0.8%, DDD 4.5%, FFF 4.7%.
--  Band '10-20' hatte im Rohdatensatz kein %-Zeichen (siehe Audit f),
--  in cleaned vereinheitlicht.

--------------------------------
-- A4b. Demografie: b) age_band, Module nebeneinander
SELECT age_band,
       COUNT(*) FILTER (WHERE code_module = 'BBB') AS bbb_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'BBB'), 1) AS bbb_prozent,
       COUNT(*) FILTER (WHERE code_module = 'DDD') AS ddd_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'DDD'), 1) AS ddd_prozent,
       COUNT(*) FILTER (WHERE code_module = 'FFF') AS fff_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'FFF'), 1) AS fff_prozent
FROM cleaned.student_info
GROUP BY age_band
ORDER BY age_band;

--> Altersstruktur aehnlich: Ueberwiegend unter 35 
--  (BBB 66.8%, DDD 74.3%, FFF 74.0%), BBB etwas aelter (35-55: 33.1% vs. ~25%).
--  Band 55+ sehr klein (BBB 8, DDD 68, FFF 28 Faelle) 
--  -> fuer Gruppenvergleiche nicht belastbar, ggf. mit 35-55 zusammenfassen.

---------------------------------
-- A4c. Demografie: c) highest_education, Module nebeneinander
SELECT highest_education,
       COUNT(*) FILTER (WHERE code_module = 'BBB') AS bbb_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'BBB'), 1) AS bbb_prozent,
       COUNT(*) FILTER (WHERE code_module = 'DDD') AS ddd_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'DDD'), 1) AS ddd_prozent,
       COUNT(*) FILTER (WHERE code_module = 'FFF') AS fff_anzahl,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'FFF'), 1) AS fff_prozent
FROM cleaned.student_info
GROUP BY highest_education
ORDER BY CASE highest_education
             WHEN 'No Formal quals' THEN 1
             WHEN 'Lower Than A Level' THEN 2
             WHEN 'A Level or Equivalent' THEN 3
             WHEN 'HE Qualification' THEN 4
             WHEN 'Post Graduate Qualification' THEN 5
         END;

--> A4c: BBB hat den hoechsten Anteil mit Abschluss unter A-Level 
--  (46.9% vs. 36.9% DDD, 43.1% FFF; No Formal quals + Lower Than A Level) 
--  und den niedrigsten Anteil mit Studium (11.6% vs. 17.1% / 14.1%). 
--  Passt zur IMD-Verteilung aus A4a (mehr Studierende aus benachteiligten Gebieten).
--  Kategorien 'No Formal quals' (50-109) und 'Post Graduate' (15-64) klein 
--  -> bei Vergleichen ggf. zusammenfassen.
--  Verdacht: niedriger IMD und niedriger Vorabschluss haengen zusammen.
--  Der Modulvergleich kann das nicht pruefen 
--  (Vergleich von Modulen, nicht von Personen) 
-- -> Zusatzabfrage A4e.

-------------------------------------
-- A4d. Demografie: d) region, Module nebeneinander (nur Prozent)
SELECT region,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'BBB'), 1) AS bbb_prozent,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'DDD'), 1) AS ddd_prozent,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF')
             / (SELECT COUNT(*) FROM cleaned.student_info
                WHERE code_module = 'FFF'), 1) AS fff_prozent
FROM cleaned.student_info
GROUP BY region
ORDER BY region;

--> A4d: Regionale Verteilung in den Modulen insgesamt aehnlich.
--  Auffaellig: Wales in BBB doppelt so haeufig (10.6% vs. ~5.7%),
--  North Region in BBB nur halb so haeufig (3.1% vs. ~6.7%).
--  Region als Einzelmerkmal hier nur deskriptiv;
--  ob sie mit dem Bestehen zusammenhaengt, wird nicht in Block A geprueft.

----------------------------------------
-- A4e (Zusatz). Zusammenhang imd_band und Vorabschluss (alle 3 Module)
SELECT imd_band,
       COUNT(*) AS anzahl,
       ROUND(100.0 * COUNT(*) FILTER (
             WHERE highest_education IN ('No Formal quals', 'Lower Than A Level'))
             / COUNT(*), 1) AS prozent_unter_a_level
FROM cleaned.student_info
WHERE imd_band IS NOT NULL
GROUP BY imd_band
ORDER BY imd_band;

--> A4e: Zusammenhang bestaetigt. Der Anteil mit Abschluss unter A-Level
--  sinkt von 51.1% (IMD 0-10%, staerkste Benachteiligung) auf 32.3%
--  (IMD 90-100%), also rund 19 Prozentpunkte Unterschied. 
--  Verlauf fast durchgehend fallend (kleine Abweichung bei 60-70% vs. 70-80%).
--  Konsequenz fuer B2/B3: 
--  IMD und Vorabschluss sind nicht unabhaengig,
--  ein Effekt in B2 kann teils ein IMD-Effekt sein und umgekehrt.
--  Vorbehalt: IMD beschreibt das Wohngebiet, nicht die Person, und
--  der Zusammenhang ist deskriptiv, nicht kausal.

---------------------------------------
-- A5. Anteil disability
SELECT code_module,
       COUNT(*) AS einschreibungen,
       COUNT(*) FILTER (WHERE disability = 'Y') AS mit_disability,
       ROUND(100.0 * COUNT(*) FILTER (WHERE disability = 'Y')
             / COUNT(*), 1) AS prozent_disability
FROM cleaned.student_info
GROUP BY code_module
ORDER BY code_module;

--> A5: Anteil mit disability: BBB 9.4%, DDD 11.8%, FFF 9.5%.
--  Absolute Zahlen fast identisch (742 / 741 / 735); 
--  der hoehere Anteil in DDD entsteht durch die geringere Modulgroesse.
--  Alle drei Gruppen gross genug fuer Subgruppenvergleiche (B2).
--  Modulinhalte sind im Datensatz anonymisiert, inhaltliche Deutung
--  der Unterschiede daher nur begrenzt moeglich.


-- ------------------------------------------------------------
-- BLOCK B: WER BESTEHT?
-- ------------------------------------------------------------

--   B1 Bestehensquote pro Modul (Referenz, mit und ohne Abbrecher)
--   B2 Bestehensquote nach disability
--   B3 nach highest_education (Kategorien in Reihenfolge)
--   B4 nach imd_band

-----------------------------------
-- B1. Bestehensquote pro Modul (bestanden = Pass + Distinction)
SELECT code_module,
       COUNT(*) AS einschreibungen,
       ROUND(100.0 * COUNT(*) FILTER (WHERE final_result IN ('Pass','Distinction'))
             / COUNT(*), 1) AS bestanden_alle_prozent,
       COUNT(*) FILTER (WHERE final_result <> 'Withdrawn') AS ohne_abbrecher,
       ROUND(100.0 * COUNT(*) FILTER (WHERE final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE final_result <> 'Withdrawn'), 0), 1)
             AS bestanden_ohne_abbrecher_prozent
FROM cleaned.student_info
GROUP BY code_module
ORDER BY code_module;

--> B1: Bestehensquote (Pass + Distinction) ueber alle Einschreibungen:
--  BBB 47.5%, DDD 41.6%, FFF 47.0%. 
--  Ohne Abbrecher: BBB 68.0%, DDD 64.9%, FFF 68.1%. 
--  Der Abstand von DDD schrumpft von ~6 auf ~3 Prozentpunkte 
--  -> der Unterschied entsteht ueberwiegend durch Abbrueche, 
--  nicht durch mehr Durchfaller (bestaetigt A2/A3).
--  Diese Werte dienen als Referenz fuer B2 bis B4.

--------------------------------------
-- B2. Bestehensquote nach disability (bestanden = Pass + Distinction)
SELECT code_module,
       disability,
       COUNT(*) AS einschreibungen,
       ROUND(100.0 * COUNT(*) FILTER (WHERE final_result IN ('Pass','Distinction'))
             / COUNT(*), 1) AS bestanden_alle_prozent,
       COUNT(*) FILTER (WHERE final_result <> 'Withdrawn') AS ohne_abbrecher,
       ROUND(100.0 * COUNT(*) FILTER (WHERE final_result = 'Withdrawn') / COUNT(*), 1) AS abbruch_prozent,
       ROUND(100.0 * COUNT(*) FILTER (WHERE final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE final_result <> 'Withdrawn'), 0), 1)
             AS bestanden_ohne_abbrecher_prozent
FROM cleaned.student_info
GROUP BY code_module, disability
ORDER BY code_module, disability;


--> B2: In allen Modulen liegt die Bestehensquote mit disability niedriger
--  (alle Einschreibungen: BBB 38.5% vs. 48.4%, DDD 31.7% vs. 42.9%,
--  FFF 35.4% vs. 48.2%; Differenz 10-13 Prozentpunkte).
--  Ohne Abbrecher kleinerer Abstand (BBB 8.6, DDD 4.3, FFF 6.7 Punkte):
--  der Unterschied entsteht ueberwiegend durch Abbrueche
--  (Abbruchquote mit disability: BBB 35.8%, DDD 48.0%, FFF 42.9%;
--  ohne: 29.6% / 34.2% / 29.7%, siehe Spalte abbruch_prozent).
--  Gruppen gross genug (>= 385 Faelle je Gruppe ohne Abbrecher).
--  Deskriptiv, nicht kausal: kein Signifikanztest, moegliche
--  Zusammenhaenge mit anderen Merkmalen nicht kontrolliert (-> D1).

------------------------------------------
-- B3. Bestehensquote nach highest_education, Module nebeneinander
-- alle = alle Einschreibungen, ohne = ohne Abbrecher
SELECT highest_education,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'BBB'), 0), 1) AS bbb_alle,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'BBB'
                 AND final_result <> 'Withdrawn'), 0), 1) AS bbb_ohne,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'DDD'), 0), 1) AS ddd_alle,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'DDD'
                 AND final_result <> 'Withdrawn'), 0), 1) AS ddd_ohne,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'FFF'), 0), 1) AS fff_alle,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'FFF'
                 AND final_result <> 'Withdrawn'), 0), 1) AS fff_ohne
FROM cleaned.student_info
GROUP BY highest_education
ORDER BY CASE highest_education
             WHEN 'No Formal quals' THEN 1
             WHEN 'Lower Than A Level' THEN 2
             WHEN 'A Level or Equivalent' THEN 3
             WHEN 'HE Qualification' THEN 4
             WHEN 'Post Graduate Qualification' THEN 5
         END;

--> B3: In allen Modulen steigt die Bestehensquote mit dem Vorabschluss.
--  Ohne Abbrecher: Lower Than A Level 58.8 / 53.0 / 59.8%, 
--  A Level:  74.5 / 69.0 / 72.4%, HE: 77.1 / 74.7 / 77.2% (BBB / DDD / FFF).
--  Groesster Sprung zwischen Lower Than A Level und A Level (13-16 Punkte).
--  Abstand mit und ohne Abbrecher aehnlich (~15 Punkte): 
--  der Unterschied besteht auch bei denen, die durchgehalten haben.
--  'No Formal quals' (23-59 Faelle ohne Abbrecher) und 'Post Graduate'
--  (14-49) zu klein fuer belastbare Aussagen.
--  Vorbehalt: Vorabschluss haengt mit IMD zusammen (A4e), 
--  Effekte nicht getrennt -> D1 (log. Regression).

-------------------------------------
-- B4. Bestehensquote nach imd_band, Module nebeneinander
-- alle = alle Einschreibungen, ohne = ohne Abbrecher
SELECT COALESCE(imd_band, 'fehlend') AS imd_band,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'BBB'), 0), 1) AS bbb_alle,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'BBB'
                 AND final_result <> 'Withdrawn'), 0), 1) AS bbb_ohne,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'DDD'), 0), 1) AS ddd_alle,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'DDD'
                 AND final_result <> 'Withdrawn'), 0), 1) AS ddd_ohne,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'FFF'), 0), 1) AS fff_alle,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF'
                 AND final_result IN ('Pass','Distinction'))
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'FFF'
                 AND final_result <> 'Withdrawn'), 0), 1) AS fff_ohne
FROM cleaned.student_info
GROUP BY imd_band
ORDER BY imd_band NULLS LAST;

--> B4: In allen Modulen steigt die Bestehensquote mit dem IMD-Band
--  0-10% -> 90-100%, alle Einschreibungen:
--  BBB 34.0 -> 61.5%, DDD 31.1 -> 51.7%, FFF 32.9 -> 56.9%.
--  Ohne Abbrecher bleibt der Gradient in BBB und FFF aehnlich gross
--  (29.5 / 22.7 Punkte), in DDD ist er kleiner (16.7 vs. 20.6 Punkte):
--  dort entsteht der Unterschied staerker ueber Abbrueche (siehe Zusatz).
--  Einzelne Spruenge (z.B. DDD 10-20%) bei ~500-700 Faellen pro Zelle
--  im Rahmen des Zufalls, nicht gedeutet.
--  Deskriptiv, nicht kausal; IMD und Vorabschluss haengen zusammen
--  (A4e) -> D1.

---------------------------------------
-- B4 (Zusatz). Abbruchquote nach imd_band, Module nebeneinander
SELECT COALESCE(imd_band, 'fehlend') AS imd_band,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'BBB'
                 AND final_result = 'Withdrawn')
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'BBB'), 0), 1) AS bbb_abbruch,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'DDD'
                 AND final_result = 'Withdrawn')
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'DDD'), 0), 1) AS ddd_abbruch,
       ROUND(100.0 * COUNT(*) FILTER (WHERE code_module = 'FFF'
                 AND final_result = 'Withdrawn')
             / NULLIF(COUNT(*) FILTER (WHERE code_module = 'FFF'), 0), 1) AS fff_abbruch
FROM cleaned.student_info
GROUP BY imd_band
ORDER BY imd_band NULLS LAST;

--> B4 (Zusatz): Abbruchquote sinkt mit dem IMD-Band in allen Modulen
--  (0-10% -> 90-100%: BBB 35.9 -> 25.5%, DDD 43.2 -> 27.7%,
--  FFF 39.1 -> 25.8%). Staerkster Gradient in DDD.
--  Fehlende IMD-Werte (n = 63 / 280 / 367): niedrigste Abbruchquote
--  (18.5-22.5%) und hoechste Bestehensquote aller Gruppen 
--  -> unterscheiden sich vom Rest, fehlen also vermutlich nicht zufaellig 
--  (Ursache unbekannt).
--  Gruppe klein, daher nicht ueberinterpretieren.

-- ------------------------------------------------------------
-- BLOCK C: MATERIALNUTZUNG
-- ------------------------------------------------------------

-- C1a. Meistgenutzte activity_types pro Modul (Top 5 nach Gesamtklicks)
-- Zwei Kennzahlen:
--   klick_anteil_prozent = Anteil an allen Klicks im Modul (Klickaufkommen)
--   nutzende_prozent     = Anteil der Einschreibungen, die den Typ
--                          mindestens einmal geklickt haben (=Reichweite)
-- Basis: alle Einschreibungen inkl. Withdrawn
-- zaehlt alle Klicks, auch vor Kursbeginn

-- Schritt 1: Klicks pro Person (Einschreibung) und Materialtyp
WITH nutzung AS (
    SELECT sv.code_module, sv.code_presentation, sv.id_student,
           v.activity_type, SUM(sv.sum_click) AS klicks
    FROM cleaned.student_vle sv
    JOIN cleaned.vle v ON v.id_site = sv.id_site      -- holt activity_type
    GROUP BY 1, 2, 3, 4
),
-- Schritt 2: pro Modul und Typ: Gesamtklicks und Anzahl Nutzende
pro_typ AS (
    SELECT code_module, activity_type,
           SUM(klicks) AS gesamtklicks,
           COUNT(*) AS nutzende          -- eine Zeile je Person -> Personen
    FROM nutzung
    GROUP BY 1, 2
),
-- Schritt 3: Modulgroesse (Nenner fuer nutzende_prozent)
gruppe AS (
    SELECT code_module, COUNT(*) AS einschreibungen
    FROM cleaned.student_info
    GROUP BY 1
),
-- Schritt 4: Prozente und Rangfolge (Window Functions)
ranking AS (
    SELECT p.code_module, p.activity_type, p.gesamtklicks,
           -- Anteil an allen Klicks des Moduls
           ROUND(100.0 * p.gesamtklicks
                 / SUM(p.gesamtklicks) OVER (PARTITION BY p.code_module), 1)
                 AS klick_anteil_prozent,
           ROUND(100.0 * p.nutzende / g.einschreibungen, 1) AS nutzende_prozent,
           -- Rang 1 = meiste Klicks, Zaehlung neu je Modul
           ROW_NUMBER() OVER (PARTITION BY p.code_module
                              ORDER BY p.gesamtklicks DESC) AS rang
    FROM pro_typ p
    JOIN gruppe g USING (code_module)
)
SELECT *
FROM ranking
WHERE rang <= 5          -- nur die fuenf meistgenutzten je Modul
ORDER BY code_module, rang;


--> C1a: Meistgenutzte Typen unterscheiden sich nach Modul:
--  BBB und DDD vor allem forumng und homepage
--  (BBB Forum 40.3% der Klicks, 73.3% Reichweite),
--  FFF vor allem oucontent (37.3% der Klicks, 89.5% Reichweite)
--  und quiz (21.8%).
--  homepage: in allen Modulen hoechste Reichweite der Top 5
--  (83.5 / 91.5 / 91.3%), bei Rang 2-3 im Klickaufkommen
--  -> von fast allen genutzt (vermutlich Einstiegsseite).
--  FFF hat gut dreimal so viele Klicks pro Einschreibung wie BBB
--  (Durchschnitt ab Kursbeginn: BBB 629, DDD 804, FFF 2163, siehe
--  Materialized View) -> absolute Klickzahlen zwischen Modulen
--  nicht direkt vergleichbar.
--  quiz: Klicks erhoehen sich vermutlich schon durch das Ablegen von
--  Pruefungen/Tests -> Zusammenhang mit Bestehen nicht gedeutet.

-------------------------------------
-- C1b. Durchschnittliche Klicks pro Materialtyp: 
-- Bestandene vs. Durchgefallene
-- Basis: nur Einschreibungen, die den Typ mindestens einmal genutzt haben;
-- ohne Withdrawn; nur Klicks ab Kursbeginn (date >= 0)
-- Schritt 1: Klicks pro Person (Einschreibung) und Materialtyp

WITH nutzung AS (
    SELECT sv.code_module, sv.code_presentation, sv.id_student,
           v.activity_type,
           SUM(sv.sum_click) AS klicks          -- Summe ueber alle Tage/Seiten
    FROM cleaned.student_vle sv
    JOIN cleaned.vle v ON v.id_site = sv.id_site   -- holt activity_type
    WHERE sv.date >= 0                          -- nur ab Kursbeginn
    GROUP BY 1, 2, 3, 4
)
-- Schritt 2: Durchschnitt dieser Personen-Summen je Gruppe
SELECT n.code_module, n.activity_type,
       -- Durchschnitt nur ueber Pass + Distinction
       ROUND(AVG(n.klicks) FILTER (WHERE si.final_result IN ('Pass','Distinction')), 1)
           AS klicks_bestanden,
       -- Durchschnitt nur ueber Fail
       ROUND(AVG(n.klicks) FILTER (WHERE si.final_result = 'Fail'), 1)
           AS klicks_durchgefallen,
       -- Verhaeltnis: wie viel mehr klicken die Bestandenen?
       ROUND(AVG(n.klicks) FILTER (WHERE si.final_result IN ('Pass','Distinction'))
           / AVG(n.klicks) FILTER (WHERE si.final_result = 'Fail'), 2) AS verhaeltnis
FROM nutzung n
JOIN cleaned.student_info si                    -- holt final_result
  ON  si.code_module = n.code_module
  AND si.code_presentation = n.code_presentation
  AND si.id_student = n.id_student
WHERE si.final_result <> 'Withdrawn'            -- Abbrecher ausgeschlossen
  AND n.activity_type IN ('forumng','homepage','oucontent','quiz','subpage','resource')
GROUP BY n.code_module, n.activity_type
ORDER BY n.code_module, verhaeltnis DESC;

--> C1b: In allen Modulen und bei allen Materialtypen klicken Bestandene
--  im Schnitt mehr als Durchgefallene (Verhaeltnis 1.5 bis 3.5).
--  Groesstes Verhaeltnis: 
--  oucontent in BBB (3.48) und FFF (3.45), forumng in DDD (3.03). 
--  Kleinstes Verhaeltnis: oucontent in DDD (1.47).
--  Basis: Einschreibungen ohne Withdrawn, die den Typ mind. einmal
--  genutzt haben; Klicks ab Kursbeginn; Durchschnitt pro Person.
--  Korrelativ, nicht kausal: wer besteht, ist vermutlich insgesamt
--  aktiver (Motivation, Zeit nicht erfasst). 
--  Da alle Typen hoehere Werte zeigen, unterscheidet sich vor allem die Gesamtaktivitaet;
--  Unterschiede zwischen den Typen sind deshalb nur vorsichtig zu deuten.
--  quiz: Klicks erhoehen sich vermutlich schon durch das Ablegen von
--  Pruefungen/Tests -> Zusammenhang mit Bestehen nicht gedeutet.


-- ============================================================
-- VIEWS & MATERIALIZED VIEWS
-- ============================================================


CREATE SCHEMA IF NOT EXISTS analytics;

-- Reihenfolge wichtig: erst die Materialized View loeschen (haengt vom
-- View ab), dann den View. Kann beliebig oft ausgefuehrt werden.
DROP MATERIALIZED VIEW IF EXISTS analytics.mv_zentrumsbericht;
DROP VIEW IF EXISTS analytics.v_zentrumsbericht;

-- View: eine Zeile pro Einschreibung (Zentrumsbericht)
CREATE VIEW analytics.v_zentrumsbericht AS
-- Schritt 1: Klicks pro Einschreibung (nur ab Kursbeginn)
WITH klicks AS (
    SELECT code_module, code_presentation, id_student,
           SUM(sum_click)       AS klicks_gesamt,
           COUNT(DISTINCT date) AS aktive_tage    -- Tage, nicht Zeilen
    FROM cleaned.student_vle
    WHERE date >= 0
    GROUP BY 1, 2, 3
),
-- Schritt 2: Pruefungsabgaben pro Einschreibung
-- (student_assessment hat kein code_module -> Join ueber assessments)
pruefungen AS (
    SELECT a.code_module, a.code_presentation, sa.id_student,
           COUNT(*)                AS abgaben,
           ROUND(AVG(sa.score), 1) AS score_durchschnitt
    FROM cleaned.student_assessment sa
    JOIN cleaned.assessments a ON a.id_assessment = sa.id_assessment
    GROUP BY 1, 2, 3
),
-- Schritt 3: alles an student_info haengen (LEFT JOIN: niemand geht verloren)
basis AS (
    SELECT si.id_student, si.code_module, si.code_presentation,
       si.gender, si.age_band, si.imd_band, si.highest_education,
       si.disability, si.final_result,
           CASE WHEN si.final_result IN ('Pass','Distinction')
                THEN 1 ELSE 0 END          AS bestanden,
           COALESCE(k.klicks_gesamt, 0)    AS klicks_gesamt,
           COALESCE(k.aktive_tage, 0)      AS aktive_tage,
           COALESCE(p.abgaben, 0)          AS abgaben,
           p.score_durchschnitt
    FROM cleaned.student_info si
    LEFT JOIN klicks k
      ON  k.code_module = si.code_module
      AND k.code_presentation = si.code_presentation
      AND k.id_student = si.id_student
    LEFT JOIN pruefungen p
      ON  p.code_module = si.code_module
      AND p.code_presentation = si.code_presentation
      AND p.id_student = si.id_student
)
-- Schritt 4: Window Function: Abstand zum Klick-Durchschnitt des Moduls
SELECT b.*,
       ROUND(b.klicks_gesamt
             - AVG(b.klicks_gesamt) OVER (PARTITION BY b.code_module), 1)
             AS klicks_diff_vom_modulschnitt
FROM basis b;


-- Zeilenzahl muss cleaned.student_info entsprechen (7909 / 6272 / 7762)
SELECT code_module, COUNT(*) AS zeilen,
       COUNT(*) FILTER (WHERE klicks_gesamt = 0) AS ohne_klicks
FROM analytics.v_zentrumsbericht
GROUP BY code_module ORDER BY code_module;

-- Stichprobe
SELECT * FROM analytics.v_zentrumsbericht LIMIT 10;

-------------------------------------------
-- Materialized View: speichert das Ergebnis des Views als echte Tabelle
-------------------------------------------

-- (wird beim Anlegen einmal berechnet, danach sofort abrufbar)
DROP MATERIALIZED VIEW IF EXISTS analytics.mv_zentrumsbericht;
CREATE MATERIALIZED VIEW analytics.mv_zentrumsbericht AS
SELECT * FROM analytics.v_zentrumsbericht;

-- Index: eine Zeile je Einschreibung (Schluessel wie in student_info)
CREATE UNIQUE INDEX idx_mv_zentrumsbericht
    ON analytics.mv_zentrumsbericht (code_module, code_presentation, id_student);

-- Aktualisieren, falls sich cleaned-Daten aendern (hier nicht noetig,
-- weil die Daten statisch sind):
-- REFRESH MATERIALIZED VIEW analytics.mv_zentrumsbericht;

-- Zeilenzahl muss dem View entsprechen (7909 / 6272 / 7762)
SELECT code_module, COUNT(*) AS zeilen
FROM analytics.mv_zentrumsbericht
GROUP BY code_module ORDER BY code_module;
--> passt

-- Geschwindigkeit: 
-- Abfrage 1: auf dem View
SELECT code_module, ROUND(AVG(klicks_gesamt), 1) AS klicks_schnitt
FROM analytics.v_zentrumsbericht GROUP BY code_module;

-- Abfrage 2: auf der Materialized View
SELECT code_module, ROUND(AVG(klicks_gesamt), 1) AS klicks_schnitt
FROM analytics.mv_zentrumsbericht GROUP BY code_module;

--> Abfrage 1 View 0.824 s (rechnet bei jedem Aufruf neu ueber student_vle),
--  Abfrage 2 Materialized View 0.01 s (gespeichertes Ergebnis), gleiche Werte
--  (BBB 629.4, DDD 804.4, FFF 2162.7).
--  Nachteil der Materialized View: nicht automatisch aktuell, bei
--  Aenderungen in cleaned ist ein REFRESH noetig (hier nicht noetig,
--  Daten sind statisch).

-- Kontrolle: Zeilen, die im View, aber nicht in der Materialized View stehen
-- (und umgekehrt). Erwartet: 0 und 0
SELECT COUNT(*) AS nur_im_view
FROM (SELECT * FROM analytics.v_zentrumsbericht
      EXCEPT
      SELECT * FROM analytics.mv_zentrumsbericht) t;

SELECT COUNT(*) AS nur_in_mv
FROM (SELECT * FROM analytics.mv_zentrumsbericht
      EXCEPT
      SELECT * FROM analytics.v_zentrumsbericht) t;

--> Kontrolle EXCEPT: 0 Zeilen in beide Richtungen -> Materialized View
--  ist inhaltlich identisch mit dem View.

-- ============================================================
-- WINDOW FUNCTIONS
-- ============================================================
-- Im Projekt verwendet. PARTITION BY code_module = die Berechnung
-- laeuft getrennt je Modul, die Zeilen bleiben einzeln erhalten.
--
--   A2/A3, C1a:  SUM(...) OVER (PARTITION BY code_module)
--                -> Prozentanteil an der Modulsumme

--   C1a:         ROW_NUMBER() OVER (PARTITION BY code_module ORDER BY ...)
--                -> Rangfolge der Materialtypen je Modul

--   VIEWS:       AVG(...) OVER (PARTITION BY code_module)
--                -> Abstand zum Modulschnitt (v_zentrumsbericht)


-- ------------------------------------------------------------
-- TECHNIKEN (abgehakt, mit Fundstelle)
-- ------------------------------------------------------------
--   [x] Analytics-Schema: Schema "analytics" mit v_zentrumsbericht und
--       mv_zentrumsbericht (Abschnitt Views & Materialized Views)
--   [x] View: analytics.v_zentrumsbericht, eine Zeile pro Einschreibung
--       (Klicks, Pruefungsabgaben, Demografie, Ergebnis)
--   [x] Materialized View: analytics.mv_zentrumsbericht mit UNIQUE INDEX;
--       0.01 s statt 0.824 s beim View
--   [x] Window Functions (drei Formen, je PARTITION BY code_module):
--       SUM() OVER      -> A2/A3, C1a (Prozentanteile)
--       ROW_NUMBER() OVER -> C1a (Rangfolge)
--       AVG() OVER      -> v_zentrumsbericht (Abstand zum Modulschnitt)
--   Weitere: CTEs (C1a, C1b, View), JOIN/LEFT JOIN (C1a, C1b, View),
--   CASE WHEN (A4c, B3, View), FILTER, COALESCE, NULLIF (A4 bis B4)

-- ------------------------------------------------------------
-- AUSBLICK (nicht Teil des 2-Tage-Projekts)
-- ------------------------------------------------------------
--   D1. Was sagt Bestehen (bzw. Score > 70) am besten voraus?
--       Logistische Regression in Python (statsmodels) auf Basis von
--       analytics.mv_zentrumsbericht 
--       (IMD, Bildung, Alter, disability, Gesamtklicks). 
--       Region und Klicks je Materialtyp muessten dafuer ergaenzt werden.

-- Tabelle erstellen für: Klicks nur aus den ersten vier Wochen.
SELECT code_module, code_presentation, id_student,
       SUM(sum_click) AS klicks_frueh
FROM cleaned.student_vle
WHERE date BETWEEN 0 AND 27
GROUP BY code_module, code_presentation, id_student;

-- Klicks pro Materialtyp und Einschreibung (fuer Python-Regression, Modell 4)
-- gleiche 6 Typen wie in C1a/C1b, ab Kursbeginn (date >= 0)
SELECT sv.code_module, sv.code_presentation, sv.id_student,
       v.activity_type,
       SUM(sv.sum_click) AS klicks
FROM cleaned.student_vle sv
JOIN cleaned.vle v ON v.id_site = sv.id_site
WHERE sv.date >= 0
  AND v.activity_type IN ('forumng','homepage','oucontent','quiz','subpage','resource')
GROUP BY sv.code_module, sv.code_presentation, sv.id_student, v.activity_type;

-- ============================================================
-- EXPORT
-- ============================================================
-- Abgabe-Paket:
--   OULAD_1_aufbau.sql       Teil 1-11 (Setup, Audit, Clean, FKs), eigene Datei
--   OULAD_2_analysis.sql     diese Datei (Teil 12: Analyse, Views, Techniken)
--   oulad_er_diagramm.png    ER-Diagramm cleaned-Schema
--
--   [x] oulad_zentrumsbericht.csv
--       analytics.mv_zentrumsbericht, 21.943 Zeilen 
--       (eine je Einschreibung: BBB 7.909, DDD 6.272, FFF 7.762). 
--       Grundlage fuer D1 (Python).
--   [x] oulad_klicks_frueh.csv   (Regression Modell 3)
--   [x] oulad_klicks_typ.csv     (Regression Modell 4b)
--   [x] Datenbank-Backup (nur lokal, ca. 235 MB, nicht Teil der Abgabe)
--
-- Neuaufbau in leerer Datenbank OULAD: erst Skript 1 von oben nach unten
-- (CSV-Pfad in Teil 3 anpassen), dann diese Datei.