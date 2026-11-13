# Modulo 03 — JavaScript

> **Livello:** fondamenta · **Tempo:** 10 h · **Prerequisiti:** HTML, CSS
> **Deliverable:** motore quiz lato client con timer, punteggio, persistenza e test.

---

## 1. Traguardi

Al termine del modulo sapete:

- usare i tipi, le funzioni e i metodi degli array senza copiare codice a caso;
- manipolare il DOM e gestire eventi in modo prevedibile;
- scrivere codice **asincrono** con `async/await`, gestendo errori e cancellazioni;
- separare logica, storage e interfaccia in moduli;
- simulare uno stato complesso (quiz, timer, tentativi) con una macchina a stati;
- scrivere test unitari con Vitest.

---

## 2. Concetti chiave (cheat sheet)

### Tipi e uguaglianza

```js
typeof null          // "object" (bug storico)
Number("12px")       // NaN
"5" == 5             // true  → non usare
"5" === 5            // false → usa sempre ===
[] === []            // false (reference)
structuredClone(obj) // copia profonda
```

### Funzioni e array

```js
const domande = [
  { id: 1, livello: 1, corretta: 0 },
  { id: 2, livello: 3, corretta: 2 },
  { id: 3, livello: 2, corretta: 1 },
];

const facili = domande.filter(d => d.livello === 1);
const ids = domande.map(d => d.id);
const peso = domande.reduce((somma, d) => somma + d.livello, 0);
const ordinate = [...domande].sort((a, b) => a.livello - b.livello);
```

### DOM essenziale

```js
const lista = document.querySelector("#lista-domande");
const template = document.querySelector("#template-domanda");

function renderDomanda(domanda) {
  const nodo = template.content.cloneNode(true);
  nodo.querySelector(".domanda__testo").textContent = domanda.testo;
  lista.append(nodo);
}
```

> `textContent` per il testo, `createElement` per la struttura. **Mai** `innerHTML` con dati utente.

### Eventi e delega

```js
lista.addEventListener("click", (event) => {
  const bottone = event.target.closest("[data-answer]");
  if (!bottone) return;
  const indice = Number(bottone.dataset.answer);
  selezionaRisposta(indice);
});
```

### Fetch con errori e cancellazione

```js
async function caricaQuiz(id, signal) {
  const res = await fetch(`/api/quiz/${id}`, { signal });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

const controller = new AbortController();
try {
  const quiz = await caricaQuiz(42, controller.signal);
} catch (err) {
  if (err.name === "AbortError") return; // richiesta superata
  mostraErrore("Impossibile caricare il quiz.");
}
```

### Storage sicuro

```js
const storage = {
  get(key, fallback = null) {
    try {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch {
      return false; // quota piena o storage disabilitato
    }
  },
  remove(key) { localStorage.removeItem(key); },
};
```

### Shuffle corretto (Fisher–Yates)

```js
function shuffle(items) {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}
```

### Macchina a stati del quiz

```text
idle → loading → question → feedback → question → … → review → submitted
                       ↘ error ↗
```

```js
const TRANSIZIONI = {
  idle:      { START: "loading" },
  loading:   { LOADED: "question", FAIL: "error" },
  question:  { ANSWER: "feedback", TIMEOUT: "review" },
  feedback:  { NEXT: "question", LAST: "review" },
  review:    { SUBMIT: "submitted" },
  error:     { RETRY: "loading" },
  submitted: { RESTART: "loading" },
};
```

### Punteggio pesato per livello

```js
const PESI = { 1: 1, 2: 2, 3: 3, 4: 4 };

function calcolaMastery(risposte) {
  const totale = risposte.reduce((s, r) => s + PESI[r.livello], 0);
  const ottenuto = risposte
    .filter(r => r.corretta)
    .reduce((s, r) => s + PESI[r.livello], 0);
  return totale === 0 ? 0 : Math.round((ottenuto / totale) * 100);
}
```

### Test con Vitest

