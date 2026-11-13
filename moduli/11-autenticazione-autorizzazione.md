# Modulo 11 — Autenticazione e autorizzazione

> **Livello:** avanzato · **Tempo:** 8 h · **Prerequisiti:** JavaScript, React, Express, Prisma, Supabase
> **Deliverable:** login sicuro, ruoli, policy RLS e audit per la piattaforma RipassoAI.

---

## 1. Traguardi

Al termine del modulo sapete:

- distinguere **autenticazione** (chi sei) da **autorizzazione** (cosa puoi fare);
- gestire password, sessioni, cookie e token senza salvare segreti in chiaro;
- usare **Supabase Auth** e proteggere le rotte lato client *e* lato database;
- progettare ruoli e permessi con **RBAC**, ownership e **Row Level Security**;
- riconoscere e prevenire **IDOR**, **CSRF**, **XSS**, **privilege escalation** e **user enumeration**;
- aggiungere **MFA/passkey**, revoca delle sessioni e log di audit;
- spiegare perché il controllo fatto solo nel browser non è un controllo di sicurezza.

---

## 2. Concetti chiave (cheat sheet)

### Autenticazione vs autorizzazione

| | Autenticazione | Autorizzazione |
|---|---|---|
| Domanda | *Chi sei?* | *Cosa puoi fare?* |
| Quando | Prima | Dopo l'autenticazione |
| Esempi | password, OTP, passkey, OAuth | ruoli, permessi, RLS, ownership |
| Errore tipico | **401 Unauthorized** (credenziali mancanti o errate) | **403 Forbidden** (identità valida, permesso negato) |
| Dove si verifica | Server / provider di identità | Server e database, mai solo il client |

**Regola d'oro:** l'autenticazione dice *chi* sta chiamando; l'autorizzazione decide *se* quella persona può compiere l'azione su *quella specifica risorsa*. Un utente autenticato non è automaticamente autorizzato.

### Identità, sessione e credenziali

- L'**identità** è l'utente (id stabile, email verificata, ruoli).
- La **sessione** è lo stato che dimostra che quell'utente ha effettuato l'accesso.
- Le **credenziali** sono i dati usati per provarlo: password, OTP, chiave passkey.
- Una sessione ha sempre: scadenza, possibilità di revoca, un identificatore non prevedibile.

### Password: non si salvano, si hashan

Una password non va mai salvata in chiaro, cifrata in modo reversibile o hashed con MD5/SHA-1/SHA-256 "nudo": sono troppo veloci e vulnerabili a rainbow table e GPU.

```js
import bcrypt from 'bcrypt'

// Registrazione: 12 round sono un buon compromesso nel 2026.
const hash = await bcrypt.hash(password, 12)

// Login: confronto a tempo costante gestito dalla libreria.
const ok = await bcrypt.compare(passwordInviata, hashSalvato)
```

- **Argon2id** è la prima scelta; **bcrypt** va benissimo se configurato con un cost adeguato.
- Il **salt** è unico per utente e viene generato dalla libreria: impedisce hash identici per password identiche.
- La **policy** (lunghezza minima, no password comuni, no dati personali) è un requisito, non un consiglio.
- **Rate limiting** e blocco progressivo sul login; confronto sempre a tempo costante.
- Al cambio password: invalida le sessioni esistenti e invia una notifica.

### Sessioni e cookie

Con sessioni **server-side** il browser riceve solo un ID di sessione opaco; i dati stanno sul server.

```js
app.use(session({
  name: 'rai_sid',
  secret: process.env.SESSION_SECRET,          // mai nel codice
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,   // non leggibile da JavaScript: niente furto via XSS
    secure: true,     // solo HTTPS
    sameSite: 'lax',  // limita le richieste cross-site (CSRF)
    maxAge: 1000 * 60 * 60 * 8,
  },
}))
```

