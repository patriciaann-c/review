# RipassoAI — Corso completo di AI Web Development

> Da zero alla piattaforma multiutente con cui centinaia di studenti ripassano gli argomenti e si preparano all'esame finale.

Questo repository è un **piano didattico completo**: teoria essenziale, esercizi graduati per ogni argomento, quiz di verifica, mini-progetti e un progetto finale che mette insieme tutto lo stack.

---

## 1. La visione

Non si impara a programmare guardando video: si impara **costruendo, sbagliando e correggendo**. L'AI è il vostro tirocinante velocissimo: sa scrivere codice, ma non sa cosa volete davvero, non conosce il contesto della vostra classe e a volte inventa. Il corso insegna a:

1. **Capire** il problema prima di chiedere codice.
2. **Scrivere prompt** precisi, con contesto, vincoli e formato di output.
3. **Verificare** ogni risposta con test, documentazione e buon senso.
4. **Integrare** l'AI in un prodotto reale, sicuro e multiutente.

### Il prodotto finale: RipassoAI

Una web app in cui:

- **Lo studente** si registra, entra in una classe, fa un test diagnostico, riceve quiz adattivi dal livello base a quello esperto, genera schede di ripasso personalizzate, ripassa con flashcard a ripetizione spaziata e chatta con un tutor AI basato sui materiali del corso.
- **Il docente** crea classi, assegna quiz, vede statistiche per argomento e per studente, approva le domande generate dall'AI.
- **L'amministratore** gestisce utenti, ruoli, cataloghi e monitora costi/sicurezza dell'AI.

Stack: **HTML, CSS, JavaScript, React, Node.js, MySQL, Express, Prisma, LangChain, agenti e skill AI**.

---

## 2. Il sistema dei livelli

Ogni argomento ha esercizi su quattro livelli. I livelli non sono "difficoltà" astratta: sono **cosa sapete fare senza aiuto**.

| Livello | Nome | Obiettivo (Bloom) | Cosa sapete fare | Uso dell'AI |
|---|---|---|---|---|
| **L1** | Base | Riconoscere / ricordare | Leggere, modificare, completare codice esistente; usare la sintassi corretta | Chiedere spiegazioni ed esempi minimi |
| **L2** | Intermedio | Applicare | Costruire da zero un componente o una feature con requisiti chiari | Generare bozze, poi correggerle e testarle |
| **L3** | Avanzato | Analizzare / valutare | Integrare più tecnologie, gestire errori, stati, accessibilità e performance | Usare l'AI per review, test e refactoring |
| **L4** | Esperto | Creare / progettare | Progettare architetture, prendere decisioni motivate, mettere in sicurezza e scalare | Progettare agenti e pipeline AI, valutarne l'affidabilità |

> **Regola d'oro:** un esercizio è superato solo se sapete **spiegare** perché funziona e cosa succede se lo rompete.

---

## 3. Metodo didattico

Ogni modulo vale circa **6–10 ore** e segue sempre lo stesso ritmo:

| Fase | Tempo | Attività |
|---|---|---|
| Teoria attiva | 20% | Leggere il cheat sheet, fare domande, spiegare a voce |
| Pratica guidata | 25% | Esercizi L1–L2 con il professore |
| Pratica autonoma | 35% | Esercizi L3–L4, mini-progetto, debug |
| AI pairing | 20% | Prompt, review incrociata, test generation, valutazione critica |

**Il ciclo di ogni esercizio:**

1. **Prevedi** — cosa dovrebbe succedere? Scrivilo prima di eseguire.
2. **Esegui** — scrivi o fai generare il codice.
3. **Verifica** — test, validatore, DevTools, query SQL, prova manuale.
4. **Spiega** — in 3 righe, cosa hai imparato e cosa rifaresti diverso.
5. **Rifattorizza** — rendi il codice più semplice, non più furbo.

### Le 7 regole del pair programming con l'AI

1. **Prima il problema, poi il prompt.** Se non sai descrivere l'input e l'output atteso, non sei pronto.
2. **Mai copiare senza capire.** Ogni riga accettata deve avere una spiegazione.
3. **Testa sempre.** L'AI non esegue il vostro contesto: il codice può sembrare giusto ed essere sbagliato.
4. **Mai segreti nel codice.** Chiavi API, password e token stanno in `.env`, mai su Git.
5. **Chiedi il perché, non solo il come.** "Spiegami questa scelta e mostrami due alternative".
6. **Diffida delle certezze.** L'AI hallucina librerie, API e versioni: verifica sulla documentazione ufficiale.
7. **Documenta le decisioni.** Un file `ADR.md` (Architecture Decision Record) vale più di dieci chat.

