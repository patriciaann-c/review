# Modulo 07 — Express

> **Livello:** intermedio · **Tempo:** 10 h · **Prerequisiti:** Node.js, MySQL
> **Deliverable:** API REST della piattaforma con autenticazione, ruoli e validazione.

---

## 1. Traguardi

Al termine del modulo sapete:

- progettare endpoint REST coerenti e prevedibili;
- usare middleware, router e gestione centralizzata degli errori;
- implementare registrazione/login con hash password e sessioni sicure;
- applicare autorizzazione per ruolo e per risorsa;
- validare input e output con Zod;
- proteggere l'API da abusi, injection e informazioni sensibili;
- testare le API con Supertest.

---

## 2. Concetti chiave (cheat sheet)

### Struttura minima

```js
import express from "express";
import helmet from "helmet";
import cors from "cors";
import cookieParser from "cookie-parser";

const app = express();

app.use(helmet());
app.use(cors({ origin: process.env.CLIENT_URL, credentials: true }));
app.use(express.json({ limit: "100kb" }));
app.use(cookieParser());

app.get("/health", (req, res) => res.json({ ok: true }));

// 404
app.use((req, res) => res.status(404).json({ error: "Not found" }));

// error handler (4 argomenti)
app.use((err, req, res, next) => {
  const status = err.status ?? 500;
  console.error({ event: "error", message: err.message, path: req.path });
  res.status(status).json({
    error: status === 500 ? "Errore interno" : err.message,
    ...(err.details ? { details: err.details } : {}),
  });
});

export default app;
```

### Router modulare

```js
// routes/quiz.js
import { Router } from "express";
export const quizRouter = Router();

quizRouter.get("/", listQuiz);
quizRouter.get("/:id", getQuiz);
quizRouter.post("/", requireAuth, requireRole("docente", "admin"), createQuiz);
```

```js
// app.js
app.use("/api/quiz", quizRouter);
```

### Status code corretti

| Codice | Uso |
|---|---|
| 200 | OK con body |
| 201 | Risorsa creata (con `Location`) |
| 204 | OK senza body (delete) |
| 400 | Input malformato |
| 401 | Non autenticato |
| 403 | Autenticato ma senza permesso |
| 404 | Risorsa inesistente |
| 409 | Conflitto (email già usata) |
| 422 | Validazione semantica fallita |
| 429 | Troppe richieste |
| 500 | Errore interno |

### Validazione con Zod

```js
import { z } from "zod";

export const creaDomandaSchema = z.object({
  testo: z.string().min(10).max(2000),
  argomentoId: z.coerce.number().int().positive(),
  livello: z.coerce.number().int().min(1).max(4),
  opzioni: z.array(
    z.object({
      testo: z.string().min(1).max(500),
      corretta: z.boolean(),
    })
  ).length(4).refine(opts => opts.filter(o => o.corretta).length === 1, {
    message: "Deve esserci esattamente una risposta corretta",
  }),
  spiegazione: z.string().max(4000).optional(),
});

export function validate(schema) {
  return (req, res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return res.status(422).json({
        error: "Dati non validi",
        details: result.error.flatten().fieldErrors,
      });
    }
    req.validated = result.data;
    next();
  };
}
```

### Auth: registrazione e login

```js
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

const SALT_ROUNDS = 12;

export async function register({ email, password, nome }) {
  const hash = await bcrypt.hash(password, SALT_ROUNDS);
  return prisma.utente.create({
    data: { email: email.toLowerCase(), passwordHash: hash, nome },
    select: { id: true, email: true, nome: true, ruolo: true },
  });
}

export async function login({ email, password }) {
  const utente = await prisma.utente.findUnique({ where: { email: email.toLowerCase() } });
  const ok = utente && await bcrypt.compare(password, utente.passwordHash);
  if (!ok) {
    const err = new Error("Credenziali non valide");
    err.status = 401;
    throw err; // messaggio identico per email inesistente e password errata
  }
  return jwt.sign(
    { sub: utente.id, ruolo: utente.ruolo },
    process.env.JWT_SECRET,
    { expiresIn: "2h", issuer: "ripasso-ai" }
  );
}
```

