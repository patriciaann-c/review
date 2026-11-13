# Modulo 08 — Prisma

> **Livello:** intermedio-avanzato · **Tempo:** 8 h · **Prerequisiti:** MySQL, Express
> **Deliverable:** livello di accesso dati tipizzato e sicuro per RipassoAI.

---

## 1. Traguardi

Al termine del modulo sapete:

- modellare entità e relazioni nello schema Prisma;
- gestire migrazioni in sviluppo e in produzione;
- scrivere query tipizzate con `select`, `include`, filtri e paginazione;
- usare transazioni per operazioni atomiche;
- riconoscere e gestire gli errori Prisma;
- evitare N+1 e over-fetching;
- applicare soft delete e isolamento multiutente.

---

## 2. Concetti chiave (cheat sheet)

### Setup

```bash
npm i @prisma/client
npm i -D prisma
npx prisma init --datasource-provider mysql
```

```env
DATABASE_URL="mysql://app:password@localhost:3306/ripasso_ai"
```

### Schema

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}

enum Ruolo {
  STUDENTE
  DOCENTE
  ADMIN
}

model Utente {
  id           BigInt    @id @default(autoincrement())
  email        String    @unique @db.VarChar(255)
  passwordHash String    @map("password_hash")
  nome         String    @db.VarChar(100)
  ruolo        Ruolo     @default(STUDENTE)
  creatoIl     DateTime  @default(now()) @map("creato_il")
  tentativi    Tentativo[]

  @@index([ruolo])
  @@map("utenti")
}

model Argomento {
  id        BigInt      @id @default(autoincrement())
  slug      String      @unique @db.VarChar(80)
  titolo    String      @db.VarChar(150)
  domande   Domanda[]
  tentativi Tentativo[]

  @@map("argomenti")
}

model Domanda {
  id          BigInt    @id @default(autoincrement())
  argomentoId BigInt    @map("argomento_id")
  argomento   Argomento @relation(fields: [argomentoId], references: [id])
  testo       String    @db.Text
  livello     Int       @db.TinyInt
  spiegazione String?   @db.Text
  attiva      Boolean   @default(true)
  eliminataIl DateTime? @map("eliminata_il")
  opzioni     Opzione[]
  risposte    Risposta[]
  creatoIl    DateTime  @default(now()) @map("creato_il")

  @@index([argomentoId, livello, attiva])
  @@map("domande")
}

model Opzione {
  id        BigInt  @id @default(autoincrement())
  domandaId BigInt  @map("domanda_id")
  domanda   Domanda @relation(fields: [domandaId], references: [id], onDelete: Cascade)
  testo     String  @db.VarChar(500)
  corretta  Boolean @default(false)
  posizione Int     @db.TinyInt

  @@unique([domandaId, posizione])
  @@map("opzioni")
}

model Tentativo {
  id           BigInt    @id @default(autoincrement())
  utenteId     BigInt    @map("utente_id")
  utente       Utente    @relation(fields: [utenteId], references: [id], onDelete: Cascade)
  argomentoId  BigInt    @map("argomento_id")
  argomento    Argomento @relation(fields: [argomentoId], references: [id])
  punteggio    Decimal   @default(0) @db.Decimal(5, 2)
  iniziatoIl   DateTime  @default(now()) @map("iniziato_il")
  conclusoIl   DateTime? @map("concluso_il")
  risposte     Risposta[]

  @@index([utenteId, iniziatoIl])
  @@map("tentativi")
}

model Risposta {
  id          BigInt    @id @default(autoincrement())
  tentativoId BigInt    @map("tentativo_id")
  tentativo   Tentativo @relation(fields: [tentativoId], references: [id], onDelete: Cascade)
  domandaId   BigInt    @map("domanda_id")
  domanda     Domanda   @relation(fields: [domandaId], references: [id])
  opzioneId   BigInt?   @map("opzione_id")
  corretta    Boolean
  tempoMs     Int?      @map("tempo_ms")

  @@unique([tentativoId, domandaId])
  @@map("risposte")
}
```

### Migrazioni

```bash
# sviluppo
npx prisma migrate dev --name init

# produzione (mai migrate dev)
npx prisma migrate deploy

