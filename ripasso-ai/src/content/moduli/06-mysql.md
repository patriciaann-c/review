# Modulo 06 — Database con MySQL

> **Livello:** intermedio · **Tempo:** 10 h · **Prerequisiti:** Node.js di base
> **Deliverable:** database multiutente della piattaforma RipassoAI.

---

## 1. Traguardi

Al termine del modulo sapete:

- progettare uno schema normalizzato con chiavi primarie ed esterne;
- scrivere query con filtri, join, aggregazioni e window function;
- creare indici motivati e leggere un piano di esecuzione;
- usare transazioni per operazioni atomiche;
- gestire ruoli e permessi minimi;
- riconoscere e prevenire SQL injection;
- pianificare backup, retention e crescita dei dati.

---

## 2. Concetti chiave (cheat sheet)

### Tipi di dato utili

| Esigenza | Tipo consigliato |
|---|---|
| ID numerico | `BIGINT UNSIGNED AUTO_INCREMENT` |
| UUID | `CHAR(36)` o `BINARY(16)` |
| Testo breve | `VARCHAR(255)` |
| Testo lungo | `TEXT` / `MEDIUMTEXT` |
| Booleano | `TINYINT(1)` / `BOOLEAN` |
| Data/ora | `DATETIME(3)` (senza timezone) o `TIMESTAMP` |
| Denaro | `DECIMAL(10,2)` (mai `FLOAT`) |
| JSON | `JSON` (con moderazione) |
| Enum | `ENUM(...)` o tabella di lookup |

### Schema di esempio

```sql
CREATE DATABASE ripasso_ai
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE ripasso_ai;

CREATE TABLE utenti (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  nome          VARCHAR(100) NOT NULL,
  ruolo         ENUM('studente', 'docente', 'admin') NOT NULL DEFAULT 'studente',
  creato_il     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_utenti_email (email)
) ENGINE=InnoDB;

CREATE TABLE argomenti (
  id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  slug   VARCHAR(80) NOT NULL,
  titolo VARCHAR(150) NOT NULL,
  UNIQUE KEY uq_argomenti_slug (slug)
) ENGINE=InnoDB;

CREATE TABLE domande (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  argomento_id BIGINT UNSIGNED NOT NULL,
  testo        TEXT NOT NULL,
  livello      TINYINT UNSIGNED NOT NULL,
  spiegazione  TEXT NULL,
  attiva       BOOLEAN NOT NULL DEFAULT TRUE,
  creato_il    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT fk_domande_argomento
    FOREIGN KEY (argomento_id) REFERENCES argomenti(id),
  CONSTRAINT chk_domande_livello CHECK (livello BETWEEN 1 AND 4),
  KEY idx_domande_arg_livello (argomento_id, livello, attiva)
) ENGINE=InnoDB;

CREATE TABLE opzioni (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  domanda_id BIGINT UNSIGNED NOT NULL,
  testo      VARCHAR(500) NOT NULL,
  corretta   BOOLEAN NOT NULL DEFAULT FALSE,
  posizione  TINYINT UNSIGNED NOT NULL,
  CONSTRAINT fk_opzioni_domanda
    FOREIGN KEY (domanda_id) REFERENCES domande(id) ON DELETE CASCADE,
  UNIQUE KEY uq_opzioni_posizione (domanda_id, posizione)
) ENGINE=InnoDB;

CREATE TABLE tentativi (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  utente_id    BIGINT UNSIGNED NOT NULL,
  argomento_id BIGINT UNSIGNED NOT NULL,
  punteggio    DECIMAL(5,2) NOT NULL DEFAULT 0,
  iniziato_il  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  concluso_il  DATETIME(3) NULL,
  CONSTRAINT fk_tentativi_utente
    FOREIGN KEY (utente_id) REFERENCES utenti(id) ON DELETE CASCADE,
  CONSTRAINT fk_tentativi_argomento
    FOREIGN KEY (argomento_id) REFERENCES argomenti(id),
  KEY idx_tentativi_utente_data (utente_id, iniziato_il DESC)
) ENGINE=InnoDB;

CREATE TABLE risposte (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tentativo_id BIGINT UNSIGNED NOT NULL,
  domanda_id   BIGINT UNSIGNED NOT NULL,
  opzione_id   BIGINT UNSIGNED NULL,
  corretta     BOOLEAN NOT NULL,
  tempo_ms     INT UNSIGNED NULL,
  CONSTRAINT fk_risposte_tentativo
    FOREIGN KEY (tentativo_id) REFERENCES tentativi(id) ON DELETE CASCADE,
  CONSTRAINT fk_risposte_domanda
    FOREIGN KEY (domanda_id) REFERENCES domande(id),
  CONSTRAINT fk_risposte_opzione
    FOREIGN KEY (opzione_id) REFERENCES opzioni(id),
  UNIQUE KEY uq_risposte_tentativo_domanda (tentativo_id, domanda_id)
) ENGINE=InnoDB;
```

