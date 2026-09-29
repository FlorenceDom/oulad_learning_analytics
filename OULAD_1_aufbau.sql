-- ================================
-- OULAD Teil 1: Aufbau (Setup, Audit, Clean, FKs)
-- ================================
-- Nur in leerer Datenbank ausfuehren, nicht erneut: CREATE SCHEMA/TABLE
-- schlagen beim zweiten Lauf fehl, und COPY wuerde die raw-Daten verdoppeln.
-- Skript 2 (OULAD_2_analysis.sql) baut auf dem Schema cleaned auf.

CREATE SCHEMA raw;


-- ============================================================
-- TEIL 2: RAW SCHEMA — TABELLEN ANLEGEN (alles TEXT)
-- ============================================================
-- 7 Tabellen: courses, assessments, vle, studentInfo,
-- studentRegistration, studentAssessment, studentVle

CREATE TABLE raw.courses (
    code_module TEXT,
    code_presentation TEXT,
    module_presentation_length TEXT
);

CREATE TABLE raw.assessments (
    code_module TEXT,
    code_presentation TEXT,
    id_assessment TEXT,
    assessment_type TEXT,
    date TEXT,
    weight TEXT
);

CREATE TABLE raw.vle (
    id_site TEXT,
    code_module TEXT,
    code_presentation TEXT,
    activity_type TEXT,
    week_from TEXT,
    week_to TEXT
);

CREATE TABLE raw.studentInfo (
    code_module TEXT,
    code_presentation TEXT,
    id_student TEXT,
    gender TEXT,
    region TEXT,
    highest_education TEXT,
    imd_band TEXT,
    age_band TEXT,
    num_of_prev_attempts TEXT,
    studied_credits TEXT,
    disability TEXT,
    final_result TEXT
);

CREATE TABLE raw.studentRegistration (
    code_module TEXT,
    code_presentation TEXT,
    id_student TEXT,
    date_registration TEXT,
    date_unregistration TEXT
);

CREATE TABLE raw.studentAssessment (
    id_assessment TEXT,
    id_student TEXT,
    date_submitted TEXT,
    is_banked TEXT,
    score TEXT
);

CREATE TABLE raw.studentVle (
    code_module TEXT,
    code_presentation TEXT,
    id_student TEXT,
    id_site TEXT,
    date TEXT,
    sum_click TEXT
);


-- ============================================================
-- TEIL 3: CSV-IMPORT (COPY)
-- ============================================================

-- falls Probleme mit Mac und Rechten, diese Befehle ueber Terminal ausfuehren:
-- chmod -R 755 /tmp/OULAD_raw
-- ls -la /tmp/OULAD_raw/

COPY raw.courses FROM '/tmp/OULAD_raw/courses.csv' WITH (FORMAT csv, HEADER true);
COPY raw.assessments FROM '/tmp/OULAD_raw/assessments.csv' WITH (FORMAT csv, HEADER true);
COPY raw.vle FROM '/tmp/OULAD_raw/vle.csv' WITH (FORMAT csv, HEADER true);
COPY raw.studentInfo FROM '/tmp/OULAD_raw/studentInfo.csv' WITH (FORMAT csv, HEADER true);
COPY raw.studentRegistration FROM '/tmp/OULAD_raw/studentRegistration.csv' WITH (FORMAT csv, HEADER true);
COPY raw.studentAssessment FROM '/tmp/OULAD_raw/studentAssessment.csv' WITH (FORMAT csv, HEADER true);
COPY raw.studentVle FROM '/tmp/OULAD_raw/studentVle.csv' WITH (FORMAT csv, HEADER true);


-- ====================================================
-- TEIL 4: Modulauswahl aus 7 Modulen
-- ====================================================

-- da der Datensatz sehr groß ist, werde ich im folgenden nur eine 
-- Subgruppe analysieren, 2-3 Module
-- Fuer die Fragestellungen später, hätte ich gern in den Modulen der Subgruppe:
--	 - a) ausreichende Gruppengroesse
--	 - b) Score-Streuung
-- 	 - c) Verteilung von final_result (nicht nur bestanden)
-- 	 - d) Vielfalt an activity_type in vle
--   - e) ausreichend Faelle mit disability = 'Y'
--   - f) moeglichst hohe Streuung in imd_band (nicht nur eine SES-Gruppe)
--   - g) Module mit mehreren code_presentation-Durchlaeufen (fuer Zeitreihen)

---------------------------------------
-- Datenuebersicht RAW fuer Auswahl
---------------------------------------

-- --> Erste explorative Analyse ueber die Verteilung dieser Merkmale
--     ueber alle Module hinweg, als Grundlage fuer die Auswahl

-------------------------------------------
-- a) ausreichende Gruppengroesse
-------------------------------------------

SELECT code_module, COUNT(DISTINCT id_student) as anzahl_studierende
FROM raw.studentInfo
GROUP BY code_module
ORDER BY anzahl_studierende DESC;
--
--code_module|anzahl_studierende|
-------------+------------------+
--BBB        |              7692|
--FFF        |              7397|
--DDD        |              5848|
--CCC        |              4251|
--EEE        |              2859|
--GGG        |              2525|
--AAA        |               712|

