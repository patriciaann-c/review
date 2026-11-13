# Modulo 04 — React

> **Livello:** intermedio · **Tempo:** 10 h · **Prerequisiti:** JavaScript
> **Deliverable:** interfaccia della piattaforma quiz con routing, stato e test.

---

## 1. Traguardi

Al termine del modulo sapete:

- scomporre una UI in componenti con responsabilità chiare;
- distinguere **stato locale**, **stato condiviso** e **stato del server**;
- usare hook in modo corretto (dipendenze, cleanup, effetti);
- gestire form controllati e validazione;
- proteggere le rotte e gestire sessioni lato client;
- testare componenti con Testing Library;
- riconoscere e prevenire problemi di performance e accessibilità.

---

## 2. Concetti chiave (cheat sheet)

### Componenti e props

```jsx
function BadgeLivello({ livello }) {
  const etichette = { 1: "Base", 2: "Intermedio", 3: "Avanzato", 4: "Esperto" };
  return (
    <span className={`badge badge--l${livello}`} aria-label={`Livello ${etichette[livello]}`}>
      {etichette[livello]}
    </span>
  );
}
```

### Stato e eventi

```jsx
function Contatore() {
  const [count, setCount] = useState(0);
  return (
    <button onClick={() => setCount(c => c + 1)}>
      Click: {count}
    </button>
  );
}
```

> Aggiornamenti funzionali (`setState(prev => …)`) quando il nuovo stato dipende dal precedente.

### Liste e key

```jsx
<ul>
  {domande.map(d => (
    <li key={d.id}>{d.testo}</li>
  ))}
</ul>
```

La `key` deve essere stabile e unica: **mai** l'indice se la lista può riordinarsi o cambiare.

### Form controllato

```jsx
function LoginForm({ onSubmit }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  function handleSubmit(event) {
    event.preventDefault();
    onSubmit({ email, password });
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <label htmlFor="email">Email</label>
      <input id="email" type="email" value={email}
             onChange={e => setEmail(e.target.value)}
             autoComplete="email" required />

      <label htmlFor="password">Password</label>
      <input id="password" type="password" value={password}
             onChange={e => setPassword(e.target.value)}
             autoComplete="current-password" required />

      <button type="submit">Accedi</button>
    </form>
  );
}
```

### Effetti e cleanup

```jsx
useEffect(() => {
  const controller = new AbortController();

  async function carica() {
    try {
      const res = await fetch(`/api/quiz/${id}`, { signal: controller.signal });
      if (!res.ok) throw new Error("Errore di rete");
      setQuiz(await res.json());
    } catch (err) {
      if (err.name !== "AbortError") setErrore(err.message);
    }
  }

  carica();
  return () => controller.abort();
}, [id]);
```

Regole:
- ogni effetto dichiara **tutte** le dipendenze usate;
- cleanup obbligatorio per fetch, timer, listener;
- non usate un effetto per calcolare ciò che potete derivare durante il render.

### Stato complesso con useReducer

```jsx
function quizReducer(stato, azione) {
  switch (azione.type) {
    case "ANSWER": {
      if (stato.fase !== "question") return stato;
      return {
        ...stato,
        risposte: { ...stato.risposte, [azione.id]: azione.scelta },
        fase: "feedback",
      };
    }
    case "NEXT":
      return { ...stato, indice: stato.indice + 1, fase: "question" };
    case "SUBMIT":
      return { ...stato, fase: "submitted" };
    default:
      return stato;
  }
}
```

### Context per session e tema

```jsx
const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [utente, setUtente] = useState(null);
  const value = useMemo(() => ({ utente, setUtente }), [utente]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth deve essere usato dentro AuthProvider");
  return ctx;
}
```

### Routing e route protette

```jsx
<Routes>
  <Route path="/" element={<Home />} />
  <Route path="/login" element={<Login />} />
  <Route element={<ProtectedRoute />}>
    <Route path="/dashboard" element={<Dashboard />} />
    <Route path="/quiz/:id" element={<QuizPage />} />
  </Route>
  <Route path="*" element={<NotFound />} />
</Routes>
```

