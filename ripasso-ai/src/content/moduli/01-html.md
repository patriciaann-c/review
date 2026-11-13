# Modulo 01 — HTML

> **Livello:** fondamenta · **Tempo:** 6 h · **Prerequisiti:** nessuno
> **Deliverable:** scheletro accessibile e semanticamente corretto della "scheda di ripasso".

---

## 1. Traguardi

Al termine del modulo sapete:

- scrivere un documento HTML valido e con la lingua corretta;
- scegliere l'elemento giusto in base al **significato**, non all'aspetto;
- costruire form usabili da tastiera e con validazione nativa;
- rendere una pagina comprensibile a screen reader e motori di ricerca;
- riconoscere e correggere gli errori più comuni (div soup, label mancanti, heading saltati).

---

## 2. Concetti chiave (cheat sheet)

### Struttura minima

```html
<!doctype html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>RipassoAI — Scheda di ripasso</title>
    <meta name="description" content="Quiz e schede per il ripasso." />
  </head>
  <body>
    <a class="skip-link" href="#main">Vai al contenuto</a>
    <header>…</header>
    <nav aria-label="Principale">…</nav>
    <main id="main">…</main>
    <footer>…</footer>
  </body>
</html>
```

### Elementi semantici: quando usarli

| Elemento | Significato | Non usarlo per |
|---|---|---|
| `header` | Intestazione di pagina o di sezione | Ogni titolo |
| `nav` | Gruppo di link di navigazione | Qualsiasi elenco di link |
| `main` | Contenuto principale, **uno solo** per pagina | Contenitore generico |
| `section` | Sezione con un titolo proprio | Sostituire `div` |
| `article` | Contenuto autonomo e riutilizzabile (una domanda, un post) | Layout |
| `aside` | Contenuto correlato ma non principale | Pubblicità qualsiasi |
| `figure`/`figcaption` | Immagine + didascalia | Sfondo decorativo |
| `details`/`summary` | Risposta espandibile senza JS | Menu di navigazione |
| `dialog` | Finestra modale nativa | Tooltip |
| `time` | Data/ora leggibile da machine | Testo qualsiasi |

### Form accessibili

```html
<form action="/iscrizione" method="post" novalidate>
  <fieldset>
    <legend>Dati dello studente</legend>

    <label for="email">Email</label>
    <input id="email" name="email" type="email"
           autocomplete="email" required
           aria-describedby="email-help" />
    <p id="email-help">Usa l'email della scuola.</p>

    <label for="livello">Livello di partenza</label>
    <select id="livello" name="livello" required>
      <option value="">Scegli…</option>
      <option value="L1">Base</option>
      <option value="L2">Intermedio</option>
      <option value="L3">Avanzato</option>
      <option value="L4">Esperto</option>
    </select>

    <button type="submit">Iscriviti</button>
  </fieldset>
</form>
```

**Regole:**
- ogni campo ha una `label` associata con `for`/`id` (o avvolge l'input);
- `name` è obbligatorio per inviare il dato;
- `type` corretto (`email`, `password`, `number`, `date`, `search`, `tel`, `url`);
- `autocomplete` aiuta tutti, soprattutto chi usa tecnologie assistive;
- `required`, `minlength`, `pattern`, `min`/`max` fanno validazione nativa;
- gli errori vanno collegati con `aria-describedby` e annunciati con `role="alert"`;
- il `button` dentro un form ha sempre `type` esplicito.

### Accessibilità: la checklist minima

- [ ] `lang` corretto sull'`html`.
- [ ] Un solo `h1`; gerarchia `h2` → `h3` senza salti.
- [ ] Ogni immagine ha `alt`; decorative → `alt=""`.
- [ ] Ogni campo ha una label visibile.
- [ ] Focus visibile e ordine di tabulazione logico.
- [ ] Contrasto testo ≥ 4.5:1 (testo normale) e 3:1 (testo grande).
- [ ] Link con testo comprensibile fuori contesto (non "clicca qui").
- [ ] `skip link` come primo elemento focalizzabile.
- [ ] Nessuna informazione trasmessa solo con il colore.
- [ ] Tabelle con `caption`, `th` e `scope`.

### Microdati e SEO

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Quiz",
  "name": "Quiz di HTML — Livello base",
  "about": "HTML semantico",
  "educationalLevel": "Beginner",
  "inLanguage": "it"
}
</script>
```

### Concetti fondamentali aggiuntivi

#### Percorsi e URL

Un URL è composto da schema, host, percorso, query string e frammento. Nei link usate il percorso più semplice possibile.

```html
<a href="/moduli/html">Modulo HTML</a>          <!-- assoluto dal dominio -->
<a href="../css">Modulo CSS</a>                  <!-- relativo -->
<a href="./assets/guida.pdf" download>Guida</a> <!-- download -->
<a href="mailto:tutor@example.com">Scrivi al tutor</a>
```

- `/` iniziale = radice del sito; `../` = cartella superiore; `.` = cartella corrente.
- La query string (`?livello=2`) non cambia la risorsa, il frammento (`#sezione`) scorre la pagina.
- Codificate i caratteri speciali negli URL (`spazio` → `%20`); non mettete mai dati non fidati direttamente in un `href`.
- Evitate `<base href>` se non sapete esattamente come influisce su tutti i link relativi.

