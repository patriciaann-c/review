# Modulo 09 — LangChain

> **Livello:** avanzato · **Tempo:** 10 h · **Prerequisiti:** JavaScript, Node.js, Express
> **Deliverable:** pipeline che genera, valida e archivia quiz a partire dagli appunti del corso.

---

## 1. Traguardi

Al termine del modulo sapete:

- invocare un modello con prompt template e output strutturato;
- progettare una pipeline RAG sui materiali del corso;
- dividere documenti, generare embedding e recuperare i passaggi rilevanti;
- validare automaticamente le domande generate (schema, duplicati, correttezza);
- stimare costi e latenza e applicare caching/fallback;
- proteggere la pipeline da prompt injection e dati sensibili.

---

## 2. Concetti chiave (cheat sheet)

### Setup

```bash
npm i langchain @langchain/core @langchain/openai zod
npm i -D tsx
```

```env
OPENAI_API_KEY=sk-...
LLM_MODEL=gpt-4o-mini
EMBEDDING_MODEL=text-embedding-3-small
```

> Le API di LangChain cambiano tra versioni: fissate le versioni nel `package.json` e verificate la documentazione della vostra release.

### Modello e prompt template

```js
import { ChatOpenAI } from "@langchain/openai";
import { ChatPromptTemplate } from "@langchain/core/prompts";
import { StringOutputParser } from "@langchain/core/output_parsers";

const model = new ChatOpenAI({
  model: process.env.LLM_MODEL,
  temperature: 0.2,
  maxRetries: 2,
  timeout: 30_000,
});

const prompt = ChatPromptTemplate.fromMessages([
  ["system", `Sei un docente esperto di {materia}.
Scrivi in italiano, con linguaggio chiaro e senza inventare fatti.
Se non sai qualcosa, dillo invece di indovinare.`],
  ["human", "Spiega in massimo 120 parole: {argomento}"],
]);

const chain = prompt.pipe(model).pipe(new StringOutputParser());
const risposta = await chain.invoke({ materia: "HTML", argomento: "il box model" });
```

### Output strutturato con Zod

```js
import { z } from "zod";

const domandaSchema = z.object({
  testo: z.string().min(10).describe("Testo della domanda, una sola nozione"),
  opzioni: z.array(z.string().min(1)).length(4).describe("Quattro opzioni distinte"),
  corretta: z.number().int().min(0).max(3).describe("Indice dell'opzione corretta"),
  spiegazione: z.string().min(20).describe("Perché la risposta è corretta"),
  livello: z.number().int().min(1).max(4),
});

const quizSchema = z.object({
  titolo: z.string(),
  domande: z.array(domandaSchema).min(3).max(10),
});

const structuredModel = model.withStructuredOutput(quizSchema, {
  name: "genera_quiz",
});

const quiz = await structuredModel.invoke([
  ["system", "Genera quiz didattici verificabili. Una sola risposta corretta per domanda."],
  ["human", `Argomento: ${argomento}. Livello: ${livello}. Numero domande: 5.
Usa solo le informazioni fornite nel contesto.`],
]);

for (const d of quiz.domande) {
  if (new Set(d.opzioni.map(o => o.toLowerCase())).size !== 4) {
    throw new Error("Opzioni duplicate");
  }
  if (d.corretta < 0 || d.corretta > 3) {
    throw new Error("Indice risposta non valido");
  }
}
```

### Documenti, splitter, embedding

```js
import { Document } from "@langchain/core/documents";
import { RecursiveCharacterTextSplitter } from "@langchain/textsplitters";
import { OpenAIEmbeddings } from "@langchain/openai";
import { MemoryVectorStore } from "langchain/vectorstores/memory";

const docs = [
  new Document({
    pageContent: "Il box model è composto da content, padding, border e margin…",
    metadata: { fonte: "appunti/css.md", argomento: "CSS", livello: 1 },
  }),
];

const splitter = new RecursiveCharacterTextSplitter({
  chunkSize: 800,
  chunkOverlap: 120,
  separators: ["\n\n", "\n", ". ", " "],
});

const chunks = await splitter.splitDocuments(docs);

const embeddings = new OpenAIEmbeddings({
  model: process.env.EMBEDDING_MODEL,
});

const vectorStore = await MemoryVectorStore.fromDocuments(chunks, embeddings);
const retriever = vectorStore.asRetriever({ k: 4 });
```