# ispezione
npx prisma studio
npx prisma migrate status
```

Regole:
- ogni modifica allo schema = nuova migrazione versionata;
- mai modificare a mano una migrazione già applicata;
- in produzione usare strategie **expand/contract** per cambi non distruttivi;
- backup prima di migrazioni importanti.

### Client e query

```js
import { PrismaClient } from "@prisma/client";
export const prisma = new PrismaClient({
  log: process.env.NODE_ENV === "development" ? ["query", "warn", "error"] : ["error"],
});
```

```js
// Lista paginata, solo i campi necessari
const domande = await prisma.domanda.findMany({
  where: { argomentoId: 3n, attiva: true, eliminataIl: null, livello: { lte: 2 } },
  select: {
    id: true,
    testo: true,
    livello: true,
    opzioni: {
      select: { id: true, testo: true, posizione: true }, // NON corretta
      orderBy: { posizione: "asc" },
    },
  },
  orderBy: [{ livello: "asc" }, { id: "asc" }],
  skip: 0,
  take: 20,
});
```

> `BigInt` non è serializzabile in JSON: convertilo esplicitamente (`Number(id)` o `id.toString()`), meglio con un mapper di risposta.

### Transazione

```js
const risultato = await prisma.$transaction(async (tx) => {
  const tentativo = await tx.tentativo.create({
    data: { utenteId, argomentoId, conclusoIl: new Date() },
  });

  await tx.risposta.createMany({
    data: risposte.map(r => ({
      tentativoId: tentativo.id,
      domandaId: r.domandaId,
      opzioneId: r.opzioneId,
      corretta: r.corretta,
      tempoMs: r.tempoMs,
    })),
  });

  const aggregate = await tx.risposta.aggregate({
    where: { tentativoId: tentativo.id },
    _avg: { corretta: true },
    _count: true,
  });

  return tx.tentativo.update({
    where: { id: tentativo.id },
    data: { punteggio: (aggregate._avg.corretta ?? 0) * 100 },
  });
});
```

### Errori tipici

```js
import { Prisma } from "@prisma/client";

try {
  await prisma.utente.create({ data: { email, passwordHash, nome } });
} catch (err) {
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === "P2002") {
      const e = new Error("Email già registrata");
      e.status = 409;
      throw e;
    }
    if (err.code === "P2025") {
      const e = new Error("Risorsa non trovata");
      e.status = 404;
      throw e;
    }
  }
  throw err;
}
```

| Codice | Significato |
|---|---|
| `P2002` | Violazione vincolo unico |
| `P2003` | Violazione chiave esterna |
| `P2025` | Record richiesto non trovato |
| `P1001` | DB irraggiungibile |
| `P1017` | Connessione chiusa |

### Aggregazioni e groupBy

```js
const stats = await prisma.risposta.groupBy({
  by: ["domandaId"],
  where: { tentativo: { utenteId } },
  _count: { _all: true },
  _avg: { corretta: true },
  orderBy: { _count: { domandaId: "desc" } },
  take: 10,
});
```

### Soft delete con estensione

```js
export const prisma = new PrismaClient().$extends({
  query: {
    domanda: {
      async findMany({ args, query }) {
        args.where = { ...args.where, eliminataIl: null };
        return query(args);
      },
    },
  },
});
```

> Le estensioni aiutano ma vanno testate: un `findUnique` o una query raw non le applicano automaticamente.

### Seed

```js
// prisma/seed.js
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

const argomenti = [
  { slug: "html", titolo: "HTML" },
  { slug: "css", titolo: "CSS" },
  { slug: "javascript", titolo: "JavaScript" },
];

for (const a of argomenti) {
  await prisma.argomento.upsert({ where: { slug: a.slug }, update: {}, create: a });
}