> Messaggio unico "Credenziali non valide": non rivelare se l'email esiste.

### Cookie httpOnly

```js
res.cookie("session", token, {
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "lax",
  maxAge: 2 * 60 * 60 * 1000,
  path: "/",
});
```

### Middleware di autenticazione

```js
export function requireAuth(req, res, next) {
  const token = req.cookies?.session ??
    req.headers.authorization?.replace(/^Bearer /, "");
  if (!token) return res.status(401).json({ error: "Non autenticato" });

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET, {
      issuer: "ripasso-ai",
    });
    req.user = { id: Number(payload.sub), ruolo: payload.ruolo };
    next();
  } catch {
    res.status(401).json({ error: "Sessione scaduta" });
  }
}

export function requireRole(...ruoli) {
  return (req, res, next) => {
    if (!req.user || !ruoli.includes(req.user.ruolo)) {
      return res.status(403).json({ error: "Permesso negato" });
    }
    next();
  };
}
```

### Autorizzazione per risorsa

```js
// Uno studente può leggere solo i propri tentativi.
app.get("/api/tentativi/:id", requireAuth, async (req, res) => {
  const tentativo = await prisma.tentativo.findUnique({
    where: { id: Number(req.params.id) },
  });
  if (!tentativo) return res.status(404).json({ error: "Non trovato" });
  if (tentativo.utenteId !== req.user.id && req.user.ruolo === "studente") {
    return res.status(403).json({ error: "Permesso negato" });
  }
  res.json(tentativo);
});
```

### Rate limiting

```js
import rateLimit from "express-rate-limit";

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: { error: "Troppi tentativi, riprova più tardi" },
});
```

### Paginazione

```js
// GET /api/domande?page=1&pageSize=20&livello=2
const page = Math.max(1, Number(req.query.page ?? 1));
const pageSize = Math.min(100, Math.max(1, Number(req.query.pageSize ?? 20)));

const where = req.query.livello ? { livello: Number(req.query.livello) } : {};
const [items, total] = await Promise.all([
  prisma.domanda.findMany({
    where,
    skip: (page - 1) * pageSize,
    take: pageSize,
    orderBy: { id: "asc" },
  }),
  prisma.domanda.count({ where }),
]);

res.json({ items, page, pageSize, total, pages: Math.ceil(total / pageSize) });
```

### Test con Supertest

```js
import request from "supertest";
import { test, expect } from "vitest";
import app from "../src/app.js";

test("GET /health risponde 200", async () => {
  const res = await request(app).get("/health");
  expect(res.status).toBe(200);
  expect(res.body).toEqual({ ok: true });
});

test("POST /api/auth/login con password errata → 401", async () => {
  const res = await request(app)
    .post("/api/auth/login")
    .send({ email: "studente@example.com", password: "sbagliata" });
  expect(res.status).toBe(401);
  expect(res.body.error).toBe("Credenziali non valide");
});
```

### Concetti fondamentali aggiuntivi

#### Ciclo di vita di una richiesta

```text
richiesta → helmet → cors → body parser → cookie → logger
          → router → middleware di route → handler → risposta
          → (errore?) → error handler centralizzato
```

- L'ordine dei middleware è l'ordine di esecuzione: un `app.use` registrato prima vale per tutte le route successive.
- `next()` passa al middleware successivo; `next(err)` salta all'error handler.
- Un handler che invia la risposta non deve chiamare `next()`.
- Il 404 va dopo tutte le route; l'error handler per ultimo, con **quattro** argomenti.
- In Express 5 le Promise rifiutate dagli handler async arrivano automaticamente all'error handler; in Express 4 serve un wrapper (`asyncHandler`).

```js
const asyncHandler = fn => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

router.get("/:id", asyncHandler(async (req, res) => {
  res.json(await service.trova(req.params.id));
}));
```