> In produzione usate un vector store persistente (pgvector su PostgreSQL, oppure Chroma, Qdrant, Weaviate), non la memoria del processo.

### Catena RAG

```js
import { RunnablePassthrough, RunnableSequence } from "@langchain/core/runnables";
import { StringOutputParser } from "@langchain/core/output_parsers";

const formatDocs = (docs) =>
  docs.map((d, i) => `[${i + 1}] (${d.metadata.fonte})\n${d.pageContent}`).join("\n\n");

const ragPrompt = ChatPromptTemplate.fromMessages([
  ["system", `Rispondi usando SOLO il contesto fornito.
Se il contesto non basta, scrivi: "Non ho informazioni sufficienti".
Cita le fonti con il formato [n].`],
  ["human", "Contesto:\n{context}\n\nDomanda: {question}"],
]);

const ragChain = RunnableSequence.from([
  {
    context: retriever.pipe(formatDocs),
    question: new RunnablePassthrough(),
  },
  ragPrompt,
  model,
  new StringOutputParser(),
]);

const risposta = await ragChain.invoke("Cos'è il box model?");
```

### Generazione con citazioni e controllo duplicati

```js
async function generaDomande({ argomento, livello, n = 5, contesto }) {
  const quiz = await structuredModel.invoke([
    ["system", `Genera domande fondate esclusivamente sul contesto.
Ogni domanda deve avere una sola risposta corretta e tre distrattori plausibili.
Non usare "tutte le precedenti" o "nessuna delle precedenti".`],
    ["human", `Argomento: ${argomento}\nLivello: ${livello}\nNumero: ${n}\n\nCONTESTO:\n${contesto}`],
  ]);

  const viste = new Set();
  return quiz.domande.filter(d => {
    const chiave = d.testo.toLowerCase().replace(/\s+/g, " ").trim();
    if (viste.has(chiave)) return false;
    viste.add(chiave);
    return true;
  });
}
```

### Valutazione automatica

```js
const giudizioSchema = z.object({
  corretta: z.boolean(),
  motivazione: z.string(),
  difficolta: z.number().min(1).max(4),
});

const giudice = model.withStructuredOutput(giudizioSchema, { name: "giudica" });

async function validaDomanda(domanda, contesto) {
  const esito = await giudice.invoke([
    ["system", `Sei un revisore. Verifica se la risposta indicata è corretta
usando solo il contesto. Controlla anche che i distrattori siano chiaramente sbagliati.`],
    ["human", `CONTESTO:\n${contesto}\n\nDOMANDA: ${domanda.testo}
OPZIONI: ${domanda.opzioni.map((o, i) => `${i}) ${o}`).join("\n")}
RISPOSTA INDICATA: ${domanda.corretta}`],
  ]);
  return esito;
}
```

> Un secondo modello non è una verità assoluta: serve a **ridurre** gli errori. La pubblicazione richiede sempre approvazione umana.

### Costi, latenza, caching

- Preferite modelli piccoli per generazione massiva e riservate i grandi alla revisione.
- Limitate `maxTokens` e il numero di domande per chiamata.
- Cache per chiave `(argomento, livello, versione prompt, modello)`.
- Batch e queue: la generazione non deve bloccare la richiesta HTTP.
- Loggate token input/output e costo stimato per job.

### Prompt injection: difese minime

1. Separare **istruzioni** e **contenuto** con delimitatori espliciti.
2. Istruire il modello a ignorare comandi contenuti nei documenti.
3. Validare l'output con schema: un'iniezione non può cambiare il formato.
4. Non dare al modello tool distruttivi senza conferma umana.
5. Filtrare PII in input e output.
6. Non inserire segreti nel contesto.

### Concetti fondamentali aggiuntivi

#### Come funziona un LLM (quello che serve sapere)

- Il modello genera **token** uno alla volta in base alla probabilità del successivo.
- La **context window** è il limite totale di token in input + output: se superato, troncate o riassumete.
- `temperature` e `top_p` controllano la casualità: bassi per classificazione e dati, più alti per brainstorming.
- Il system prompt definisce ruolo e vincoli; i messaggi utente portano il compito.
- Il modello non "sa" cosa non è nel contesto o nei suoi addestramenti: può allucinare con sicurezza.
- Costo e latenza crescono con i token; output lunghi costano più dell'input in molti modelli.