#### Link o button?

| Serve per | Elemento |
|---|---|
| Navigare a un'altra pagina o sezione | `<a href="…">` |
| Eseguire un'azione (salva, invia, apri modale) | `<button type="…">` |
| Inviare un form | `<button type="submit">` |

Un `div` con `onclick` non è accessibile da tastiera, non è annunciato come controllo e non ha stato. Se serve un'azione, usate un `button`; se serve una navigazione, un link. Per i link che aprono una nuova scheda aggiungete `rel="noopener noreferrer"`.

#### Attributi globali utili

| Attributo | Quando usarlo |
|---|---|
| `id` | Unico nella pagina, per `label`, `for`, ancore e `aria-*` |
| `class` | Stili e hook JavaScript, riutilizzabile |
| `hidden` | Nasconde il contenuto anche alle tecnologie assistive |
| `lang` / `dir` | Cambio lingua o direzione dentro la pagina |
| `tabindex="0"` | Rende focalizzabile un elemento non interattivo (raro) |
| `tabindex="-1"` | Focalizzabile via JS, fuori dall'ordine di tabulazione |
| `data-*` | Dati personalizzati leggibili via `dataset` |
| `title` | Suggerimento aggiuntivo, **non** sostituisce una label |

**Mai** `tabindex` positivi: rompono l'ordine naturale di tabulazione.

#### Testo, liste e codice

```html
<h2>Tipi di dato</h2>
<p>I tipi primitivi sono <strong>immutabili</strong>; per approfondire vedi <a href="#tipi">tipi</a>.</p>
<ul>
  <li>string</li>
  <li>number</li>
</ul>
<ol start="3">
  <li>terzo passo</li>
</ol>
<dl>
  <dt>Hoisting</dt>
  <dd>Sollevamento delle dichiarazioni all'inizio dello scope.</dd>
</dl>
<blockquote cite="https://example.com/fonte">
  <p>Il codice è poesia che deve funzionare.</p>
</blockquote>
<pre><code>const x = 1;</code></pre>
```

- `strong` = importanza, `em` = enfasi: non sono solo grassetto/corsivo.
- `code` per frammenti inline, `pre > code` per blocchi.
- `br` solo per interruzioni di riga semantiche (poesie, indirizzi), non per spaziare.
- I caratteri `<`, `>`, `&` nel testo vanno scritti come `&lt;`, `&gt;`, `&amp;`.

#### Tabelle accessibili

```html
<table>
  <caption>Punteggi per livello</caption>
  <thead>
    <tr>
      <th scope="col">Livello</th>
      <th scope="col">Punteggio</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th scope="row">Base</th>
      <td>12</td>
    </tr>
  </tbody>
</table>
```

`caption` descrive la tabella, `scope` collega intestazioni e celle. Le tabelle servono per **dati tabellari**, mai per impaginare.

#### Immagini responsive e performance

```html
<img
  src="quiz-800.jpg"
  srcset="quiz-400.jpg 400w, quiz-800.jpg 800w, quiz-1600.jpg 1600w"
  sizes="(max-width: 48rem) 100vw, 50vw"
  width="800" height="450"
  loading="lazy"
  decoding="async"
  alt="Studente che risolve un quiz su un portatile"
/>
```

- `srcset`/`sizes` fanno scegliere al browser il file giusto.
- `width`/`height` evitano il salto di layout (CLS); il CSS può comunque ridimensionare.
- `loading="lazy"` per immagini sotto la piega; non usatelo sull'immagine principale above-the-fold.
- `alt` descrive lo scopo dell'immagine; decorative → `alt=""`.
- `<picture>` serve per formati alternativi (AVIF/WebP) o art direction.

#### Form: dettagli che contano