### Query essenziali

```sql
-- Domande attive di un argomento, dal livello più basso
SELECT d.id, d.testo, d.livello
FROM domande d
JOIN argomenti a ON a.id = d.argomento_id
WHERE a.slug = 'javascript' AND d.attiva = TRUE
ORDER BY d.livello ASC, d.id ASC
LIMIT 20 OFFSET 0;

-- Media e numero tentativi per studente
SELECT u.id, u.nome, COUNT(*) AS tentativi, ROUND(AVG(t.punteggio), 1) AS media
FROM utenti u
JOIN tentativi t ON t.utente_id = u.id
WHERE u.ruolo = 'studente'
GROUP BY u.id, u.nome
HAVING tentativi >= 3
ORDER BY media DESC, tentativi DESC;

-- Tasso di risposte corrette per argomento e livello
SELECT a.titolo, d.livello,
       COUNT(*) AS risposte,
       ROUND(100 * AVG(r.corretta), 1) AS tasso_corretto
FROM risposte r
JOIN domande d ON d.id = r.domanda_id
JOIN argomenti a ON a.id = d.argomento_id
GROUP BY a.titolo, d.livello
ORDER BY a.titolo, d.livello;
```

### Window function

```sql
-- Ultimo tentativo per utente
SELECT *
FROM (
  SELECT t.*,
         ROW_NUMBER() OVER (PARTITION BY utente_id ORDER BY iniziato_il DESC) AS rn
  FROM tentativi t
) ranked
WHERE rn = 1;
```

### Transazione

```sql
START TRANSACTION;

INSERT INTO tentativi (utente_id, argomento_id, iniziato_il, concluso_il)
VALUES (42, 3, NOW(3), NOW(3));

SET @tentativo_id = LAST_INSERT_ID();

INSERT INTO risposte (tentativo_id, domanda_id, opzione_id, corretta, tempo_ms)
VALUES
  (@tentativo_id, 101, 401, TRUE, 5200),
  (@tentativo_id, 102, 408, FALSE, 8100);

UPDATE tentativi
SET punteggio = (
  SELECT ROUND(100 * AVG(corretta), 2)
  FROM risposte
  WHERE tentativo_id = @tentativo_id
)
WHERE id = @tentativo_id;

COMMIT;
```

### Indici: quando e perché

- indice su colonne usate in `WHERE`, `JOIN`, `ORDER BY`;
- **indice composito** con la colonna più selettiva a sinistra, ma rispetta l'ordine delle query;
- troppi indici rallentano `INSERT`/`UPDATE`;
- `EXPLAIN ANALYZE` per verificare l'uso reale.

```sql
EXPLAIN ANALYZE
SELECT id, testo FROM domande
WHERE argomento_id = 7 AND attiva = TRUE AND livello = 2
ORDER BY id
LIMIT 10;
```

### Sicurezza

```sql
-- ❌ mai: concatenazione
-- "SELECT * FROM utenti WHERE email = '" + input + "'"

-- ✅ prepared statement
PREPARE stmt FROM 'SELECT id, email FROM utenti WHERE email = ?';
SET @email = 'studente@example.com';
EXECUTE stmt USING @email;
DEALLOCATE PREPARE stmt;

-- ✅ principio del minimo privilegio
CREATE ROLE 'app_rw';
GRANT SELECT, INSERT, UPDATE, DELETE ON ripasso_ai.* TO 'app_rw';
CREATE USER 'app'@'%' IDENTIFIED BY 'password-lunga-e-casuale';
GRANT 'app_rw' TO 'app'@'%';
```