---

## 4. Calendario (12 settimane)

| Settimana | Moduli | Deliverable |
|---|---|---|
| 1 | HTML + CSS (parte 1) | Scheda di ripasso statica, accessibile e responsive |
| 2 | CSS (parte 2) + JavaScript (parte 1) | Tema della piattaforma + quiz engine base |
| 3 | JavaScript (parte 2) | Motore quiz con timer, punteggio e persistenza |
| 4 | React (parte 1) | Interfaccia quiz componentizzata |
| 5 | React (parte 2) | Dashboard studente con routing e stato |
| 6 | Node.js + MySQL | API e database della piattaforma |
| 7 | Express | API REST con validazione, errori e auth |
| 8 | Prisma | Persistenza tipizzata, migrazioni e seed |
| 9 | LangChain | Generazione e validazione automatica dei quiz |
| 10 | Skill e agenti AI + avvio progetto | Tutor AI con tool, memoria e guardrail; schema DB e auth |
| 11 | Progetto finale | Integrazione, test, sicurezza, deploy |
| 12 | Progetto finale | Demo, valutazione, esame simulato |

---

## 5. Mappa dei moduli

| # | Modulo | Competenze chiave | Deliverable |
|---|---|---|---|
| 01 | [HTML](moduli/01-html.md) | Semantica, form, accessibilità, SEO | Scheletro accessibile della scheda di ripasso |
| 02 | [CSS](moduli/02-css.md) | Layout, responsive, design token, animazioni | Design system e dashboard responsive |
| 03 | [JavaScript](moduli/03-javascript.md) | DOM, async, stato, storage, test | Motore quiz completo lato client |
| 04 | [React](moduli/04-react.md) | Componenti, hook, context, routing, test | UI della piattaforma quiz |
| 05 | [Node.js](moduli/05-nodejs.md) | Runtime, moduli, I/O, processi, tooling | CLI e servizi di supporto |
| 06 | [MySQL](moduli/06-mysql.md) | Schema, query, join, indici, transazioni | Database multiutente |
| 07 | [Express](moduli/07-express.md) | REST, middleware, auth, errori, sicurezza | API della piattaforma |
| 08 | [Prisma](moduli/08-prisma.md) | Modelli, relazioni, migrazioni, transazioni | Accesso dati tipizzato |
| 09 | [LangChain](moduli/09-langchain.md) | Prompt, structured output, RAG, eval | Pipeline di generazione quiz |
| 10 | [AI: skill e agenti](moduli/10-ai-skills-agenti.md) | Tool, memoria, orchestrazione, guardrail | Tutor e agente di valutazione |
| 11 | [Autenticazione e autorizzazione](moduli/11-autenticazione-autorizzazione.md) | Sessioni, JWT, OAuth, ruoli, RLS, attacchi web | Login sicuro con ruoli e policy RLS |
| — | [Progetto finale](progetto-finale.md) | Architettura, multiutenza, sicurezza, scalabilità | RipassoAI in produzione |
| — | [Banca quiz ed esami](esami/banca-quiz.md) | Ripasso e simulazione d'esame | 3 prove complete con soluzioni |
| — | [Esempio di scheda compilata](esami/esempio-scheda-ripasso.md) | Modello di output della piattaforma | Scheda pronta da personalizzare |

---

## 6. Come usare i file

- **Studente:** parti dal modulo 01, leggi il cheat sheet, fai gli esercizi L1 e L2, poi affronta L3 e L4. Tieni un `diario.md` con errori e scoperte.
- **Docente:** usa le checklist di uscita come griglia di valutazione; assegna un modulo a settimana; usa i quiz di modulo come exit ticket.
- **Team di progetto:** leggete `progetto-finale.md` prima della settimana 6, così ogni modulo produce un pezzo del prodotto.
- **Esame:** usate `esami/banca-quiz.md` per tre simulazioni cronometrate.

### Gestione di più studenti in classe

| Momento | Cosa fare | Perché |
|---|---|---|
| Inizio modulo | Exit ticket di 5 domande sul modulo precedente | Recupera le lacune prima di aggiungerne altre |
| Laboratorio | Gruppi da 3 con ruoli ruotati: driver, navigator, reviewer | Nessuno guarda passivamente; il reviewer controlla l'AI |
| Metà modulo | Code review incrociata con checklist | La spiegazione è la prova della comprensione |
| Fine modulo | Demo di 3 minuti + 1 domanda "perché" | Verifica il processo, non solo il risultato |
| Ogni venerdì | Quiz di 10 domande e aggiornamento della scheda | Ripasso distribuito e tracciabile |

