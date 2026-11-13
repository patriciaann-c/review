# Modulo 10 — AI: skill e agenti

> **Livello:** avanzato · **Tempo:** 10 h · **Prerequisiti:** LangChain, Express, Prisma
> **Deliverable:** tutor AI e agente di valutazione integrati nella piattaforma.

---

## 1. Traguardi

Al termine del modulo sapete:

- scrivere una **skill** riutilizzabile (istruzioni + risorse + criteri di qualità);
- progettare un **agente** con tool, memoria e limiti;
- orchestrare più agenti (generatore, critico, validatore);
- applicare guardrail, permessi e human-in-the-loop;
- misurare qualità, costi e latenza;
- mettere in sicurezza un agente esposto a input ostili.

---

## 2. Concetti chiave (cheat sheet)

### Che cos'è una skill

Una **skill** è un pacchetto di istruzioni riutilizzabili che insegna a un modello/agente *come* svolgere un compito ricorrente, con esempi e criteri di accettazione. Non è un prompt una tantum: è un artefatto versionato, testabile e condivisibile.

```text
skills/
└── quiz-generator/
    ├── SKILL.md          # istruzioni e contratto
    ├── examples/         # input/output di riferimento
    ├── templates/        # formato di output
    └── tests/            # casi di valutazione
```

### Anatomia di `SKILL.md`

```md
---
name: quiz-generator
description: Genera quiz a 4 livelli su un argomento, con 4 opzioni, una sola corretta e spiegazione. Usare quando un docente chiede nuove domande verificabili.
version: 1.2.0
---

# Quiz Generator

## Quando usarla
Quando serve creare domande a scelta multipla a partire da appunti del corso.

## Input
- `argomento` (string)
- `livello` (1–4)
- `numero` (3–10)
- `contesto` (testo fonte, obbligatorio)

## Regole
1. Usa solo informazioni presenti nel contesto.
2. Una sola risposta corretta per domanda.
3. I distrattori devono essere plausibili ma chiaramente errati.
4. Non usare "tutte le precedenti" / "nessuna delle precedenti".
5. Ogni domanda verifica una sola nozione.
6. Lingua italiana, tono neutro.
7. Se il contesto non basta, restituisci `domande: []` e spiega perché.

## Output
JSON conforme allo schema `quiz.schema.json`.

## Criteri di qualità
- Fedeltà al contesto ≥ 95%
- Nessun duplicato
- Risposta corretta verificabile senza ambiguità
- Spiegazione ≥ 20 parole

## Esempi
Vedi `examples/input-1.md` e `examples/output-1.json`.
```

### Prompt: struttura affidabile

```text
RUOLO: sei un revisore didattico.
CONTESTO: [materiale del corso, delimitato]
COMPITO: valuta se la risposta indicata è corretta.
VINCOLI: usa solo il contesto; se manca, scrivi "non verificabile".
OUTPUT: JSON { corretta: boolean, motivazione: string, confidenza: 0-1 }.
```

Regole:
- delimitare chiaramente il contenuto non fidato (`<documento>…</documento>`);
- dire cosa fare in caso di dubbio;
- imporre un formato macchina-leggibile;
- non chiedere al modello di "essere sicuro": chiedigli di dichiarare l'incertezza.

### Tool per un agente

```js
import { tool } from "@langchain/core/tools";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";

export const getProgressi = tool(
  async ({ utenteId }) => {
    const tentativi = await prisma.tentativo.findMany({
      where: { utenteId: BigInt(utenteId) },
      select: { argomentoId: true, punteggio: true, conclusoIl: true },
      orderBy: { conclusoIl: "desc" },
      take: 20,
    });
    return JSON.stringify(tentativi, (_, v) => typeof v === "bigint" ? Number(v) : v);
  },
  {
    name: "get_progressi",
    description: "Restituisce gli ultimi tentativi di uno studente. Usalo prima di proporre un piano di ripasso.",
    schema: z.object({
      utenteId: z.string().describe("ID dello studente autenticato"),
    }),
  }
);
```

**Regola d'oro:** il tool riceve l'`utenteId` dalla sessione, **non** dal testo del modello. Un agente non deve poter leggere dati di altri utenti.