### Concetti fondamentali aggiuntivi

#### NULL e logica a tre valori

```sql
SELECT * FROM domande WHERE spiegazione IS NULL;
SELECT COALESCE(spiegazione, 'Nessuna spiegazione') FROM domande;
SELECT NULLIF(voto, 0) FROM tentativi;
```

- `NULL` significa "valore sconosciuto", non zero né stringa vuota.
- `NULL = NULL` restituisce `NULL`, non `TRUE`: usate `IS NULL` / `IS NOT NULL`.
- Le aggregazioni (`SUM`, `AVG`, `COUNT(col)`) **ignorano** i NULL; `COUNT(*)` no.
- `NOT IN (subquery con NULL)` può non restituire righe: preferite `NOT EXISTS`.
- Definite `NOT NULL` + `DEFAULT` quando il valore è obbligatorio.

#### JOIN in pratica

```sql
-- INNER: solo righe con corrispondenza
SELECT u.nome, t.punteggio
FROM utenti u
JOIN tentativi t ON t.utente_id = u.id;

-- LEFT: tutti gli utenti, anche senza tentativi
SELECT u.nome, COUNT(t.id) AS tentativi
FROM utenti u
LEFT JOIN tentativi t ON t.utente_id = u.id
GROUP BY u.id, u.nome;

-- Anti-join: utenti senza tentativi
SELECT u.*
FROM utenti u
LEFT JOIN tentativi t ON t.utente_id = u.id
WHERE t.id IS NULL;

-- Self join: dipendenti e responsabile
SELECT d.nome AS dipendente, r.nome AS responsabile
FROM dipendenti d
LEFT JOIN dipendenti r ON r.id = d.responsabile_id;
```

| Tipo | Restituisce |
|---|---|
| `INNER JOIN` | Solo le righe con match in entrambe |
| `LEFT JOIN` | Tutte le righe di sinistra + match a destra |
| `RIGHT JOIN` | Tutte le righe di destra + match a sinistra |
| `CROSS JOIN` | Prodotto cartesiano (usare con cautela) |

MySQL non supporta `FULL OUTER JOIN`: si emula con `UNION` di `LEFT` e `RIGHT`. Attenzione ai duplicati quando una relazione è 1→N: aggregate o usate `DISTINCT`.

#### Sottoquery, EXISTS, CTE e UNION

```sql
-- EXISTS è spesso più leggibile e performante di IN
SELECT d.*
FROM domande d
WHERE EXISTS (
  SELECT 1 FROM risposte r WHERE r.domanda_id = d.id AND r.corretta = FALSE
);

-- CTE: leggibilità e riuso
WITH punteggi AS (
  SELECT utente_id, AVG(punteggio) AS media
  FROM tentativi
  GROUP BY utente_id
)
SELECT u.nome, p.media
FROM utenti u
JOIN punteggi p ON p.utente_id = u.id
WHERE p.media < 60;

-- Ricorsione: gerarchie
WITH RECURSIVE livelli AS (
  SELECT id, titolo, NULL AS genitore FROM argomenti WHERE genitore_id IS NULL
  UNION ALL
  SELECT a.id, a.titolo, a.genitore_id
  FROM argomenti a JOIN livelli l ON a.genitore_id = l.id
)
SELECT * FROM livelli;

-- UNION elimina duplicati, UNION ALL no (più veloce)
SELECT email FROM studenti
UNION ALL
SELECT email FROM docenti;
```

#### Normalizzazione e design

- **1NF**: valori atomici, niente liste in una colonna.
- **2NF**: nessuna dipendenza parziale dalla chiave composta.
- **3NF**: nessuna dipendenza transitiva tra attributi non chiave.
- Chiavi primarie stabili (surrogate `BIGINT` o UUID) e chiavi naturali con `UNIQUE`.
- La denormalizzazione è una scelta consapevole per letture frequenti, non una scorciatoia.
- Usate `utf8mb4`, timestamp UTC, `DECIMAL` per il denaro, `BOOLEAN`/`TINYINT(1)` per i flag.
- Evitate `ENUM` se i valori cambiano spesso: meglio una tabella di lookup.