```html
<form action="/iscrizione" method="post" enctype="multipart/form-data">
  <label for="avatar">Avatar</label>
  <input id="avatar" name="avatar" type="file" accept="image/*" />

  <label for="bio">Bio</label>
  <textarea id="bio" name="bio" maxlength="500"></textarea>

  <label for="citta">Città</label>
  <input id="citta" name="citta" list="citta-suggerite" />
  <datalist id="citta-suggerite">
    <option value="Milano"></option>
    <option value="Roma"></option>
  </datalist>

  <button type="submit">Invia</button>
</form>
```

- `GET` mette i dati nell'URL (ricerche, filtri); `POST` nel body (creazioni, dati sensibili).
- `multipart/form-data` è obbligatorio per caricare file.
- I campi `disabled` **non vengono inviati**; `readonly` sì.
- `inputmode`, `enterkeyhint` e `autocomplete` migliorano la tastiera mobile.
- `novalidate` sul form disattiva la validazione nativa: usatelo solo se validate voi.
- Mostrate gli errori vicino al campo e con `aria-live="polite"` per farli annunciare.

#### Script e risorse

```html
<script src="app.js" defer></script>
<script type="module" src="main.js"></script>
<link rel="preload" href="font.woff2" as="font" type="font/woff2" crossorigin />
<link rel="icon" href="/favicon.svg" type="image/svg+xml" />
```

| Attributo | Comportamento |
|---|---|
| `defer` | Scarica in parallelo, esegue dopo il parsing, in ordine |
| `async` | Scarica in parallelo, esegue appena pronto, ordine non garantito |
| `type="module"` | ESM, `defer` implicito, scope separato, top-level await |

Per script che manipolano il DOM usate `defer` o `type="module"`. Per risorse critiche usate `preload`, per pagine successive `prefetch`.

#### iframe e media

```html
<iframe
  src="https://example.com/mappa"
  title="Mappa della sede"
  loading="lazy"
  sandbox="allow-scripts allow-same-origin"
  referrerpolicy="no-referrer"
></iframe>

<video controls width="640" poster="copertina.jpg">
  <source src="lezione.webm" type="video/webm" />
  <track kind="captions" src="lezione.vtt" srclang="it" label="Italiano" default />
</video>
```

Ogni `iframe` ha un `title` descrittivo (è il nome letto dagli screen reader). `sandbox` limita ciò che la pagina incorporata può fare. I video didattici hanno sempre i sottotitoli.

#### SEO, condivisione e metadati

```html
<title>Quiz di HTML — RipassoAI</title>
<meta name="description" content="50 domande di HTML semantico, accessibilità e form." />
<link rel="canonical" href="https://ripasso.example/quiz/html" />
<meta property="og:title" content="Quiz di HTML — RipassoAI" />
<meta property="og:description" content="Allenati con domande a livelli." />
<meta property="og:image" content="https://ripasso.example/og/html.png" />
<meta name="twitter:card" content="summary_large_image" />
```

Titolo e description sono **unici per pagina**. `canonical` evita contenuti duplicati. Open Graph controlla l'anteprima quando il link viene condiviso. Aggiungete `robots.txt` e una sitemap se il sito è pubblico.

#### ARIA: le regole che evitano disastri

1. **Prima l'HTML nativo**: un `button` è già accessibile, un `div role="button"` no.
2. Non cambiate il ruolo di elementi nativi se non sapete cosa comporta.
3. Ogni controllo interattivo deve funzionare da tastiera (Enter, Spazio, frecce, Escape).
4. `aria-label` solo se non c'è testo visibile; altrimenti usate `aria-labelledby`.
5. `aria-hidden="true"` mai su elementi focalizzabili.
6. Un `role` senza comportamenti e stati è peggio di nessun ruolo.
7. Testate con tastiera, zoom 200% e almeno uno screen reader.

#### Errori comuni da riconoscere

- **Div soup**: tutto è un `div`, nessuna semantica.
- **Heading saltati**: da `h1` a `h4` senza `h2`/`h3`.
- **`alt` mancante** o uguale a "immagine".
- **Label non associata** al campo (`for` sbagliato o assente).
- **Link "clicca qui"** senza contesto.
- **`button` senza `type`** dentro un form: invia involontariamente.
- **`id` duplicati** nella pagina.
- **`tabindex` positivo**, `autofocus` e scorciatoie non disattivabili.
- **`placeholder` usato come label**: sparisce appena si scrive.
- **Tabelle usate per il layout**.

---

## 3. Esercizi per livello

### L1 — Base (riconoscere e modificare)

**1.1 — Boilerplate valido**
Crea `index.html` con `doctype`, `lang="it"`, charset, viewport, titolo e struttura `header`/`main`/`footer`. Dentro `main` metti un `h1` e due paragrafi.
- **Vincoli:** nessun CSS; passa il validatore W3C senza errori.
- **Criterio:** il documento ha un solo `h1` e un solo `main`.