await prisma.$disconnect();
```

```json
"prisma": { "seed": "node prisma/seed.js" }
```

### Concetti fondamentali aggiuntivi

#### Modello, mapping e tipi

```prisma
model Domanda {
  id          BigInt   @id @default(autoincrement())
  argomentoId BigInt   @map("argomento_id")
  testo       String   @db.Text
  livello     Int      @db.TinyInt
  attiva      Boolean  @default(true)
  creatoIl    DateTime @default(now()) @map("creato_il")
  aggiornatoIl DateTime @updatedAt @map("aggiornato_il")
  argomento   Argomento @relation(fields: [argomentoId], references: [id], onDelete: Restrict)

  @@index([argomentoId, livello, attiva])
  @@map("domande")
}
```

- `@map`/`@@map` allineano i nomi Prisma (camelCase) a quelli SQL (snake_case).
- `@updatedAt` è gestito dal client Prisma, non dal database.
- `Decimal` e `BigInt` non sono serializzabili in JSON: convertiteli nei DTO.
- Scegliete `onDelete`/`onUpdate` espliciti per ogni relazione: il default può non essere quello che volete.
- Gli enum Prisma diventano enum MySQL; aggiungere valori richiede una migrazione.

#### Query API: select, include, omit

```js
// solo i campi necessari, con relazione annidata filtrata
const domande = await prisma.domanda.findMany({
  where: {
    argomento: { slug: "javascript" },
    attiva: true,
    livello: { in: [1, 2] },
    opzioni: { some: { corretta: true } },
  },
  select: {
    id: true,
    testo: true,
    livello: true,
    opzioni: {
      select: { id: true, testo: true, posizione: true },
      orderBy: { posizione: "asc" },
    },
  },
  orderBy: [{ livello: "asc" }, { id: "asc" }],
  skip: 0,
  take: 20,
});
```

- `select` sceglie i campi; `include` aggiunge relazioni mantenendo tutti i campi scalari; `omit` esclude campi (versioni recenti).
- **Mai** esporre `passwordHash`, `corretta` o dati interni: costruite un DTO esplicito.
- I filtri di relazione usano `some`, `every`, `none`.
- Gli operatori (`contains`, `startsWith`, `gt`, `lte`, `in`) hanno semantica che dipende dal database; verificate case sensitivity e collation.
- `findUnique` richiede un campo unico; per filtri arbitrari usate `findFirst`.

#### Scritture e nested writes

```js
const domanda = await prisma.domanda.create({
  data: {
    testo,
    livello,
    argomento: { connect: { slug: "javascript" } },
    opzioni: {
      create: opzioni.map((o, i) => ({ testo: o.testo, corretta: o.corretta, posizione: i + 1 })),
    },
  },
  include: { opzioni: true },
});

await prisma.domanda.update({
  where: { id },
  data: {
    testo: nuovoTesto,
    opzioni: { deleteMany: {}, create: nuoveOpzioni }, // sostituzione atomica
  },
});
```

`connect`, `create`, `connectOrCreate`, `update`, `upsert`, `delete`, `deleteMany`, `set` compongono le scritture annidate. Sono comode ma generano più query: controllate il piano per operazioni massive. Per aggiornamenti parziali ricordate che `undefined` significa "non toccare", `null` significa "imposta NULL".

#### Transazioni

```js
// Sequenziale: array di operazioni già pronte
const [tentativo, risposte] = await prisma.$transaction([
  prisma.tentativo.create({ data: { utenteId, argomentoId } }),
  prisma.risposta.createMany({ data: righe }),
]);

// Interattiva: logica che dipende dai risultati
await prisma.$transaction(async tx => {
  const t = await tx.tentativo.create({ data: { utenteId, argomentoId } });
  await tx.risposta.createMany({ data: righe.map(r => ({ ...r, tentativoId: t.id })) });
  return tx.tentativo.update({
    where: { id: t.id },
    data: { conclusoIl: new Date(), punteggio },
  });
}, { isolationLevel: "Serializable", timeout: 10_000 });
```

- La transazione interattiva ha `maxWait` e `timeout`: non tenetela aperta per chiamate esterne.
- Se una Promise fallisce, tutto viene rollbackato.
- Deadlock e timeout vanno ritentati con backoff, non ignorati.
- Per operazioni massive valutate `createMany` e batch, non migliaia di `create` in un loop.

#### Raw SQL in sicurezza

```js
import { Prisma } from "@prisma/client";

// ✅ tagged template: parametri separati, niente injection
const righe = await prisma.$queryRaw`
  SELECT id, testo FROM domande
  WHERE argomento_id = ${argomentoId} AND livello = ${livello}
  LIMIT ${limite}
`;

// ✅ composizione sicura
const filtro = Prisma.sql`WHERE attiva = TRUE`;
const risultato = await prisma.$queryRaw`SELECT * FROM domande ${filtro}`;