#### Vincoli e integrità

```sql
CREATE TABLE domande (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  argomento_id BIGINT UNSIGNED NOT NULL,
  livello TINYINT UNSIGNED NOT NULL,
  testo TEXT NOT NULL,
  attiva BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_domande_argomento
    FOREIGN KEY (argomento_id) REFERENCES argomenti(id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_domande_livello CHECK (livello BETWEEN 1 AND 4),
  UNIQUE KEY uq_domanda_testo (argomento_id, testo(255))
) ENGINE=InnoDB;
```

- `ON DELETE CASCADE` per dati figli che non hanno senso senza il padre; `RESTRICT` per bloccare cancellazioni pericolose.
- I `CHECK` sono applicati da MySQL 8.0.16 in poi.
- Gli `AUTO_INCREMENT` possono avere buchi: non usateli come conteggio.
- I vincoli sono documentazione eseguibile: non aggirateli solo applicativamente.

#### ACID, transazioni e lock

```sql
START TRANSACTION;

SELECT punteggio FROM tentativi WHERE id = 42 FOR UPDATE;

UPDATE tentativi SET punteggio = punteggio + 1 WHERE id = 42;

COMMIT;
-- In caso di errore: ROLLBACK;
```

- **Atomicità**: tutto o niente. **Consistenza**: i vincoli restano validi. **Isolamento**: le transazioni non vedono stati intermedi. **Durabilità**: dopo il commit i dati restano.
- Il livello di isolamento di default in MySQL/InnoDB è `REPEATABLE READ`; `READ COMMITTED` riduce i gap lock ma cambia la semantica delle letture.
- `SELECT ... FOR UPDATE` blocca le righe lette; `FOR SHARE` blocca solo le scritture concorrenti.
- Deadlock: due transazioni si attendono. MySQL ne uccide una: gestite l'errore e ritentate.
- Transazioni **brevi**: mai chiamate HTTP o attese lunghe dentro una transazione.

#### Indici in profondità

```sql
-- Composito: l'ordine delle colonne conta (leftmost prefix)
CREATE INDEX idx_domande_arg_livello ON domande (argomento_id, livello, attiva);

-- Covering index: la query è soddisfatta dall'indice
SELECT argomento_id, livello FROM domande WHERE argomento_id = 7;

-- Prefix index per testi lunghi
CREATE INDEX idx_domande_testo ON domande (testo(100));
```

- Un indice accelera letture filtrate ma rallenta scritture e occupa spazio.
- La colonna più selettiva non è sempre la prima: dipende dalle query e dai filtri usati.
- Evitate funzioni sulla colonna indissata (`WHERE YEAR(creato_il) = 2026`): riscrivete come range.
- Un indice composito copre anche le query che usano solo il prefisso sinistro.
- `ANALYZE TABLE` aggiorna le statistiche; `SHOW INDEX FROM tabella` ispeziona gli indici.
- Gli indici invisibili aiutano a testare la rimozione senza perdere l'indice.

#### Leggere `EXPLAIN`

```sql
EXPLAIN ANALYZE
SELECT id, testo FROM domande
WHERE argomento_id = 7 AND attiva = TRUE AND livello = 2
ORDER BY id LIMIT 10;
```

| Colonna/valore | Cosa indica |
|---|---|
| `type: ALL` | Full table scan, spesso da evitare |
| `type: ref`/`range` | Uso di indice, buono |
| `type: const`/`eq_ref` | Accesso a una singola riga |
| `rows` | Stima delle righe esaminate |
| `filtered` | Percentuale stimata che passa il filtro |
| `Extra: Using index` | Covering index |
| `Extra: Using temporary` | Tabella temporanea, spesso per GROUP BY/ORDER BY |
| `Extra: Using filesort` | Ordinamento non coperto dall'indice |

`EXPLAIN` mostra il piano stimato; `EXPLAIN ANALYZE` lo esegue e mostra i tempi reali. Confrontate le righe stimate con quelle effettive: una grande differenza indica statistiche obsolete o query poco selettive.

#### Pattern di query