#### Struttura del progetto

```text
src/
├── app.js              # express app, senza listen
├── server.js           # listen + graceful shutdown
├── config.js           # validazione env all'avvio
├── routes/             # definizione endpoint
├── controllers/        # parsing request/response
├── services/           # regole di business
├── repositories/       # accesso dati
├── middleware/         # auth, validazione, errori
└── errors.js           # classi di errore
```

Separare `app.js` da `server.js` permette di testare l'app con Supertest senza aprire una porta. Validata la configurazione all'avvio: meglio fallire subito che a metà richiesta.

#### Validazione completa

```js
const listaQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
  livello: z.coerce.number().int().min(1).max(4).optional(),
  q: z.string().trim().max(100).optional(),
});

export const validateQuery = schema => (req, res, next) => {
  const result = schema.safeParse(req.query);
  if (!result.success) {
    return res.status(422).json({
      error: "Parametri non validi",
      details: result.error.flatten().fieldErrors,
    });
  }
  req.validatedQuery = result.data;
  next();
};
```

Validate **body, query, params e header** pertinenti. I query param sono sempre stringhe: usate `z.coerce`. Rifiutate chiavi sconosciute nei body con `.strict()`. Non fidatevi del `content-type` dichiarato dal client. Non restituite mai il body grezzo in caso di errore.

#### Errori tipizzati e logging

```js
export class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

app.use((err, req, res, next) => {
  const status = err.status ?? 500;
  const requestId = req.id;

  if (status >= 500) {
    console.error(JSON.stringify({
      level: "error", requestId, message: err.message,
      stack: err.stack, path: req.path, method: req.method,
    }));
  }

  res.status(status).json({
    error: status >= 500 ? "Errore interno" : err.message,
    requestId,
    ...(err.details ? { details: err.details } : {}),
  });
});
```

Distinguete errori **operativi** (input non valido, non trovato, permesso negato) da errori **di programmazione** (bug). Non esponete stack, query SQL o dettagli interni in produzione. Collegate un `requestId` a ogni log e risposta per la diagnosi.

#### Autenticazione: sessioni o token?

| Approccio | Pro | Contro |
|---|---|---|
| Cookie di sessione | Revoca semplice, `httpOnly` | Serve storage sessioni, CSRF |
| JWT in cookie | Stateless, scade da solo | Revoca difficile, rotazione refresh |
| JWT in header | Comodo per API/mobile | Rischio XSS se salvato in `localStorage` |

Regole minime:
- password con `bcrypt`/`argon2` e cost factor adeguato;
- cookie `httpOnly`, `secure` in produzione, `sameSite` coerente;
- refresh token con rotazione e revoca;
- logout che invalida davvero la sessione;
- messaggi identici per email inesistente e password errata;
- protezione da timing attack e da enumerazione utenti;
- rate limit su login, registrazione e reset password.

#### Autorizzazione e IDOR

L'autenticazione dice **chi sei**, l'autorizzazione **cosa puoi fare**. Controllate sempre la proprietà della risorsa, non solo il ruolo:

```js
async function getTentativo(req, res) {
  const tentativo = await prisma.tentativo.findUnique({
    where: { id: Number(req.params.id) },
  });
  if (!tentativo) throw new HttpError(404, "Non trovato");

  const èTuo = tentativo.utenteId === req.user.id;
  const èStaff = ["docente", "admin"].includes(req.user.ruolo);
  if (!èTuo && !èStaff) throw new HttpError(403, "Permesso negato");

  res.json(tentativo);
}
```

Un ID incrementale nell'URL è un invito all'**IDOR** (Insecure Direct Object Reference). Verificate sempre la proprietà a livello di query, non solo nell'interfaccia. Testate esplicitamente i casi 403.

#### CORS, CSRF e header di sicurezza

```js
app.use(cors({
  origin: ["https://app.example.com"],
  credentials: true,
  methods: ["GET", "POST", "PATCH", "DELETE"],
}));

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));
```