### Agente: ciclo percezione → piano → azione → osservazione

```text
utente → [LLM] → tool call → risultato → [LLM] → … → risposta finale
```

Un agente è utile quando:
- serve scegliere tra più azioni;
- servono dati aggiornati (progressi, catalogo);
- il percorso non è noto in anticipo.

Non serve quando basta una catena deterministica: **meno autonomia = più sicurezza e prevedibilità**.

### Agente con LangGraph (schema)

```js
import { StateGraph, Annotation } from "@langchain/langgraph";

const Stato = Annotation.Root({
  messaggi: Annotation({ reducer: (a, b) => a.concat(b), default: () => [] }),
  utenteId: Annotation(),
  step: Annotation({ reducer: (_, b) => b, default: () => 0 }),
});

async function nodoAgente(state) {
  const risposta = await model.bindTools(tools).invoke(state.messaggi);
  return { messaggi: [risposta], step: state.step + 1 };
}

async function nodoTool(state) {
  const ultimo = state.messaggi.at(-1);
  const risultati = await Promise.all(
    (ultimo.tool_calls ?? []).map(async (call) => {
      const t = tools.find(x => x.name === call.name);
      if (!t) return { role: "tool", content: "Tool non disponibile", tool_call_id: call.id };
      const out = await t.invoke({ ...call.args, utenteId: state.utenteId });
      return { role: "tool", content: String(out), tool_call_id: call.id };
    })
  );
  return { messaggi: risultati };
}

const grafo = new StateGraph(Stato)
  .addNode("agente", nodoAgente)
  .addNode("tool", nodoTool)
  .addEdge("__start__", "agente")
  .addConditionalEdges("agente", (s) => {
    const ultimo = s.messaggi.at(-1);
    if (s.step > 6) return "fine";
    return ultimo?.tool_calls?.length ? "tool" : "fine";
  }, { tool: "tool", fine: "__end__" })
  .addEdge("tool", "agente")
  .compile();
```

> Il limite di step è un guardrail: evita loop infiniti e costi fuori controllo.

### Memoria

| Tipo | Contenuto | Dove |
|---|---|---|
| Breve termine | conversazione corrente | stato del grafo / messaggi |
| Lungo termine | preferenze, errori ricorrenti | DB (con consenso) |
| Di dominio | appunti e domande | vector store |

Non memorizzate più del necessario. La memoria è un trattamento di dati personali.

### Multi-agente: separare i ruoli

```text
Generator  → produce bozze
Critic     → cerca ambiguità, errori, duplicati
Validator  → verifica schema e fedeltà al contesto
Human      → approva o rifiuta
```

Vantaggi: ogni agente ha istruzioni e tool limitati, è più facile valutarlo e sostituirlo. Svantaggi: più chiamate, più latenza, più costo.

### Guardrail

- **Input:** dimensione massima, PII redaction, rilevamento prompt injection.
- **Tool:** whitelist, permessi per ruolo, parametri validati, nessuna operazione distruttiva senza conferma.
- **Output:** schema, moderazione, citazioni obbligatorie, rifiuto esplicito se manca contesto.
- **Runtime:** timeout, max step, budget token per utente/giorno, kill switch.
- **Dati:** isolamento tenant, retention, audit log.

### Valutazione

| Dimensione | Come misurarla |
|---|---|
| Correttezza | confronto con risposte attese / giudice + umano |
| Fedeltà | la risposta è supportata dalle fonti citate? |
| Utilità | lo studente arriva alla soluzione? |
| Sicurezza | attacchi bloccati / testati |
| Costo | token e € per sessione |
| Latenza | p50/p95 |

Un agente senza eval set è un esperimento, non un prodotto.

### Concetti fondamentali aggiuntivi

#### Skill, prompt, tool, workflow o agente?

| Concetto | Cos'è | Esempio |
|---|---|---|
| Prompt | Istruzioni per una singola chiamata | "Riassumi in 5 punti" |
| Skill | Conoscenza procedurale riutilizzabile e versionata | Come generare un quiz valido |
| Tool | Capacità eseguibile con schema e permessi | `get_progressi(utenteId)` |
| Workflow | Orchestrazione deterministica di passi | estrai → valida → salva |
| Agente | Ciclo decisionale che sceglie azioni e tool | tutor che consulta i progressi |