```js
import { describe, it, expect } from "vitest";
import { calcolaMastery } from "./scoring.js";

describe("calcolaMastery", () => {
  it("restituisce 100 con tutte le risposte corrette", () => {
    const risposte = [
      { livello: 1, corretta: true },
      { livello: 3, corretta: true },
    ];
    expect(calcolaMastery(risposte)).toBe(100);
  });

  it("restituisce 0 senza risposte", () => {
    expect(calcolaMastery([])).toBe(0);
  });
});
```

### Concetti fondamentali aggiuntivi

#### Scope, hoisting e TDZ

```js
console.log(a); // undefined — var è "sollevata" e inizializzata a undefined
var a = 1;

// console.log(b); // ReferenceError: Cannot access 'b' before initialization
let b = 2;

saluta(); // funziona: le dichiarazioni di funzione sono sollevate interamente
function saluta() { console.log("ciao"); }

// const e let hanno lo stesso comportamento di hoisting,
// ma restano nella Temporal Dead Zone fino alla dichiarazione.
```

- `var` ha scope di funzione ed è soggetta a hoisting con valore `undefined`.
- `let`/`const` hanno scope di blocco e TDZ: usarle prima della dichiarazione è un errore.
- Le function declaration sono disponibili prima della riga in cui compaiono; le function expression no.
- Evitate `var`: rende più difficile ragionare su scope e closure.

#### Closure

```js
function creaContatore() {
  let valore = 0;          // catturato dalla closure
  return {
    incrementa: () => ++valore,
    valore: () => valore,
  };
}

const c = creaContatore();
c.incrementa();
c.incrementa();
console.log(c.valore()); // 2
```

Una closure è una funzione che ricorda l'ambiente lessicale in cui è stata creata. Serve per stato privato, memoization, callback e moduli. Attenzione ai cicli con `var`: la variabile è condivisa; con `let` ogni iterazione ha il proprio binding.

```js
for (var i = 0; i < 3; i++) setTimeout(() => console.log(i)); // 3, 3, 3
for (let j = 0; j < 3; j++) setTimeout(() => console.log(j)); // 0, 1, 2
```

#### `this`

```js
const utente = {
  nome: "Ada",
  saluta() { return `Ciao, ${this.nome}`; },
};

utente.saluta();          // "Ciao, Ada" — this = utente
const f = utente.saluta;
f();                      // errore in strict mode: this = undefined

const bound = utente.saluta.bind(utente);
bound();                  // "Ciao, Ada"
```

- Metodo chiamato come `oggetto.metodo()` → `this` è l'oggetto.
- Funzione isolata → `undefined` in strict mode/moduli, `globalThis` in sloppy mode.
- Arrow function → `this` lessicale, non può essere cambiato con `call`/`apply`/`bind`.
- `call`/`apply` invocano subito, `bind` crea una nuova funzione.
- I metodi di classe non sono automaticamente bound: passandoli come callback perdono `this`.

#### Destructuring, spread e rest

```js
const domanda = {
  id: 7,
  testo: "Cos'è il DOM?",
  opzioni: ["A", "B", "C", "D"],
  meta: { livello: 2, autore: "docente" },
};

const { testo, opzioni: scelte, meta: { livello }, autore = "anonimo" } = domanda;
const [prima, ...altre] = scelte;

const copia = { ...domanda, attiva: true };        // shallow
const nuovoArray = [...scelte, "E"];               // shallow

function media(...numeri) {                        // rest parameter
  return numeri.reduce((s, n) => s + n, 0) / numeri.length;
}
```

- Il destructuring funziona su array, oggetti, parametri e risultati di funzioni.
- `...` a sinistra raccoglie (rest), a destra espande (spread).
- Spread e `Object.assign` fanno copie **superficiali**: gli oggetti annidati restano condivisi.
- Le proprietà con lo stesso nome vengono sovrascritte: l'ultima vince.

#### Template literals e stringhe