--> AAA faellt raus wegen zu kleiner Stichprobengroesse 
-- (nur 712 Studierende, deutlich kleiner als die anderen 6 Module)

-------------------------------------------
-- b) Score-Streuung
-------------------------------------------


-- Erster Versuch ohne Filter, bricht ab (score enthaelt '?'):

--SELECT 
--    a.code_module,
--    MIN(sa.score::NUMERIC) as min_score,
--    MAX(sa.score::NUMERIC) as max_score,
--    ROUND(STDDEV(sa.score::NUMERIC), 1) as score_streuung
--FROM raw.studentAssessment sa
--JOIN raw.assessments a ON sa.id_assessment = a.id_assessment
--WHERE a.code_module != 'AAA'
--GROUP BY a.code_module
--ORDER BY score_streuung DESC;

--> hier fallen schon ? Werte in Zellen auf
-- die müssen rausgefiltert werden

SELECT 
    a.code_module,
    MIN(sa.score::NUMERIC) as min_score,
    MAX(sa.score::NUMERIC) as max_score,
    ROUND(STDDEV(sa.score::NUMERIC), 1) as score_streuung
FROM raw.studentAssessment sa
JOIN raw.assessments a ON sa.id_assessment = a.id_assessment
WHERE a.code_module != 'AAA'
  AND sa.score ~ '^[0-9]+$'
GROUP BY a.code_module
ORDER BY score_streuung DESC;

--> alle 6 Module zeigen die volle Bandbreite (0-100)
-- also keine Deckeneffekte oder Ähnliches. 

-- Die Streuung unterscheidet sich aber:

-- Höchste Streuung: CCC (22.6), BBB (20.2), DDD (20.1)
-- mehr Varianz zwischen Studierenden
-- Niedrigste Streuung: FFF (14.8), EEE (15.0)
-- Studierende schneiden eher aehnlich ab

----------------------------------------------
-- c) Verteilung von final_result (nicht nur bestanden)
----------------------------------------------

SELECT code_module, final_result, COUNT(*)
FROM raw.studentInfo
WHERE code_module != 'AAA'
GROUP BY code_module, final_result
ORDER BY code_module, final_result;

--> alle 6 Module zeigen alle 4 Kategorien gut vertreten

-- Ergebnisse:
-- BBB, DDD, FFF haben alle einen hohen Withdrawn-Anteil (2.250–2.403)
-- das größte "Problem" bei diesen Modulen scheint Abbruch zu sein, nicht Durchfallen

-- GGG sticht heraus mit auffällig wenig Withdrawn (292) im Vergleich zu Fail (728) 
-- --> anderes Muster als die anderen

-- EEE hat den kleinsten Fail-Anteil relativ zu Pass 
-- – wirkt wie das "erfolgreichste" Modul

----------------------------------------
-- d) Vielfalt an activity_type in vle
----------------------------------------

SELECT code_module, COUNT(DISTINCT activity_type) as anzahl_activity_types
FROM raw.vle
WHERE code_module != 'AAA'
GROUP BY code_module
ORDER BY anzahl_activity_types DESC;

--> FFF sehr hohe activity Vielfalt (18), BBB und DDD je 12

-----------------------------------------
-- e) ausreichend Faelle mit disability = 'Y'
-----------------------------------------

SELECT code_module, disability, COUNT(*)
FROM raw.studentInfo
WHERE code_module != 'AAA'
GROUP BY code_module, disability
ORDER BY code_module, disability;

-- Ergebnisse:

-- BBB, DDD, FFF haben alle ähnlich viele disability = Y-Fälle (735-742)
-- deutlich mehr als EEE (168, klar zu wenig für eine sinnvolle Subgruppenanalyse) 
-- oder GGG (356)


-- Ausschluss EEE und GGG:
--> EEE faellt raus wegen zu wenig disability-Faellen 
-- (nur 168, deutlich weniger als BBB/DDD/FFF mit ~740)

--> GGG faellt raus wegen zu wenig disability-Faellen (356) 
-- UND geringster Activity-Vielfalt (nur 7 Typen)

-------------------------------------------
-- f) IMD-Verteilung pro Modul (nur die 3 relevanten Module)
-------------------------------------------

SELECT code_module, imd_band, COUNT(*)
FROM raw.studentInfo
WHERE code_module IN ('BBB', 'DDD', 'FFF')
GROUP BY code_module, imd_band
ORDER BY code_module, imd_band;

--> Alle 10 IMD-Baender in BBB, DDD, FFF gut besetzt (kleinstes Band 455,
--  groesstes 1040 Einschreibungen) -> ausreichende SES-Streuung fuer
--  Gruppenvergleiche.
--  BBB: staerker in den unteren Baendern (0-10%: 1040 vs. 90-100%: 455),
--  DDD fast gleichverteilt (538-669), FFF dazwischen (610-895).
--  Fehlende Werte als '?': BBB 63, DDD 280, FFF 367 (siehe Audit c).
--  Auffaellig: Band '10-20' ohne %-Zeichen (siehe Audit f).