Scegliete sempre la soluzione con **meno autonomia** che risolve il problema: un workflow deterministico è più sicuro, economico e testabile di un agente libero.

#### Progettare una skill

```md
---
name: quiz-review
description: Verifica e corregge domande a scelta multipla. Usare quando una domanda generata deve essere pubblicata o revisionata.
version: 2.0.0
owner: didattica
---

# Quiz Review

## Quando usarla
Prima della pubblicazione di domande generate automaticamente.

## Input
- `domanda` (testo, 4 opzioni, indice corretto)
- `contesto` (fonte obbligatoria)

## Regole
1. La risposta corretta deve essere supportata dal contesto.
2. I distrattori devono essere chiaramente errati e plausibili.
3. Una sola nozione per domanda.
4. Se il contesto non basta, restituisci `verificabile: false`.

## Output
JSON conforme a `review.schema.json`.

## Criteri di accettazione
- Nessuna ambiguità
- Spiegazione ≥ 20 parole
- Nessun duplicato
```

- La `description` è ciò che permette al sistema di **scegliere** la skill: scrivetela in termini di "quando usarla".
- Input, regole, output e criteri devono essere verificabili, non genericamente "di qualità".
- Gli esempi sono parte del contratto: mostrano il formato atteso meglio di mille parole.
- Versionate la skill e mantenete un changelog.
- Caricate solo le risorse necessarie (progressive disclosure): non riempite il contesto di tutto.

#### Anatomia di un buon tool

```js
export const cercaDomande = tool(
  async ({ argomento, livello, limite }) => {
    const domande = await prisma.domanda.findMany({
      where: { argomento: { slug: argomento }, livello, attiva: true },
      select: { id: true, testo: true, livello: true },
      take: limite,
    });
    return JSON.stringify(domande.map(d => ({ ...d, id: Number(d.id) })));
  },
  {
    name: "cerca_domande",
    description: "Cerca domande attive per argomento e livello. Usalo per proporre esercizi.",
    schema: z.object({
      argomento: z.enum(["html", "css", "javascript", "react"]),
      livello: z.number().int().min(1).max(4),
      limite: z.number().int().min(1).max(20).default(5),
    }),
  }
);
```

Un tool deve avere: responsabilità singola, nome descrittivo, schema stretto, validazione, autorizzazione, timeout, output limitato e messaggi di errore azionabili. Le operazioni distruttive richiedono conferma esplicita. L'identità dell'utente arriva dalla sessione, **non** dai parametri del modello.

#### Pattern di orchestrazione

```text
Router      → classifica la richiesta e sceglie il percorso
ReAct       → pensa → agisci (tool) → osserva → ripeti
Plan-Execute→ pianifica i passi, poi esegue
Reflection  → produce, critica, corregge
Supervisor  → coordina agenti specializzati
Handoff     → passa il controllo a un agente più adatto
```

- Usate ReAct solo quando il percorso non è noto in anticipo.
- Un limite di step e un budget di token sono obbligatori.
- Preferite passi deterministici per tutto ciò che non richiede giudizio.
- Il reflection può migliorare la qualità ma raddoppia costi e latenza: misuratelo.

#### Contesto e memoria

- Il contesto è una risorsa finita: riassumete la conversazione e recuperate solo i dati necessari.
- Tenete uno stato strutturato (JSON) invece di affidarvi al testo della chat.
- Separate memoria di sessione, preferenze di lungo periodo e conoscenza di dominio.
- Non fate memorizzare al modello dati che potete leggere dal database in modo affidabile.
- Resettate il contesto tra task diversi per evitare trascinamento di istruzioni.
- Applicate retention e cancellazione: la memoria contiene dati personali.

#### MCP (Model Context Protocol)

MCP è uno standard per esporre **tool, risorse e prompt** a un client/model in modo interoperabile.

```text
client (IDE, app)  ⇄  server MCP  →  database, API, filesystem
```