| Attributo | Cosa impedisce |
|---|---|
| `HttpOnly` | Lettura del cookie da JavaScript (XSS) |
| `Secure` | Invio del cookie su HTTP in chiaro |
| `SameSite=Lax` | Richieste cross-site su POST/PUT/DELETE |
| `SameSite=Strict` | Qualsiasi invio cross-site (più restrittivo) |
| `SameSite=None; Secure` | Solo se serve davvero l'uso cross-site (es. iframe) |

Dopo il login **rigenera l'ID di sessione** (mitigazione della *session fixation*); al logout distruggi la sessione sul server, non solo il cookie nel browser.

### Token e JWT

Un **JWT** è composto da tre parti separate da un punto:

```text
header.payload.signature
eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1dXRpZCJ9.firma
```

- La **firma** garantisce integrità e provenienza: **non cifra** il contenuto. Chiunque può leggere il payload (basta base64url).
- Claim standard: `sub` (utente), `exp` (scadenza), `iat` (emissione), `aud` (destinatario), `iss` (emittente), `role`.
- **Non inserire segreti o dati sensibili** nel payload: è leggibile.
- **Access token** breve (5–15 min) + **refresh token** lungo, con **rotazione** a ogni uso e revoca su logout/password change.
- Un JWT firmato resta valido fino a `exp`: per revocarlo subito servono una denylist, una versione utente (`token_version`) o sessioni server-side.

```js
import { jwtVerify } from 'jose'

const { payload } = await jwtVerify(token, chiavePubblica, {
  issuer: 'https://auth.example.it',
  audience: 'ripasso-ai',
})
```

### OAuth 2.0 e OpenID Connect

- **OAuth 2.0** delega l'accesso a risorse; **OpenID Connect (OIDC)** aggiunge l'identità (ID token).
- Per una SPA il flusso corretto è **Authorization Code + PKCE**: evita di esporre il client secret nel browser.
- `state` previene il CSRF del flusso; `nonce` protegge l'ID token.
- La **redirect URI** deve essere in whitelist esatta: un redirect aperto può rubare il codice.
- `access_token` serve per le API, `id_token` per sapere chi è l'utente: non sono intercambiabili.
- Non usare l'*implicit flow*: i token finirebbero nella cronologia e nei referer.

### MFA e passkey

- **TOTP** (app authenticator): secondo fattore economico, ma vulnerabile a phishing in tempo reale.
- **WebAuthn / passkey**: legata al dominio, resistente al phishing, preferibile quando disponibile.
- I **codici di recupero** vanno generati una volta, mostrati una volta e salvati come hash.
- MFA non sostituisce l'autorizzazione: un utente con MFA può comunque non avere i permessi.

### Autorizzazione: modelli

- **RBAC** (Role-Based Access Control): permessi assegnati a ruoli (`STUDENTE`, `DOCENTE`, `ADMIN`).
- **ABAC** (Attribute-Based): decisioni su attributi (classe, corso, tenant, orario).
- **Ownership**: puoi leggere/modificare solo le risorse che possiedi.
- **Deny by default**: tutto è negato finché una regola esplicita non concede.
- **Minimo privilegio**: ogni utente, servizio e chiave ha solo i permessi necessari.

```js
// Sbagliato: il ruolo arriva dal client.
app.post('/api/utenti', (req, res) => {
  if (req.body.ruolo === 'ADMIN') { /* ... */ }
})

// Corretto: il ruolo si legge dal server, l'id dalla sessione.
app.post('/api/utenti', richiediLogin, async (req, res) => {
  const utente = await trovaUtente(req.session.utenteId)
  if (utente.ruolo !== 'ADMIN') return res.sendStatus(403)
  // ...
})
```

### Supabase Auth e Row Level Security

- `auth.users` è la tabella delle identità gestita da Supabase; `public.utente` è il profilo applicativo.
- `auth.uid()` restituisce l'id dell'utente autenticato **nel database**, non nel client.
- La **anon key** è pubblica e può stare nel bundle: la sicurezza viene dalle policy RLS.
- La **service_role key** scavalca RLS: va usata **solo** in backend fidato, mai in React, mai in `VITE_*`.