```js
const nome = "Ada";
const messaggio = `Ciao ${nome},
benvenuta nel quiz.`;

const prezzo = new Intl.NumberFormat("it-IT", {
  style: "currency", currency: "EUR",
}).format(19.9);

const data = new Intl.DateTimeFormat("it-IT", {
  dateStyle: "long", timeZone: "Europe/Rome",
}).format(new Date());

const grezzo = String.raw`C:\cartella\nuova`; // non interpreta \n
```

I template literal supportano interpolazione e testo multiriga. Per numeri, date e valute usate `Intl` invece di concatenare formati a mano. Non costruite HTML con stringhe contenenti input utente: rischio XSS.

#### Optional chaining e nullish coalescing

```js
const città = utente?.indirizzo?.città ?? "Non specificata";
const lunghezza = lista?.length ?? 0;
const risultato = api?.fetch?.(url);          // chiamata opzionale
opzioni.verbose ??= false;                    // assegna solo se null/undefined
```

- `?.` restituisce `undefined` se il valore a sinistra è `null`/`undefined`.
- `??` usa il fallback solo per `null`/`undefined`; `||` anche per `0`, `""`, `false`.
- `??=` assegna solo quando il valore è nullish.
- Non usate `?.` su variabili non dichiarate: è comunque un `ReferenceError`.

#### Copie, riferimenti e immutabilità

```js
const originale = { nome: "Ada", indirizzi: [{ città: "Milano" }] };

const superficiale = { ...originale };
superficiale.indirizzi[0].città = "Roma"; // modifica anche l'originale!

const profonda = structuredClone(originale); // copia reale
```

- I primitivi sono copiati per valore; oggetti, array e funzioni per riferimento.
- `JSON.parse(JSON.stringify(obj))` perde `undefined`, funzioni, `Date`, `Map`, `Set` e fallisce sui riferimenti circolari.
- `Object.freeze` congela solo il primo livello.
- Metodi come `sort`, `splice`, `reverse` mutano l'array: copiate prima (`[...arr].sort()`).
- Nei reducer e nello stato di React non mutate mai l'oggetto esistente: create una nuova struttura.

#### Map, Set e WeakMap

```js
const mappa = new Map();
mappa.set("a", 1).set({ id: 1 }, 2);
console.log(mappa.get("a"));        // 1
console.log(mappa.has({ id: 1 }));  // false: chiavi per identità

const set = new Set([1, 2, 2, 3]);  // {1, 2, 3}
const unici = [...set];

const cache = new WeakMap();        // chiavi oggetto, liberate dal GC
```

- `Map` accetta chiavi di qualsiasi tipo e mantiene l'ordine di inserimento; un oggetto usa solo stringhe/symbol come chiavi.
- `Set` deduplica i primitivi e gli oggetti per riferimento.
- `WeakMap`/`WeakSet` non sono iterabili e non impediscono la garbage collection: ideali per metadati privati.

#### Errori e gestione

```js
class ErroreValidazione extends Error {
  constructor(messaggio, dettagli) {
    super(messaggio, { cause: dettagli });
    this.name = "ErroreValidazione";
  }
}

try {
  throw new ErroreValidazione("Email non valida", { campo: "email" });
} catch (err) {
  if (err instanceof ErroreValidazione) {
    console.warn(err.message, err.cause);
  } else {
    throw err; // non ingoiate errori sconosciuti
  }
} finally {
  chiudiConnessione();
}
```

Tipi comuni: `Error`, `TypeError`, `RangeError`, `SyntaxError`, `ReferenceError`. `cause` conserva l'errore originale. Non usate `catch {}` vuoti: nascondono i bug. Un `throw` dentro una funzione `async` diventa una Promise rifiutata.

#### Promise e combinatori

```js
const p1 = fetch("/api/quiz").then(r => r.json());
const p2 = fetch("/api/progressi").then(r => r.json());

const [quiz, progressi] = await Promise.all([p1, p2]); // fallisce al primo errore
const esiti = await Promise.allSettled([p1, p2]);      // sempre tutte le attese
const primo = await Promise.race([p1, timeout(3000)]); // la prima che termina
const primoOk = await Promise.any([p1, p2]);           // la prima che riesce
```