**1.2 — Debug dell'annidamento**
Correggi questo frammento (ci sono 5 errori):

```html
<ul>
  <li>HTML
  <li>CSS</li>
</ul>
<p>Testo <strong>importante</p></strong>
<div><span>fuori</div></span>
<img src="logo.png">
```

- **Criterio:** struttura valida, `alt` presente, nessun tag chiuso nel posto sbagliato.

**1.3 — Form di login accessibile**
Costruisci un form con email, password, checkbox "Ricordami" e bottone. Ogni campo deve avere label, `autocomplete` corretto e validazione nativa.
- **Prova:** cliccando la label il cursore entra nel campo; Invio invia il form.
- **Criterio:** nessun `placeholder` usato al posto della label.

**1.4 — Tabella orario**
Rappresenta l'orario settimanale delle lezioni con `caption`, `thead`, `tbody`, `th scope="col"` e `th scope="row"`.
- **Criterio:** la tabella è comprensibile anche senza vederla (prova con uno screen reader o con l'albero di accessibilità di DevTools).

---

### L2 — Intermedio (costruire)

**2.1 — Scheda di ripasso**
Crea una pagina con 3 argomenti (HTML, CSS, JavaScript). Per ognuno: `article`, titolo `h2`, una definizione con `dl`/`dt`/`dd`, 3 domande con risposte nascoste in `details`/`summary`.
- **Vincoli:** niente `div` come contenitore di titoli; niente JS.
- **Criterio:** la pagina è navigabile da tastiera e la struttura dei titoli è corretta.

**2.2 — Form di iscrizione studente**
Campi: nome, cognome, email, data di nascita, classe (select), livello (radio L1–L4), materie preferite (checkbox), accettazione privacy (checkbox required).
- **Vincoli:** usa `fieldset`/`legend` per raggruppare; `pattern` per il nome (solo lettere, spazi, apostrofi); `min`/`max` sulla data.
- **Criterio:** la validazione nativa blocca i dati errati e i messaggi sono comprensibili.

**2.3 — Pagina risultato quiz**
Mostra: punteggio (es. 8/10) con `<meter>`, tempo impiegato con `<time>`, elenco delle risposte con esito corretto/errato, e un link per riprovare.
- **Vincoli:** l'esito non deve essere comunicato solo dal colore: usa testo ("Corretta"/"Errata") e un'icona con `aria-hidden`.
- **Criterio:** la pagina resta comprensibile in bianco e nero.

**2.4 — SEO e social**
Aggiungi a una pagina: `meta description`, `canonical`, Open Graph (`og:title`, `og:description`, `og:image`), favicon e JSON-LD di tipo `Quiz`.
- **Criterio:** i tag sono validi e il JSON-LD passa il Rich Results Test.

---

### L3 — Avanzato (integrare e valutare)

**3.1 — Audit di accessibilità**
Ricevi una pagina piena di problemi (il professore la fornisce) e produci un report con: problema, gravità (bloccante / grave / minore), riferimento WCAG, correzione proposta.
- **Minimo:** 10 problemi reali, di cui almeno 3 bloccanti.
- **Criterio:** nessun falso positivo; ogni correzione è verificabile.

**3.2 — Creazione quiz con `<template>`**
Costruisci il markup per un form di creazione domanda: testo, 4 opzioni, livello, spiegazione. Usa `<template>` per il blocco "opzione" e clonalo via JS.
- **Vincoli:** il form deve essere utilizzabile anche senza clonazione (prima opzione presente nell'HTML).
- **Criterio:** aggiungendo e rimuovendo opzioni, gli `id`/`for` restano univoci e le label corrette.

**3.3 — Dialog nativo**
Implementa una modale "Confermi l'invio del quiz?" con `<dialog>`, chiusura con Esc, focus sul primo elemento e ritorno del focus al bottone di apertura.
- **Criterio:** da tastiera si completa tutto il flusso; il focus non esce dalla modale.

**3.4 — Internazionalizzazione**
Prepara la pagina per italiano e inglese: `lang` dinamico, testi con `data-i18n`, date con `<time datetime>`, link `hreflang` alternativi.
- **Criterio:** cambiando lingua non restano testi hardcoded nella struttura.

---

### L4 — Esperto (progettare)

**4.1 — Design system HTML**
Definisci il markup canonico di 8 componenti della piattaforma: bottone, campo di testo, card quiz, badge livello, barra di avanzamento, alert, modale, tab. Per ognuno scrivi:
- HTML di riferimento;
- contratto di accessibilità (ruoli, attributi, tastiera);
- casi limite (disabilitato, errore, caricamento).

- **Criterio:** un altro sviluppatore può implementare i componenti senza ambiguità.

**4.2 — Specifica di accessibilità del flusso quiz**
Scrivi la specifica completa del flusso "rispondi a una domanda": ordine di focus, annunci dello screen reader, gestione del timer, feedback corretto/errato, pausa, ripresa, invio.
- **Criterio:** include almeno 8 requisiti testabili e una mappa dei tasti.

**4.3 — Code review**
Rivedi la pagina di un compagno con la checklist del modulo. Produci:
- 5 problemi prioritizzati con patch;
- 2 punti di forza;
- 1 rischio nascosto (es. contenuto che dipende dal colore, heading usato per stile).

- **Criterio:** ogni osservazione cita una riga o un elemento preciso.

**4.4 — Prototipo della scheda di ripasso**
Realizza la pagina statica definitiva della scheda: intestazione, obiettivi, mappa argomenti per livello, 10 domande con risposte espandibili, form di autovalutazione, footer con licenza e contatti.
- **Criterio:** valida, accessibile, stampabile (`@media print`), senza dipendenze esterne.

---

## 4. Quiz di verifica

1. Quale elemento contiene il contenuto principale e unico della pagina?
2. Perché si usa `<label for="...">` invece del solo `placeholder`?
3. Differenza tra `<section>` e `<article>`?
4. Cosa fa `required` e dove viene applicato?
5. Quando è corretto usare `alt=""`?
6. Quale elemento rappresenta una coppia termine/definizione?

<details>
<summary>Risposte</summary>

1. `<main>`.
2. La label è un'etichetta persistente e programmaticamente associata al campo: resta visibile, aiuta tutti e viene letta dalle tecnologie assistive. Il placeholder sparisce alla digitazione e non è un'etichetta affidabile.
3. `section` raggruppa contenuti correlati con un titolo; `article` è un contenuto autonomo, distribuibile o riutilizzabile fuori dal contesto (una domanda, un post, una card).
4. Attiva la validazione nativa del campo: il form non viene inviato finché il campo non è compilato (con le eccezioni previste dal tipo di campo).
5. Per immagini puramente decorative, che non aggiungono informazione: lo screen reader le ignora.
6. `<dl>` con `<dt>` e `<dd>`.

</details>

---

## 5. Mini-progetto del modulo

**"Scheda di ripasso — versione statica"**

Requisiti:

- 3 argomenti, 3 domande per argomento, risposte in `details`;
- un form di autovalutazione (1–5) per ogni argomento;
- una tabella riepilogativa dei punteggi;
- navigazione interna con `nav` e link a frammenti;
- nessun CSS o JS esterno (solo file locali);
- validatore W3C senza errori, audit Lighthouse accessibilità ≥ 95.

**Consegna:** cartella `modulo-01/` con `index.html`, `README.md` (scelte fatte, problemi trovati) e screenshot dell'audit.

---

## 6. AI pairing

**Prompt utili**

```text
Agisci come revisore di accessibilità HTML.
Ti incollo una pagina. Elenca solo problemi verificabili, con:
1) elemento/riga, 2) criterio WCAG, 3) gravità, 4) patch minima.
Non inventare problemi: se non sei sicuro, scrivi "da verificare".
```

```text
Genera lo scheletro HTML semantico di una scheda di ripasso con 3 argomenti
e 3 domande espandibili. Vincoli: un solo h1, nessun div per i titoli,
nessuna classe CSS, italiano corretto. Poi spiegami ogni scelta semantica.
```

**Come verificare l'AI**

- Passa l'output nel validatore W3C.
- Controlla con l'albero di accessibilità di DevTools.
- Diffida di attributi ARIA inventati: l'ARIA nativa è quasi sempre meglio.
- Chiedi sempre "quale problema stai risolvendo con questo attributo?".

**Anti-pattern tipici dell'AI:** aggiungere `role="button"` a un `<div>`, usare `aria-label` al posto del testo visibile, inserire heading per fare testo grande, generare `alt` generici ("immagine").

---

## 7. Checklist di uscita

- [ ] So spiegare la differenza tra `section`, `article`, `div`.
- [ ] Costruisco un form accessibile senza guardare il cheat sheet.
- [ ] Riconosco almeno 8 problemi di accessibilità in una pagina.
- [ ] Conosco la differenza tra validazione nativa e validazione lato server.
- [ ] So quando un'immagine va con `alt=""`.
- [ ] Ho consegnato la scheda statica e il report di audit.