```sql
-- Abilita RLS: senza questo le policy non contano.
alter table public.scheda enable row level security;

-- Lettura: solo le proprie schede.
create policy "scheda_lettura"
on public.scheda for select to authenticated
using (utente_id = auth.uid());

-- Inserimento: il proprietario deve essere l'utente della sessione.
create policy "scheda_inserimento"
on public.scheda for insert to authenticated
with check (utente_id = auth.uid());

-- Update: separa il filtro righe (USING) dal valore scritto (WITH CHECK).
create policy "scheda_modifica"
on public.scheda for update to authenticated
using (utente_id = auth.uid())
with check (utente_id = auth.uid());
```

- `USING` decide **quali righe** puoi vedere/modificare; `WITH CHECK` valida **i nuovi valori**.
- Le policy si combinano in OR tra loro (per lo stesso comando): una policy troppo permissiva annulla le altre.
- Funzioni helper come `ha_ruolo('ADMIN')` vanno dichiarate `security definer` con `search_path` fisso, altrimenti si rischia ricorsione o hijacking.
- Testare RLS con due utenti diversi è obbligatorio: la policy "sembra giusta" finché non provi l'accesso incrociato.

### Errori di autorizzazione comuni (OWASP A01)

- **IDOR** (*Insecure Direct Object Reference*): cambi l'id nell'URL e vedi i dati di un altro.

```text
GET /api/schede/8f3c...   ← l'id non basta: serve verificare il proprietario
```

- **Escalation orizzontale**: utente A accede ai dati di utente B (stesso ruolo).
- **Escalation verticale**: uno studente ottiene funzioni da docente/admin (es. campo `ruolo` modificabile).
- **Mancato controllo a livello di funzione**: la UI nasconde il pulsante, ma l'endpoint risponde comunque.
- **Fidarsi del client**: ruoli, prezzi, `utente_id` e flag inviati dal browser non sono attendibili.

La difesa è sempre **doppia**: controllo nell'API/endpoint + vincolo nel database (RLS o foreign key + check).

### Attacchi al browser

- **XSS**: uno script iniettato legge `localStorage` e ruba il token. Mitigazioni: escaping, CSP, cookie `HttpOnly`, sanitizzazione del Markdown.
- **CSRF**: il browser invia i cookie automaticamente anche da un altro sito. Mitigazioni: `SameSite`, token anti-CSRF, verifica `Origin`.
- **Open redirect**: `?next=https://evil.example` porta l'utente su un sito ostile. Whitelist dei redirect interni.
- **User enumeration**: messaggi diversi per "email inesistente" e "password errata" rivelano quali account esistono. Usa un messaggio unico.
- **Token nel localStorage**: comodo, ma qualsiasi XSS lo esfiltra. Se possibile, cookie `HttpOnly` gestiti dal backend.

### Log, audit e monitoraggio

- Logga login riusciti/falliti, cambi di ruolo, accessi negati, revoche: con utente, IP, user agent, timestamp.
- **Mai** loggare password, token completi, cookie o chiavi.
- Conserva un **audit trail** immutabile per le azioni sensibili (chi ha approvato cosa, quando).
- Alert su picchi di 401/403, login da paesi anomali e tentativi ripetuti sullo stesso account.

### Errori comuni

- Salvare password in chiaro o con hash veloce.
- Fidarsi del ruolo inviato dal client.
- Nascondere un pulsante e chiamarlo "autorizzazione".
- Mettere la `service_role` key in una variabile `VITE_*`.
- Dimenticare `enable row level security` o scrivere policy solo `using (true)`.
- Token senza scadenza, senza revoca, salvati in `localStorage` senza pensarci.
- Messaggi di errore che distinguono email esistente e non esistente.
- Cookie senza `HttpOnly`, `Secure`, `SameSite`.

---

## 3. Esercizi per livello

### L1 — Base

**1.1 — 401 o 403?**
Classifica 8 situazioni (token assente, token scaduto, utente non admin, IDOR) indicando status e motivo.
- **Criterio:** 8/8 corretti con motivazione.