```sql
-- Paginazione keyset (più stabile dell'OFFSET grande)
SELECT id, testo FROM domande
WHERE argomento_id = 7 AND id > 120
ORDER BY id
LIMIT 20;

-- Deduplica con window function
WITH ranked AS (
  SELECT r.*, ROW_NUMBER() OVER (
    PARTITION BY tentativo_id, domanda_id ORDER BY id DESC
  ) AS rn
  FROM risposte r
)
SELECT * FROM ranked WHERE rn = 1;
```

- `WHERE` filtra prima dell'aggregazione, `HAVING` dopo: non usate `HAVING` per filtri semplici.
- `ORDER BY` + `LIMIT` senza indice adeguato produce filesort.
- `SELECT *` trasferisce più dati del necessario e rompe i covering index.
- `OFFSET` alto degenera: la keyset pagination usa l'ultimo valore visto.
- Con `ONLY_FULL_GROUP_BY`, ogni colonna non aggregata deve essere nel `GROUP BY`.

#### UPSERT e operazioni massive

```sql
INSERT INTO argomenti (slug, titolo)
VALUES ('html', 'HTML'), ('css', 'CSS') AS nuovo
ON DUPLICATE KEY UPDATE titolo = nuovo.titolo;

INSERT IGNORE INTO opzioni (domanda_id, testo, posizione)
VALUES (1, 'Opzione A', 1);
```

`ON DUPLICATE KEY UPDATE` è l'upsert nativo. `INSERT IGNORE` trasforma gli errori in warning: usatelo solo se sapete quali errori state ignorando. `REPLACE` cancella e reinserisce (trigger e FK incluse): spesso non è ciò che volete. Per import massivi preferite multi-row insert o `LOAD DATA` dentro transazioni controllate.

#### JSON, full-text e tipi speciali

```sql
ALTER TABLE domande
  ADD COLUMN meta JSON,
  ADD COLUMN livello_estratto TINYINT
    GENERATED ALWAYS AS (meta->>'$.livello') STORED;

CREATE INDEX idx_meta_livello ON domande (livello_estratto);

SELECT id FROM domande
WHERE MATCH(testo, spiegazione) AGAINST ('indice composto' IN BOOLEAN MODE);
```

- Le funzioni JSON (`JSON_EXTRACT`, `->`, `->>`) sono comode ma gli indici richiedono colonne generate.
- Il full-text index serve per ricerca testuale; la rilevanza si legge con `MATCH ... AGAINST`.
- Per lingue diverse dall'inglese valutate parser e stopword adeguati (o un motore di ricerca dedicato).
- Non usate JSON per dati che devono essere filtrati e aggregati di frequente: normalizzate.

#### Date, timezone e charset

```sql
SELECT UTC_TIMESTAMP(3);
SELECT CONVERT_TZ(creato_il, '+00:00', 'Europe/Rome') FROM tentativi;
SELECT DATE_ADD(NOW(), INTERVAL 7 DAY);
```

- `DATETIME` non ha timezone; `TIMESTAMP` converte in base alla sessione. Scegliete una convenzione e documentatela.
- Salvate in **UTC** e convertite solo per la visualizzazione.
- `utf8mb4` è obbligatorio per emoji e caratteri fuori dal BMP; verificate collation a livello di database, tabella e connessione.
- Le collation `_ci` sono case-insensitive, `_bin` confrontano i byte.

#### Backup, sicurezza e operazioni

- `mysqldump --single-transaction --routines --triggers` per un backup coerente di InnoDB.
- Testate il **restore**, non solo il backup. Definite RPO/RTO.
- Binlog + backup per point-in-time recovery.
- Utente applicativo con privilegi minimi: niente `DROP`, niente `GRANT`, niente root.
- Connessioni TLS, password robuste, rotazione e audit degli accessi.
- Pool di connessioni dimensionato: ogni connessione costa memoria sul server.
- Monitorate slow query log, connessioni attive, lock wait e spazio disco.

#### Viste, procedure e trigger