Una Promise è in stato `pending`, `fulfilled` o `rejected`, e lo stato non cambia più. `then` restituisce una nuova Promise; `catch` gestisce il rifiuto; `finally` esegue sempre. Le Promise rifiutate senza gestore generano `unhandledRejection`.

#### Event loop: microtask e macrotask

```js
console.log("A");

setTimeout(() => console.log("D"), 0);

Promise.resolve().then(() => console.log("C"));

console.log("B");

// Output: A, B, C, D
```

L'ordine è: codice sincrono → **tutte** le microtask (Promise, `queueMicrotask`, `MutationObserver`) → la prossima macrotask (`setTimeout`, I/O, eventi). Un `await` sospende la funzione e riprende in una microtask. Microtask infinite affamano il rendering e i timer.

In Node l'event loop ha fasi (timers, pending, poll, check, close); `process.nextTick` e le microtask hanno priorità sulle fasi successive. Non bloccare mai il thread con calcoli lunghi: usate `worker_threads`.

#### Async/await in pratica

```js
async function caricaDashboard(id) {
  const controller = new AbortController();

  try {
    const [quiz, progressi] = await Promise.all([
      caricaQuiz(id, controller.signal),
      caricaProgressi(id, controller.signal),
    ]);
    return { quiz, progressi };
  } catch (err) {
    if (err.name === "AbortError") return null;
    throw new Error("Dashboard non disponibile", { cause: err });
  }
}

// timeout senza timer manuali
const res = await fetch(url, { signal: AbortSignal.timeout(5000) });

// retry con backoff
async function conRetry(fn, tentativi = 3) {
  for (let i = 0; i < tentativi; i++) {
    try { return await fn(); }
    catch (err) {
      if (i === tentativi - 1) throw err;
      await new Promise(r => setTimeout(r, 2 ** i * 200));
    }
  }
}
```

- Una funzione `async` restituisce sempre una Promise.
- Dimenticare `await` produce un valore `Promise` invece del dato.
- In un ciclo usate `for...of` con `await` per la sequenza, `Promise.all` per il parallelismo.
- Annullate le richieste quando non servono più: evitate race condition e lavoro inutile.
- `for await...of` legge stream e iteratori asincroni.

#### Moduli ES

```js
// scoring.js
export const PESI = { 1: 1, 2: 2, 3: 3, 4: 4 };
export function calcolaMastery(risposte) { /* … */ }
export default function creaQuiz() { /* … */ }

// main.js
import creaQuiz, { calcolaMastery, PESI } from "./scoring.js";
const modulo = await import("./grafici.js"); // dinamico, code splitting
```

- I moduli hanno scope proprio e sono valutati una sola volta (singleton).
- I binding esportati sono **live**: chi importa vede gli aggiornamenti.
- Nel browser servono `type="module"` e percorsi con estensione; niente `__dirname`.
- Import dinamico per caricare codice solo quando serve.
- Evitate dipendenze circolari: rendono l'inizializzazione imprevedibile.

#### Classi, prototipi e campi privati

```js
class Domanda {
  #corretta;                    // campo privato, non accessibile dall'esterno

  constructor({ testo, opzioni, corretta }) {
    this.testo = testo;
    this.opzioni = opzioni;
    this.#corretta = corretta;
  }

  get corretta() { return this.#corretta; }

  verifica(indice) {
    return indice === this.#corretta;
  }

  static daJson(json) {
    return new Domanda(JSON.parse(json));
  }
}

class DomandaTimer extends Domanda {
  constructor(dati, secondi) {
    super(dati);
    this.secondi = secondi;
  }
}
```

Le classi sono zucchero sintattico sui prototipi. `#` rende un campo davvero privato (non è una convenzione). Preferite la composizione all'ereditarietà profonda. `instanceof` attraversa la catena dei prototipi.

#### Iteratori e generatori

```js
function* livelli() {
  for (let i = 1; i <= 4; i++) yield i;
}

for (const livello of livelli()) console.log(livello);

async function* streamDomande(response) {
  for await (const chunk of response.body) {
    yield new TextDecoder().decode(chunk);
  }
}
```

