# Modulo 02 — CSS

> **Livello:** fondamenta · **Tempo:** 8 h · **Prerequisiti:** HTML
> **Deliverable:** design system e dashboard responsive della piattaforma quiz.

---

## 1. Traguardi

Al termine del modulo sapete:

- ragionare su **cascata, specificità e box model** senza tentativi casuali;
- costruire layout con **Flexbox** e **Grid** scegliendo lo strumento giusto;
- progettare **mobile-first** con unità fluide e container query;
- usare **custom properties** e design token per temi coerenti (chiaro/scuro);
- animare senza rompere accessibilità e performance;
- fare un audit di contrasto e di layout.

---

## 2. Concetti chiave (cheat sheet)

### Cascata e specificità

Ordine di priorità (dal più forte):

1. `!important` (da evitare);
2. stili inline;
3. ID;
4. classi, attributi, pseudo-classi;
5. elementi e pseudo-elementi.

A parità di specificità vince **l'ultima regola** nell'ordine di caricamento. Preferite specificità bassa e classi singole.

```css
/* ❌ fragile */
#app .card .title span { color: red; }

/* ✅ robusto */
.card__title { color: var(--color-text); }
```

### Box model

```css
*, *::before, *::after { box-sizing: border-box; }

.card {
  inline-size: min(100%, 28rem); /* meglio di width */
  padding: 1rem;
  border: 1px solid var(--color-border);
  border-radius: 0.75rem;
}
```

`content-box` (default): `width` = contenuto. `border-box`: `width` include padding e bordo. Usate quasi sempre `border-box`.

### Layout: quale strumento?

| Esigenza | Strumento |
|---|---|
| Riga o colonna di elementi, allineamento | **Flexbox** |
| Griglia bidimensionale, aree, dashboard | **Grid** |
| Testo che scorre | flusso normale |
| Componente isolato che si adatta al contenitore | **container query** |

```css
/* Flex: barra di navigazione */
.navbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

/* Grid: griglia di card che si adatta */
.quiz-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(16rem, 100%), 1fr));
  gap: 1rem;
}
```

### Dashboard con Grid Areas

```css
.dashboard {
  display: grid;
  grid-template-columns: 16rem 1fr;
  grid-template-rows: auto 1fr;
  grid-template-areas:
    "sidebar header"
    "sidebar main";
  min-block-size: 100dvh;
}

.dashboard__sidebar { grid-area: sidebar; }
.dashboard__header  { grid-area: header; }
.dashboard__main    { grid-area: main; }

@media (max-width: 48rem) {
  .dashboard {
    grid-template-columns: 1fr;
    grid-template-areas:
      "header"
      "main";
  }
  .dashboard__sidebar { display: none; }
}
```

### Design token

```css
:root {
  /* primitivi */
  --blue-500: #2563eb;
  --blue-700: #1d4ed8;
  --gray-50: #f8fafc;
  --gray-900: #0f172a;

  /* semantici */
  --color-bg: var(--gray-50);
  --color-text: var(--gray-900);
  --color-primary: var(--blue-500);
  --color-primary-hover: var(--blue-700);
  --color-border: #e2e8f0;

  /* spaziatura e tipografia */
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  --space-3: 1rem;
  --space-4: 1.5rem;
  --radius-md: 0.75rem;
  --font-body: system-ui, sans-serif;
  --text-base: clamp(1rem, 0.95rem + 0.25vw, 1.125rem);
  --text-xl: clamp(1.5rem, 1.2rem + 1.5vw, 2.25rem);
}

[data-theme="dark"] {
  --color-bg: #0b1120;
  --color-text: #e2e8f0;
  --color-border: #1e293b;
}
```

### Tipografia fluida

```css
h1 { font-size: clamp(1.75rem, 1.2rem + 2.5vw, 3rem); line-height: 1.1; }
p  { font-size: var(--text-base); line-height: 1.6; max-inline-size: 65ch; }
```

### Feedback e animazioni

```css
.answer--correct { border-color: #16a34a; background: #f0fdf4; }
.answer--wrong   { border-color: #dc2626; background: #fef2f2; }

@keyframes pop {
  0%   { transform: scale(0.96); opacity: 0.6; }
  100% { transform: scale(1);    opacity: 1; }
}

.answer--correct { animation: pop 180ms ease-out; }

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### Container query

```css
.quiz-card-wrapper { container-type: inline-size; }