--------------------------------------------
-- g) Module mit mehreren code_presentation-Durchlaeufen (fuer Zeitreihen)
--------------------------------------------

SELECT code_module, COUNT(DISTINCT code_presentation) as anzahl_praesentationen
FROM raw.studentInfo
GROUP BY code_module
ORDER BY anzahl_praesentationen DESC;

-- Ergebnis:
--> BBB, DDD, FFF haben alle 4 Praesentationen (am meisten)
--> CCC faellt zusaetzlich auf: nur 2 Praesentationen, genau wie AAA
--    (war bisher nur wegen "kleinerer Stichprobe" ausgeschlossen, 
--     jetzt zusaetzliche Bestaetigung)

-- ====================================================
-- Modulvergleich ALLE 7 Module — inkl. Ausschlussbegruendung
-- ====================================================

WITH kennzahlen AS (
    SELECT
        si.code_module,
        COUNT(DISTINCT si.id_student) AS gruppengroesse,
        COUNT(DISTINCT si.code_presentation) AS anzahl_praesentationen,
        SUM(CASE WHEN si.disability = 'Y' THEN 1 ELSE 0 END) AS disability_faelle,
        SUM(CASE WHEN si.imd_band = '?' THEN 1 ELSE 0 END) AS fehlende_imd_werte,
        COUNT(DISTINCT si.final_result) AS anzahl_ergebnistypen
    FROM raw.studentInfo si
    GROUP BY si.code_module
),
scores AS (
    SELECT
        a.code_module,
        ROUND(STDDEV(sa.score::NUMERIC), 1) AS score_streuung
    FROM raw.studentAssessment sa
    JOIN raw.assessments a ON sa.id_assessment = a.id_assessment
    WHERE sa.score ~ '^[0-9]+$'
    GROUP BY a.code_module
),
activities AS (
    SELECT code_module, COUNT(DISTINCT activity_type) AS anzahl_activity_types
    FROM raw.vle
    GROUP BY code_module
)

SELECT
    k.code_module,
    CASE WHEN k.gruppengroesse >= 2000 THEN '+' ELSE '-' END AS gruppengroesse,
    CASE WHEN k.anzahl_praesentationen >= 3 THEN '+' ELSE 'o' END AS praesentationen,
    CASE WHEN s.score_streuung >= 20 THEN '+' 
         WHEN s.score_streuung >= 17 THEN 'o'
         ELSE '-' END AS score_streuung,
    CASE WHEN act.anzahl_activity_types >= 15 THEN '+' 
         WHEN act.anzahl_activity_types >= 10 THEN 'o'
         ELSE '-' END AS activity_vielfalt,
    CASE WHEN k.disability_faelle >= 700 THEN '+' 
         WHEN k.disability_faelle >= 350 THEN 'o'
         ELSE '-' END AS disability_faelle,
    CASE WHEN k.fehlende_imd_werte <= 100 THEN '+' 
         WHEN k.fehlende_imd_werte <= 300 THEN 'o' 
         ELSE '-' END AS imd_vollstaendigkeit,
    CASE WHEN k.anzahl_ergebnistypen = 4 THEN '+' ELSE '-' END AS ergebnistypen,
       CASE 
        WHEN k.code_module = 'AAA' THEN 'AUSGESCHLOSSEN: Stichprobe zu klein (712 Studierende) UND nur 2 Praesentationen'
        WHEN k.code_module = 'CCC' THEN 'AUSGESCHLOSSEN: nur 2 Praesentationen (wie AAA) - weniger Zeitreihen-Potenzial'
        WHEN k.code_module = 'EEE' THEN 'AUSGESCHLOSSEN: zu wenig disability-Faelle (168)'
        WHEN k.code_module = 'GGG' THEN 'AUSGESCHLOSSEN: zu wenig disability-Faelle (356) und geringste Activity-Vielfalt'
        WHEN k.code_module IN ('BBB','DDD','FFF') THEN 'AUSGEWAEHLT'
        ELSE ''
    END AS entscheidung
FROM kennzahlen k
JOIN scores s ON k.code_module = s.code_module
JOIN activities act ON k.code_module = act.code_module
ORDER BY 
    CASE WHEN k.code_module IN ('BBB','DDD','FFF') THEN 0 ELSE 1 END,
    k.code_module;

-- ============================================================
-- TEIL 5: DATA AUDIT (beschraenkt auf Module BBB/DDD/FFF)
-- ============================================================

-- Checkliste, angewendet auf die relevanten Tabellen:
--   a) Whitespace/TRIM-Probleme
--   b) Duplikate (doppelte IDs)
--   c) Fehlende Werte (NULL/?/leer)
--   d) Falsche Formate (Text in Zahlenfeldern)
--   e) Ausreisser
--   f) Inkonsistente Schreibweise/Kategorien
--   g) Widersprueche zwischen Tabellen
-- Nicht jede Tabelle braucht jeden Punkt; angewendet wird, was relevant ist.