- Un server MCP dichiara capacità e schemi; il client decide cosa esporre al modello.
- Applicate il minimo privilegio: il server non deve avere accesso a più dati di quelli necessari.
- Autenticazione, isolamento per tenant e audit sono responsabilità del server.
- Versionate gli schemi e gestite la retrocompatibilità.
- Non installate server MCP non fidati: possono leggere file ed eseguire azioni.

#### Human-in-the-loop

- Approvazione umana per azioni distruttive o con impatto legale/didattico.
- Mostrate un'anteprima delle modifiche (diff) prima di applicarle.
- Prevedete annullamento e rollback.
- Soglie di confidenza: sotto una soglia, escalate a una persona.
- Audit trail di chi ha approvato cosa e quando.
- Non usate l'approvazione umana come scusa per non validare: i guardrail restano.

#### Guardrail e sicurezza

| Livello | Controlli |
|---|---|
| Input | Dimensione, PII, prompt injection, rate limit |
| Modello | Istruzioni separate dal contenuto, no segreti |
| Tool | Allowlist, permessi, validazione, timeout, idempotenza |
| Output | Schema, moderazione, citazioni, escaping |
| Runtime | Max step, budget, kill switch, sandbox |
| Dati | Tenant isolation, retention, audit, cifratura |

- La **sandbox** è obbligatoria per eseguire codice generato.
- Controllate l'egress di rete: un tool non deve poter chiamare qualsiasi URL.
- Red-teamate con prompt ostili e documenti avvelenati.
- Un agente esposto a input pubblici va trattato come un utente non fidato.

#### Valutazione e regressioni

```text
eval set → esecuzione → metriche → soglia → deploy
```

- Metriche: task success, correttezza, fedeltà, tool-call accuracy, sicurezza, latenza, costo.
- Offline per ogni modifica a prompt, skill, modello o tool; online con canary e feedback.
- LLM-as-judge è utile ma va calibrato con valutazione umana.
- Salvate i casi falliti come nuovi test: ogni incidente diventa una regressione.
- Versionate skill, prompt e set di valutazione insieme.

#### Failure mode tipici

| Sintomo | Causa probabile | Rimedio |
|---|---|---|
| Loop infinito | Nessun limite di step | Max step + budget |
| Tool inventato | Descrizioni ambigue | Schemi e nomi chiari |
| Dati di altri utenti | Identità presa dal prompt | ID dalla sessione + ownership |
| Risposta sicura ma falsa | Nessun grounding | Citazioni e rifiuto |
| Contesto ignorato | Troppo testo o lost-in-the-middle | Retrieval mirato + riassunto |
| Istruzioni divergenti | Prompt injection | Delimitatori + validazione |
| Costi impazziti | Nessun budget | Token accounting + alert |
| Output non parsabile | Formato libero | Structured output + repair |

#### Costi e latenza

- Routing: modello piccolo per classificare, grande solo per il compito difficile.
- Caching di risposte e risultati dei tool quando sono deterministici.
- Parallelizzare tool indipendenti; non serializzare ciò che non dipende.
- Riassumere la memoria invece di reinviare tutta la conversazione.
- Streaming per la percezione di velocità; batch per i job notturni.
- Budget per utente/giorno e alert prima di superare la soglia.
- Misurate p95, non solo la media.

#### Governance

- Ogni skill/agente ha un owner e un changelog.
- Permessi e dati classificati (pubblico, interno, personale, sensibile).
- Retention e cancellazione documentate.
- Incident response: kill switch, rollback, notifica.
- Deprecazione con preavviso e migrazione.
- Documentazione per chi usa e per chi mantiene.

#### Errori comuni

- Chiamare "agente" un workflow deterministico.
- Dare al modello tool con privilegi eccessivi.
- Mettere l'ID utente nel prompt invece che nella sessione.
- Nessun eval set e nessun test di regressione.
- Skill scritte come muri di testo senza criteri verificabili.
- Ignorare costi e latenza fino alla bolletta.
- Fidarsi dell'output strutturato senza validarlo.
- Memorizzare tutto per sempre senza consenso.
- Usare un agente dove basta una query SQL.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Prima skill**
Scrivi `skills/flashcard/SKILL.md` con frontmatter, input, regole, output e un esempio. Testala su 3 argomenti.
- **Criterio:** input e output sono riproducibili; le regole sono verificabili.