#### Prompt template efficaci

```js
const prompt = ChatPromptTemplate.fromMessages([
  ["system", `Sei un tutor di {materia}.
Regole:
- rispondi in italiano;
- usa solo il CONTESTO fornito;
- se manca l'informazione, scrivi "non verificabile";
- cita le fonti come [n].`],
  ["human", `<contesto>
{contesto}
</contesto>

Domanda: {domanda}`],
]);
```

- Variabili esplicite e delimitate; niente concatenazione confusa.
- Dite cosa fare in caso di dubbio, non solo cosa fare nel caso felice.
- Separate chiaramente istruzioni e contenuto non fidato.
- Versionate i prompt come codice: un cambio può alterare tutte le risposte.
- Aggiungete 1–3 esempi (few-shot) quando il formato è difficile da descrivere.

#### Runnable e composizione (LCEL)

```js
import { RunnableLambda, RunnableParallel } from "@langchain/core/runnables";

const prepara = RunnableLambda(({ domanda }) => ({
  domanda,
  contesto: recupera(domanda),
}));

const catena = prepara.pipe(prompt).pipe(model).pipe(new StringOutputParser());

const risposta = await catena.invoke({ domanda: "Cos'è una closure?" });
const risposte = await catena.batch([{ domanda: "A" }, { domanda: "B" }]);

for await (const chunk of await catena.stream({ domanda: "C" })) {
  process.stdout.write(chunk);
}
```

Le API `invoke`, `batch` e `stream` sono intercambiabili sulla maggior parte dei Runnable. `RunnableParallel` esegue rami indipendenti, `RunnablePassthrough` conserva l'input, `withRetry` e `withFallbacks` aggiungono robustezza. Le callback propagano tracing e log.

#### Output strutturato senza sorprese

```js
const schema = z.object({
  domande: z.array(z.object({
    testo: z.string().min(10),
    opzioni: z.array(z.string().min(1)).length(4),
    corretta: z.number().int().min(0).max(3),
    spiegazione: z.string().min(20),
    livello: z.enum(["1", "2", "3", "4"]),
  })).min(1).max(10),
});

const modelStrutturato = model.withStructuredOutput(schema, {
  name: "quiz",
  strict: true,
});
```

- Lo schema è il contratto: validatelo **sempre** anche dopo il parsing.
- Preferite enum e campi obbligatori a testo libero.
- Il modello può restituire JSON valido ma contenuto sbagliato: validate la semantica.
- Prevedete un repair loop limitato (max 1–2 tentativi) e un fallback.
- Non fidatevi dei numeri di indice: verificate che `corretta` sia nell'intervallo.

#### Embedding e similarità

```js
const [a, b] = await embeddings.embedDocuments(["box model", "margin e padding"]);

function coseno(x, y) {
  let dot = 0, nx = 0, ny = 0;
  for (let i = 0; i < x.length; i++) {
    dot += x[i] * y[i];
    nx += x[i] ** 2;
    ny += y[i] ** 2;
  }
  return dot / (Math.sqrt(nx) * Math.sqrt(ny));
}
```

Un embedding è un vettore che rappresenta il significato. La similarità coseno misura l'angolo tra vettori; per testi normalizzati è equivalente al prodotto scalare. Usate lo **stesso modello** per indicizzare e interrogare: modelli diversi hanno spazi vettoriali incompatibili. Verificate il supporto multilingue e la dimensione.

#### Chunking e ingestione

| Strategia | Quando |
|---|---|
| Fixed size + overlap | Base, documenti uniformi |
| Recursive | Markdown, codice, testi con struttura |
| Per heading/sezione | Dispense e documentazione |
| Semantic | Testi lunghi senza struttura chiara |

- `chunkSize` troppo piccolo perde contesto, troppo grande diluisce la ricerca.
- L'overlap evita di tagliare frasi importanti a metà.
- Conservate metadati: fonte, titolo, argomento, livello, data, permessi.
- Tabelle e codice richiedono chunk dedicati: non spezzateli a caso.
- Deduplicate e versionate i documenti; gestite aggiornamenti incrementali.
- Valutate il retrieval, non solo la qualità del testo estratto.

#### Retrieval di qualità

