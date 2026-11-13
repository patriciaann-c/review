-- =====================================================================
-- RipassoAI — 0011: modulo 11 "Autenticazione e autorizzazione"
--   * crea il modulo 11, l'argomento "autenticazione" e la fonte
--   * 30 domande approvate: 8 L1, 8 L2, 8 L3, 6 L4
--   * idempotente: modulo/argomento in upsert, importa_quiz salta i testi
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Catalogo: modulo, argomento e fonte del modulo
-- ---------------------------------------------------------------------
do $$
declare
  v_corso     uuid;
  v_modulo    uuid;
begin
  select c.id into v_corso
  from public.corso c
  where c.codice = 'AIWEB'
  limit 1;

  if v_corso is null then
    raise exception 'Corso AIWEB non trovato: applica prima 0002_seed.sql';
  end if;

  insert into public.modulo (corso_id, numero, titolo)
  values (v_corso, 11, 'Autenticazione e autorizzazione')
  on conflict (corso_id, numero) do update set titolo = excluded.titolo
  returning id into v_modulo;

  insert into public.argomento (modulo_id, nome, slug, descrizione)
  values (
    v_modulo,
    'Autenticazione e autorizzazione',
    'autenticazione',
    'Login, sessioni, token, ruoli e RLS: chi sei e cosa puoi fare.'
  )
  on conflict (modulo_id, slug) do update
    set nome = excluded.nome,
        descrizione = excluded.descrizione;

  insert into public.fonte (corso_id, tipo, titolo, riferimento)
  select v_corso, 'MODULO', 'Modulo 11 — Autenticazione e autorizzazione',
         'moduli/11-autenticazione-autorizzazione.md'
  where not exists (
    select 1 from public.fonte f
    where f.corso_id = v_corso
      and f.titolo = 'Modulo 11 — Autenticazione e autorizzazione'
  );
end $$;