// ❌ mai concatenare input
// prisma.$queryRawUnsafe(`SELECT * FROM domande WHERE testo = '${testo}'`)
```

Le query raw servono per aggregazioni complesse, full-text, window function o ottimizzazioni. Restituiscono tipi che dovete mappare a mano. `$queryRawUnsafe` esiste ma va usato solo con stringhe completamente controllate.

#### Migrazioni e ambienti

```bash
npx prisma migrate dev --name aggiungi_indice_livello   # sviluppo
npx prisma migrate deploy                               # produzione
npx prisma migrate status                               # stato
npx prisma migrate resolve --applied 20260101_init      # baseline
```

- `migrate dev` può resettare il database: mai in produzione.
- Il **drift** è una differenza tra schema e migrazioni: risolvetelo, non ignoratelo.
- Per un database esistente usate il **baselining**.
- Cambi non distruttivi con strategia **expand/contract**: aggiungi colonna → scrivi su entrambe → migra i dati → rimuovi la vecchia.
- Revisionate l'SQL generato: un `DROP COLUMN` può perdere dati.
- Backup prima delle migrazioni e piano di rollback (spesso forward-fix).

#### Performance

```js
// Paginazione cursor: stabile con dati che cambiano
const pagina = await prisma.domanda.findMany({
  where: { argomentoId },
  orderBy: { id: "asc" },
  take: 20,
  ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
});
```

- Abilitate il log `query` solo in sviluppo e contate le query per richiesta: il problema più comune è l'**N+1**.
- Usate `select` mirati e indici allineati ai filtri.
- Preferite la paginazione cursor all'`OFFSET` alto.
- Il pool di connessioni ha un limite: richieste concorrenti in eccesso attendono. Dimensionatelo sul database, non sul numero di utenti.
- Le transazioni lunghe bloccano righe e connessioni.
- Per letture pesanti valutate cache applicativa, non solo indici.
- `relationLoadStrategy: "join"` (dove supportato) può ridurre le query rispetto al default.

#### Errori e robustezza

```js
try {
  await prisma.utente.create({ data });
} catch (err) {
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === "P2002") throw new HttpError(409, "Email già registrata");
    if (err.code === "P2025") throw new HttpError(404, "Risorsa non trovata");
  }
  if (err instanceof Prisma.PrismaClientInitializationError) {
    throw new HttpError(503, "Database non disponibile");
  }
  throw err;
}
```

| Codice | Significato | Azione tipica |
|---|---|---|
| `P2002` | Vincolo unico violato | 409 |
| `P2003` | Chiave esterna violata | 400/409 |
| `P2025` | Record non trovato | 404 |
| `P1001` | Database irraggiungibile | 503, retry |
| `P1017` | Connessione chiusa | retry |
| `P2034` | Conflitto di transazione/deadlock | retry con backoff |

Non trasformate tutti gli errori in 500: mappate i casi noti e loggate il resto. In produzione non restituite mai il messaggio grezzo del database.

#### Tipi, DTO e serializzazione

```js
// mapper esplicito: niente BigInt o campi interni verso il client
function toDto(domanda) {
  return {
    id: Number(domanda.id),
    testo: domanda.testo,
    livello: domanda.livello,
    opzioni: domanda.opzioni.map(o => ({ id: Number(o.id), testo: o.testo })),
  };
}

