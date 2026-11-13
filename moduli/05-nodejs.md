# Modulo 05 — Node.js

> **Livello:** intermedio · **Tempo:** 8 h · **Prerequisiti:** JavaScript
> **Deliverable:** CLI di importazione quiz e servizi di supporto alla piattaforma.

---

## 1. Traguardi

Al termine del modulo sapete:

- spiegare cos'è il runtime Node e come funziona l'event loop;
- organizzare un progetto in moduli ESM con dipendenze chiare;
- leggere/scrivere file e gestire variabili d'ambiente;
- creare un server HTTP minimale senza framework;
- gestire errori, logging e spegnimento controllato;
- scrivere test con `node:test`;
- riconoscere i rischi di sicurezza di un processo server.

---

## 2. Concetti chiave (cheat sheet)

### Runtime ed event loop

Node esegue JavaScript fuori dal browser su **un solo thread** per il codice JS, delegando I/O al sistema operativo. L'event loop gestisce callback, promise e timer. Operazioni CPU-intensive bloccano tutto: per quelle servono `worker_threads` o processi separati.

```js
console.log("1");
setTimeout(() => console.log("3"), 0);
Promise.resolve().then(() => console.log("2"));
console.log("4");
// 1, 4, 2, 3
```

### Moduli ESM

```js
// src/scoring.js
export const PESI = { 1: 1, 2: 2, 3: 3, 4: 4 };

export function calcolaPunteggio(risposte) {
  const totale = risposte.reduce((s, r) => s + PESI[r.livello], 0);
  const corrette = risposte
    .filter(r => r.corretta)
    .reduce((s, r) => s + PESI[r.livello], 0);
  return totale === 0 ? 0 : Math.round((corrette / totale) * 100);
}
```

```js
// src/index.js
import { calcolaPunteggio } from "./scoring.js";
```

Nel `package.json`: `"type": "module"`.

### Variabili d'ambiente

```js
// src/config.js
function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Variabile mancante: ${name}`);
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 3000),
  databaseUrl: required("DATABASE_URL"),
  llmApiKey: required("LLM_API_KEY"),
  nodeEnv: process.env.NODE_ENV ?? "development",
};
```

`.env` va in `.gitignore`. Fornite sempre `.env.example`.

### File system

```js
import { readFile, writeFile, mkdir } from "node:fs/promises";
import path from "node:path";

export async function leggiJson(file) {
  const raw = await readFile(file, "utf8");
  return JSON.parse(raw);
}

export async function scriviJson(file, data) {
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, JSON.stringify(data, null, 2), "utf8");
}
```

### Server HTTP minimale

```js
import { createServer } from "node:http";

const server = createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
    return;
  }
  res.writeHead(404).end("Not found");
});

server.listen(3000, () => console.log("http://localhost:3000"));
```

### Errori e logging

```js
process.on("unhandledRejection", (reason) => {
  console.error({ event: "unhandledRejection", reason });
  process.exitCode = 1;
});

process.on("uncaughtException", (err) => {
  console.error({ event: "uncaughtException", err });
  process.exit(1); // stato potenzialmente corrotto
});
```

Log **strutturati** in JSON, con livelli (`debug`, `info`, `warn`, `error`) e senza dati personali.

### Graceful shutdown

```js
const server = app.listen(config.port);