-- ---------------------------------------------------------------------
-- 2. Banco domande (30)
-- ---------------------------------------------------------------------
select public.importa_quiz('autenticazione', $j$[
  {"livello":"L1","testo":"Quale domanda descrive l'autenticazione?","spiegazione":"L'autenticazione risponde a chi sei: verifica l'identità. L'autorizzazione decide cosa puoi fare.","opzioni":["Chi sei?","Cosa puoi fare?","Dove ti trovi?","Quanto puoi spendere?"],"corretta":0},
  {"livello":"L1","testo":"Quale codice HTTP indica credenziali mancanti o non valide?","spiegazione":"401 Unauthorized segnala che manca un'autenticazione valida; 403 indica un utente autenticato ma senza permesso.","opzioni":["401","403","404","500"],"corretta":0},
  {"livello":"L1","testo":"Come va salvata una password nel database?","spiegazione":"Solo come hash lento e saltato (bcrypt o Argon2id). Mai in chiaro, mai cifrata in modo reversibile, mai in base64.","opzioni":["In chiaro per poterla mostrare all'utente","Come hash lento con salt","Cifrata con una chiave nel codice","Codificata in base64"],"corretta":1},
  {"livello":"L1","testo":"A cosa serve il salt nel hashing di una password?","spiegazione":"Il salt rende diverso l'hash di password uguali e neutralizza le rainbow table precalcolate.","opzioni":["A rendere diversi gli hash di password uguali","A comprimere l'hash","A rendere la password più corta","A cifrare il traffico HTTPS"],"corretta":0},
  {"livello":"L1","testo":"Quante parti separate da un punto ha un JWT?","spiegazione":"Un JWT ha header, payload e signature: tre parti in base64url separate da un punto.","opzioni":["Una","Due","Tre","Quattro"],"corretta":2},
  {"livello":"L1","testo":"Dove può essere inclusa la chiave publishable (anon) di Supabase?","spiegazione":"La chiave publishable è pubblica e sta nel client: la sicurezza viene dalle policy RLS. La service_role non deve mai finire nel browser.","opzioni":["Nel bundle del client, perché è pubblica","Solo nel database","Solo nei log del server","Mai da nessuna parte"],"corretta":0},
  {"livello":"L1","testo":"Cosa restituisce auth.uid() in Supabase?","spiegazione":"Restituisce l'id dell'utente autenticato nella sessione del database: è la base delle policy RLS.","opzioni":["L'id della tabella utente","L'id dell'utente autenticato","Il ruolo dell'utente","La chiave anon"],"corretta":1},
  {"livello":"L1","testo":"Quale attributo impedisce a JavaScript di leggere un cookie?","spiegazione":"HttpOnly esclude il cookie da document.cookie: un XSS non può esfiltrare il token di sessione.","opzioni":["HttpOnly","Secure","SameSite","Max-Age"],"corretta":0},
  {"livello":"L2","testo":"Perché per le password si usano bcrypt o Argon2id invece di SHA-256?","spiegazione":"Sono funzioni volutamente lente e saltate: rendono costosi gli attacchi a forza bruta e con GPU.","opzioni":["Perché producono hash più corti","Perché sono lente e saltate, quindi costose da attaccare","Perché non richiedono una password","Perché cifrano il traffico di rete"],"corretta":1},
  {"livello":"L2","testo":"Cosa limita SameSite=Lax su un cookie di sessione?","spiegazione":"Lax invia il cookie nelle navigazioni top-level ma non nelle richieste cross-site di POST, riducendo il CSRF.","opzioni":["La dimensione massima del cookie","La lettura del cookie da JavaScript","L'invio del cookie nelle richieste cross-site non top-level","La scadenza del cookie"],"corretta":2},
  {"livello":"L2","testo":"Cosa NON va mai inserito nel payload di un JWT?","spiegazione":"Il payload è solo codificato, non cifrato: chiunque può leggerlo. Mai segreti, password o dati sensibili.","opzioni":["Una password o un dato sensibile","La data di scadenza exp","L'identificativo sub","Il nome del ruolo"],"corretta":0},
  {"livello":"L2","testo":"Qual è la combinazione corretta per access e refresh token?","spiegazione":"Access token breve (5-15 minuti) e refresh token lungo con rotazione a ogni uso: limita la finestra di furto e permette la revoca.","opzioni":["Access token di un anno e refresh token di un'ora","Due access token identici","Access token lungo e refresh token brevissimo","Access token breve e refresh token lungo con rotazione"],"corretta":3},
  {"livello":"L2","testo":"Su cosa si basa il modello RBAC?","spiegazione":"RBAC assegna permessi ai ruoli e ruoli agli utenti: è il modello usato per STUDENTE, DOCENTE e ADMIN.","opzioni":["Sugli attributi della richiesta","Sui ruoli assegnati agli utenti","Sull'indirizzo IP","Sulla posizione geografica"],"corretta":1},
  {"livello":"L2","testo":"In una policy RLS, cosa fa WITH CHECK?","spiegazione":"WITH CHECK valida i nuovi valori scritti da INSERT o UPDATE; USING filtra invece le righe esistenti.","opzioni":["Seleziona le righe visibili in lettura","Imposta il ruolo dell'utente","Valida i nuovi valori scritti da insert e update","Disabilita la RLS"],"corretta":2},
  {"livello":"L2","testo":"Perché la chiave anon di Supabase può essere pubblica?","spiegazione":"I permessi reali sono nelle policy RLS: la chiave identifica il progetto, non concede accesso illimitato ai dati.","opzioni":["Perché le policy RLS limitano ciò che ogni utente può fare","Perché non permette di leggere nessuna tabella","Perché viene cambiata a ogni deploy","Perché è cifrata nel bundle"],"corretta":0},
  {"livello":"L2","testo":"Cosa fa signOut di Supabase?","spiegazione":"Chiude la sessione locale e revoca il refresh token; un access token già emesso resta valido fino alla sua scadenza.","opzioni":["Elimina tutti i dati dell'utente","Invalidare immediatamente ogni JWT emesso","Cancella il profilo dal database","Chiude la sessione locale e revoca il refresh token"],"corretta":3},
  {"livello":"L3","testo":"Come si previene un attacco IDOR su una risorsa personale?","spiegazione":"Non basta autenticare: va verificato il proprietario lato server e aggiunta una policy RLS. L'id nell'URL non è una prova di permesso.","opzioni":["Nascondendo il link nella UI","Verificando il proprietario lato server e con RLS","Cambiando gli id in UUID","Aggiungendo un captcha"],"corretta":1},
  {"livello":"L3","testo":"Un pulsante di amministrazione è nascosto agli studenti: è sufficiente?","spiegazione":"No: l'endpoint resta chiamabile direttamente. L'autorizzazione va imposta su API e database, non sulla UI.","opzioni":["Sì, se il pulsante non è visibile","No, perché l'endpoint resta raggiungibile","Sì, perché React non espone le rotte","Dipende solo dal browser usato"],"corretta":1},
  {"livello":"L3","testo":"Cos'è la session fixation e come si mitiga?","spiegazione":"L'attaccante impone all'utente un id di sessione che conosce. Si mitiga rigenerando l'id dopo il login e accettando solo id generati dal server.","opzioni":["Un attacco che ruba il database","Un errore di hashing delle password","Un id di sessione imposto dall'attaccante, mitigato rigenerandolo al login","Una tecnica per velocizzare il login"],"corretta":2},
  {"livello":"L3","testo":"Perché i cookie di sessione sono esposti al CSRF?","spiegazione":"Il browser allega automaticamente i cookie alle richieste verso il sito, anche se la richiesta parte da una pagina ostile.","opzioni":["Perché sono leggibili da JavaScript","Perché il browser li invia automaticamente anche su richieste cross-site","Perché non hanno una scadenza","Perché sono sempre in chiaro"],"corretta":1},
  {"livello":"L3","testo":"Un XSS legge il localStorage e ruba il token: quale mitigazione lo impedisce davvero?","spiegazione":"Spostare il token in un cookie HttpOnly lo rende invisibile a JavaScript. Escaping e CSP riducono l'XSS, ma il flag HttpOnly protegge il token.","opzioni":["Rinominare la chiave in localStorage","Comprimere il token","Usare un token più corto","Gestire la sessione con cookie HttpOnly"],"corretta":3},
  {"livello":"L3","testo":"Perché il login fallito deve restituire sempre lo stesso messaggio?","spiegazione":"Messaggi diversi per email inesistente e password errata permettono di scoprire quali account esistono (user enumeration).","opzioni":["Per evitare di rivelare quali account esistono","Per ridurre i token inviati","Per velocizzare il database","Per abilitare il caching"],"corretta":0},
  {"livello":"L3","testo":"Perché si ruota il refresh token a ogni utilizzo?","spiegazione":"Se un refresh token viene riusato, il server può rilevare il furto e revocare la famiglia di token. Riduce anche la finestra di sfruttamento.","opzioni":["Per consumare meno memoria","Per evitare di usare HTTPS","Per rilevare il riuso e limitare i danni di un furto","Per cambiare l'id utente a ogni login"],"corretta":2},
  {"livello":"L3","testo":"Quale flusso OAuth è adatto a una SPA senza client secret?","spiegazione":"Authorization Code con PKCE è pensato per i client pubblici: nessun secret nel browser e protezione del codice di autorizzazione.","opzioni":["Implicit flow","Authorization Code con PKCE","Resource Owner Password Credentials","Client Credentials"],"corretta":1},
  {"livello":"L4","testo":"Cosa serve perché una RLS multi-tenant sia davvero sicura?","spiegazione":"Ogni policy deve filtrare anche il tenant, oltre all'utente, e servono test automatici che tentino accessi incrociati.","opzioni":["Filtrare il tenant nelle policy e testare accessi cross-tenant","Contare sui controlli della UI","Salvare il tenant nel localStorage","Usare una sola policy using (true)"],"corretta":0},
  {"livello":"L4","testo":"Un utente invia ruolo ADMIN nel proprio profilo: qual è la mitigazione completa?","spiegazione":"L'API deve ignorare i campi non consentiti e il database deve impedire l'aggiornamento del ruolo (colonna protetta o trigger). Il controllo solo nel client non basta.","opzioni":["Validare il campo nel form React","Cambiare il nome del campo ad ADMIN","Registrare il tentativo nei log","Ignorare il campo nell'API e impedirne la modifica nel database"],"corretta":3},
  {"livello":"L4","testo":"Come si invalida subito un access token JWT già emesso?","spiegazione":"Essendo stateless, un JWT resta valido fino a exp. Servono una denylist o un token_version per utente confrontato a ogni richiesta.","opzioni":["Cancellando il token dal localStorage","Con una denylist o un token_version lato server","Riavviando il browser","Rigenerando la chiave anon"],"corretta":1},
  {"livello":"L4","testo":"Perché la RLS non protegge se il backend usa la service_role key?","spiegazione":"La service_role scavalca le policy RLS: con quella chiave l'autorizzazione deve essere imposta esplicitamente dal backend.","opzioni":["Perché la service_role disabilita il database","Perché la RLS vale solo per gli admin","Perché la service_role bypassa RLS e richiede controlli applicativi","Perché la RLS non funziona su Postgres"],"corretta":2},
  {"livello":"L4","testo":"Perché le passkey sono più resistenti al phishing di un codice TOTP?","spiegazione":"WebAuthn è legato all'origine del sito: una passkey non può essere usata su un dominio clone, mentre un OTP può essere intercettato e riusato in tempo reale.","opzioni":["Perché sono legate al dominio e non funzionano su siti clone","Perché non scadono mai","Perché non richiedono un dispositivo","Perché sostituiscono l'autorizzazione"],"corretta":0},
  {"livello":"L4","testo":"Cosa deve contenere un audit log di sicurezza?","spiegazione":"Chi ha fatto cosa, su quale risorsa, quando ed esito. Mai password, token completi o segreti, che diventerebbero un'altra fuga di dati.","opzioni":["Tutte le password cifrate","Chi, cosa, quando ed esito, senza segreti","Solo i messaggi di errore del database","I token completi per poterli riprodurre"],"corretta":1}
]$j$::jsonb);