Le viste incapsulano query di reporting e possono semplificare i permessi. Le procedure raggruppano operazioni, ma sono più difficili da versionare e testare. I trigger sono potenti e pericolosi: logica nascosta, effetti a cascata e debug complesso. Preferite la logica applicativa, usate i trigger solo per invarianti semplici e documentate ogni routine con una migrazione.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Creare e popolare**
Crea il database `palestra_sql` e la tabella `studenti` (id, nome, email, livello, creato_il). Inserisci 5 studenti, poi seleziona tutti ordinati per nome.
- **Criterio:** tipi corretti, email `UNIQUE`, `utf8mb4`.

**1.2 — Filtri e ordinamenti**
Sulla tabella studenti: cerca per livello, cerca per email parziale, ordina per data di creazione, limita a 3 risultati.
- **Criterio:** usi `WHERE`, `LIKE`, `ORDER BY`, `LIMIT` senza errori.

**1.3 — Modifica e cancellazione**
Aggiorna il livello di uno studente, cancella uno studente, verifica l'impatto. Poi annulla con una transazione di prova.
- **Criterio:** sai spiegare la differenza tra `DELETE` e `TRUNCATE`.

**1.4 — Join base**
Crea `argomenti` e collega `domande` con una FK. Scrivi una query che mostri domanda + titolo argomento.
- **Criterio:** nessuna domanda orfana; `INNER JOIN` corretto.

---

### L2 — Intermedio

**2.1 — Schema quiz**
Implementa le tabelle `utenti`, `argomenti`, `domande`, `opzioni`, `tentativi`, `risposte` con FK, vincoli e indici. Motiva ogni indice.
- **Criterio:** lo schema passa una review; nessun dato duplicabile.

**2.2 — Query di reporting**
Per ogni argomento: numero domande, numero risposte, tasso di correttezza, tempo medio. Solo argomenti con almeno 10 risposte.
- **Criterio:** `GROUP BY` + `HAVING`; risultati verificabili a mano su un dataset piccolo.

**2.3 — Vincoli**
Aggiungi: livello 1–4, una sola opzione corretta per domanda (o più, se decidi così), email unica, `ON DELETE CASCADE` dove sensato.
- **Criterio:** i test di inserimento invalido falliscono come previsto.

**2.4 — Indici**
Data una query lenta su `risposte(domanda_id, corretta)`, aggiungi l'indice giusto e confronta `EXPLAIN` prima/dopo.
- **Criterio:** il piano passa da full scan a range/index scan.

**2.5 — Backup e ripristino**
Esegui un dump con `mysqldump`, cancella i dati in una copia, ripristina e verifica i conteggi.
- **Criterio:** procedura documentata passo-passo e testata.

---

### L3 — Avanzato

**3.1 — Transazione di invio tentativo**
Scrivi la transazione che inserisce tentativo + risposte + aggiorna punteggio. Se una risposta è invalida, rollback completo.
- **Criterio:** nessun tentativo senza risposte; nessun punteggio incoerente.

**3.2 — Analytics per docente**
Query con window function per: ultimo tentativo per studente, media mobile degli ultimi 5 tentativi, classifica per classe.
- **Criterio:** usa `ROW_NUMBER`/`AVG OVER`; nessuna sottoquery correlata ridondante.

**3.3 — Soft delete**
Aggiungi `eliminato_il` alle domande. Le query pubbliche escludono le eliminate, quelle admin le vedono. Crea una vista `domande_attive`.
- **Criterio:** i report non contano le domande eliminate.

**3.4 — Query lenta**
Analizza una query con `EXPLAIN ANALYZE`. Proponi indice o riscrittura, misura il miglioramento, verifica che non peggiori le scritture.
- **Criterio:** report con piano prima/dopo e tempi reali.

**3.5 — Viste e riepiloghi**
Crea una vista `progresso_studente` con: utente, argomento, tentativi, media, ultimo tentativo, livello consigliato.
- **Criterio:** la vista è usabile dall'API senza join complessi lato applicazione.

---

### L4 — Esperto

**4.1 — Schema multiutente scalabile**
Estendi lo schema per: classi, iscrizioni, docenti, assegnazioni, codici invito, ruoli. Gestisci uno studente in più classi e un docente con più classi.
- **Criterio:** nessuna ridondanza; integrità referenziale completa; query di accesso per classe.