Un iterabile implementa `Symbol.iterator`; un generatore produce valori in modo lazy con `yield`. Gli async generator si consumano con `for await...of`. Utili per paginazione, stream e sequenze potenzialmente infinite.

#### JSON, Date e numeri

```js
JSON.stringify({ a: 1 }, null, 2);
JSON.parse('{"a":1}', (chiave, valore) =>
  chiave === "data" ? new Date(valore) : valore
);

Number.isNaN(NaN);            // true (meglio del globale isNaN)
Number.isInteger(3.0);        // true
Number.parseFloat("12.5px");  // 12.5
(0.1 + 0.2).toFixed(2);       // "0.30" — attenzione ai binari
```

- `JSON` non serializza funzioni, `undefined`, `BigInt` e riferimenti circolari.
- `Date` è mutabile e lavora in millisecondi; conservate le date in UTC e formattate con `Intl`.
- I numeri sono floating point a 64 bit: per denaro usate centesimi interi o una libreria decimale.
- `BigInt` (`10n`) gestisce interi arbitrari, non si mescola con `Number` e non è serializzabile in JSON senza conversione.

#### Espressioni regolari

```js
const email = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
email.test("ada@example.com");           // true

const data = /(?<anno>\d{4})-(?<mese>\d{2})/;
const { anno, mese } = "2026-11".match(data).groups;

"a-b-c".replaceAll("-", "/");
```

Flags: `g` (tutte), `i` (case-insensitive), `m` (multiline), `s` (dotAll), `u` (unicode), `y` (sticky). Attenzione alle regex catastrofiche (backtracking) su input lunghi. Non validate l'email solo con una regex: la vera verifica è l'invio.

#### Debounce, throttle e performance

```js
function debounce(fn, ms = 300) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}

function throttle(fn, ms = 100) {
  let ultimo = 0;
  return (...args) => {
    const ora = Date.now();
    if (ora - ultimo >= ms) {
      ultimo = ora;
      fn(...args);
    }
  };
}
```

- **Debounce**: esegue dopo l'ultima chiamata (ricerca mentre si digita).
- **Throttle**: esegue al massimo una volta ogni intervallo (scroll, resize).
- Raggruppate letture e scritture del DOM per evitare layout thrashing.
- Usate `requestAnimationFrame` per animazioni, `IntersectionObserver` per lazy load, `performance.now()` per misurare.
- Spostate i calcoli pesanti in un Web Worker; misurate prima di ottimizzare.

#### Sicurezza lato client

- Non fidatevi mai del client: validazione e autorizzazione vanno anche sul server.
- `innerHTML` con dati esterni apre a XSS; usate `textContent` o sanitizzate.
- `localStorage` è leggibile da qualsiasi script: non è un posto sicuro per token sensibili.
- Non usate `eval`/`new Function` su input.
- Controllate l'`origin` nei messaggi `postMessage`.
- Una Content Security Policy rigorosa riduce l'impatto di un'iniezione.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Prevedi l'output**
Senza eseguire, scrivi il risultato di 10 espressioni (coercion, `==`/`===`, `typeof`, `NaN`, array/oggetti). Poi verifica in console e annota gli errori di previsione.
- **Criterio:** almeno 8/10 corrette e spiegazione del perché.

**1.2 — Manipolazione array**
Data una lista di domande, produci: solo le L2, i testi in maiuscolo, il conteggio per livello, la domanda con id 7, l'array ordinato per livello. Usa `filter`, `map`, `reduce`, `find`, `sort`.
- **Criterio:** nessun ciclo `for`; nessuna mutazione dell'array originale.

**1.3 — DOM base**
Crea una pagina con un bottone e un contatore. Al click incrementa il numero e aggiorna il testo. A 10 click mostra "Traguardo!".
- **Criterio:** il contatore non si resetta al re-render; nessun `innerHTML` con input utente.