async function shutdown(signal) {
  console.log({ event: "shutdown", signal });
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```

### Test con node:test

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { calcolaPunteggio } from "../src/scoring.js";

test("tutte corrette → 100", () => {
  assert.equal(
    calcolaPunteggio([{ livello: 1, corretta: true }, { livello: 4, corretta: true }]),
    100
  );
});

test("nessuna risposta → 0", () => {
  assert.equal(calcolaPunteggio([]), 0);
});
```

Esegui con `node --test`.

### Stream per file grandi

```js
import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const rl = createInterface({
  input: createReadStream("domande.jsonl"),
  crlfDelay: Infinity,
});

for await (const line of rl) {
  if (!line.trim()) continue;
  const domanda = JSON.parse(line);
  await salva(domanda);
}
```

### Concetti fondamentali aggiuntivi

#### ESM e CommonJS

```js
// package.json → "type": "module"
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
```

| CommonJS | ESM |
|---|---|
| `require()` / `module.exports` | `import` / `export` |
| Caricamento sincrono | Caricamento asincrono, live bindings |
| `__dirname`, `__filename` | `import.meta.url` + `fileURLToPath` |
| `require.main === module` | `import.meta.main` (dove disponibile) |

Con ESM il top-level `await` è consentito. Nei progetti misti usate estensioni esplicite (`.mjs`, `.cjs`) o `createRequire`. Le dipendenze devono dichiarare correttamente `exports` e `type`.

#### `package.json` e scripts

```json
{
  "type": "module",
  "engines": { "node": ">=22" },
  "scripts": {
    "dev": "node --watch src/index.js",
    "start": "node src/index.js",
    "test": "node --test",
    "lint": "eslint ."
  }
}
```

- `dependencies` = runtime; `devDependencies` = build, test, lint.
- Committate il lockfile e usate `npm ci` in CI per installazioni riproducibili.
- `engines` documenta la versione minima; in produzione usate una LTS.
- Gli script devono funzionare su Windows, macOS e Linux: evitate comandi shell non portabili.

#### Processo, argomenti e segnali

```js
const [comando, ...argomenti] = process.argv.slice(2);
console.log({ pid: process.pid, node: process.version, cwd: process.cwd() });

process.on("SIGINT", () => {
  console.log("Interruzione richiesta");
  process.exitCode = 0; // preferibile a process.exit()
});
```

- `process.env` contiene le variabili d'ambiente (sempre stringhe).
- `process.exit()` termina subito e può troncare I/O; impostate `exitCode` e chiudete con ordine.
- `stdout`/`stderr` sono stream: per log strutturati usate `stderr`.
- `process.hrtime.bigint()` misura intervalli con alta precisione.

#### Timer e scheduling

```js
setTimeout(fn, 0);          // macrotask, non "immediato"
setInterval(fn, 1000);      // può accumulare ritardo
setImmediate(fn);           // fase check, dopo I/O
queueMicrotask(fn);         // prima della prossima macrotask
process.nextTick(fn);       // priorità massima in Node
```

I timer non sono precisi al millisecondo. `setInterval` può sovrapporre esecuzioni lente: preferite un loop con `setTimeout` e attesa dell'esito. Chiamate `.unref()` su timer che non devono tenere vivo il processo. Nei test usate fake timer.

#### Buffer, stream e backpressure

```js
import { createReadStream, createWriteStream } from "node:fs";
import { pipeline } from "node:stream/promises";
import { Transform } from "node:stream";

const maiuscolo = new Transform({
  transform(chunk, encoding, callback) {
    callback(null, chunk.toString().toUpperCase());
  },
});

await pipeline(
  createReadStream("input.txt"),
  maiuscolo,
  createWriteStream("output.txt")
);
```

- `Buffer` è memoria binaria; specificate sempre l'encoding (`utf8`).
- Gli stream evitano di caricare file enormi in memoria.
- `pipeline` propaga errori e chiude gli stream; gestitela con try/catch.
- La **backpressure** è il meccanismo che rallenta il produttore quando il consumatore è lento: rispettate `write()` e `drain`.

#### EventEmitter

```js
import { EventEmitter } from "node:events";
const emitter = new EventEmitter();

emitter.on("quiz:creato", ({ id }) => console.log("Creato", id));
emitter.once("avvio", () => console.log("Solo una volta"));

emitter.emit("quiz:creato", { id: 7 });
```

L'evento `error` è speciale: se non ha un listener, il processo lancia. Rimuovete i listener quando non servono (`off`/`removeListener`) per evitare memory leak. `events.once` e `AbortSignal` aiutano con promise e cancellazione.

#### HTTP e `fetch`

```js
const res = await fetch(url, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify(payload),
  signal: AbortSignal.timeout(8000),
});

if (!res.ok) {
  const testo = await res.text();
  throw new Error(`HTTP ${res.status}: ${testo.slice(0, 200)}`);
}
const dati = await res.json();
```

- `fetch` in Node è disponibile globalmente (basato su undici).
- Il body si legge **una sola volta**; clonatelo con `res.clone()` se serve due volte.
- Impostate timeout e gestite redirect, proxy e certificati.
- Gli header HTTP sono case-insensitive; `content-type` guida il parsing.
- Per risposte grandi usate lo streaming invece di `json()`.

#### Sicurezza del processo

- **Path traversal**: normalizzate e verificate che il percorso resti dentro la cartella consentita.
- **Command injection**: `execFile`/`spawn` con array di argomenti e `shell: false`; mai concatenare input.
- **Prototype pollution**: non fare merge ricorsivi di JSON non fidato su oggetti con `__proto__`.
- **ReDoS**: attenzione a regex con backtracking su input lunghi.
- **SSRF**: validate gli URL che il server scarica (allowlist di host).
- **Segreti**: solo in variabili d'ambiente, mai nei log o nel repository. Ruotate le chiavi.
- **Dipendenze**: `npm audit`, lockfile, aggiornamenti pianificati.

#### Crittografia di base

```js
import { randomUUID, randomBytes, timingSafeEqual, scrypt } from "node:crypto";
import { promisify } from "node:util";

const id = randomUUID();
const token = randomBytes(32).toString("base64url");
const scryptAsync = promisify(scrypt);
const hash = await scryptAsync(password, salt, 64);
```

- Per password usate `bcrypt`, `scrypt` o Argon2 con salt e cost factor adeguato.
- Hashing ≠ cifratura: l'hash è irreversibile, la cifratura è reversibile con chiave.
- Confrontate i token con `timingSafeEqual` per evitare timing attack.
- Non inventate protocolli crittografici: usate librerie standard.

#### Concorrenza e CPU

Node è single-thread per il JavaScript. I/O asincrono non blocca, ma un calcolo CPU-bound sì. Per quello servono `worker_threads`, `child_process` o un servizio separato. `cluster` replica il processo per sfruttare più core, ma non condivide memoria. Limitate la concorrenza con code e `p-limit` per non saturare DB o API.

```js
import { Worker } from "node:worker_threads";

const worker = new Worker(new URL("./calcolo.js", import.meta.url));
worker.postMessage({ domande });
worker.on("message", risultato => console.log(risultato));
worker.on("error", console.error);
```

#### File e persistenza

- Scritture atomiche: scrivete su un file temporaneo nella stessa directory e poi `rename`.
- Usate `fs/promises` per codice async; evitate le versioni sync in un server.
- Controllate permessi, encoding, path assoluti e spazi nel nome file.
- `fs.watch` è piattaforma-dipendente: per produzione valutate chokidar o un watcher dedicato.
- Non salvate dati applicativi in file locali se il processo può scalare su più istanze.

#### Diagnostica e osservabilità

```bash
node --inspect src/index.js
node --prof src/index.js
node --report-on-fatalerror src/index.js
```

- `--inspect` per il debugger, `--prof` per il profilo CPU, heap snapshot per i memory leak.
- `perf_hooks` misura operazioni; `diagnostics_channel` collega instrumentation.
- Log strutturati in JSON con livello, timestamp, request id e contesto.
- Metriche: latenza p50/p95/p99, error rate, throughput, memoria, event loop lag.
- In produzione esportate verso un sistema centralizzato, non solo console.

#### Versioni e deployment

- Usate una versione LTS e fissatela in `engines`, Docker e CI.
- Immagini multi-stage, utente non-root, `NODE_ENV=production`, `npm ci --omit=dev`.
- Healthcheck e readiness separati; graceful shutdown su `SIGTERM`.
- Configurazione via ambiente (12-factor), segreti da un vault.
- Le migrazioni a startup possono essere rischiose con più repliche: eseguitele come job separato.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Script somma**
Leggi due numeri da `process.argv`, valida che siano numeri, stampa la somma. Se mancano, mostra l'uso corretto ed esci con codice 1.
- **Criterio:** `node somma.js 2 3` → 5; input errato → messaggio chiaro.

**1.2 — Leggi e scrivi**
Leggi un file JSON di domande, aggiungi un campo `importedAt`, scrivi il risultato in un nuovo file. Gestisci file inesistente e JSON invalido.
- **Criterio:** nessun crash non gestito; messaggi distinti per i due errori.

**1.3 — Moduli**
Dividi uno script monolitico in tre moduli: `config`, `io`, `logica`. Esporta solo ciò che serve.
- **Criterio:** nessuna variabile globale; import espliciti con estensione `.js`.

**1.4 — HTTP hello**
Server con `/health`, `/api/version`, 404 per il resto. Content type corretto e status code corretti.
- **Criterio:** test con `curl` o `Invoke-WebRequest` per tutti i casi.

---

### L2 — Intermedio

**2.1 — CLI import quiz**
Comando `node import.js --file domande.json --dry-run`. Valida lo schema di ogni domanda, salta le invalide, stampa un riepilogo (lette, valide, scartate) e scrive un report.
- **Criterio:** exit code 1 se ci sono errori bloccanti; 0 altrimenti.

**2.2 — Logger**
Implementa un logger con livelli, timestamp ISO e output JSON. In sviluppo colori leggibili; in produzione solo JSON. Non loggare email o token.
- **Criterio:** `LOG_LEVEL=warn` nasconde info e debug.

**2.3 — Validazione input**
Accetta solo domande con: testo ≥ 10 caratteri, 4 opzioni non vuote, risposta corretta tra 0 e 3, livello 1–4. Usa Zod o validazione manuale.
- **Criterio:** 10 casi di test, inclusi duplicati e caratteri strani.

**2.4 — Static server**
Servi una cartella `public/` con content type corretti, protezione da path traversal (`../`), cache header e 404 personalizzato.
- **Criterio:** `GET /../.env` non restituisce il file.

**2.5 — Test**
Scrivi test con `node:test` per la logica di import e per `calcolaPunteggio`. Copri casi limite.
- **Criterio:** `node --test` verde; nessun test dipendente dall'ordine.

---

### L3 — Avanzato

**3.1 — Coda di job**
Implementa una coda in memoria per job AI (genera quiz, valida domande) con concorrenza massima 2, retry con backoff, stato (`queued`, `running`, `done`, `failed`) e endpoint di consultazione.
- **Criterio:** un job fallito non blocca la coda; i retry sono limitati.

**3.2 — Streaming file grandi**
Importa un file da 500 MB senza caricarli in memoria. Usa stream + `readline`, mostra progresso ogni 1000 righe, gestisci righe malformate senza interrompere.
- **Criterio:** memoria del processo stabile durante l'import.

**3.3 — Worker threads**
Sposta un calcolo CPU-intensive (es. generazione di statistiche su 1M di risposte) in un worker. Confronta il tempo di risposta del server con e senza worker.
- **Criterio:** il server resta reattivo durante il calcolo.

**3.4 — Graceful shutdown**
Gestisci SIGTERM/SIGINT: smetti di accettare nuove richieste, attendi quelle in corso, chiudi DB e coda, esci. Timeout di 10 secondi.
- **Criterio:** durante un deploy simulato nessuna richiesta viene troncata.

**3.5 — Osservabilità**
Aggiungi request id, log strutturati, metriche base (richieste, errori, durata) e un endpoint `/metrics` o log di riepilogo.
- **Criterio:** da un log puoi ricostruire l'intero percorso di una richiesta.

---

### L4 — Esperto

**4.1 — Architettura dei servizi**
Separa API, worker AI e job scheduler. Definisci confini, contratto di comunicazione, gestione retry e dead letter queue. Scrivi un ADR.
- **Criterio:** ogni servizio può essere riavviato senza perdere job.

**4.2 — Rate limiting e abuso**
Implementa rate limit per IP e per utente su login, quiz e AI. Distingui limiti orari/giornalieri, restituisci `429` con `Retry-After`, logga gli abusi.
- **Criterio:** uno script che martella l'endpoint viene bloccato senza penalizzare gli altri utenti.

**4.3 — Load test**
Con `autocannon` o `k6`, simula 200 utenti concorrenti sul flusso quiz. Individua il collo di bottiglia (CPU, DB, pool connessioni) e proponi 3 interventi.
- **Criterio:** report con p50/p95/p99 e spiegazione dei limiti.

**4.4 — Threat model**
Analizza il servizio Node con STRIDE: input non validati, path traversal, SSRF, dipendenze vulnerabili, secret esposti. Proponi contromisure e test.
- **Criterio:** almeno 8 minacce con impatto e mitigazione verificabile.

**4.5 — CI e rilascio**
Pipeline: lint, test, build, audit dipendenze, migrazioni DB, deploy con health check e rollback. Versionamento semantico.
- **Criterio:** un commit rotto non arriva in produzione.

---

## 4. Quiz di verifica

1. Node è multi-thread?
2. Perché un calcolo CPU-intensive blocca il server?
3. Cosa fa `process.exitCode = 1` rispetto a `process.exit(1)`?
4. Perché non committare `.env`?
5. Differenza tra `readFile` e stream?
6. Cosa deve fare un graceful shutdown?
7. Perché `uncaughtException` è pericoloso da ignorare?

<details>
<summary>Risposte</summary>

1. Il codice JS gira su un thread; Node usa thread del sistema/threadpool per I/O e può usare `worker_threads` per il CPU-bound.
2. L'event loop è occupato: non può servire altre callback finché il calcolo non termina.
3. Imposta il codice di uscita quando il processo termina naturalmente, senza forzare l'uscita immediata; `exit()` termina subito e può troncare operazioni in corso.
4. Contiene segreti (chiavi API, password DB) e configurazioni locali; va in `.gitignore` con un `.env.example` versionato.
5. `readFile` carica tutto in memoria; gli stream processano a pezzi, con memoria costante.
6. Smettere di accettare nuove richieste, completare quelle in corso, chiudere risorse (DB, code, file) ed uscire entro un timeout.
7. Dopo un'eccezione non gestita lo stato del processo può essere inconsistente: meglio loggare e terminare, lasciando che il supervisor riavvii.

</details>

---

## 5. Mini-progetto del modulo

**"Quiz CLI"**

Comandi:

```bash
node cli.js import --file data/domande.json
node cli.js validate --file data/domande.json
node cli.js stats --file data/domande.json
node cli.js export --level 3 --out data/livello3.json
```

Requisiti: validazione schema, report errori, exit code corretti, log strutturati, test, nessuna dipendenza pesante.

**Consegna:** cartella `modulo-05/` con CLI, test, fixture e README.

---

## 6. AI pairing

```text
Agisci come Node.js reviewer.
Il mio processo va in crash con "ERR_MODULE_NOT_FOUND".
Ti incollo package.json, struttura cartelle e stack trace.
Dammi 3 ipotesi ordinate, il comando per verificarle e la correzione minima.
Non cambiare l'architettura.
```

```text
Scrivi test con node:test per questa funzione di validazione.
Copri: input null, array vuoto, livello fuori range, opzioni duplicate.
Non modificare la funzione; se trovi un bug, scrivi un test che fallisce.
```

**Verifica:** esegui davvero i comandi, controlla gli exit code, prova path traversal e file mancanti. L'AI spesso dimentica la gestione degli errori e usa `process.exit` a sproposito.

---

## 7. Checklist di uscita

- [ ] So spiegare l'event loop e quando usare un worker.
- [ ] Uso ESM e variabili d'ambiente in modo pulito.
- [ ] Gestisco errori e chiusura del processo.
- [ ] Non committo segreti.
- [ ] So leggere un file grande senza esaurire la memoria.
- [ ] Ho testato la CLI con casi limite.
- [ ] Ho consegnato CLI e test.