**1.2 — Hash e verifica**
Implementa registrazione e login con `bcrypt.hash` e `bcrypt.compare`. Verifica che nel database non compaia mai la password.
- **Criterio:** la password in chiaro non esiste in nessuna tabella né nei log.

**1.3 — Cookie flags**
Configura una sessione Express con `HttpOnly`, `Secure`, `SameSite=Lax` e scadenza di 8 ore.
- **Criterio:** in DevTools il cookie mostra i flag e non è leggibile da `document.cookie`.

**1.4 — Anatomia di un JWT**
Decodifica un token su jwt.io (senza incollare token reali) e individua header, payload, firma e claim `exp`.
- **Criterio:** sai spiegare perché la firma non rende il payload segreto.

### L2 — Intermedio

**2.1 — Login Supabase**
Implementa `signInWithPassword`, gestione della sessione con `getSession`, logout con `signOut` e messaggio di errore unico.
- **Criterio:** dopo il logout la rotta protetta non è più accessibile; il messaggio non rivela se l'email esiste.

**2.2 — Rotta protetta**
Crea una rotta React che reindirizza al login se non c'è sessione, e un endpoint Express che restituisce 401 se manca l'autenticazione.
- **Criterio:** il client non è l'unica difesa: la chiamata diretta all'API viene bloccata.

**2.3 — Primo ruolo**
Aggiungi i ruoli `STUDENTE` e `DOCENTE`: lo studente vede i propri quiz, il docente vede i quiz della propria classe.
- **Criterio:** nessun endpoint decide il ruolo leggendolo dal body o dal query string.

**2.4 — RLS di base**
Abilita RLS su una tabella e scrivi policy `select`, `insert`, `update` basate su `auth.uid()`.
- **Criterio:** con due utenti, ciascuno vede solo le proprie righe anche chiamando l'API direttamente.

### L3 — Avanzato

**3.1 — Test IDOR**
Prova a leggere la scheda di un altro utente cambiando l'id: verifica che API e RLS rispondano 404/403.
- **Criterio:** 20 tentativi con id diversi, zero accessi non autorizzati.

**3.2 — Escalation verticale**
Un utente prova a impostare `ruolo: 'ADMIN'` nel proprio profilo. Blocca il campo lato API e con un trigger/colonna non aggiornabile.
- **Criterio:** il tentativo fallisce anche con richiesta artigianale (curl/Postman).

**3.3 — CSRF e SameSite**
Costruisci una pagina ostile che invia un POST cross-site e osserva il comportamento con `SameSite=Lax`, `Strict` e token anti-CSRF.
- **Criterio:** report con richiesta bloccata/permessa per ogni configurazione.

**3.4 — XSS e token**
Simula un XSS che legge `localStorage`; poi sposta il token in un cookie `HttpOnly` e aggiungi una CSP.
- **Criterio:** dopo la modifica il payload non riesce più a leggere il token.

**3.5 — Revoca**
Implementa la revoca delle sessioni al cambio password e un `token_version` per invalidare i JWT emessi prima.
- **Criterio:** un token emesso prima del cambio password viene rifiutato.

### L4 — Esperto

**4.1 — Multi-tenant**
Isola due scuole con RLS e test cross-tenant automatici su tutte le tabelle sensibili.
- **Criterio:** 100 tentativi incrociati, zero fughe di dati.

**4.2 — Modello ABAC**
Autorizza un docente a vedere una classe solo se è il titolare *e* la classe è del suo corso. Documenta la matrice dei permessi.
- **Criterio:** matrice completa; ogni regola ha un test.

**4.3 — Passkey**
Aggiungi WebAuthn come secondo fattore e confronta il rischio phishing con TOTP.
- **Criterio:** login con passkey funzionante e fallback sicuro documentato.

**4.4 — Audit e alert**
Registra login, 401/403, cambi ruolo e revoche; crea un alert su 10 fallimenti in 5 minuti dallo stesso IP.
- **Criterio:** simulando un attacco a forza bruta l'alert scatta e il log non contiene segreti.