```jsx
function ProtectedRoute() {
  const { utente } = useAuth();
  const location = useLocation();
  if (!utente) return <Navigate to="/login" state={{ from: location }} replace />;
  return <Outlet />;
}
```

> La protezione lato client è **solo UX**. I permessi veri si verificano sul server.

### Custom hook

```jsx
function useLocalStorage(key, initial) {
  const [value, setValue] = useState(() => {
    try {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : initial;
    } catch {
      return initial;
    }
  });

  useEffect(() => {
    localStorage.setItem(key, JSON.stringify(value));
  }, [key, value]);

  return [value, setValue];
}
```

### Test con Testing Library

```jsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { expect, test } from "vitest";
import { QuizCard } from "./QuizCard";

test("mostra il feedback dopo la conferma", async () => {
  const user = userEvent.setup();
  render(<QuizCard domanda={{ testo: "Cos'è HTML?", opzioni: ["Linguaggio", "DB"], corretta: 0 }} />);

  await user.click(screen.getByRole("radio", { name: "Linguaggio" }));
  await user.click(screen.getByRole("button", { name: /conferma/i }));

  expect(screen.getByText(/corretto/i)).toBeInTheDocument();
});
```

### Concetti fondamentali aggiuntivi

#### Render puro e StrictMode

Il render deve essere una funzione pura: stessi input → stesso output, nessuna modifica a variabili esterne, nessun effetto collaterale. In sviluppo `<StrictMode>` invoca due volte componenti ed effetti per far emergere impurità e cleanup mancanti. Se il doppio render rompe qualcosa, il problema è nel codice, non in StrictMode.

#### Stato: snapshot, batching e aggiornamenti funzionali

```jsx
function Contatore() {
  const [count, setCount] = useState(0);

  function incrementa() {
    setCount(c => c + 1);
    setCount(c => c + 1); // legge il valore aggiornato
  }

  // setCount(count + 1) due volte produrrebbe solo +1
  return <button onClick={incrementa}>{count}</button>;
}
```

- Lo stato è uno **snapshot** del render corrente: non cambia subito dopo `setState`.
- React raggruppa gli aggiornamenti (batching), anche dentro eventi asincroni in React 18+.
- Usate la forma funzionale quando il nuovo valore dipende dal precedente.
- Non mutate mai lo stato: `stato.push(x)` non fa rerender, `setStato([...stato, x])` sì.

#### Sollevare lo stato e fonte unica di verità

Se due componenti devono condividere un dato, spostate lo stato nel loro antenato comune e passate valore + callback. Non duplicate lo stato e non tenete due copie sincronizzate con effetti: è la causa più comune di bug.

```jsx
function Genitore() {
  const [filtro, setFiltro] = useState("");
  return (
    <>
      <Filtro valore={filtro} onChange={setFiltro} />
      <Lista filtro={filtro} />
    </>
  );
}
```

Lo **stato derivato** si calcola durante il render, non si salva in un altro `useState`:

```jsx
const visibili = domande.filter(d => d.livello === livello); // non useState
```

#### Controllati e non controllati

| Controllato | Non controllato |
|---|---|
| `value` + `onChange` | `defaultValue` + `ref` |
| Validazione e UI sempre sincronizzate | Meno rerender, integrazione con form nativi |
| Più codice | Stato letto al submit |

L'input `type="file"` è sempre non controllato. Per form complessi valutate una libreria (React Hook Form) invece di decine di `useState`.

#### Ref e valori mutabili

```jsx
function Misura() {
  const boxRef = useRef(null);
  const timerRef = useRef(null);

  useEffect(() => {
    const observer = new ResizeObserver(([entry]) => {
      console.log(entry.contentRect.width);
    });
    observer.observe(boxRef.current);
    return () => observer.disconnect();
  }, []);

  return <div ref={boxRef}>Contenuto</div>;
}
```