**1.4 — Debug**
Correggi 5 bug in uno snippet fornito: `const` riassegnato, `=` invece di `===`, `this` perso nella callback, indice fuori range, `await` mancante.
- **Criterio:** ogni correzione ha un commento con la causa.

---

### L2 — Intermedio

**2.1 — Quiz engine v1**
Array di 5 domande con 4 opzioni. Renderizza una domanda alla volta, evidenzia la scelta, mostra "Corretto/Errato" con la spiegazione, passa alla successiva, mostra il punteggio finale.
- **Vincoli:** separa `data.js`, `quiz.js`, `ui.js`; nessuna libreria.
- **Criterio:** una risposta non può essere cambiata dopo la conferma.

**2.2 — Validazione form**
Form di iscrizione al quiz: nome, email, livello. Valida al submit e su `blur`, mostra errori sotto i campi, impedisci l'invio se non valido.
- **Criterio:** i messaggi sono specifici ("Inserisci un'email valida", non "Errore").

**2.3 — Fetch e stati**
Carica le domande da `/api/questions.json`. Mostra skeleton durante il caricamento, messaggio con retry in caso di errore, lista in caso di successo.
- **Criterio:** niente schermo bianco; il retry funziona davvero.

**2.4 — Persistenza**
Salva su `localStorage`: miglior punteggio, streak giornaliero, ultimo livello giocato. Gestisci JSON corrotto e quota piena.
- **Criterio:** ricaricando la pagina i dati restano; un valore corrotto non rompe l'app.

**2.5 — Estrazione domande**
Estrai 10 domande casuali da una banca di 40, senza ripetizioni, mescolando anche le opzioni. Mantieni traccia della risposta corretta dopo lo shuffle.
- **Criterio:** nessun duplicato in 100 esecuzioni; la risposta corretta resta allineata.

---

### L3 — Avanzato

**3.1 — Timer e cleanup**
Timer di 60 secondi per domanda, con pausa/riprendi e auto-submit allo scadere. Il timer si ferma quando la scheda è nascosta (`visibilitychange`) e non accumula intervalli multipli.
- **Criterio:** nessun `setInterval` orfano dopo il reset; il tempo residuo è coerente dopo pausa/ripresa.

**3.2 — Punteggio adattivo**
Implementa `calcolaMastery` con pesi per livello. Dopo 3 risposte corrette consecutive a L2, proponi una domanda L3; dopo 2 errori, scendi di livello.
- **Criterio:** la funzione è pura e testata; l'algoritmo è descritto in `README.md`.

**3.3 — Refactor in moduli + test**
Dividi il motore quiz in moduli ES (`store`, `quiz`, `scoring`, `ui`). Scrivi almeno 8 test con Vitest: punteggio, shuffle, transizioni, storage corrotto.
- **Criterio:** `npm test` verde; nessun test che dipende dall'ordine.

**3.4 — Ricerca con debounce e race condition**
Campo di ricerca nella banca domande: attendi 300 ms, annulla la richiesta precedente con `AbortController`, mostra i risultati solo se la risposta è la più recente.
- **Criterio:** digitando velocemente non compaiono risultati vecchi.

**3.5 — Retry con backoff**
Implementa `fetchWithRetry(url, { retries: 3 })` con backoff esponenziale e jitter. Non ritentare errori 4xx. Logga i tentativi.
- **Criterio:** un 500 simulato viene ritentato; un 404 no.

---

### L4 — Esperto

**4.1 — Macchina a stati completa**
Implementa il quiz come macchina a stati esplicita (tabella delle transizioni + `dispatch`). Gestisci: idle, loading, question, feedback, review, submitted, error. Ogni transizione non valida lancia un errore in sviluppo.
- **Criterio:** nessuno stato impossibile è rappresentabile; test di tutte le transizioni.

**4.2 — Offline-first**
Salva i tentativi in IndexedDB quando la rete manca e sincronizzali al ritorno online. Definisci la politica in caso di conflitto (vince il tentativo con timestamp più recente, ma non perdere i dati).
- **Criterio:** completando un quiz offline e tornando online, il tentativo arriva al server una sola volta (idempotenza).

