-- =====================================================================
-- RipassoAI — DDL di riferimento per la gestione delle schede
-- MySQL 8.0.16+ (CHECK constraints, indici DESC, JSON)
--
-- Modello concettuale: docs/schema-er-schede.md
-- Ordine di creazione rispetta le dipendenze delle foreign key.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. Tenant e identità
-- ---------------------------------------------------------------------

CREATE TABLE scuola (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome        VARCHAR(150)    NOT NULL,
  slug        VARCHAR(80)     NOT NULL,
  creato_il   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_scuola_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE utente (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scuola_id         BIGINT UNSIGNED NOT NULL,
  email             VARCHAR(255)    NOT NULL,
  password_hash     VARCHAR(255)    NOT NULL,
  nome              VARCHAR(100)    NOT NULL,
  ruolo             ENUM('STUDENTE', 'DOCENTE', 'ADMIN') NOT NULL DEFAULT 'STUDENTE',
  email_verificata  BOOLEAN         NOT NULL DEFAULT FALSE,
  creato_il         DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_utente_email (email),
  KEY ix_utente_scuola_ruolo (scuola_id, ruolo),
  CONSTRAINT fk_utente_scuola
    FOREIGN KEY (scuola_id) REFERENCES scuola (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE corso (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scuola_id   BIGINT UNSIGNED NOT NULL,
  titolo      VARCHAR(150)    NOT NULL,
  codice      VARCHAR(40)     NOT NULL,
  descrizione TEXT            NULL,
  attivo      BOOLEAN         NOT NULL DEFAULT TRUE,
  creato_il   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_corso_scuola_codice (scuola_id, codice),
  KEY ix_corso_scuola_attivo (scuola_id, attivo),
  CONSTRAINT fk_corso_scuola
    FOREIGN KEY (scuola_id) REFERENCES scuola (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE iscrizione_corso (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  corso_id       BIGINT UNSIGNED NOT NULL,
  utente_id      BIGINT UNSIGNED NOT NULL,
  iscritto_il    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completato_il  DATE            NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_iscrizione_corso (corso_id, utente_id),
  KEY ix_iscrizione_corso_utente (utente_id),
  CONSTRAINT fk_iscrizione_corso_corso
    FOREIGN KEY (corso_id) REFERENCES corso (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_iscrizione_corso_utente
    FOREIGN KEY (utente_id) REFERENCES utente (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE classe (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scuola_id      BIGINT UNSIGNED NOT NULL,
  corso_id       BIGINT UNSIGNED NOT NULL,
  nome           VARCHAR(100)    NOT NULL,
  codice_invito  VARCHAR(12)     NOT NULL,
  docente_id     BIGINT UNSIGNED NOT NULL,
  creato_il      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_classe_codice_invito (codice_invito),
  KEY ix_classe_corso_docente (corso_id, docente_id),
  KEY ix_classe_scuola (scuola_id),
  CONSTRAINT fk_classe_scuola
    FOREIGN KEY (scuola_id) REFERENCES scuola (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_classe_corso
    FOREIGN KEY (corso_id) REFERENCES corso (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_classe_docente
    FOREIGN KEY (docente_id) REFERENCES utente (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE iscrizione_classe (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  classe_id  BIGINT UNSIGNED NOT NULL,
  utente_id  BIGINT UNSIGNED NOT NULL,
  creato_il  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_iscrizione_classe (classe_id, utente_id),
  KEY ix_iscrizione_classe_utente (utente_id),
  CONSTRAINT fk_iscrizione_classe_classe
    FOREIGN KEY (classe_id) REFERENCES classe (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_iscrizione_classe_utente
    FOREIGN KEY (utente_id) REFERENCES utente (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- 2. Catalogo didattico
-- ---------------------------------------------------------------------

CREATE TABLE modulo (
  id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  corso_id  BIGINT UNSIGNED NOT NULL,
  numero    SMALLINT UNSIGNED NOT NULL,
  titolo    VARCHAR(150)    NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_modulo_corso_numero (corso_id, numero),
  CONSTRAINT chk_modulo_numero CHECK (numero > 0),
  CONSTRAINT fk_modulo_corso
    FOREIGN KEY (corso_id) REFERENCES corso (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE argomento (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  modulo_id   BIGINT UNSIGNED NOT NULL,
  nome        VARCHAR(100)    NOT NULL,
  slug        VARCHAR(80)     NOT NULL,
  descrizione TEXT            NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_argomento_modulo_slug (modulo_id, slug),
  CONSTRAINT fk_argomento_modulo
    FOREIGN KEY (modulo_id) REFERENCES modulo (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE utente_argomento (
  utente_id          BIGINT UNSIGNED NOT NULL,
  argomento_id       BIGINT UNSIGNED NOT NULL,
  mastery            DECIMAL(5,4)    NOT NULL DEFAULT 0.0000,
  tentativi_totali   INT UNSIGNED    NOT NULL DEFAULT 0,
  ultimo_ripasso_il  DATETIME(3)     NULL,
  aggiornato_il      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
                                      ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (utente_id, argomento_id),
  KEY ix_utente_argomento_argomento (argomento_id),
  CONSTRAINT chk_utente_argomento_mastery CHECK (mastery BETWEEN 0 AND 1),
  CONSTRAINT fk_utente_argomento_utente
    FOREIGN KEY (utente_id) REFERENCES utente (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_utente_argomento_argomento
    FOREIGN KEY (argomento_id) REFERENCES argomento (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fonte (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  corso_id    BIGINT UNSIGNED NULL,
  tipo        ENUM('MODULO', 'APPUNTI', 'DOCUMENTAZIONE', 'PROGETTO', 'ALTRO')
                              NOT NULL DEFAULT 'ALTRO',
  titolo      VARCHAR(200)    NOT NULL,
  riferimento VARCHAR(500)    NULL,
  creato_il   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_fonte_corso_tipo (corso_id, tipo),
  CONSTRAINT fk_fonte_corso
    FOREIGN KEY (corso_id) REFERENCES corso (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- 3. Scheda e sezioni
-- ---------------------------------------------------------------------

CREATE TABLE scheda (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  utente_id          BIGINT UNSIGNED NOT NULL,
  corso_id           BIGINT UNSIGNED NOT NULL,
  classe_id          BIGINT UNSIGNED NULL,
  titolo             VARCHAR(150)    NOT NULL,
  versione           SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  stato              ENUM('BOZZA', 'GENERATA', 'PUBBLICATA', 'ARCHIVIATA')
                                       NOT NULL DEFAULT 'BOZZA',
  data_esame         DATE            NULL,
  giorni_all_esame   SMALLINT        NULL,
  tempo_stimato_min  SMALLINT UNSIGNED NULL,
  obiettivo          TEXT            NULL,
  generata_da        ENUM('AI', 'UMANO', 'MISTA') NOT NULL DEFAULT 'MISTA',
  modello_ai         VARCHAR(80)     NULL,
  snapshot_json      JSON            NULL,
  creata_il          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  pubblicata_il      DATETIME(3)     NULL,
  aggiornata_il      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
                                      ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_scheda_utente_corso_versione (utente_id, corso_id, versione),
  KEY ix_scheda_utente_data (utente_id, creata_il DESC),
  KEY ix_scheda_utente_stato (utente_id, stato),
  KEY ix_scheda_corso_stato (corso_id, stato),
  CONSTRAINT chk_scheda_giorni CHECK (giorni_all_esame IS NULL OR giorni_all_esame >= 0),
  CONSTRAINT chk_scheda_pubblicata CHECK (stato <> 'PUBBLICATA' OR pubblicata_il IS NOT NULL),
  CONSTRAINT fk_scheda_utente
    FOREIGN KEY (utente_id) REFERENCES utente (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_scheda_corso
    FOREIGN KEY (corso_id) REFERENCES corso (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_scheda_classe
    FOREIGN KEY (classe_id) REFERENCES classe (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE scheda_argomento (
  id                       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scheda_id                BIGINT UNSIGNED NOT NULL,
  argomento_id             BIGINT UNSIGNED NOT NULL,
  mastery_snapshot         DECIMAL(5,4)    NOT NULL,
  ultimo_ripasso_snapshot  DATETIME(3)     NULL,
  tentativi_snapshot       INT UNSIGNED    NOT NULL DEFAULT 0,
  priorita                 ENUM('CRITICA', 'ALTA', 'MEDIA', 'BASSA') NOT NULL,
  ruolo                    ENUM('STANDARD', 'FORZA', 'LACUNA') NOT NULL DEFAULT 'STANDARD',
  evidenza                 TEXT            NULL,
  motivazione_lacuna       TEXT            NULL,
  azione                   TEXT            NULL,
  ordine                   SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_scheda_argomento (scheda_id, argomento_id),
  UNIQUE KEY uq_scheda_argomento_ordine (scheda_id, ordine),
  KEY ix_scheda_argomento_argomento (argomento_id),
  CONSTRAINT chk_scheda_argomento_mastery
    CHECK (mastery_snapshot BETWEEN 0 AND 1),
  CONSTRAINT chk_scheda_argomento_forza
    CHECK (ruolo <> 'FORZA' OR evidenza IS NOT NULL),
  CONSTRAINT chk_scheda_argomento_lacuna
    CHECK (ruolo <> 'LACUNA' OR motivazione_lacuna IS NOT NULL),
  CONSTRAINT fk_scheda_argomento_scheda
    FOREIGN KEY (scheda_id) REFERENCES scheda (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_scheda_argomento_argomento
    FOREIGN KEY (argomento_id) REFERENCES argomento (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE scheda_fonte (
  scheda_id  BIGINT UNSIGNED NOT NULL,
  fonte_id   BIGINT UNSIGNED NOT NULL,
  ordine     SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (scheda_id, fonte_id),
  UNIQUE KEY uq_scheda_fonte_ordine (scheda_id, ordine),
  CONSTRAINT fk_scheda_fonte_scheda
    FOREIGN KEY (scheda_id) REFERENCES scheda (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_scheda_fonte_fonte
    FOREIGN KEY (fonte_id) REFERENCES fonte (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE scheda_concetto (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scheda_id     BIGINT UNSIGNED NOT NULL,
  argomento_id  BIGINT UNSIGNED NULL,
  fonte_id      BIGINT UNSIGNED NOT NULL,
  titolo        VARCHAR(150)    NOT NULL,
  spiegazione   TEXT            NOT NULL,
  ordine        SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_scheda_concetto_ordine (scheda_id, ordine),
  KEY ix_scheda_concetto_argomento (argomento_id),
  KEY ix_scheda_concetto_fonte (fonte_id),
  CONSTRAINT chk_scheda_concetto_ordine CHECK (ordine BETWEEN 1 AND 7),
  CONSTRAINT fk_scheda_concetto_scheda
    FOREIGN KEY (scheda_id) REFERENCES scheda (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_scheda_concetto_argomento
    FOREIGN KEY (argomento_id) REFERENCES argomento (id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_scheda_concetto_fonte
    FOREIGN KEY (fonte_id) REFERENCES fonte (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE scheda_piano (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scheda_id      BIGINT UNSIGNED NOT NULL,
  giorno         TINYINT UNSIGNED NOT NULL,
  durata_min     SMALLINT UNSIGNED NOT NULL,
  attivita       TEXT            NOT NULL,
  output_atteso  VARCHAR(250)    NULL,
  completato_il  DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_scheda_piano_giorno (scheda_id, giorno),
  CONSTRAINT chk_scheda_piano_giorno CHECK (giorno BETWEEN 1 AND 7),
  CONSTRAINT fk_scheda_piano_scheda
    FOREIGN KEY (scheda_id) REFERENCES scheda (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE scheda_autovalutazione (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scheda_id    BIGINT UNSIGNED NOT NULL,
  testo        TEXT            NOT NULL,
  categoria    ENUM('SAPER_SPIEGARE', 'SAPER_FARE', 'DA_RIVEDERE') NOT NULL,
  ordine       SMALLINT UNSIGNED NOT NULL,
  spuntata_il  DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_scheda_autovalutazione_ordine (scheda_id, ordine),
  CONSTRAINT fk_scheda_autovalutazione_scheda
    FOREIGN KEY (scheda_id) REFERENCES scheda (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- 4. Quiz
-- ---------------------------------------------------------------------

CREATE TABLE domanda (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  argomento_id  BIGINT UNSIGNED NOT NULL,
  livello       ENUM('L1', 'L2', 'L3', 'L4') NOT NULL,
  testo         TEXT            NOT NULL,
  spiegazione   TEXT            NOT NULL,
  stato         ENUM('BOZZA', 'APPROVATA', 'RIFIUTATA', 'ARCHIVIATA')
                                NOT NULL DEFAULT 'BOZZA',
  origine       ENUM('AI', 'UMANO', 'MISTA') NOT NULL DEFAULT 'UMANO',
  fonte_id      BIGINT UNSIGNED NULL,
  creata_da     BIGINT UNSIGNED NULL,
  approvata_da  BIGINT UNSIGNED NULL,
  approvata_il  DATETIME(3)     NULL,
  creata_il     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_domanda_selezione (argomento_id, livello, stato),
  KEY ix_domanda_fonte (fonte_id),
  CONSTRAINT chk_domanda_approvata
    CHECK (stato <> 'APPROVATA'
           OR (approvata_da IS NOT NULL AND approvata_il IS NOT NULL)),
  CONSTRAINT fk_domanda_argomento
    FOREIGN KEY (argomento_id) REFERENCES argomento (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_domanda_fonte
    FOREIGN KEY (fonte_id) REFERENCES fonte (id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_domanda_creata_da
    FOREIGN KEY (creata_da) REFERENCES utente (id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_domanda_approvata_da
    FOREIGN KEY (approvata_da) REFERENCES utente (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE opzione (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  domanda_id  BIGINT UNSIGNED NOT NULL,
  testo       TEXT            NOT NULL,
  corretta    BOOLEAN         NOT NULL DEFAULT FALSE,
  ordine      TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_opzione_domanda_ordine (domanda_id, ordine),
  CONSTRAINT chk_opzione_ordine CHECK (ordine BETWEEN 1 AND 4),
  CONSTRAINT fk_opzione_domanda
    FOREIGN KEY (domanda_id) REFERENCES domanda (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE scheda_domanda (
  scheda_id   BIGINT UNSIGNED NOT NULL,
  domanda_id  BIGINT UNSIGNED NOT NULL,
  ordine     TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (scheda_id, domanda_id),
  UNIQUE KEY uq_scheda_domanda_ordine (scheda_id, ordine),
  KEY ix_scheda_domanda_domanda (domanda_id),
  CONSTRAINT chk_scheda_domanda_ordine CHECK (ordine BETWEEN 1 AND 10),
  CONSTRAINT fk_scheda_domanda_scheda
    FOREIGN KEY (scheda_id) REFERENCES scheda (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_scheda_domanda_domanda
    FOREIGN KEY (domanda_id) REFERENCES domanda (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tentativo (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  utente_id          BIGINT UNSIGNED NULL,
  scheda_id          BIGINT UNSIGNED NULL,
  origine            ENUM('SCHEDA', 'DIAGNOSTICO', 'ADATTIVO', 'ASSEGNAZIONE')
                                       NOT NULL DEFAULT 'SCHEDA',
  stato              ENUM('IN_CORSO', 'COMPLETATO', 'ABBANDONATO')
                                       NOT NULL DEFAULT 'IN_CORSO',
  iniziato_il        DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  finito_il          DATETIME(3)     NULL,
  risposte_totali    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  risposte_corrette  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  punteggio          DECIMAL(5,2)    NULL,
  PRIMARY KEY (id),
  KEY ix_tentativo_utente_data (utente_id, iniziato_il DESC),
  KEY ix_tentativo_scheda (scheda_id),
  KEY ix_tentativo_origine_stato (origine, stato),
  CONSTRAINT chk_tentativo_conteggi
    CHECK (risposte_corrette <= risposte_totali),
  CONSTRAINT chk_tentativo_punteggio
    CHECK (punteggio IS NULL OR punteggio BETWEEN 0 AND 100),
  CONSTRAINT chk_tentativo_date
    CHECK (finito_il IS NULL OR finito_il >= iniziato_il),
  CONSTRAINT fk_tentativo_utente
    FOREIGN KEY (utente_id) REFERENCES utente (id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_tentativo_scheda
    FOREIGN KEY (scheda_id) REFERENCES scheda (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE risposta (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tentativo_id  BIGINT UNSIGNED NOT NULL,
  domanda_id    BIGINT UNSIGNED NOT NULL,
  opzione_id    BIGINT UNSIGNED NULL,
  corretta      BOOLEAN         NOT NULL DEFAULT FALSE,
  tempo_ms      INT UNSIGNED    NULL,
  risposto_il   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_risposta_tentativo_domanda (tentativo_id, domanda_id),
  KEY ix_risposta_domanda (domanda_id),
  KEY ix_risposta_opzione (opzione_id),
  CONSTRAINT fk_risposta_tentativo
    FOREIGN KEY (tentativo_id) REFERENCES tentativo (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_risposta_domanda
    FOREIGN KEY (domanda_id) REFERENCES domanda (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_risposta_opzione
    FOREIGN KEY (opzione_id) REFERENCES opzione (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- 5. Flashcard e ripetizione spaziata
-- ---------------------------------------------------------------------

CREATE TABLE flashcard (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  utente_id         BIGINT UNSIGNED NOT NULL,
  argomento_id      BIGINT UNSIGNED NOT NULL,
  fonte_id          BIGINT UNSIGNED NULL,
  fronte            TEXT            NOT NULL,
  retro             TEXT            NOT NULL,
  facilita          DECIMAL(3,2)    NOT NULL DEFAULT 2.50,
  intervallo_giorni INT UNSIGNED    NOT NULL DEFAULT 1,
  ripasso_il        DATE            NOT NULL,
  stato             ENUM('ATTIVA', 'SOSPESA', 'ARCHIVIATA') NOT NULL DEFAULT 'ATTIVA',
  creata_il         DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_flashcard_utente_ripasso (utente_id, ripasso_il),
  KEY ix_flashcard_argomento (argomento_id),
  KEY ix_flashcard_fonte (fonte_id),
  CONSTRAINT chk_flashcard_facilita CHECK (facilita BETWEEN 1.30 AND 2.80),
  CONSTRAINT chk_flashcard_intervallo CHECK (intervallo_giorni >= 1),
  CONSTRAINT fk_flashcard_utente
    FOREIGN KEY (utente_id) REFERENCES utente (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_flashcard_argomento
    FOREIGN KEY (argomento_id) REFERENCES argomento (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_flashcard_fonte
    FOREIGN KEY (fonte_id) REFERENCES fonte (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE scheda_flashcard (
  scheda_id    BIGINT UNSIGNED NOT NULL,
  flashcard_id BIGINT UNSIGNED NOT NULL,
  ordine       TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (scheda_id, flashcard_id),
  UNIQUE KEY uq_scheda_flashcard_ordine (scheda_id, ordine),
  KEY ix_scheda_flashcard_flashcard (flashcard_id),
  CONSTRAINT chk_scheda_flashcard_ordine CHECK (ordine BETWEEN 1 AND 10),
  CONSTRAINT fk_scheda_flashcard_scheda
    FOREIGN KEY (scheda_id) REFERENCES scheda (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_scheda_flashcard_flashcard
    FOREIGN KEY (flashcard_id) REFERENCES flashcard (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE flashcard_ripasso (
  id                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  flashcard_id           BIGINT UNSIGNED NOT NULL,
  qualita                TINYINT UNSIGNED NOT NULL,
  intervallo_precedente  INT UNSIGNED    NOT NULL,
  intervallo_nuovo       INT UNSIGNED    NOT NULL,
  facilita_precedente    DECIMAL(3,2)    NOT NULL,
  facilita_nuova         DECIMAL(3,2)    NOT NULL,
  ripassata_il           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_flashcard_ripasso_carta_data (flashcard_id, ripassata_il DESC),
  CONSTRAINT chk_flashcard_ripasso_qualita CHECK (qualita BETWEEN 0 AND 5),
  CONSTRAINT chk_flashcard_ripasso_facilita
    CHECK (facilita_precedente BETWEEN 1.30 AND 2.80
       AND facilita_nuova BETWEEN 1.30 AND 2.80),
  CONSTRAINT fk_flashcard_ripasso_flashcard
    FOREIGN KEY (flashcard_id) REFERENCES flashcard (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