-- --- studentAssessment ---

-- d) Falsche Formate: ungueltige score-Werte
SELECT COUNT(*) FROM raw.studentAssessment sa
JOIN raw.assessments a ON sa.id_assessment = a.id_assessment
WHERE a.code_module IN ('BBB','DDD','FFF') AND sa.score !~ '^[0-9]+$';

--> 148 ungueltige Werte gefunden (von insgesamt 173 im gesamten Datensatz)
--> werden bei Clean-Schritt (Teil 7) als NULL behandelt

-- b) Duplikate: gleiche id_student + id_assessment mehrfach?
-- Alias (sa./a.) noetig, weil sowohl studentAssessment als auch 
-- assessments eine Spalte "id_assessment" haben - ohne Alias 
-- weiss Postgres nicht, welche der beiden gemeint ist (Fehler: "ambiguous")
SELECT sa.id_assessment, sa.id_student, COUNT(*)
FROM raw.studentAssessment sa
JOIN raw.assessments a ON sa.id_assessment = a.id_assessment
WHERE a.code_module IN ('BBB','DDD','FFF')
GROUP BY sa.id_assessment, sa.id_student
HAVING COUNT(*) > 1;

--> keine Duplikate


-- --- studentInfo ---

-- c) Fehlende Werte: imd_band
SELECT code_module, COUNT(*) 
FROM raw.studentInfo
WHERE code_module IN ('BBB','DDD','FFF') AND imd_band = '?'
GROUP BY code_module
ORDER BY COUNT(*) ASC;
--> BBB: 63, DDD: 280, FFF: 367
--> bestaetigt den Befund aus der Modulauswahl (Teil 4):
--   FFF hat mit Abstand die meisten fehlenden IMD-Werte (~5% der Gruppe),
--   wird bei Clean (Teil 7) als NULL behandelt

-- b) Duplikate: gleiche id_student + code_module + code_presentation mehrfach?
SELECT code_module, code_presentation, id_student, COUNT(*)
FROM raw.studentInfo
WHERE code_module IN ('BBB','DDD','FFF')
GROUP BY code_module, code_presentation, id_student
HAVING COUNT(*) > 1;

--> keine Duplikate

-- e) Ausreisser: unrealistische sum_click-Werte in studentVle
SELECT MIN(sum_click::NUMERIC), MAX(sum_click::NUMERIC), 
       ROUND(AVG(sum_click::NUMERIC), 1) as durchschnitt
FROM raw.studentVle
WHERE code_module IN ('BBB','DDD','FFF') AND sum_click ~ '^[0-9]+$';

--min|max |durchschnitt|
-----+----+------------+
--  1|6977|         3.7|

--> min=1, max=6977, durchschnitt=3.7
--> max wirkt wie extremer Ausreisser (fast 1900x der Durchschnitt)
--   evtl. technisches Artefakt statt echtes Nutzerverhalten,
--   naeher pruefen (z.B. wie viele Faelle > 100?)

-- Wie viele Faelle liegen weit ueber dem Durchschnitt?
SELECT COUNT(*) FROM raw.studentVle
WHERE code_module IN ('BBB','DDD','FFF') 
  AND sum_click ~ '^[0-9]+$' 
  AND sum_click::NUMERIC > 100;

--> 4.733 Faelle (sehr kleiner Anteil bei >10 Mio. Gesamtzeilen)

-- Verteilung der Ausreisser genauer anschauen
SELECT 
    CASE 
        WHEN sum_click::NUMERIC BETWEEN 100 AND 500 THEN '100-500'
        WHEN sum_click::NUMERIC BETWEEN 501 AND 1000 THEN '501-1000'
        WHEN sum_click::NUMERIC BETWEEN 1001 AND 2000 THEN '1001-2000'
        ELSE 'ueber 2000'
    END as bereich,
    COUNT(*)
FROM raw.studentVle
WHERE code_module IN ('BBB','DDD','FFF') 
  AND sum_click ~ '^[0-9]+$' 
  AND sum_click::NUMERIC > 100
GROUP BY bereich
ORDER BY MIN(sum_click::NUMERIC);

--> Bereich 100-500: 4.689 Faelle 
-- - plausibel, intensives, aber normales Lernverhalten
--> Bereich 501-2000: 38 Faelle 
-- - grenzwertig, noch denkbar
--> ueber 2000: 6 Faelle 
-- - hoechstwahrscheinlich technisches Artefakt,
--   nicht plausibel als echte menschliche Klickaktivitaet

--> Fazit: nur diese 6 Extremfaelle als echte Ausreisser behandeln 
-- (z.B. bei Clean auffaellig markieren oder capping anwenden)
--  Rest bleibt unveraendert

-- f) Inkonsistente Schreibweise/Kategorien: distinct Werte in Textspalten pruefen
SELECT DISTINCT gender FROM raw.studentInfo WHERE code_module IN ('BBB','DDD','FFF');
--> M, F - sauber