**Regole per gestire il volume:**

- Chi finisce prima fa da peer tutor o affronta gli esercizi L4: non aggiungete esercizi extra uguali per tutti.
- Tenete un foglio condiviso con: studente, modulo, esercizi completati, lacuna principale, prossima azione.
- Non correggete tutto voi: usate rubric e review tra pari, intervenite solo sui blocchi concettuali.
- Loggate i prompt usati con l'AI: servono per capire *come* ha risolto, non solo *cosa* ha prodotto.
- Un errore ricorrente in 5 studenti è un problema di lezione, non di studenti: rifate la spiegazione.

---

## 7. Setup dell'ambiente

```bash
# Versioni consigliate
Node.js >= 20
npm >= 10
MySQL >= 8
Git >= 2.40

# Editor consigliati
VS Code + estensioni: ESLint, Prettier, Prisma, MySQL, axe Accessibility Linter

# Verifica
node -v
npm -v
mysql --version
git --version
```

Struttura consigliata del progetto:

```text
ripasso-ai/
├── client/                 # React + Vite
├── server/                 # Express + Prisma
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── migrations/
│   │   └── seed.ts
│   └── src/
│       ├── routes/
│       ├── services/
│       ├── middleware/
│       ├── ai/
│       └── lib/
├── docs/
│   ├── ADR.md
│   └── api.md
├── .env.example
└── README.md
```

---

## 8. Valutazione finale (100 punti)

| Area | Punti | Criteri |
|---|---|---|
| Esercizi e quiz dei moduli | 20 | Completezza, correttezza, spiegazioni |
| Progetto di modulo | 20 | Requisiti, qualità del codice, test |
| Progetto finale — funzionalità | 25 | Flussi studente/docente/admin funzionanti |
| Progetto finale — qualità tecnica | 15 | Architettura, accessibilità, performance, sicurezza |
| Progetto finale — AI | 10 | Pipeline, valutazione, guardrail, costi |
| Esame orale e demo | 10 | Spiegazione delle decisioni e del codice |

**Soglia di sufficienza:** 60/100, con almeno 12/25 nelle funzionalità del progetto finale.

---

## 9. Regole di sicurezza e privacy (valgono da subito)

- Password **mai** in chiaro: hash con `bcrypt` o `argon2`.
- Token in cookie `httpOnly`, `secure`, `sameSite`; niente token in `localStorage` se potete evitarlo.
- Validare **sempre** input lato server (Zod), anche se il client valida già.
- Query parametrizzate o ORM: mai concatenare stringhe SQL.
- Ruoli e permessi verificati **sul server**, non solo nascosti nella UI.
- Dati degli studenti = dati personali: minimizzazione, retention, diritto alla cancellazione (GDPR).
- Prompt e log AI: non inviare PII non necessarie; oscurare email e nomi nei log.
- Rate limiting su auth, quiz e chiamate AI (i token costano).
- Backup del database e piano di ripristino provati almeno una volta.

---

## 10. Indice rapido

- [Modulo 01 — HTML](moduli/01-html.md)
- [Modulo 02 — CSS](moduli/02-css.md)
- [Modulo 03 — JavaScript](moduli/03-javascript.md)
- [Modulo 04 — React](moduli/04-react.md)
- [Modulo 05 — Node.js](moduli/05-nodejs.md)
- [Modulo 06 — MySQL](moduli/06-mysql.md)
- [Modulo 07 — Express](moduli/07-express.md)
- [Modulo 08 — Prisma](moduli/08-prisma.md)
- [Modulo 09 — LangChain](moduli/09-langchain.md)
- [Modulo 10 - Skill e agenti AI](moduli/10-ai-skills-agenti.md)
- [Modulo 11 - Autenticazione e autorizzazione](moduli/11-autenticazione-autorizzazione.md)
- [Progetto finale — RipassoAI](progetto-finale.md)
- [Banca quiz ed esami simulati](esami/banca-quiz.md)
- [Esempio di scheda di ripasso compilata](esami/esempio-scheda-ripasso.md)

> "L'AI non ti sostituisce: ti obbliga a essere più preciso. Chi non sa spiegare il problema, non merita la soluzione."