- Con `credentials: true` non potete usare `origin: "*"`.
- Il preflight `OPTIONS` va gestito prima delle route.
- Se usate cookie per l'autenticazione, proteggete le mutazioni con **CSRF token** o `sameSite=strict/lax` + verifica dell'`Origin`.
- Dietro un proxy impostate `app.set("trust proxy", 1)` per IP e rate limit corretti.
- Limitate la dimensione del body (`express.json({ limit: "100kb" })`).
- Per gli upload validate tipo, dimensione e nome file; non fidatevi dell'estensione.

#### Semantica HTTP e API

```js
// POST /api/domande → 201 + Location
res.status(201).location(`/api/domande/${creata.id}`).json(creata);

// DELETE /api/domande/:id → 204 senza body
res.status(204).end();

// PATCH parziale, PUT sostituzione completa
router.patch("/:id", validate(aggiornaSchema), aggiorna);
```

- `GET`, `HEAD`, `OPTIONS` sono safe; `PUT` e `DELETE` idempotenti; `POST` no.
- Usate `201` con `Location` per le creazioni, `204` per le cancellazioni riuscite.
- `409` per conflitti, `422` per validazione semantica, `429` per rate limit.
- Paginate con `page`/`pageSize` e restituite `total` e `pages` (o link).
- Versionate l'API (`/api/v1`) prima di rompere i client.
- Formato errore coerente (valutate RFC 7807 `application/problem+json`).

#### Performance e affidabilità

- Abilitate `compression` e caching (`ETag`, `Cache-Control`) per le risposte statiche.
- Evitate N+1: caricate le relazioni in una query o con `include` mirati.
- Paginate sempre; non restituite intere tabelle.
- Usate un pool di connessioni al DB e timeout espliciti verso servizi esterni.
- Non eseguite operazioni CPU-intensive nella request: code o worker.
- Healthcheck `/health` (liveness) e `/ready` (DB raggiungibile) separati.
- Graceful shutdown: smettete di accettare connessioni, attendete le richieste in corso, chiudete il pool.

#### Test delle API

```js
test("POST /api/domande senza titolo → 422", async () => {
  const res = await request(app)
    .post("/api/domande")
    .set("Authorization", `Bearer ${tokenDocente}`)
    .send({ livello: 2, opzioni: [] });

  expect(res.status).toBe(422);
  expect(res.body.details.testo).toBeDefined();
});
```

Testate il percorso felice, i casi limite e soprattutto gli errori (401, 403, 404, 409, 422, 429). Usate un database di test isolato e dati deterministici. Mockate i servizi esterni, non il database se potete usarlo vero. Verificate che le risposte non contengano `passwordHash` o altri campi sensibili.

#### Documentazione e operazioni

- OpenAPI/Swagger come contratto vivo, con esempi di richiesta e risposta.
- Documentate autenticazione, paginazione, errori e limiti.
- Variabili d'ambiente in `.env.example`, segreti fuori dal repository.
- Migrazioni come job separato, non all'avvio di ogni replica.
- Feature flag per rilasci graduali; deprecazione annunciata con preavviso.
- Log, metriche e trace correlati da un request id.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Hello API**
Crea un server con `/health`, `/api/version`, `/api/echo` (POST che restituisce il body). Gestisci 404 e JSON malformato.
- **Criterio:** status e content type corretti su tutti i casi.

**1.2 — CRUD in memoria**
API `/api/domande` con array in memoria: GET lista, GET per id, POST, PUT, DELETE. Validazione minima.
- **Criterio:** 404 per id inesistente; 201 con `Location` alla creazione.

**1.3 — Parametri e query**
Endpoint `/api/domande?livello=2&q=html&page=1`. Filtra, cerca e pagina. Gestisci parametri invalidi con 400.
- **Criterio:** nessun `NaN` passato al database.