SELECT DISTINCT disability FROM raw.studentInfo WHERE code_module IN ('BBB','DDD','FFF');
--> Y, N - sauber

SELECT DISTINCT highest_education FROM raw.studentInfo WHERE code_module IN ('BBB','DDD','FFF');

--> A Level or Equivalent, Lower Than A Level, HE Qualification, 
--   Post Graduate Qualification, No Formal quals - alle 5 erwarteten 
--   Kategorien vorhanden, keine Inkonsistenzen

SELECT DISTINCT age_band FROM raw.studentInfo WHERE code_module IN ('BBB','DDD','FFF');
--> 3 saubere Kategorien (0-35, 35-55, 55<=), keine Inkonsistenzen

-- f) Inkonsistente Schreibweise/Kategorien (Fortsetzung)
SELECT DISTINCT imd_band FROM raw.studentInfo
WHERE code_module IN ('BBB','DDD','FFF') ORDER BY 1;

--> 10 Baender + '?' (fehlend, siehe c). 
--  Auffaellig: '10-20' ohne %-Zeichen, 
--  alle anderen Baender mit % (0-10%, 20-30% ...).
--  Faellt erst beim Modulvergleich (Teil 12, A4) auf, weil imd_band
--  im Audit bisher nur auf '?' geprueft wurde.
--  -> Clean (Teil 7): '10-20' wird zu '10-20%' vereinheitlicht.


-- a) Whitespace/TRIM-Probleme
SELECT DISTINCT region FROM raw.studentInfo 
WHERE code_module IN ('BBB','DDD','FFF') 
  AND (region != TRIM(region));

--> leer, kein whitespace Problem

SELECT DISTINCT highest_education FROM raw.studentInfo 
WHERE code_module IN ('BBB','DDD','FFF') 
  AND (highest_education != TRIM(highest_education));

--> leer, kein whitespace Problem

-- --- assessments ---

-- c) Fehlende Werte: date (v.a. bei assessment_type = 'Exam' erwartet)
-- Geprueft wird auf alles, was keine Zahl ist (nicht nur leer/NULL),
-- weil fehlende Werte in diesem Datensatz als Platzhalter (vermutlich '?') stehen.
SELECT assessment_type, COUNT(*) 
FROM raw.assessments
WHERE code_module IN ('BBB','DDD','FFF') 
  AND (date IS NULL OR date !~ '^[0-9]+$')
GROUP BY assessment_type;

--> 5 Exam-Eintraege ohne gueltiges date, sonst keine.
--  Passt zur offiziellen Beschreibung: fehlt das Exam-Datum, 
--  liegt der Termin am Ende der letzten Praesentationswoche.
--  Erster Audit-Versuch pruefte nur auf leer/NULL und fand deshalb nichts.
--  -> In cleaned als NULL belassen, kein Raten eines Datums.

-- ============================================================
-- TEIL 6: CLEANED SCHEMA — TABELLEN ANLEGEN (richtige Typen)
-- ============================================================

-- Hinweis: Primaerschluessel werden direkt beim 
-- CREATE TABLE definiert (analog zur Doxameter-Kursvorlage), 
-- nicht wie bei der Supply-Chain-Uebung als separater Schritt per ALTER TABLE 

-- ============================================================
-- BEZIEHUNGEN IM UEBERBLICK
-- ============================================================
--
--   courses
--      |
--      |--- (n) assessments
--      |--- (n) vle
--      |--- (n) student_info
--      |--- (n) student_registration
--      |--- (n) student_vle
--
--   student_info
--      |
--      |--- (n) student_registration
--      |--- (n) student_assessment
--      |--- (n) student_vle
--
--   assessments --- (n) student_assessment
--   vle          --- (n) student_vle
--
-- Primaerschluessel:
--   courses               : code_module + code_presentation
--   assessments            : id_assessment
--   vle                     : id_site
--   student_info            : code_module + code_presentation + id_student
--   student_registration    : code_module + code_presentation + id_student
--   student_assessment      : id_assessment + id_student
--   student_vle             : kein eigener PK (reine Ereignistabelle)
-- ============================================================

-- Achtung: CASCADE loescht auch abhaengige Views in analytics
-- (v_zentrumsbericht, mv_zentrumsbericht) -> danach Skript 2 neu ausfuehren.
DROP SCHEMA IF EXISTS cleaned CASCADE;

CREATE SCHEMA cleaned;

CREATE TABLE cleaned.courses (
    code_module VARCHAR(10),
    code_presentation VARCHAR(10),
    module_presentation_length INTEGER,
    PRIMARY KEY (code_module, code_presentation)
);

CREATE TABLE cleaned.assessments (
    code_module VARCHAR(10),
    code_presentation VARCHAR(10),
    id_assessment INTEGER PRIMARY KEY,
    assessment_type VARCHAR(10),
    date INTEGER,
    weight NUMERIC(5,2)
);

CREATE TABLE cleaned.vle (
    id_site INTEGER PRIMARY KEY,
    code_module VARCHAR(10),
    code_presentation VARCHAR(10),
    activity_type VARCHAR(30),
    week_from INTEGER,
    week_to INTEGER
);