**4.3 — Performance**
Con 500 domande renderizzate, misura il tempo di apertura. Implementa virtualizzazione o paginazione, memoizzazione del calcolo del punteggio e rendering per frammenti.
- **Criterio:** interazione < 100 ms; nessun long task > 50 ms misurato.

**4.4 — Sicurezza front-end**
Analizza 3 snippet con `innerHTML` alimentato da dati esterni. Correggi con `textContent`/DOM API, aggiungi una CSP e spiega perché nascondere un bottone non è autorizzazione.
- **Criterio:** un payload `<img src=x onerror=alert(1)>` non viene eseguito.

**4.5 — Test plan asincrono**
Scrivi un piano di test per timer, fetch, retry e storage: usa fake timer, mock di `fetch`, test di concorrenza. Elimina la flakiness.
- **Criterio:** 20 esecuzioni consecutive verdi.

---

## 4. Quiz di verifica

1. Differenza tra `==` e `===`?
2. Cosa restituisce `[1,2,3].map(n => n * 2).filter(n => n > 2)`?
3. Perché `innerHTML` è pericoloso con dati utente?
4. Cosa fa `AbortController`?
5. Differenza tra `localStorage` e `sessionStorage`?
6. Cosa significa che una funzione è pura?
7. Perché `setInterval` va sempre cancellato?

<details>
<summary>Risposte</summary>

1. `==` converte i tipi prima di confrontare; `===` confronta tipo e valore senza conversioni. Usa `===`.
2. `[4, 6]`.
3. Interpreta la stringa come HTML: può eseguire script e iniettare markup (XSS). Usa `textContent` o sanitizzazione.
4. Permette di annullare una richiesta fetch (o un listener) passando `signal`; l'errore risultante ha nome `AbortError`.
5. `localStorage` persiste oltre la chiusura della scheda; `sessionStorage` dura quanto la sessione della scheda.
6. Dato lo stesso input restituisce lo stesso output e non modifica stato esterno.
7. Altrimenti continua a girare, consuma risorse e aggiorna UI smontate: memory leak e comportamenti imprevedibili.

</details>

---

## 5. Mini-progetto del modulo

**"Motore quiz"**

Requisiti:

- banca di almeno 20 domande su 4 livelli;
- selezione casuale senza ripetizioni;
- timer per domanda con pausa;
- feedback immediato con spiegazione;
- punteggio pesato e livello di padronanza;
- salvataggio tentativi in `localStorage`;
- riepilogo finale con risposte errate;
- test con Vitest (≥ 10 test);
- nessuna libreria UI.

**Consegna:** cartella `modulo-03/` con codice, test, `README.md` (algoritmo di scoring, scelte, limiti) e 3 screenshot.

---

## 6. AI pairing

```text
Agisci come test engineer.
Ecco il mio modulo quiz.js. Scrivi test Vitest per:
1) punteggio con pesi, 2) shuffle senza perdita della risposta corretta,
3) storage corrotto, 4) transizione non valida.
Non modificare il codice di produzione: mostra solo i test e spiega i casi limite.
```

```text
Ho questo errore: "Cannot read properties of undefined (reading 'corretta')".
Ti incollo codice e stack trace. Fai 3 ipotesi ordinate per probabilità,
indicami come verificarle e la correzione minima. Non riscrivere tutto.
```

**Verifica:** esegui i test, prova a 320px, simula offline, controlla che l'AI non abbia introdotto `eval`, `innerHTML` o dipendenze inutili.

---

## 7. Checklist di uscita

- [ ] So spiegare `map`, `filter`, `reduce` con un esempio reale.
- [ ] Gestisco loading, errore e successo di una fetch.
- [ ] Non uso mai `innerHTML` con dati non fidati.
- [ ] Pulisco timer e listener quando non servono.
- [ ] Ho testato la logica di punteggio.
- [ ] Il mio quiz funziona anche con storage pieno o corrotto.
- [ ] Ho consegnato motore e test.