- `useRef` conserva un valore tra i render **senza** provocare rerender.
- Usatelo per nodi DOM, timer, subscription, valori precedenti.
- Non leggete/scrivete `ref.current` durante il render (tranne l'inizializzazione).
- `forwardRef` permette di esporre un nodo interno; `useImperativeHandle` limita l'API esposta.
- Preferite callback ref o `useEffect` per misurare, non `document.querySelector`.

#### Memoization: quando serve davvero

```jsx
const Lista = memo(function Lista({ items, onSelect }) {
  return items.map(i => <Riga key={i.id} item={i} onSelect={onSelect} />);
});

const handleSelect = useCallback(id => setAttivo(id), []);
const ordinati = useMemo(() => [...items].sort(cmp), [items]);
```

- `memo` evita rerender se le props sono uguali (confronto superficiale).
- `useMemo`/`useCallback` servono per calcoli costosi o per stabilizzare props/effetti.
- Se il genitore crea ogni volta un oggetto/array/callback, la memoization non aiuta: stabilizzate la prop.
- Non memoizzate tutto "per sicurezza": aggiunge complessità e memoria.
- Misurate con React DevTools Profiler prima di ottimizzare.

#### Concorrenza e UI reattiva

```jsx
const [isPending, startTransition] = useTransition();
const [query, setQuery] = useState("");
const deferredQuery = useDeferredValue(query);

function cerca(e) {
  setQuery(e.target.value);
  startTransition(() => setFiltro(e.target.value));
}
```

`useTransition` segna un aggiornamento come non urgente; `useDeferredValue` mostra un valore "in ritardo" mentre il resto si aggiorna. Servono per mantenere reattivo l'input con liste grandi. Non sono un sostituto di paginazione o virtualizzazione.

#### Code splitting, lazy e Error Boundary

```jsx
const ModuliPage = lazy(() => import("./pages/ModuliPage.jsx"));

<Suspense fallback={<Spinner />}>
  <ModuliPage />
</Suspense>
```

```jsx
class ErrorBoundary extends React.Component {
  state = { errore: null };
  static getDerivedStateFromError(errore) { return { errore }; }
  componentDidCatch(errore, info) { console.error(errore, info); }
  render() {
    return this.state.errore
      ? <p>Qualcosa è andato storto. <button onClick={() => location.reload()}>Riprova</button></p>
      : this.props.children;
  }
}
```

`lazy` riduce il bundle iniziale; `Suspense` mostra un fallback. Gli Error Boundary catturano errori di render, lifecycle e costruttori, **non** errori in handler o codice asincrono (gestiteli con try/catch).

#### Portali, modali e focus

```jsx
import { createPortal } from "react-dom";

function Modale({ aperta, onClose, children }) {
  useEffect(() => {
    if (!aperta) return;
    const precedente = document.activeElement;
    const onKey = e => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      precedente?.focus();
    };
  }, [aperta, onClose]);

  if (!aperta) return null;
  return createPortal(
    <div role="dialog" aria-modal="true" aria-labelledby="titolo-modale">
      {children}
    </div>,
    document.body
  );
}
```

Un portale cambia il DOM, non l'albero React: gli eventi continuano a fare bubbling nel componente. Per una modale accessibile servono focus trap, chiusura con Escape, ripristino del focus e blocco dello scroll.

#### Composizione e condivisione

```jsx
function Card({ titolo, azioni, children }) {
  return (
    <section className="card">
      <header><h2>{titolo}</h2>{azioni}</header>
      <div className="card__body">{children}</div>
    </section>
  );
}
```

Preferite `children` e props di rendering alla duplicazione. Pattern utili: compound components (`Tabs`, `Tabs.List`, `Tabs.Panel`), render props, custom hook. Il Context serve per dati trasversali (tema, sessione), non per evitare ogni prop.

#### Eventi

- Gli eventi React sono sintetici e delegano al root; il pool è stato rimosso da React 17.
- `preventDefault()` annulla il comportamento nativo; `stopPropagation()` ferma il bubbling.
- Un handler inline ricreato a ogni render può rompere `memo`: usate `useCallback` se serve.
- Per liste lunghe, la delega con un handler sul contenitore riduce i listener.
- Gestite sempre tastiera e focus, non solo click.

#### Accessibilità in JSX

```jsx
<button
  type="button"
  aria-expanded={aperto}
  aria-controls="pannello-filtri"
  onClick={() => setAperto(v => !v)}
>
  Filtri
</button>
<div id="pannello-filtri" hidden={!aperto}>…</div>
```

- Usate elementi semantici (`button`, `nav`, `main`, `label`).
- Ogni input ha una label associata o `aria-label`.
- Gestite il focus dopo navigazione, apertura modale e cambi di vista.
- Annunciate gli aggiornamenti dinamici con `role="status"` o `aria-live`.
- Testate con tastiera, zoom e screen reader, non solo con il mouse.

#### Data fetching e stato del server

```jsx
function useQuiz(id) {
  const [stato, setStato] = useState({ dati: null, errore: null, loading: true });

  useEffect(() => {
    const controller = new AbortController();
    setStato({ dati: null, errore: null, loading: true });

    fetch(`/api/quiz/${id}`, { signal: controller.signal })
      .then(r => r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`)))
      .then(dati => setStato({ dati, errore: null, loading: false }))
      .catch(err => {
        if (err.name !== "AbortError") setStato({ dati: null, errore: err, loading: false });
      });

    return () => controller.abort();
  }, [id]);

  return stato;
}
```

- Sempre cleanup: senza `AbortController` una risposta lenta può sovrascrivere quella nuova (race condition).
- Distinguete `loading`, `error`, `empty` e `success`: non usate un solo booleano.
- Lo stato del server ha bisogno di cache, invalidazione e retry: valutate React Query/SWR.
- Evitate waterfall di `useEffect`: caricate in parallelo o a livello di route.
- Le mutazioni ottimistiche richiedono rollback in caso di errore.

#### Routing

- Rotte annidate e layout route per condividere navbar e protezione.
- `useParams` per l'id, `useSearchParams` per filtri condivisibili.
- `lazy` per route pesanti, `Suspense` per il fallback.
- Route protette solo per UX: i permessi reali sono sul server.
- Gestite 404, scroll restoration e focus sul titolo dopo il cambio pagina.

#### Styling

CSS Modules, Tailwind, CSS-in-JS e fogli globali hanno tradeoff. In ogni caso: temi con custom property, classi componibili, nessuno stile inline per media query e pseudo-classi. Evitate conflitti con specificità crescente e non duplicate i token.

#### Testing

```jsx
test("mostra un errore se l'email è vuota", async () => {
  const user = userEvent.setup();
  render(<LoginForm onSubmit={vi.fn()} />);
  await user.click(screen.getByRole("button", { name: /accedi/i }));
  expect(screen.getByRole("alert")).toHaveTextContent(/email obbligatoria/i);
});
```

Testate il comportamento visibile all'utente, non i dettagli implementativi. Query per ruolo e nome accessibile. Usate `userEvent` invece di `fireEvent`. Mockate la rete con MSW. Non riempite il progetto di snapshot.

#### Performance e errori comuni

- Profilate prima di ottimizzare; controllate quali componenti rerenderizzano e perché.
- Virtualizzate liste molto lunghe; paginate o caricate a blocchi.
- `key` stabili e uniche: l'indice rompe stato e animazioni.
- Evitate stato duplicato, stato derivato in `useEffect` e dipendenze mancanti.
- Attenzione alle **stale closure**: l'effetto vede i valori del render in cui è stato creato.
- Non usate Context per tutto: ogni consumer rerenderizza al cambio del valore.
- Cleanup per fetch, timer, listener, observer e subscription.
- Errori asincroni non catturati da Error Boundary: gestiteli esplicitamente.
- Misurate le metriche reali (LCP, INP, CLS), non solo il tempo di render.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Componenti statici**
Crea `Header`, `Footer`, `BadgeLivello`, `QuizCard` (senza stato) e componili in una pagina. Props tipizzate con PropTypes o TypeScript.
- **Criterio:** nessun componente supera 40 righe; nessuna logica duplicata.

**1.2 — Liste e condizionali**
Renderizza una lista di 6 domande con `map` e `key`. Mostra un messaggio se la lista è vuota e un badge "Nuova" per le domande con `createdAt` recente.
- **Criterio:** nessun warning di React in console.

**1.3 — Form controllato**
Form con nome, email e livello. Mostra in tempo reale l'anteprima dei dati inseriti. Il bottone è disabilitato finché i campi non sono validi.
- **Criterio:** l'anteprima è sempre sincronizzata; nessun `document.querySelector`.

**1.4 — Debug**
Correggi 5 errori tipici: `key` mancante, stato mutato direttamente, `useEffect` senza dipendenze, evento non preventDefault, props lette come array quando sono oggetto.
- **Criterio:** ogni correzione spiegata con il concetto React violato.

---

### L2 — Intermedio

**2.1 — QuizCard interattiva**
Componente con 4 opzioni, selezione singola, conferma, feedback corretto/errato con spiegazione, blocco delle modifiche dopo la conferma.
- **Vincoli:** accessibile con tastiera; usa `fieldset`/`legend` e `input type="radio"`.
- **Criterio:** test RTL che copre il flusso completo.

**2.2 — Barra di avanzamento**
Componente `ProgressBar` con `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, percentuale e testo "Domanda 3 di 10". Nessuna informazione solo cromatica.
- **Criterio:** lo screen reader annuncia il progresso corretto.