**1.4 — Static**
Servi la build del client con `express.static` e fallback SPA su `index.html` per le route non API.
- **Criterio:** refresh su `/dashboard` non dà 404.

---

### L2 — Intermedio

**2.1 — Router modulare**
Dividi l'API in `auth`, `quiz`, `domande`, `tentativi`. Ogni router ha il suo file, controller e schema di validazione.
- **Criterio:** `app.js` non contiene logica di business.

**2.2 — Error handling**
Definisci una classe `HttpError` e un handler centrale. Gli errori di validazione rispondono 422 con dettagli per campo; gli errori imprevisti 500 senza stack trace al client.
- **Criterio:** nessun `try/catch` duplicato nei controller.

**2.3 — Validazione**
Valida body, query e params con Zod. Rifiuta campi sconosciuti (`strict()`). Sanifica le stringhe.
- **Criterio:** 15 test di validazione, inclusi payload oversized e tipi errati.

**2.4 — CORS e sicurezza base**
Configura CORS con origine esplicita, Helmet, body limit, disabilitazione `x-powered-by`, HTTPS in produzione.
- **Criterio:** un'origine non autorizzata non riceve `Access-Control-Allow-Origin`.

**2.5 — Paginazione e filtri**
Lista domande con paginazione, filtri per argomento/livello/attiva, ordinamento whitelisted. Risposta con metadati.
- **Criterio:** `pageSize` massimo 100; ordinamenti non whitelisted → 400.

---

### L3 — Avanzato

**3.1 — Registrazione e login**
Implementa `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/auth/me`. Hash bcrypt, cookie httpOnly, messaggi generici.
- **Criterio:** nessuna password nei log; email duplicata → 409.

**3.2 — Ruoli e risorse**
Uno studente vede solo i propri tentativi; un docente vede quelli delle sue classi; l'admin vede tutto. Middleware + query filtrata.
- **Criterio:** test di accesso incrociato tra due studenti e due docenti.

**3.3 — Rate limit e lockout**
Limita login (10/15min per IP), registrazione e generazione AI. Dopo 5 tentativi falliti sullo stesso account, blocco temporaneo.
- **Criterio:** il 429 include `Retry-After`; un utente legittimo non viene bloccato dagli altri.

**3.4 — API quiz**
`POST /api/tentativi` crea un tentativo e restituisce 10 domande senza la soluzione; `POST /api/tentativi/:id/risposte` valida e salva la risposta e, in modalità allenamento, restituisce esito e spiegazione; `POST /api/tentativi/:id/submit` calcola il punteggio finale. In modalità esame non restituire l'esito prima del submit.
- **Criterio:** in modalità esame la soluzione non è deducibile dalle risposte dell'API; in allenamento il feedback arriva solo dopo la risposta a quella domanda.

**3.5 — Test API**
Test con Supertest: auth, permessi, validazione, paginazione, errori. Database di test isolato, reset tra i test.
- **Criterio:** suite verde in CI, nessun test dipendente dall'ordine.

---

### L4 — Esperto

**4.1 — Architettura a layer**
Separa route → controller → service → repository. Definisci le responsabilità e le dipendenze consentite. Scrivi un ADR.
- **Criterio:** i controller non contengono query; i service non conoscono `req`/`res`.

**4.2 — Idempotenza e concorrenza**
Rendi idempotente il submit del tentativo con una chiave `Idempotency-Key`. Gestisci due submit simultanei senza duplicare risposte.
- **Criterio:** doppio click o retry di rete produce un solo tentativo.

**4.3 — Multi-tenancy**
Ogni richiesta è associata a una scuola/classe. Impedisci accessi cross-tenant anche con ID validi. Documenta la strategia (colonna `tenant_id` + policy applicativa).
- **Criterio:** test che tenta di leggere dati di un'altra scuola → 404/403.

**4.4 — Streaming AI**
Endpoint `POST /api/ai/tutor` che inoltra lo stream del modello al client con SSE, gestendo abort, timeout, rate limit e costi.
- **Criterio:** il client riceve i token progressivamente; la connessione si chiude correttamente.