```js
const retriever = vectorStore.asRetriever({
  k: 6,
  searchType: "similarity",
  filter: { argomento: "javascript" },
});
```

- `top-k` alto aumenta il richiamo ma porta rumore e token; sperimentate.
- La **soglia** di similarità evita contesti irrilevanti.
- La ricerca **ibrida** (BM25 + vettori) gestisce meglio sigle, nomi e parole esatte.
- Il **reranking** con un cross-encoder migliora la precisione sui primi risultati.
- **MMR** aumenta la diversità e riduce chunk quasi identici.
- Query rewriting e decomposizione aiutano domande complesse.
- I filtri di metadati applicano permessi e scope: mai recuperare documenti di altri tenant.

#### Qualità del RAG

- **Grounding**: ogni affermazione deve essere supportata dal contesto.
- **Citazioni**: collegate la risposta alle fonti; senza citazioni non è verificabile.
- **Rifiuto**: "non ho informazioni sufficienti" è una risposta corretta.
- Attenzione al **lost in the middle**: le informazioni centrali in un contesto lungo vengono usate meno.
- Fonti contraddittorie: mostrate il conflitto, non scegliete a caso.
- Documenti obsoleti: data e versione nei metadati.
- Prompt injection nei documenti: il contenuto recuperato non deve impartire ordini.

#### Memoria

| Tipo | Contenuto | Costo/rischio |
|---|---|---|
| Buffer | Tutta la conversazione | Cresce e supera il contesto |
| Window | Ultimi N messaggi | Perde informazioni vecchie |
| Summary | Riassunto progressivo | Rischio di perdita e distorsione |
| Vettoriale | Ricordi recuperati | Privacy e pertinenza |

La memoria è un trattamento di dati personali: definite retention, consenso e cancellazione. Spesso un sistema **stateless** con contesto esplicito è più semplice e sicuro.

#### Tool calling

```js
const tools = [getProgressi, cercaDomande, salvaPiano];

const risposta = await model.bindTools(tools).invoke(messaggi);
```

- Nome e descrizione guidano la scelta del modello: siate specifici su quando usarli.
- Schema stretto, parametri validati, output limitato.
- Il tool non deve fidarsi dei parametri: autorizzazione e ownership lato server.
- Operazioni distruttive richiedono conferma umana.
- Timeout, retry e messaggi di errore utili come osservazione.
- Restituite dati compatti: un output enorme consuma contesto.

#### Streaming e cancellazione

```js
const controller = new AbortController();
const stream = await model.stream(messaggi, { signal: controller.signal });

for await (const chunk of stream) {
  res.write(chunk.content);
}
```

- Lo streaming migliora la percezione di velocità ma complica errori e parsing.
- Con output strutturato lo streaming parziale può non essere JSON valido: gestitelo.
- Supportate l'annullamento lato client e chiudete la connessione.
- Per SSE impostate gli header corretti e gestite i proxy che bufferizzano.

#### Valutazione

```js
const casi = [
  { domanda: "Cos'è il box model?", atteso: ["content", "padding", "border", "margin"] },
];

for (const caso of casi) {
  const risposta = await catena.invoke({ domanda: caso.domanda });
  const ok = caso.atteso.every(k => risposta.includes(k));
  console.log({ caso: caso.domanda, ok });
}
```

- Costruite un **golden set** con domande rappresentative e risposte attese.
- Misurate correttezza, fedeltà alle fonti, pertinenza e tasso di rifiuto.
- LLM-as-judge è utile ma va validato con valutazione umana e ha bias.
- Eseguite le eval in CI per evitare regressioni quando cambiate prompt o modello.
- Tracciate versione del prompt, del modello e dei documenti insieme ai risultati.
- Un sistema senza eval è una demo, non un prodotto.

#### Costi, latenza e caching

- Contate i token di input e output per ogni chiamata e stimimate il costo per utente.
- Modelli piccoli per compiti semplici, grandi solo dove servono.
- Cache esatta per prompt identici; cache semantica con soglia e attenzione ai falsi positivi.
- Batch quando la latenza non è critica; parallelizzate i passaggi indipendenti.
- Limitate `maxTokens`, numero di retrieval e lunghezza del contesto.
- Retry con backoff e fallback su un modello secondario.
- Monitorate p50/p95, error rate e token per sessione.

#### Sicurezza e privacy