**4.2 — Partizionamento e retention**
I tentativi crescono di milioni di righe. Progetta partizionamento per data (o archivio), retention a 24 mesi, job di pulizia e impatto sulle query.
- **Criterio:** piano scritto con soglie, rischi e rollback.

**4.3 — Sicurezza dei ruoli**
Definisci utenti DB distinti per API, worker AI e analytics. Permessi minimi, revoca, rotazione password. Verifica con test di accesso negato.
- **Criterio:** il worker AI non può cancellare utenti.

**4.4 — Capacity planning**
Stima: 5.000 studenti, 20 quiz/mese, 10 domande/quiz, 3 anni. Calcola righe, GB, IOPS attese e dimensione indici. Proponi scaling verticale/orizzontale.
- **Criterio:** stime con assunzioni esplicite e margine.

**4.5 — Disaster recovery**
Definisci RPO/RTO, backup full + binlog, replica, test di ripristino trimestrale. Simula la perdita del DB primario.
- **Criterio:** runbook con comandi e responsabili; ripristino cronometrato.

---

## 4. Quiz di verifica

1. Differenza tra `PRIMARY KEY` e `UNIQUE`?
2. Cosa fa `ON DELETE CASCADE`?
3. Perché `SELECT *` è sconsigliato in produzione?
4. Cos'è un indice composito e da cosa dipende l'ordine delle colonne?
5. Differenza tra `WHERE` e `HAVING`?
6. Cosa garantisce una transazione ACID?
7. Perché `EXPLAIN` è importante?

<details>
<summary>Risposte</summary>

1. La PK identifica la riga, è unica e non null; `UNIQUE` impone unicità ma può ammettere più null (a seconda del DB) e non è necessariamente la chiave primaria.
2. Quando la riga padre viene eliminata, elimina automaticamente le righe figlie collegate.
3. Trasferisce colonne inutili, impedisce l'uso di indici di copertura e rende fragile il codice ai cambi di schema.
4. Un indice su più colonne; l'ordine conta perché il DB può usarlo efficacemente solo partendo dalle colonne iniziali (prefisso sinistro).
5. `WHERE` filtra le righe prima dell'aggregazione; `HAVING` filtra i gruppi dopo l'aggregazione.
6. Atomicità, coerenza, isolamento, durabilità.
7. Mostra come il DB esegue la query (indici usati, full scan, join), permettendo di ottimizzare con dati alla mano.

</details>

---

## 5. Mini-progetto del modulo

**"Database RipassoAI"**

Consegna:

- script `schema.sql` completo e idempotente;
- `seed.sql` con 3 classi, 20 studenti, 10 argomenti, 100 domande, 300 tentativi;
- 10 query di reporting documentate;
- 3 indici motivati con `EXPLAIN` prima/dopo;
- procedura di backup/ripristino testata;
- `README.md` con modello ER (testo o Mermaid) e scelte di design.

**Criterio di eccellenza:** nessuna query dell'API richiede più di 50 ms su 1M di risposte simulate.

---

## 6. AI pairing

```text
Agisci come DBA MySQL 8.
Ecco lo schema e una query lenta con EXPLAIN.
1) Spiega il piano in italiano semplice.
2) Proponi massimo 2 modifiche (indice o riscrittura).
3) Mostra il costo atteso e i rischi.
Non inventare colonne che non esistono.
```

```text
Genera un dataset di test realistico per la tabella tentativi:
5.000 studenti, 12 mesi, distribuzione non uniforme dei livelli.
Fornisci uno script SQL o Node che lo inserisca in batch.
Spiega come evitare di bloccare il DB durante il seed.
```

**Verifica:** esegui su un DB di test, controlla i conteggi, misura i tempi, prova a rompere i vincoli. L'AI tende a creare indici inutili e a dimenticare le FK.

---

## 7. Checklist di uscita

- [ ] Progetto uno schema normalizzato con FK e vincoli.
- [ ] Scrivo join e aggregazioni senza guardare esempi.
- [ ] So leggere `EXPLAIN` e motivare un indice.
- [ ] Uso transazioni per operazioni multi-tabella.
- [ ] Non concateno mai input nelle query.
- [ ] Ho testato backup e ripristino.
- [ ] Ho consegnato schema, seed e report.
