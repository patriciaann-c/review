# RipassoAI — quiz e moduli di ripasso

Web app React (JavaScript) per allenarsi con quiz a livelli e consultare i moduli del corso.
Stack: **React 19 + Vite + pnpm + Bootstrap 5.3 + Supabase**.

## Requisiti

- Node.js >= 20
- pnpm

## Avvio

```bash
pnpm install
cp .env.example .env.local   # poi inserisci la chiave pubblica Supabase
pnpm dev
```

Variabili in `.env.local`:

| Variabile | Dove trovarla |
|---|---|
| `VITE_SUPABASE_URL` | Dashboard Supabase → Project Settings → API |
| `VITE_SUPABASE_ANON_KEY` | Dashboard Supabase → Project Settings → API (anon/publishable) |

Usa solo la chiave **pubblica**: la `service_role` non deve mai finire nel client né su Git.

## Deploy su Netlify

Il repository Git ha la radice un livello sopra questa cartella, quindi Netlify deve
puntare a `ripasso-ai/`. La configurazione è nel `netlify.toml` alla radice del repo:

| Impostazione | Valore |
|---|---|
| Base directory | `ripasso-ai` |
| Build command | `pnpm build` |
| Publish directory | `dist` (relativa alla base → `ripasso-ai/dist`) |

In **Site configuration → Environment variables** aggiungi:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY` (chiave pubblica anon/publishable)

Le rotte `/quiz` e `/moduli` sono gestite da React Router: `netlify.toml` e
`public/_redirects` riscrivono ogni URL su `index.html`, altrimenti Netlify
risponde con la sua pagina "Page not found".

## Pagine

- `/` — reindirizza a `/quiz`.
- `/quiz` — elenco degli 11 argomenti con ricerca, statistiche e quiz a livelli.
  Il quiz mostra una domanda alla volta, con barra di avanzamento, feedback e riepilogo finale;
  le opzioni vengono mescolate a ogni caricamento.
- `/moduli` — indice degli 11 moduli e lettura del contenuto Markdown, caricato su richiesta.

Le vecchie pagine delle schede di ripasso e delle flashcard sono state rimosse dall'interfaccia.

## Database

Le migrazioni sono in `supabase/migrations/`:

1. `0001_schema.sql` — schema Postgres completo, enum, indici, RLS, trigger e RPC.
   Contiene anche le tabelle storiche delle schede, non più usate dall'interfaccia.
2. `0002_seed.sql` — catalogo del corso e scheda demo di Giulia R. (5A).
3. `0003_quiz_catalogo.sql` — catalogo di 30 domande approvate (6 L1, 6 L2, 12 L3, 6 L4)
   e 3 prove di esempio.
4. `0004_quiz_argomenti.sql` — RPC `invia_quiz_argomento` e helper di import `importa_quiz`.
5. `0005_quiz_html_css.sql` … `0009_quiz_langchain_agenti.sql` — banco domande per i primi 10 argomenti:
   **30 domande per argomento, 300 in totale**, con 4 opzioni ciascuna.
6. `0010_quiz_javascript_extra.sql` — **20 domande JavaScript aggiuntive** (4 L1, 6 L2, 6 L3, 4 L4):
   JavaScript arriva a **50 domande**, il catalogo complessivo a **320**.
7. `0011_quiz_autenticazione.sql` — crea il **modulo 11** (Autenticazione e autorizzazione) e
   **30 domande** (8 L1, 8 L2, 8 L3, 6 L4): il catalogo arriva a **11 argomenti** e **350 domande**.

Ordine di esecuzione:

1. Applica `0001_schema.sql` (Supabase MCP oppure SQL Editor).
2. Registrati nell'app con email e password.
3. Applica `0002_seed.sql` e `0003_quiz_catalogo.sql`.
4. Applica `0004` … `0011` in ordine: aggiungono i quiz per argomento, le domande extra di JavaScript
   e il modulo su autenticazione e autorizzazione.
5. Se la registrazione richiede la conferma email, disattivala in **Authentication → Providers → Email**
   oppure conferma l'indirizzo dal link ricevuto.

L'helper `importa_quiz(p_slug, p_domande)` è idempotente sul testo della domanda: rieseguire una
migrazione non crea duplicati.

## Struttura

```text
src/
├── components/    # LoginForm, QuizArgomenti, QuizRunner, ModuliPage
├── layouts/       # MainLayout (navbar, utente, logout)
├── hooks/         # logica dati: login, quiz, argomenti, moduli
├── content/       # gli 11 moduli del corso in Markdown
├── lib/           # client Supabase
├── styles/        # design system e stili dell'app
├── App.jsx        # sessione e rotte
└── main.jsx       # bootstrap + CSS
```

I contenuti dei moduli sono file statici in `src/content/moduli/`; la copia in `supabase/moduli/`
serve come archivio dei materiali del corso e va tenuta allineata.

## Sicurezza

- RLS attiva su tutte le tabelle: ogni utente legge solo i propri dati.
- La correzione avviene lato server con RPC `SECURITY DEFINER`: il client non riceve
  `opzione.corretta` né la spiegazione prima dell'invio.
- I quiz per argomento usano `invia_quiz_argomento` (SECURITY DEFINER, grant solo ad `authenticated`):
  crea un tentativo `DIAGNOSTICO` con `scheda_id` null e aggiorna la padronanza.
- L'helper di import `importa_quiz` è revocato a `public`, `anon` e `authenticated`.
- L'RPC storica `invia_tentativo` e le RPC delle flashcard restano nel database per compatibilità,
  ma non sono più richiamate dall'app.
- La lettura dei dati passa sempre dai filtri di ownership previsti dalle policy.

## MCP Supabase in OpenCode

La configurazione globale è in `~/.config/opencode/opencode.jsonc`:

```jsonc
{
  "mcp": {
    "servers": {
      "supabase": {
        "type": "remote",
        "url": "https://mcp.supabase.com/mcp?project_ref=imgyypzzvobrewdrofby&features=database,development,docs"
      }
    }
  }
}
```

Autenticazione: dentro OpenCode esegui `/mcps`, seleziona `supabase` e completa il login OAuth.