**1.2 — Prompt con ruolo e formato**
Trasforma un prompt vago in uno strutturato (ruolo, contesto, compito, vincoli, output). Confronta i risultati su 5 generazioni.
- **Criterio:** l'output è sempre nello stesso formato.

**1.3 — Tool semplice**
Crea un tool `cerca_argomento(query)` che interroga il catalogo. Definisci schema Zod e descrizione.
- **Criterio:** il tool rifiuta input vuoti e restituisce dati reali.

**1.4 — Limiti**
Aggiungi a una chiamata: timeout, numero massimo di token e messaggio di fallback.
- **Criterio:** simulando un timeout l'utente riceve un messaggio utile, non un crash.

---

### L2 — Intermedio

**2.1 — Skill quiz-generator**
Implementa la skill completa con schema, few-shot e criteri di qualità. Genera 10 domande su 2 argomenti.
- **Criterio:** 0 duplicati, 0 risposte ambigue su revisione manuale.

**2.2 — Agente valutatore**
Agente con un solo tool (`get_domanda`) che valuta se una risposta aperta è corretta secondo una rubric. Restituisce punteggio e motivazione.
- **Criterio:** su 10 risposte di test, il punteggio coincide con la valutazione del docente nell'80% dei casi.

**2.3 — Tool calling**
Agente con 3 tool: `get_progressi`, `get_quiz`, `cerca_appunti`. Verifica che scelga il tool giusto in 10 scenari.
- **Criterio:** 8/10 scelte corrette; documenta i 2 errori.

**2.4 — Memoria di conversazione**
Tutor che ricorda le ultime 5 interazioni e l'argomento in corso. All'inizio di una nuova sessione riparte pulito.
- **Criterio:** nessun dato di altri utenti nella memoria; reset esplicito funzionante.

---

### L3 — Avanzato

**3.1 — Coach di ripasso**
Agente che: legge i progressi, individua 2 argomenti deboli, propone un piano di 3 giorni, genera un quiz mirato, spiega le risposte.
- **Vincoli:** max 5 step, tool in whitelist, citazioni dagli appunti.
- **Criterio:** su 5 profili diversi, il piano è coerente con i dati.

**3.2 — Eval set**
Crea 25 casi di test per il tutor con risposta attesa e criteri. Automatizza la valutazione e produce un report.
- **Criterio:** metriche per correttezza, fedeltà, rifiuto corretto, costo medio.

**3.3 — Human-in-the-loop**
Implementa la coda di revisione: il docente approva/modifica/rifiuta le domande generate. Ogni decisione è loggata con motivazione.
- **Criterio:** nessuna pubblicazione automatica; audit completo.

**3.4 — Memoria a lungo termine**
Salva gli errori ricorrenti dello studente (per argomento) e usali per personalizzare il ripasso. Prevedi cancellazione su richiesta.
- **Criterio:** l'utente può vedere e cancellare i propri dati.

**3.5 — Costi e latenza**
Misura token, costo e latenza per sessione. Ottimizza con modello piccolo, cache e contesto ridotto. Confronta prima/dopo.
- **Criterio:** riduzione ≥ 30% del costo senza peggiorare l'eval.

---

### L4 — Esperto

**4.1 — Orchestrazione multi-agente**
Progetta e implementa la pipeline `generator → critic → validator → human`. Definisci stato condiviso, retry, fallback e dead letter queue.
- **Criterio:** un critic che fallisce non blocca l'intera pipeline; le domande scartate sono tracciate.

**4.2 — Red teaming**
Attacca il tutor con 15 payload: jailbreak, esfiltrazione del system prompt, richiesta di dati di altri studenti, tool abuse, prompt injection nei documenti.
- **Criterio:** report con esito, severità e fix; nessuna fuga di dati.