**2.3 — ResultPanel**
Schermata finale con punteggio, livello raggiunto, elenco risposte errate espandibili, bottone "Riprova" e "Torna alla dashboard".
- **Criterio:** i dati derivano dalle risposte, non da stato duplicato.

**2.4 — Routing**
Pagine: home, login, dashboard, quiz, risultato, 404. Layout con `Outlet`. Route protette per dashboard e quiz.
- **Criterio:** refresh diretto su `/quiz/42` funziona (configurazione SPA corretta).

**2.5 — Fetch con stati**
Carica i quiz dal server con `loading`, `error`, `empty`, `success`. Aggiungi retry manuale e messaggio d'errore utile.
- **Criterio:** nessun crash se il server risponde 500 o JSON malformato.

---

### L3 — Avanzato

**3.1 — Custom hook `useQuiz`**
Estrai tutta la logica del quiz in un hook: domanda corrente, risposte, punteggio, timer, submit. Il componente si occupa solo di rendering.
- **Criterio:** l'hook è testabile senza DOM; almeno 6 test.

**3.2 — AuthContext e session**
Context con login/logout, persistenza token (preferibilmente cookie httpOnly), caricamento iniziale, route protette e redirect post-login alla pagina richiesta.
- **Criterio:** alla scadenza della sessione l'utente viene riportato al login senza loop.