// tipi derivati dallo schema, senza duplicare a mano
type DomandaConOpzioni = Prisma.DomandaGetPayload<{
  include: { opzioni: true };
}>;
```

`BigInt`, `Decimal` e `Date` richiedono una conversione consapevole. Usate `Prisma.validator` per riusare frammenti di query e `satisfies` per controllare i tipi. Tenete i modelli Prisma lontani dall'interfaccia: i DTO proteggono da fughe di dati e da cambi di schema.

#### Estensioni e soft delete

```js
const prisma = new PrismaClient().$extends({
  query: {
    domanda: {
      async findMany({ args, query }) {
        args.where = { ...args.where, eliminataIl: null };
        return query(args);
      },
    },
  },
});
```

Le estensioni possono aggiungere campi calcolati, audit, filtri di tenant e soft delete. Attenzione: `findUnique`, query raw e alcune operazioni non passano dal filtro; testate ogni percorso. Le estensioni non sostituiscono i vincoli e i controlli di autorizzazione.

#### Multi-tenancy e sicurezza

- Ogni tabella condivisa ha un `tenantId` e ogni query lo filtra.
- Non fidatevi del tenant inviato dal client: ricavatelo dalla sessione.
- Un repository centrale riduce il rischio di dimenticare il filtro.
- Con PostgreSQL valutate Row Level Security; con MySQL applicate il filtro applicativo e testatelo.
- L'utente DB dell'app non deve poter creare/eliminare schema o concedere permessi.
- Cancellazione GDPR: definite dove stanno i dati personali e come vengono rimossi o anonimizzati.

#### Test e seed

```js
// seed idempotente
for (const a of argomenti) {
  await prisma.argomento.upsert({
    where: { slug: a.slug },
    update: { titolo: a.titolo },
    create: a,
  });
}
```

- Usate un database di test dedicato o testcontainers, non quello di sviluppo.
- Applicate le migrazioni prima dei test, non `db push` in CI.
- Isolate i test con transazioni rollback o reset deterministico.
- Le factory rendono i test leggibili; evitate dipendenze tra test.
- Testate i vincoli (duplicati, FK) e gli errori, non solo il percorso felice.
- Il seed di produzione deve essere idempotente e sicuro da rieseguire.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — Init e primo modello**
Inizializza Prisma su un DB MySQL. Crea il modello `Utente`, esegui la prima migrazione, ispeziona la tabella con `prisma studio`.
- **Criterio:** la migrazione è versionata; la tabella usa i nomi mappati.

**1.2 — CRUD**
Crea, leggi, aggiorna ed elimina un utente da script Node. Usa `select` per non restituire `passwordHash`.
- **Criterio:** nessun errore di serializzazione BigInt.

**1.3 — Filtri**
Trova utenti per ruolo, cerca per email, ordina per data, limita i risultati. Confronta con l'SQL equivalente.
- **Criterio:** sai spiegare cosa genera Prisma.

**1.4 — Seed**
Scrivi un seed idempotente con 3 argomenti e 10 domande. Eseguilo due volte senza duplicati.
- **Criterio:** usa `upsert`; nessun duplicato.

---

### L2 — Intermedio

**2.1 — Relazioni**
Implementa `Domanda` → `Opzione` con `onDelete: Cascade`. Verifica che cancellando una domanda spariscano le opzioni.
- **Criterio:** test automatico che lo dimostra.

**2.2 — Query con include/select**
Endpoint che restituisce una domanda con le opzioni ordinate, **senza** il campo `corretta`. Un altro endpoint admin include `corretta`.
- **Criterio:** il client studente non può dedurre la risposta.

**2.3 — Paginazione e filtri**
Lista domande con `skip`/`take`, filtri combinabili e conteggio totale in una transazione (`$transaction` con array).
- **Criterio:** nessuna query N+1; risposta con metadati.

**2.4 — Gestione errori**
Mappa `P2002` → 409, `P2025` → 404, `P2003` → 400. Test per ogni caso.
- **Criterio:** nessun errore Prisma grezzo arriva al client.

**2.5 — Seed realistico**
Genera 50 studenti, 10 argomenti, 100 domande, 300 tentativi con date distribuite. Usa `createMany` in batch.
- **Criterio:** seed sotto i 10 secondi; dati coerenti.

---

### L3 — Avanzato

**3.1 — Transazione di submit**
Implementa il submit del tentativo in una transazione: crea tentativo, inserisci risposte, calcola punteggio, aggiorna stats. Rollback su errore.
- **Criterio:** test di errore a metà: nessun dato parziale.

**3.2 — Aggregazioni**
Calcola per studente: tentativi, media, migliore punteggio, ultimo tentativo. Usa `groupBy`, `aggregate` e una query mirata.
- **Criterio:** risultati verificati contro SQL manuale.

**3.3 — Soft delete**
Aggiungi `eliminataIl` e un’estensione che esclude le domande eliminate. Testa `findMany`, `findFirst`, `count`.
- **Criterio:** un admin può ancora vederle con una query esplicita.

**3.4 — Performance e N+1**
Data una query che carica 50 tentativi con utente e risposte, misura le query con `log: ["query"]`. Riduci a un numero costante con `include` mirati.
- **Criterio:** report con numero query prima/dopo.

**3.5 — Test con DB isolato**
Configura un database di test, migrazioni automatiche, reset tra i test e transazioni rollback. Testa repository e service.
- **Criterio:** suite ripetibile e indipendente dall'ordine.

---

### L4 — Esperto

**4.1 — Multi-tenancy**
Aggiungi `scuolaId` a utenti, classi e contenuti. Ogni query applicativa è filtrata per tenant. Valuta Prisma Client Extensions o repository dedicati.
- **Criterio:** test che prova accesso cross-tenant su ogni repository.

**4.2 — Migrazioni sicure**
Pianifica una modifica rinominando una colonna senza downtime (expand/contract): nuova colonna, doppia scrittura, backfill, switch letture, rimozione vecchia.
- **Criterio:** piano passo-passo con rollback e verifiche.

**4.3 — Pool e serverless**
Analizza il comportamento del pool di connessioni con 200 richieste concorrenti. Confronta `connection_limit`, PgBouncer/ProxySQL e Prisma Accelerate. Proponi configurazione.
- **Criterio:** report con latenze p50/p95 e connessioni attive.

**4.4 — GDPR e retention**
Implementa cancellazione account con anonimizzazione dei tentativi, export dati utente, retention dei log e delle risposte AI.
- **Criterio:** un utente cancellato non è più identificabile; i report aggregati restano validi.

**4.5 — Query raw controllate**
Dove Prisma non basta (window function, report complessi), usa `$queryRaw` con tagged template e tipi. Dimostra che non c'è injection.
- **Criterio:** test con input malevolo; nessuna concatenazione.

---

## 4. Quiz di verifica

1. Differenza tra `migrate dev` e `migrate deploy`?
2. Cosa fa `select` rispetto a `include`?
3. Perché `findMany` con `include` può creare N+1?
4. Cosa indica l'errore `P2002`?
5. Perché BigInt crea problemi in JSON?
6. Quando usare `$transaction` interattiva?
7. Perché il soft delete va testato su tutte le query?

<details>
<summary>Risposte</summary>

1. `migrate dev` crea e applica migrazioni in sviluppo, può resettare il DB; `migrate deploy` applica solo migrazioni già versionate in produzione.
2. `select` sceglie i campi da restituire; `include` aggiunge relazioni mantenendo tutti i campi scalari del modello.
3. Se per ogni record padre viene eseguita una query separata per la relazione: va usato `include`/`select` con join o batch, e verificato con i log.
4. Violazione di un vincolo di unicità (es. email duplicata).
5. `JSON.stringify` non serializza BigInt e lancia `TypeError`; va convertito in string/number.
6. Quando più operazioni dipendono l'una dall'altra e servono valori intermedi (es. ID appena creato), con isolamento e rollback.
7. Perché ogni query deve escludere esplicitamente i record eliminati; estensioni e raw query possono bypassare il filtro.

</details>

---

## 5. Mini-progetto del modulo

**"Data layer RipassoAI"**

Consegna:

- `schema.prisma` completo (utenti, classi, iscrizioni, argomenti, domande, opzioni, tentativi, risposte, flashcard, job AI);
- 3 migrazioni con nomi significativi;
- seed realistico e idempotente;
- repository per: auth, quiz, tentativi, progressi, classi;
- transazione di submit con test;
- gestione errori mappata;
- report query N+1 e ottimizzazioni;
- test su DB isolato.

**Criterio di eccellenza:** nessun endpoint esegue più di 3 query; nessun dato sensibile esce dal repository.

---

## 6. AI pairing

```text
Agisci come Prisma expert.
Ecco schema.prisma e la query che genera N+1.
1) Mostra le query SQL effettive ipotizzate.
2) Proponi la query Prisma ottimizzata.
3) Spiega il trade-off tra include, select e query separate.
Non inventare campi non presenti nello schema.
```

```text
Voglio aggiungere il soft delete alle domande senza rompere le query esistenti.
Elenca tutti i punti da modificare (repository, estensioni, test, indici)
e i casi in cui l'estensione non si applica.
```

**Verifica:** abilita il log delle query, conta le chiamate, esegui i test, controlla i tipi generati. L'AI tende a inventare API Prisma e a dimenticare le conversioni BigInt.

---

## 7. Checklist di uscita

- [ ] Modello relazioni con cardinalità corrette.
- [ ] Gestisco migrazioni in sviluppo e produzione.
- [ ] Uso `select` per non far uscire dati sensibili.
- [ ] So misurare e ridurre le query N+1.
- [ ] Uso transazioni per operazioni atomiche.
- [ ] Mappo gli errori Prisma a status HTTP.
- [ ] Ho consegnato schema, seed, repository e test.