@container (min-width: 28rem) {
  .quiz-card { display: grid; grid-template-columns: auto 1fr; gap: 1rem; }
}
```

### Focus visibile

```css
:focus-visible {
  outline: 3px solid var(--color-primary);
  outline-offset: 2px;
}
button:focus:not(:focus-visible) { outline: none; }
```

### Concetti fondamentali aggiuntivi

#### Selettori e combinazioni

```css
/* discendente: qualsiasi livello */
.card .titolo { }

/* figlio diretto */
.lista > li { }

/* fratello adiacente e fratelli successivi */
h2 + p { margin-block-start: 0.5rem; }
h2 ~ p { color: var(--color-muted); }

/* pseudo-classi utili */
:is(h2, h3) { text-wrap: balance; }       /* specificità del più specifico */
:where(.stack) > * + * { margin-block-start: 1rem; } /* specificità zero */
.form:has(input:invalid) { border-color: #dc2626; }
.lista li:not(:last-child) { border-block-end: 1px solid var(--color-border); }

/* pseudo-elementi */
.card::before { content: ""; position: absolute; inset: 0; }
.articolo::selection { background: #fde68a; }
```

`:has()` permette di selezionare un genitore in base ai figli: è utilissimo per stati del form e layout condizionali. `:where()` azzera la specificità, ideale per reset e utility.

#### Unità e funzioni matematiche

| Unità | Quando usarla |
|---|---|
| `rem` | Dimensioni globali, spaziature, tipografia |
| `em` | Dimensioni relative al componente (padding di un bottone) |
| `%` | Larghezze rispetto al contenitore |
| `vw`/`vh` | Viewport; preferite `dvh`/`svh` su mobile |
| `ch` | Larghezza di lettura del testo (`65ch`) |
| `fr` | Frazioni di spazio in Grid |
| `px` | Bordi, ombre, dettagli fini |

```css
.hero {
  padding-block: clamp(2rem, 6vw, 5rem);
  inline-size: min(100% - 2rem, 70rem);
  margin-inline: auto;
  font-size: calc(1rem + 0.5vw);
}
```

`calc()`, `min()`, `max()` e `clamp()` si combinano e accettano unità diverse. Le custom property possono avere un fallback: `var(--color-primary, #2563eb)`.

#### Position e stacking context

| Valore | Comportamento |
|---|---|
| `static` | Flusso normale, `z-index` ignorato |
| `relative` | Si sposta rispetto a sé stesso, resta nel flusso |
| `absolute` | Esce dal flusso, si posiziona rispetto all'antenato posizionato più vicino |
| `fixed` | Rispetto al viewport (o a un antenato con `transform`/`filter`) |
| `sticky` | Relativo finché non raggiunge la soglia, poi fisso nel contenitore |

`z-index` funziona solo su elementi posizionati o su flex/grid item e confronta solo elementi nello **stesso stacking context**. Un nuovo stacking context nasce con `transform`, `opacity < 1`, `filter`, `isolation: isolate`, `will-change`. Se un elemento non sale, spesso il problema è il contesto del genitore, non il numero.

```css
.modale {
  position: fixed;
  inset: 0;
  z-index: 10; /* numeri piccoli e documentati */
  isolation: isolate;
}
```

#### Display, overflow e flusso

```css
.sr-only {
  position: absolute;
  inline-size: 1px;
  block-size: 1px;
  overflow: hidden;
  clip-path: inset(50%);
  white-space: nowrap;
}

.scroll-area {
  overflow: auto;
  overscroll-behavior: contain;
  scrollbar-gutter: stable;
}
```

- `display: none` rimuove dal layout e dall'accessibilità; `visibility: hidden` riserva lo spazio.
- `display: contents` elimina la scatola del contenitore (utile per wrapper semantici, attenzione all'accessibilità).
- `overflow: clip` taglia senza creare scroll; `auto` mostra la scrollbar solo se serve.
- `overflow-x: hidden` su `body` spesso maschera un layout rotto: trovate la causa.

#### Proprietà logiche

```css
.card {
  padding-inline: 1rem;       /* sinistra + destra */
  padding-block: 0.75rem;     /* sopra + sotto */
  margin-inline-start: auto;
  border-inline-start: 4px solid var(--color-primary);
  inline-size: 100%;
  max-inline-size: 40rem;
}
```

Le proprietà logiche (`inline`/`block`, `start`/`end`) si adattano automaticamente a lingue RTL e modalità verticali. Preferitele a `left`/`right` nei nuovi progetti.

#### Colori moderni

```css
:root {
  --brand: oklch(62% 0.19 255);
  --brand-soft: color-mix(in oklab, var(--brand) 15%, white);
  --overlay: rgb(15 23 42 / 0.6);
}

.btn {
  background: linear-gradient(135deg, var(--brand), color-mix(in oklab, var(--brand) 70%, #7c3aed));
  box-shadow: 0 10px 30px -12px rgb(37 99 235 / 0.45);
}
```

`oklch` permette palette percettivamente uniformi; `color-mix()` crea varianti senza duplicare valori. Verificate **sempre** il contrasto: un colore bello può essere illeggibile.

#### Transizioni, transform e animazioni

```css
.btn {
  transition: transform 160ms ease, box-shadow 160ms ease;
}
.btn:hover { transform: translateY(-2px); }
.btn:active { transform: translateY(0) scale(0.98); }

@keyframes comparsa {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
```

- Animate `transform` e `opacity`: non causano layout/paint continui.
- Evitate di animare `width`, `height`, `top`, `left`, `margin`.
- `will-change` solo su elementi che stanno davvero per animarsi, e toglietelo dopo.
- Rispettate `prefers-reduced-motion` (già visto sopra): l'animazione non è mai l'unico segnale.

#### Tipografia

```css
body {
  font-family: "Inter", system-ui, -apple-system, "Segoe UI", sans-serif;
  font-size: 1rem;
  line-height: 1.6;
  text-wrap: pretty;
}

h1, h2 { text-wrap: balance; line-height: 1.15; }
p { max-inline-size: 68ch; }

@font-face {
  font-family: "Inter";
  src: url("/fonts/inter.var.woff2") format("woff2");
  font-display: swap;
  font-weight: 100 900;
}
```

`font-display: swap` evita testo invisibile durante il caricamento. Una linea di testo comoda sta tra 45 e 75 caratteri. Non usate mai solo il colore o la dimensione per gerarchizzare: la semantica resta negli heading.

#### Layout avanzato

```css
/* Flex: grow/shrink/basis */
.toolbar > .search { flex: 1 1 18rem; min-inline-size: 0; }

/* Grid: auto-fit vs auto-fill */
.griglia {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(16rem, 100%), 1fr));
  gap: clamp(1rem, 2vw, 1.5rem);
}

/* Aree e allineamento */
.dashboard {
  display: grid;
  grid-template-areas: "nav main";
  grid-template-columns: 15rem 1fr;
  place-items: start stretch;
}
```

- `auto-fit` collassa le tracce vuote, `auto-fill` le mantiene: cambia il comportamento con pochi elementi.
- Nei flex item il `min-width: auto` impedisce il restringimento: impostate `min-inline-size: 0` quando il contenuto deve troncare.
- `aspect-ratio` mantiene proporzioni senza padding hack; `object-fit: cover` ritaglia le immagini.

#### Responsive e preferenze utente

```css
/* mobile-first, sintassi range */
@media (width >= 48rem) {
  .layout { grid-template-columns: 15rem 1fr; }
}

@media (prefers-color-scheme: dark) {
  :root { color-scheme: dark; }
}

@media (prefers-contrast: more) {
  :root { --color-border: #000; }
}

@media (hover: none) {
  .card:hover { transform: none; }
}
```

Progettate prima per lo schermo piccolo, poi aggiungete. Le container query sono migliori delle media query per componenti riutilizzabili: il componente reagisce al suo contenitore, non al viewport.

#### Cascade layers e organizzazione

```css
@layer reset, base, layout, components, utilities;

@layer components {
  .card { border-radius: var(--radius-md); }
}
```

I layer dichiarano l'ordine di priorità in modo esplicito, riducendo la guerra di specificità. Organizzate i file per responsabilità (token, reset, layout, componenti, utility) e nominate le classi in modo coerente (BEM o utility).

#### Debug del CSS

- Usate il pannello **Computed** per vedere il valore effettivo e da quale regola arriva.
- Attivate le sovrapposizioni di Grid/Flex per capire le tracce.
- Il **box model** mostra margini, bordi e padding reali.
- Il **contrast checker** di DevTools verifica l'accessibilità.
- **Coverage** mostra il CSS inutilizzato; **paint flashing** evidenzia i repaint.
- Se un layout "esplode", controllate `min-width`, `overflow` e elementi con dimensioni fisse.

#### Errori comuni

- Numeri magici ovunque invece di token.
- `100vw` che crea scroll orizzontale per la scrollbar.
- Centratura con `position: absolute` invece di Flex/Grid.
- `!important` come soluzione a cascata mal progettata.
- `z-index: 9999` senza capire lo stacking context.
- Animare proprietà di layout.
- `outline: none` senza un focus visibile alternativo.
- Contrasto insufficiente su testi secondari e placeholder.
- Layout desktop "adattato" con media query invece di partire mobile-first.
- Font con dimensioni in `px` che ignorano lo zoom dell'utente.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Box model lab**
Data una card con `width: 300px; padding: 20px; border: 5px solid`, calcola la larghezza occupata con `content-box` e con `border-box`. Poi fai in modo che la card non sbordi mai dal contenitore.
- **Criterio:** sai spiegare la differenza e la card non genera scroll orizzontale.

**1.2 — Tre centrature**
Centra una scatola orizzontalmente e verticalmente in tre modi: Flexbox, Grid, `margin: auto`. Scrivi un commento con pro/contro di ciascuno.
- **Criterio:** i tre metodi funzionano e la spiegazione è corretta.

**1.3 — Bottone con stati**
Stila un bottone con stati default, hover, focus-visible, active, disabled. Contrasto testo/sfondo ≥ 4.5:1.
- **Criterio:** lo stato focus è visibile anche senza mouse; il disabled non sembra cliccabile.

**1.4 — Specificità**
Date 5 regole che colpiscono lo stesso elemento, prevedi il colore finale. Poi riscrivi tutto con specificità minima (solo classi).
- **Criterio:** la previsione coincide con il risultato del browser.

---

### L2 — Intermedio

**2.1 — Card quiz**
Costruisci la card di una domanda: badge livello, testo, 4 risposte, bottone "Conferma". Layout con Flexbox, spaziatura con token, tipografia fluida.
- **Criterio:** a 320px e a 1440px non ci sono overflow né testo tagliato.

**2.2 — Griglia dei livelli**
Crea una griglia di 4 card (L1–L4) che passa da 1 a 2 a 4 colonne. Ogni livello ha un colore diverso applicato tramite `data-level`, non con classi duplicate.
- **Criterio:** nessuna media query hardcoded per ogni breakpoint; usa `auto-fit`/`minmax`.

**2.3 — Navbar responsive**
Navbar mobile-first con logo, link, avatar. Su mobile i link stanno in un menu apribile senza JavaScript (`<details>` o checkbox hack), su desktop sono in linea. Navbar sticky.
- **Criterio:** funziona da tastiera e non copre il contenuto quando si salta a un'ancora.

**2.4 — Tema chiaro/scuro**
Implementa i token e un toggle che imposta `data-theme` su `<html>`. Rispetta `prefers-color-scheme` al primo caricamento.
- **Criterio:** tutti i testi hanno contrasto ≥ 4.5:1 in entrambi i temi.

**2.5 — Form con stati**
Stila input, label, messaggi di errore, `:focus-visible`, `:invalid:not(:placeholder-shown)`. L'errore deve essere visibile anche senza colore (icona + testo).
- **Criterio:** nessun messaggio di errore appare prima che l'utente interagisca.

---

### L3 — Avanzato

**3.1 — Dashboard studente**
Layout con sidebar, header, area principale e pannello statistiche. Usa `grid-template-areas`. Su tablet la sidebar diventa una barra orizzontale; su mobile un drawer.
- **Criterio:** nessun layout shift passando tra breakpoint; landmark HTML coerenti.

**3.2 — Feedback animato**
Anima la risposta corretta/errata con transform e opacity (non con width/height). Rispetta `prefers-reduced-motion`. Nessun CLS misurabile.
- **Criterio:** DevTools Performance non mostra layout thrashing; l'animazione dura < 250 ms.

**3.3 — Tipografia e spaziatura fluide**
Definisci una scala tipografica e una di spaziatura con `clamp()`. Applica `max-inline-size: 65ch` ai testi lunghi. Usa container query per la card quiz dentro la sidebar.
- **Criterio:** il testo resta leggibile da 320px a 1920px senza breakpoint aggiuntivi.

**3.4 — Audit del contrasto**
Trova e correggi 6 coppie di colori insufficienti in un tema fornito. Documenta rapporto prima/dopo con uno strumento (DevTools o contrast checker).
- **Criterio:** tutte le correzioni rispettano WCAG AA; nessuna modifica al layout.

**3.5 — Performance CSS**
Riduci il CSS di una pagina demo: elimina regole morte, sostituisci `@import`, carica i font con `font-display: swap`, preload del font critico, `content-visibility: auto` per sezioni sotto la piega.
- **Criterio:** LCP migliora o resta uguale; CLS ≤ 0.1.

---

### L4 — Esperto

**4.1 — Design token completi**
Progetta tre livelli di token: primitivi, semantici, di componente. Documenta naming, uso e divieti. Implementa i temi chiaro, scuro e ad alto contrasto.
- **Criterio:** cambiando un token primitivo cambia coerentemente tutta la UI; nessun colore hardcoded nei componenti.

**4.2 — ADR sullo stile**
Scrivi un Architecture Decision Record che scelga tra CSS Modules, Tailwind e vanilla-extract per RipassoAI. Confronta: produttività, coerenza, bundle, curva di apprendimento, testabilità, integrazione React.
- **Criterio:** decisione motivata, alternative reali, conseguenze e criteri di revisione.

**4.3 — Critical CSS e font**
Implementa una strategia di caricamento per la landing: CSS critico inline, resto asincrono, font con `preconnect`, `preload`, `font-display: swap`, subset. Misura LCP prima/dopo.
- **Criterio:** primo rendering utile senza FOUC evidente; report con numeri.

**4.4 — QA cross-browser**
Crea una matrice di test (Chrome, Firefox, Safari, Edge; 320/768/1440) per 10 componenti. Individua almeno 3 differenze reali e proponi fallback progressivi.
- **Criterio:** ogni differenza è riprodotta e documentata, non ipotizzata.

**4.5 — Code review CSS**
Rivedi un foglio di stile con: `!important`, specificità alta, magic number, duplicazioni, nomi incoerenti. Riscrivi le parti critiche e stima il ridimensionamento.
- **Criterio:** riduzione delle regole ≥ 20% senza cambi visivi.

---

## 4. Quiz di verifica

1. Con `box-sizing: border-box`, `width: 300px` include padding e bordo?
2. Quando è meglio Grid di Flexbox?
3. Cosa fa `repeat(auto-fit, minmax(16rem, 1fr))`?
4. Perché evitare `!important`?
5. Cosa cambia `prefers-reduced-motion`?
6. A cosa serve `container-type: inline-size`?
7. Qual è il contrasto minimo per testo normale secondo WCAG AA?

<details>
<summary>Risposte</summary>

1. Sì: la larghezza dichiarata include contenuto, padding e bordo.
2. Quando serve un layout bidimensionale con righe e colonne coerenti o aree nominate (dashboard, griglie complesse). Flexbox è per una dimensione principale.
3. Crea quante colonne stanno nel contenitore, ognuna larga almeno 16rem, distribuendo lo spazio residuo in parti uguali; le colonne vuote collassano.
4. Rompe la cascata, rende difficile il riuso e il tema, crea guerra di specificità.
5. Permette di ridurre o disattivare animazioni e transizioni per chi ha disturbi vestibolari o preferenze di movimento ridotto.
6. Rende il contenitore un riferimento per le container query: i figli reagiscono alla sua larghezza, non a quella del viewport.
7. 4.5:1 per testo normale, 3:1 per testo grande (≥ 24px o ≥ 18.66px bold).

</details>

---

## 5. Mini-progetto del modulo

**"Tema RipassoAI"**

Consegna:

- `tokens.css` con primitivi, semantici e componente;
- `components.css` per bottone, input, card quiz, badge livello, progress, alert;
- `dashboard.html` + `dashboard.css` con layout a grid areas;
- tema chiaro/scuro e rispetto di `prefers-reduced-motion`;
- pagina demo `index.html` con tutti i componenti;
- report di audit: contrasto, responsive 320/768/1440, Lighthouse.

**Criterio di eccellenza:** nessun colore o spazio hardcoded nei componenti; la dashboard è usabile da tastiera; il tema scuro non è un semplice invert.

---

## 6. AI pairing

```text
Agisci come senior CSS reviewer.
Ti incollo HTML e CSS. Voglio:
1) 5 problemi concreti con selettore e riga;
2) una versione refactored con custom properties;
3) spiegazione del perché, non solo il codice.
Vincolo: non cambiare la struttura HTML.
```

```text
Genera una griglia responsive per 4 card di livello.
Requisiti: mobile-first, 1/2/4 colonne, gap con token, nessuna media query
oltre a quelle strettamente necessarie, supporto a 320px.
Spiega perché hai scelto auto-fit rispetto a media query.
```

**Verifica:** ridimensiona davvero la finestra, ispeziona il box model, misura il contrasto, controlla il CLS. L'AI tende a inventare breakpoint e a usare `!important` per "far funzionare" le cose.

---

## 7. Checklist di uscita

- [ ] So prevedere quale regola vince in caso di conflitto.
- [ ] Scelgo Flexbox o Grid senza esitare.
- [ ] Uso i token e non colori sparsi.
- [ ] Il mio layout regge 320px senza scroll orizzontale.
- [ ] Il focus è sempre visibile.
- [ ] So misurare contrasto, CLS e LCP.
- [ ] Ho consegnato tema e dashboard.