CREATE TABLE cleaned.student_info (
    code_module VARCHAR(10),
    code_presentation VARCHAR(10),
    id_student INTEGER,
    gender VARCHAR(1),
    region VARCHAR(50),
    highest_education VARCHAR(50),
    imd_band VARCHAR(10),
    age_band VARCHAR(10),
    num_of_prev_attempts INTEGER,
    studied_credits INTEGER,
    disability VARCHAR(1),
    final_result VARCHAR(20),
    PRIMARY KEY (code_module, code_presentation, id_student)
);

CREATE TABLE cleaned.student_registration (
    code_module VARCHAR(10),
    code_presentation VARCHAR(10),
    id_student INTEGER,
    date_registration INTEGER,
    date_unregistration INTEGER,
    PRIMARY KEY (code_module, code_presentation, id_student)
);

CREATE TABLE cleaned.student_assessment (
    id_assessment INTEGER,
    id_student INTEGER,
    date_submitted INTEGER,
    is_banked INTEGER,
    score NUMERIC(5,2),
    PRIMARY KEY (id_assessment, id_student)
);

CREATE TABLE cleaned.student_vle (
    code_module VARCHAR(10),
    code_presentation VARCHAR(10),
    id_student INTEGER,
    id_site INTEGER,
    date INTEGER,
    sum_click INTEGER
);


-- ============================================================
-- TEIL 7: CLEANED DATA — INSERT MIT TRANSFORMATIONEN
-- beschraenkt auf Module BBB, DDD, FFF
-- ============================================================

-- Unterschied beim Datentypen-Vorgang zu frueheren Uebungen 
-- (dort erst INSERT als TEXT, Typumwandlung per separatem ALTER TABLE danach) 
-- sind die cleaned-Tabellen hier 
-- bereits mit den korrekten Typen angelegt (Teil 6).

--> Deshalb muss die Typumwandlung (::INTEGER, ::NUMERIC etc.) 
-- direkt beim INSERT erfolgen - ein Schritt statt zwei.

-- ---- courses ----

INSERT INTO cleaned.courses
SELECT 
    code_module,
    code_presentation,
    module_presentation_length::INTEGER
FROM raw.courses
WHERE code_module IN ('BBB', 'DDD', 'FFF');

-- --- assessments ----

--INSERT INTO cleaned.assessments
--SELECT 
--    code_module,
--    code_presentation,
--    id_assessment::INTEGER,
--    assessment_type,
--    CASE WHEN date = '' OR date IS NULL THEN NULL ELSE date::INTEGER END,
--    weight::NUMERIC(5,2)
--FROM raw.assessments
--WHERE code_module IN ('BBB', 'DDD', 'FFF');

--> Fehlermeldung --> bei weight scheinbar "?" Werte drin?

INSERT INTO cleaned.assessments
SELECT 
    code_module,
    code_presentation,
    id_assessment::INTEGER,
    assessment_type,
    CASE WHEN date !~ '^[0-9]+$' THEN NULL ELSE date::INTEGER END,
    CASE WHEN weight !~ '^[0-9]+\.?[0-9]*$' THEN NULL ELSE weight::NUMERIC(5,2) END
FROM raw.assessments
WHERE code_module IN ('BBB', 'DDD', 'FFF');


-- --- vle ----

INSERT INTO cleaned.vle
SELECT 
    id_site::INTEGER,
    code_module,
    code_presentation,
    activity_type,
    CASE WHEN week_from !~ '^[0-9]+$' THEN NULL ELSE week_from::INTEGER END,
    CASE WHEN week_to !~ '^[0-9]+$' THEN NULL ELSE week_to::INTEGER END
FROM raw.vle
WHERE code_module IN ('BBB', 'DDD', 'FFF');

-- --- student_info ----

INSERT INTO cleaned.student_info
SELECT
    code_module,
    code_presentation,
    id_student::INTEGER,
    gender,
    region,
    highest_education,
    -- imd_band: '?' -> NULL, '10-20' -> '10-20%' (Audit f)
    CASE WHEN imd_band = '?' THEN NULL
         WHEN imd_band = '10-20' THEN '10-20%'
         ELSE imd_band END,
    age_band,
    CASE WHEN num_of_prev_attempts !~ '^[0-9]+$' THEN NULL ELSE num_of_prev_attempts::INTEGER END,
    CASE WHEN studied_credits !~ '^[0-9]+$' THEN NULL ELSE studied_credits::INTEGER END,
    disability,
    final_result
FROM raw.studentInfo
WHERE code_module IN ('BBB', 'DDD', 'FFF');


-- --- student_registration ----

INSERT INTO cleaned.student_registration
SELECT 
    code_module,
    code_presentation,
    id_student::INTEGER,
    CASE WHEN date_registration !~ '^-?[0-9]+$' THEN NULL ELSE date_registration::INTEGER END,
    CASE WHEN date_unregistration !~ '^-?[0-9]+$' THEN NULL ELSE date_unregistration::INTEGER END