**4.5 — Hardening e osservabilità**
Aggiungi request id, audit log delle azioni sensibili, redazione PII nei log, graceful shutdown, OpenAPI aggiornata, test di sicurezza base (OWASP API Top 10).
- **Criterio:** report con 10 controlli verificati e remediation.

---

## 4. Quiz di verifica

1. Differenza tra 401 e 403?
2. Perché l'ordine dei middleware conta?
3. Perché non restituire mai `passwordHash` nelle risposte?
4. Cosa fa `bcrypt.compare`?
5. Perché il messaggio di login deve essere generico?
6. Differenza tra autenticazione e autorizzazione?
7. Perché rate limitare gli endpoint AI?

<details>
<summary>Risposte</summary>

1. 401 = non autenticato (manca o non è valida l'identità); 403 = autenticato ma senza permesso.
2. I middleware vengono eseguiti in ordine: auth prima delle route protette, body parser prima della validazione, error handler per ultimo.
3. Espone materiale utile ad attacchi e viola la minimizzazione dei dati; usa `select` espliciti.
4. Confronta la password in chiaro con l'hash memorizzato usando il salt incluso nell'hash.
5. Evita l'enumerazione degli account: un attaccante non deve capire se un'email è registrata.
6. Autenticazione = chi sei; autorizzazione = cosa puoi fare.
7. Le chiamate ai modelli costano e sono lente: senza limiti un utente può generare costi elevati o denial of service.

</details>

---

## 5. Mini-progetto del modulo

**"API RipassoAI"**

Endpoint minimi:

| Metodo | Path | Ruolo | Descrizione |
|---|---|---|---|
| POST | `/api/auth/register` | pubblico | Crea studente |
| POST | `/api/auth/login` | pubblico | Login, cookie httpOnly |
| GET | `/api/auth/me` | auth | Profilo corrente |
| GET | `/api/argomenti` | auth | Catalogo |
| GET | `/api/domande` | auth | Lista paginata/filtrata |
| POST | `/api/tentativi` | studente | Avvia quiz |
| POST | `/api/tentativi/:id/risposte` | studente | Salva risposta |
| POST | `/api/tentativi/:id/submit` | studente | Chiude e calcola |
| GET | `/api/progressi/me` | studente | Statistiche personali |
| GET | `/api/classi/:id/progressi` | docente | Statistiche classe |
| POST | `/api/ai/genera-quiz` | docente | Genera bozza quiz |

Requisiti: validazione Zod, error handler, auth JWT, RBAC, rate limit, test Supertest, documentazione OpenAPI, `.env.example`.

**Consegna:** cartella `modulo-07/` + collezione HTTP (Bruno/Postman) + report test.

---

## 6. AI pairing

```text
Agisci come security reviewer di API Express.
Ti incollo il router auth e il middleware.
Cerca: enumerazione account, timing attack, cookie insicuri, JWT senza issuer,
mancanza di rate limit, errori che leakano stack.
Per ogni finding: severità, exploit ipotetico, patch minima.
```

```text
Scrivi test Supertest per questo endpoint.
Copri: 200, 400, 401, 403, 404, 422, 429.
Usa un DB di test isolato e non mockare il DB se non necessario.
Se l'endpoint non è testabile, dimmi cosa refactorare.
```

**Verifica:** esegui i test, prova richieste con ruolo sbagliato, controlla i cookie in DevTools, osserva i log. L'AI tende a inventare middleware e a dimenticare `await`.

---

## 7. Checklist di uscita

- [ ] So progettare endpoint REST coerenti.
- [ ] Uso middleware e error handler centralizzato.
- [ ] Hasho le password e non le loggo mai.
- [ ] Controllo i permessi sul server, non solo nel client.
- [ ] Valido input e output.
- [ ] Ho testato auth, permessi ed errori.
- [ ] Ho consegnato API, test e OpenAPI.