- **Prompt injection**: delimitate il contenuto, istruite a ignorare comandi nei documenti, validate l'output.
- **PII**: minimizzate, redigete e non inviate a provider non autorizzati.
- **Segreti**: mai nel prompt, nei log o nei documenti indicizzati.
- **Tenant isolation**: filtri di accesso sui documenti e sui tool.
- **Output**: sanificate prima di rendere HTML o eseguire codice.
- **Fornitori**: verificate retention, addestramento sui dati e residenza.
- **Log**: possono contenere dati sensibili; applicate retention e accesso minimo.

#### Errori comuni

- Context window superata senza accorgersene.
- Chunk troppo grandi o senza metadati.
- Recuperare documenti irrilevanti e sperare che il modello li ignori.
- Usare il modello per calcoli deterministici che una query risolverebbe.
- Non validare l'output strutturato.
- Dimenticare timeout, retry e fallback.
- Confondere la similarità con la correttezza.
- Inviare dati personali a un provider senza base giuridica.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Prima chiamata**
Configura la chiave API in `.env`, invoca un modello con un prompt semplice e stampa la risposta. Gestisci timeout e chiave mancante.
- **Criterio:** nessun segreto nel codice; errore chiaro se manca la chiave.

**1.2 — Prompt template**
Crea un template con variabili `materia`, `livello`, `argomento`. Genera una spiegazione di 100 parole. Confronta temperature 0 e 0.8.
- **Criterio:** sai spiegare l'effetto della temperatura.

**1.3 — Output strutturato**
Genera una flashcard con `domanda`, `risposta`, `livello`. Valida con Zod e gestisci il caso di output non conforme.
- **Criterio:** il programma non crasha se il modello restituisce testo libero.

**1.4 — Costi**
Calcola il costo di 100 generazioni da 1.000 token input e 500 output con il modello scelto. Confronta due modelli.
- **Criterio:** formula e assunzioni esplicite.

---

### L2 — Intermedio

**2.1 — Generatore di quiz**
Genera 5 domande a 4 opzioni su un argomento, con spiegazione e livello. Valida schema, opzioni distinte e indice corretto.
- **Criterio:** 3 generazioni consecutive senza errori di schema.

**2.2 — RAG di base**
Indicizza 3 file Markdown del corso. Rispondi a 5 domande citando le fonti. Verifica che le risposte siano nel contesto.
- **Criterio:** nessuna risposta inventata su domande fuori contesto ("non ho informazioni").

**2.3 — Prompt con few-shot**
Aggiungi 2 esempi di domanda ben formulata e 1 controesempio (domanda ambigua). Misura la differenza di qualità su 10 generazioni.
- **Criterio:** rubric con 5 criteri e confronto prima/dopo.

**2.4 — Gestione errori**
Implementa retry con backoff su rate limit (429) e timeout. Distingui errori recuperabili e non. Logga il motivo.
- **Criterio:** un 429 simulato viene ritentato; un 401 no.

---

### L3 — Avanzato

**3.1 — Pipeline di ingestion**
Leggi i materiali del corso (Markdown/PDF), dividi in chunk con metadati (fonte, argomento, livello), genera embedding e salva in un vector store persistente.
- **Criterio:** re-ingestion idempotente; nessun chunk duplicato.

**3.2 — Generazione con citazioni**
Ogni domanda generata deve riportare la fonte (file e chunk). Verifica che la fonte contenga davvero la risposta.
- **Criterio:** 100% delle domande ha una citazione verificabile.

**3.3 — Validazione a due stadi**
Pipeline: generatore → validatore schema → giudice di correttezza → controllo duplicati → stato `bozza`. Solo le domande approvate passano a `pubblicata`.
- **Criterio:** tasso di falsi positivi misurato su 30 domande.

**3.4 — Eval set**
Crea 20 domande di riferimento con risposte attese. Valuta il tutor RAG su: correttezza, fedeltà al contesto, presenza citazioni, rifiuto quando manca informazione.
- **Criterio:** report con metriche e casi falliti analizzati.

**3.5 — Caching e batch**
Implementa cache su disco per generazioni identiche e un job batch per 100 domande. Misura risparmio di token e tempo.
- **Criterio:** riduzione documentata ≥ 30% su richieste ripetute.

---

### L4 — Esperto