**3.3 — Form con React Hook Form + Zod**
Form di creazione domanda: testo, 4 opzioni, livello, spiegazione. Schema Zod condiviso con il server (stesso contratto). Errori accessibili.
- **Criterio:** nessun messaggio di errore duplicato; il submit invia solo dati validi.

**3.4 — Focus management**
Quando cambia domanda, sposta il focus sul titolo con `tabIndex={-1}` e annuncia il cambio con una live region. Dopo la conferma, il focus va al feedback.
- **Criterio:** completando il quiz solo da tastiera, non si perde mai il focus.

**3.5 — Test di integrazione**
Testa il flusso: login → dashboard → avvia quiz → rispondi → risultato. Mocka l'API con MSW (Mock Service Worker).
- **Criterio:** il test copre anche errore di rete e retry.

---

### L4 — Esperto

**4.1 — Architettura feature-based**
Riorganizza il client in `features/auth`, `features/quiz`, `features/dashboard`, `shared/ui`, `shared/lib`. Definisci le regole di dipendenza e i confini.
- **Criterio:** nessuna feature importa da un'altra feature; i componenti condivisi non conoscono il dominio.

**4.2 — Stato server con TanStack Query**
Sostituisci le fetch manuali con query/mutation: cache, invalidazione dopo il submit, optimistic update per le flashcard, retry e stato offline.
- **Criterio:** dopo il submit la dashboard mostra i dati aggiornati senza reload.