FROM raw.studentRegistration
WHERE code_module IN ('BBB', 'DDD', 'FFF');

-- --- student_assessment ----

-- studentAssessment hat selbst kein code_module, 
-- deshalb JOIN mit assessments noetig, 
-- um auf BBB/DDD/FFF filtern zu koennen 
-- (analog zu den Audit-Checks a/b weiter oben).
-- Alias (sa./a.) noetig, weil beide Tabellen "id_assessment" haben -
-- ohne Alias waere die Spaltenreferenz mehrdeutig (siehe Fehler von vorhin)

INSERT INTO cleaned.student_assessment
SELECT 
    sa.id_assessment::INTEGER,
    sa.id_student::INTEGER,
       -- date_submitted: negative Werte moeglich (relativ zu Semesterstart), 
       -- daher -? im Regex, analog zu date_registration
    CASE WHEN sa.date_submitted !~ '^-?[0-9]+$' THEN NULL ELSE sa.date_submitted::INTEGER END,
    CASE WHEN sa.is_banked !~ '^[0-9]+$' THEN NULL ELSE sa.is_banked::INTEGER END,
       -- score: 148 ungueltige Werte im Audit (Punkt d) gefunden, 
       -- werden hier als NULL behandelt statt die Zeile zu verwerfen
    CASE WHEN sa.score !~ '^[0-9]+\.?[0-9]*$' THEN NULL ELSE sa.score::NUMERIC(5,2) END
FROM raw.studentAssessment sa
JOIN raw.assessments a ON sa.id_assessment = a.id_assessment
WHERE a.code_module IN ('BBB', 'DDD', 'FFF');

-- --- student_vle ----

-- Laufzeit: ~15s, groesste Tabelle, urspruenglich >10 Mio. Zeilen (vor Filterung)
-- Ausreisser bei sum_click (6 Faelle >2000, siehe Audit e)
-- werden NICHT rausgefiltert - bewusste Entscheidung, da nur 6 von 
-- Millionen Zeilen betroffen und als "auffaellig, aber nicht sicher falsch" 
-- eingestuft; nur echte Formatfehler (?) werden zu NULL

INSERT INTO cleaned.student_vle
SELECT 
    code_module,
    code_presentation,
    id_student::INTEGER,
    id_site::INTEGER,
    CASE WHEN date !~ '^-?[0-9]+$' THEN NULL ELSE date::INTEGER END,
    CASE WHEN sum_click !~ '^[0-9]+$' THEN NULL ELSE sum_click::INTEGER END
FROM raw.studentVle
WHERE code_module IN ('BBB', 'DDD', 'FFF');


--- Nebenfund: week_from/week_to fehlen bei sehr vielen vle-Eintraegen,

-- Ueberpruefung der Haeufigkeiten in den RAW Daten
SELECT activity_type, COUNT(*), 
    SUM(CASE WHEN week_from = '' OR week_from = '?' THEN 1 ELSE 0 END) as leere_week_from
FROM raw.vle
WHERE code_module IN ('BBB','DDD','FFF')
GROUP BY activity_type
ORDER BY leere_week_from DESC;

-- v.a. bei forumng (100%) und oucollaborate (100%) 
-- vermutlich, weil diese Materialien nicht an eine feste Woche gebunden sind, 
-- sondern durchgehend verfuegbar. 
-- Kein Bereinigungsfehler, sondern Dateneigenschaft.
-- Bleibt als NULL in cleaned, kein weiterer Handlungsbedarf.

-- ============================================================
-- TEIL 8: ZEILENZAHLEN VERIFIZIEREN (raw vs. cleaned)
-- ============================================================

-- raw-Zeilenzahl hier bereits auf BBB/DDD/FFF gefiltert, 
-- damit der Vergleich fair ist (nicht raw komplett vs. cleaned gefiltert)

SELECT 'courses' as tabelle,
    (SELECT COUNT(*) FROM raw.courses WHERE code_module IN ('BBB','DDD','FFF')) as raw_zeilen,
    (SELECT COUNT(*) FROM cleaned.courses) as cleaned_zeilen
UNION ALL
SELECT 'assessments',
    (SELECT COUNT(*) FROM raw.assessments WHERE code_module IN ('BBB','DDD','FFF')),
    (SELECT COUNT(*) FROM cleaned.assessments)
UNION ALL
SELECT 'vle',
    (SELECT COUNT(*) FROM raw.vle WHERE code_module IN ('BBB','DDD','FFF')),
    (SELECT COUNT(*) FROM cleaned.vle)
UNION ALL
SELECT 'student_info',
    (SELECT COUNT(*) FROM raw.studentInfo WHERE code_module IN ('BBB','DDD','FFF')),
    (SELECT COUNT(*) FROM cleaned.student_info)
UNION ALL
SELECT 'student_registration',
    (SELECT COUNT(*) FROM raw.studentRegistration WHERE code_module IN ('BBB','DDD','FFF')),
    (SELECT COUNT(*) FROM cleaned.student_registration)