**4.5 — Threat model**
Scrivi il threat model del login: attori, superfici, minacce (credential stuffing, session hijacking, privilege escalation) e mitigazioni.
- **Criterio:** ogni minaccia ha una mitigazione verificabile con un test.

---

## 4. Quiz di verifica

1. Differenza tra 401 e 403?
2. Perché non si salva la password con SHA-256?
3. Cosa impedisce l'attributo `HttpOnly`?
4. Il payload di un JWT è cifrato?
5. Cosa distingue `USING` da `WITH CHECK` in una policy RLS?
6. Perché nascondere un pulsante non è autorizzazione?
7. Cos'è un attacco IDOR e come si previene?
8. Perché la `service_role` key non può stare nel client?

<details>
<summary>Risposte</summary>

1. 401: manca un'autenticazione valida (credenziali assenti/errate). 403: l'utente è autenticato ma non ha il permesso.
2. È un hash veloce e senza salt: si presta a rainbow table e attacchi GPU. Servono funzioni lente e saltate come bcrypt o Argon2id.
3. Che JavaScript possa leggere il cookie: un XSS non può esfiltrare il token di sessione.
4. No: è solo codificato in base64url. La firma garantisce integrità, non riservatezza. Mai mettere segreti nel payload.
5. `USING` seleziona le righe esistenti su cui puoi agire; `WITH CHECK` valida i valori nuovi che stai scrivendo.
6. Perché l'endpoint resta raggiungibile con una chiamata diretta: l'autorizzazione va imposta su API e database.
7. È l'accesso a una risorsa altrui cambiando un identificatore. Si previene verificando il proprietario lato server e con policy RLS.
8. Perché scavalca RLS e ha permessi totali: finirebbe nel bundle pubblico e chiunque potrebbe leggere o modificare tutti i dati.

</details>

---

## 5. Mini-progetto del modulo

**"Login sicuro e ruoli di RipassoAI"**

Requisiti:

- registrazione e login con Supabase Auth; messaggi di errore non enumerabili;
- profilo in `public.utente` con ruoli `STUDENTE`, `DOCENTE`, `ADMIN`;
- RLS attiva su tutte le tabelle personali, con policy `select`/`insert`/`update`/`delete`;
- rotte protette lato React e middleware di autenticazione lato API;
- test IDOR e test di escalation verticale documentati;
- revoca delle sessioni al cambio password;
- audit log di login, 401/403 e cambi ruolo;
- checklist di sicurezza compilata e threat model.

**Consegna:** cartella `modulo-11/` con codice, migrazioni SQL, `security-report.md` e `threat-model.md`.

---

## 6. AI pairing

```text
Agisci come revisore di sicurezza di un'app React + Supabase.
Ti incollo schema delle tabelle, policy RLS e endpoint Express.
Cerca: IDOR, escalation verticale, policy troppo permissive, fiducia nel client,
segreti nel bundle, sessioni non revocabili.
Per ogni problema: impatto, prova concreta (richiesta), fix minimo.
```

```text
Genera 10 test di autorizzazione per questa piattaforma:
per ogni test indica utente, ruolo, azione, risorsa, esito atteso (200/401/403/404).
Includi almeno 3 test cross-tenant e 2 di escalation dei ruoli.
```

**Verifica:** esegui i test con account diversi, controlla i log, prova le richieste dirette con curl. Non fidarti di una policy "a occhio": provala.

---

## 7. Checklist di uscita

- [ ] Distinguo autenticazione e autorizzazione, 401 e 403.
- [ ] Le password sono hashate con bcrypt/Argon2id e salt.
- [ ] Le sessioni sono revocabili e i cookie hanno `HttpOnly`, `Secure`, `SameSite`.
- [ ] So leggere un JWT e so cosa non metterci dentro.
- [ ] So quando usare RBAC, ownership e ABAC.
- [ ] Ho RLS attiva e policy testate con due utenti diversi.
- [ ] Ho protetto API e database, non solo la UI.
- [ ] Ho testato IDOR e privilege escalation.
- [ ] Ho audit log senza segreti e alert sui tentativi sospetti.
- [ ] Ho consegnato report di sicurezza e threat model.