**4.3 — Performance**
Analizza con React DevTools Profiler. Applica `memo`, `useMemo`, `useCallback` solo dove misurato; code splitting per le route; lazy loading del grafico statistiche.
- **Criterio:** report prima/dopo con render misurati; bundle iniziale ridotto.

**4.4 — Robustezza**
Aggiungi Error Boundary per route, fallback per chunk falliti, gestione di sessioni scadute e retry automatico con backoff.
- **Criterio:** un errore in un widget non manda in crash l'intera dashboard.

**4.5 — Accessibilità e i18n**
Supporta due lingue, `lang` dinamico, formattazione date/numeri con `Intl`, e verifica l'intero flusso con axe.
- **Criterio:** zero violazioni critical/serious su tutte le pagine.

---

## 4. Quiz di verifica

1. Quando un componente si ri-renderizza?
2. Perché la `key` non dovrebbe essere l'indice?
3. Cosa fa il cleanup di `useEffect`?
4. Differenza tra stato derivato e stato duplicato?
5. Perché la protezione delle route lato client non basta?
6. Quando usare `useReducer` invece di `useState`?
7. Cosa misura il Profiler di React?

<details>
<summary>Risposte</summary>

1. Quando cambiano props o stato, quando il padre si ri-renderizza (salvo memoizzazione) o quando cambia un context consumato.
2. Se la lista si riordina, l'indice non identifica più lo stesso elemento: React riusa nodi sbagliati, causando stato e focus errati.
3. Esegue la pulizia prima del prossimo effetto e allo smontaggio: annulla fetch, timer, listener.
4. Lo stato derivato si calcola da props/stato esistenti durante il render; quello duplicato copia informazioni in un altro stato e può desincronizzarsi.
5. Il client può essere modificato o bypassato: i permessi vanno sempre verificati sul server.
6. Con logica di stato complessa, molte transizioni correlate o aggiornamenti che dipendono dallo stato precedente.
7. I render dei componenti, con durata e causa, per individuare colli di bottiglia.

</details>

---

## 5. Mini-progetto del modulo

**"Interfaccia RipassoAI"**

Requisiti:

- layout con header, sidebar, main e footer;
- pagine: login, dashboard, catalogo quiz, quiz, risultato;
- `AuthContext` e route protette;
- `useQuiz` con timer e punteggio;
- form di creazione domanda validato con Zod;
- componenti accessibili e responsive;
- test RTL per almeno 3 flussi;
- nessun dato hardcoded: tutto da API mockate con MSW.

**Consegna:** cartella `modulo-04/` + `README.md` con architettura, scelte di stato e test eseguiti.

---

## 6. AI pairing

```text
Agisci come React reviewer esperto di accessibilità.
Ti incollo QuizCard. Voglio:
1) bug di stato o dipendenze;
2) problemi di accessibilità;
3) test RTL mancanti.
Per ogni punto: riga, impatto, patch minima. Non riscrivere il componente.
```

```text
Ho questo errore: "Too many re-renders".
Spiegami le 3 cause più probabili nel mio codice e come isolarle con il Profiler.
Non darmi una soluzione generica: fai domande se manca contesto.
```

**Verifica:** esegui i test, naviga solo da tastiera, guarda la console (warning), misura i render. L'AI tende a mettere `useEffect` ovunque e a ignorare le dipendenze.

---

## 7. Checklist di uscita

- [ ] So decidere dove vive uno stato.
- [ ] Non duplico stato derivabile.
- [ ] Ogni effetto ha dipendenze corrette e cleanup.
- [ ] Le route protette non sostituiscono i controlli server.
- [ ] I form sono accessibili e validati.
- [ ] Ho testato almeno un flusso completo.
- [ ] Ho consegnato l'interfaccia con test.