UNION ALL
SELECT 'student_assessment',
    (SELECT COUNT(*) FROM raw.studentAssessment sa 
        JOIN raw.assessments a ON sa.id_assessment = a.id_assessment 
        WHERE a.code_module IN ('BBB','DDD','FFF')),
    (SELECT COUNT(*) FROM cleaned.student_assessment)
UNION ALL
SELECT 'student_vle',
    (SELECT COUNT(*) FROM raw.studentVle WHERE code_module IN ('BBB','DDD','FFF')),
    (SELECT COUNT(*) FROM cleaned.student_vle);

--> alle 7 Tabellen: raw_zeilen = cleaned_zeilen, keine Abweichungen
-- Bestaetigt: Cleaning hat nur einzelne Werte zu NULL transformiert 
-- (Formatfehler, Ausreisser), keine Zeilen wurden verworfen/verloren

-- ============================================================
-- TEIL 9: ORPHANS PRUEFEN (vor FKs)
-- ============================================================

-- student_assessment.id_assessment muss in assessments existieren
SELECT COUNT(*) FROM cleaned.student_assessment sa
WHERE NOT EXISTS (
    SELECT 1 FROM cleaned.assessments a WHERE a.id_assessment = sa.id_assessment
);

--> 0 Orphans

-- student_vle.id_site muss in vle existieren
SELECT COUNT(*) FROM cleaned.student_vle sv
WHERE NOT EXISTS (
    SELECT 1 FROM cleaned.vle v WHERE v.id_site = sv.id_site
);

--> 0 Orphans 

-- Keine Orphans gefunden - erwartungsgemaess, da die Modul-Filterung
-- (BBB/DDD/FFF) konsistent auf alle Tabellen angewendet wurde.

-- ============================================================
-- TEIL 10: FOREIGN KEYS
-- ============================================================

-- Verbindungsuebersicht (FK -> referenzierter PK):
--
-- assessments          -> courses          (code_module, code_presentation)
-- vle                  -> courses          (code_module, code_presentation)
-- student_info         -> courses          (code_module, code_presentation)
--
-- student_registration -> student_info     (code_module, code_presentation, id_student)
-- student_vle          -> student_info     (code_module, code_presentation, id_student)
--
-- student_assessment   -> assessments      (id_assessment)
-- student_vle          -> vle              (id_site)
--
-- Hinweis: Mehrere PKs bestehen hier NICHT nur aus einem einzelnen Wert,
-- sondern aus einer Kombination mehrerer Spalten 
-- (zusammengesetzter PK, siehe Teil 6). 
-- Der FK muss dann ebenfalls als Kombination genau dieser
-- Spalten referenzieren, nicht nur eine einzelne Spalte davon 
-- - sonst ist die Verbindung nicht eindeutig genug.


-- assessments -> courses
ALTER TABLE cleaned.assessments
    ADD CONSTRAINT fk_assessments_courses
        FOREIGN KEY (code_module, code_presentation) 
        REFERENCES cleaned.courses(code_module, code_presentation);

-- vle -> courses
ALTER TABLE cleaned.vle
    ADD CONSTRAINT fk_vle_courses
        FOREIGN KEY (code_module, code_presentation) 
        REFERENCES cleaned.courses(code_module, code_presentation);

-- student_info -> courses
ALTER TABLE cleaned.student_info
    ADD CONSTRAINT fk_studentinfo_courses
        FOREIGN KEY (code_module, code_presentation) 
        REFERENCES cleaned.courses(code_module, code_presentation);

-- student_registration -> student_info
ALTER TABLE cleaned.student_registration
    ADD CONSTRAINT fk_studentreg_studentinfo
        FOREIGN KEY (code_module, code_presentation, id_student) 
        REFERENCES cleaned.student_info(code_module, code_presentation, id_student);

-- student_assessment -> assessments
ALTER TABLE cleaned.student_assessment
    ADD CONSTRAINT fk_studentassess_assessments
        FOREIGN KEY (id_assessment) 
        REFERENCES cleaned.assessments(id_assessment);

-- student_vle -> student_info
ALTER TABLE cleaned.student_vle
    ADD CONSTRAINT fk_studentvle_studentinfo
        FOREIGN KEY (code_module, code_presentation, id_student) 
        REFERENCES cleaned.student_info(code_module, code_presentation, id_student);

-- student_vle -> vle
ALTER TABLE cleaned.student_vle
    ADD CONSTRAINT fk_studentvle_vle
        FOREIGN KEY (id_site) 
        REFERENCES cleaned.vle(id_site);


-- ============================================================
-- TEIL 11: ER-DIAGRAMM (DBeaver, exportiert als PNG)
-- ============================================================
-- Erstellt ueber DBeaver (Schema "cleaned" -> ER-Diagramm anzeigen),
-- per Klick als Bild exportiert: oulad_er_diagramm.png
-- Zeigt alle 7 Tabellen mit zusammengesetzten PKs (fett) und den
-- 7 FK-Beziehungen aus Teil 10.