**4.3 — Isolamento multi-tenant**
Dimostra che un utente della scuola A non può ottenere dati della scuola B via prompt, tool o RAG. Aggiungi test automatici.
- **Criterio:** 100 tentativi cross-tenant, zero successi.

**4.4 — Osservabilità**
Dashboard con: sessioni, token, costo, latenza p95, tool call, errori, feedback utente. Alert su budget e su tasso di rifiuto anomalo.
- **Criterio:** da una risposta problematica risali a prompt, contesto, tool e modello usati.

**4.5 — Versioning e rollout**
Versiona prompt e skill, usa feature flag, fai A/B su un gruppo ristretto, misura qualità e costi, rollback automatico se peggiora.
- **Criterio:** una nuova versione della skill può essere attivata/disattivata senza deploy.

---

## 4. Quiz di verifica

1. Differenza tra skill e prompt una tantum?
2. Quando un agente è preferibile a una catena deterministica?
3. Perché il tool non deve ricevere l'ID utente dal testo del modello?
4. Cosa fa un guardrail di output?
5. Perché serve un limite di step?
6. Differenza tra memoria breve e lungo termine?
7. Cosa misura la "fedeltà" di una risposta RAG?

<details>
<summary>Risposte</summary>

1. La skill è un artefatto versionato e riutilizzabile con contratto, esempi e criteri di qualità; il prompt una tantum è estemporaneo e non testato.
2. Quando il percorso non è noto, servono scelte dinamiche o dati aggiornati tramite tool. Se il flusso è fisso, una catena è più sicura, economica e prevedibile.
3. Perché il modello potrebbe essere manipolato per passare un ID altrui: l'identità va presa dalla sessione autenticata, mai dal testo.
4. Verifica che l'output rispetti schema, policy e sicurezza prima di raggiungere l'utente (formato, PII, contenuti vietati, citazioni).
5. Per evitare loop infiniti, costi incontrollati e comportamenti imprevedibili.
6. La breve termine riguarda la conversazione corrente; la lungo termine persiste informazioni tra sessioni e richiede consenso, retention e cancellazione.
7. Quanto la risposta è supportata dalle fonti recuperate, cioè se le affermazioni sono verificabili nel contesto citato.

</details>

---

## 5. Mini-progetto del modulo

**"Tutor RipassoAI"**

Requisiti:

- skill `quiz-generator` e skill `spiega-errore` versionate;
- agente tutor con tool: progressi, catalogo, ricerca appunti, genera quiz;
- memoria di sessione e riepilogo errori ricorrenti;
- citazioni dalle fonti;
- limiti: 6 step, timeout 30 s, budget token per utente;
- human-in-the-loop per la pubblicazione delle domande;
- eval set da 25 casi + report;
- red team da 15 attacchi + mitigazioni;
- dashboard costi/latenza.

**Consegna:** cartella `modulo-10/` + `eval-report.md` + `red-team.md` + `SKILL.md` delle skill.

---

## 6. AI pairing

```text
Agisci come red teamer di agenti LLM.
Ecco system prompt, tool e policy.
Prova a: 1) farti rivelare il system prompt, 2) accedere a dati di un altro utente,
3) usare un tool in modo distruttivo, 4) ignorare le citazioni.
Per ogni attacco: payload, esito atteso, difesa minima.
```

```text
Trasforma queste istruzioni in una skill versionata.
Includi frontmatter, quando usarla, input/output, regole verificabili,
criteri di qualità, 2 esempi e 5 casi di test.
Evidenzia le parti ambigue che richiedono una decisione umana.
```

**Verifica:** esegui l'eval set, prova gli attacchi, controlla i log, misura i costi. L'AI tende a dichiararsi sicura e a ignorare i casi limite: testate, non credete.

---

## 7. Checklist di uscita

- [ ] So scrivere una skill con contratto e criteri di qualità.
- [ ] Scelgo tra catena e agente in base al problema.
- [ ] Ogni tool ha schema, permessi e descrizione.
- [ ] Ho guardrail su input, tool, output e runtime.
- [ ] Ho un eval set e misuro qualità, costo e latenza.
- [ ] Ho fatto red teaming e isolamento multi-tenant.
- [ ] Ho consegnato tutor, skill, report e red team.