**4.1 — Architettura della pipeline**
Progetta separazione tra API, worker di generazione, vector store e revisione umana. Definisci stati, retry, dead letter queue e idempotenza.
- **Criterio:** un job interrotto riprende senza duplicare domande.

**4.2 — Guardrail e red teaming**
Attacca la pipeline con 10 prompt injection (nei documenti e nelle domande utente): esfiltrazione prompt, istruzioni contraddittorie, richiesta di PII, tool abuse.
- **Criterio:** 10 test documentati, con esito e mitigazione.

**4.3 — Multi-tenant e isolamento**
Impedisci che il retriever di una scuola recuperi documenti di un'altra. Applica filtri per tenant a livello di metadati e di query.
- **Criterio:** test cross-tenant su 100 query, zero fughe.

**4.4 — Osservabilità e costi**
Traccia per ogni chiamata: modello, token, costo, latenza, esito, tenant. Dashboard con budget giornaliero e alert all'80%.
- **Criterio:** il costo per quiz generato è noto e sotto la soglia definita.

**4.5 — Human-in-the-loop**
Interfaccia di revisione: il docente vede domanda, fonte, giudizio automatico, e può approvare/modificare/rifiutare con motivazione. Le decisioni alimentano un dataset di valutazione.
- **Criterio:** nessuna domanda pubblicata senza approvazione; audit trail completo.

---

## 4. Quiz di verifica

1. Cos'è un embedding?
2. Perché si fa chunking con overlap?
3. Cosa fa `withStructuredOutput`?
4. Differenza tra fine-tuning e RAG?
5. Perché un secondo LLM non basta a garantire la correttezza?
6. Cos'è un prompt injection?
7. Perché la generazione va messa in coda?

<details>
<summary>Risposte</summary>

1. Una rappresentazione vettoriale del significato di un testo; testi simili hanno vettori vicini.
2. Per non perdere informazioni al confine tra chunk e mantenere il contesto nelle retrieval.
3. Forza il modello a restituire dati conformi a uno schema (Zod/JSON Schema), riducendo il parsing manuale.
4. Il fine-tuning modifica i pesi del modello con esempi; il RAG aggiunge conoscenza al momento della richiesta recuperando documenti esterni.
5. Anche il giudice può sbagliare o condividere gli stessi bias; serve valutazione umana, test e metriche.
6. Istruzioni malevole inserite in input o documenti che cercano di far deviare il modello dai suoi compiti.
7. Per non bloccare la richiesta HTTP, gestire retry e rate limit, distribuire il carico e controllare i costi.

</details>

---

## 5. Mini-progetto del modulo

**"Quiz Generator"**

Requisiti:

- ingestion di almeno 5 documenti del corso con metadati;
- vector store persistente;
- generazione di 5 domande per argomento/livello con citazioni;
- validazione schema + duplicati + giudice automatico;
- salvataggio in stato `bozza` con audit;
- endpoint Express `POST /api/ai/genera-quiz` e `GET /api/ai/jobs/:id`;
- report di valutazione su 20 domande;
- stima dei costi per 1.000 domande.

**Consegna:** cartella `modulo-09/` + `eval-report.md` + `.env.example`.

---

## 6. AI pairing

```text
Agisci come ML engineer che revisiona una pipeline RAG.
Ti incollo prompt, schema e 5 output.
1) Individua domande non fondate sul contesto.
2) Proponi modifiche al prompt e ai controlli automatici.
3) Suggerisci 5 casi di test per la valutazione.
Non riscrivere l'intera pipeline.
```

```text
Ho questo documento con possibili istruzioni malevole.
Analizzalo come red teamer: quali attacchi potrebbero funzionare sul mio agente?
Per ognuno: payload, effetto atteso, difesa concreta.
```

**Verifica:** leggi le fonti citate, confronta le risposte con i documenti, misura i costi, prova input ostili. L'AI tende a "riempire i vuoti" e a citare fonti inesistenti.

---

## 7. Checklist di uscita

- [ ] So scrivere un prompt con ruolo, contesto, vincoli e formato.
- [ ] Uso output strutturati e valido con Zod.
- [ ] So costruire un RAG con citazioni.
- [ ] Distinguo generazione, validazione e approvazione umana.
- [ ] Ho un eval set e so misurare la qualità.
- [ ] Conosco costi e latenze del mio flusso.
- [ ] Ho consegnato pipeline e report.
