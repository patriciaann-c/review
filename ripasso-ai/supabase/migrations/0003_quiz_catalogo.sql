-- =====================================================================
-- RipassoAI — 0003: catalogo quiz da 30 domande e 3 schede
--   * 30 domande APPROVATE: 6 L1, 6 L2, 12 L3, 6 L4
--   * 3 schede per utente, ognuna con 10 domande: 4 L1-L2, 4 L3, 2 L4
--   * schede 2 e 3 copiano concetti, piano, autovalutazione, fonti e
--     flashcard dalla scheda 1 (le flashcard sono riusate, non duplicate)
--   * idempotente: le domande sono riconosciute dal testo
-- =====================================================================

do $$
declare
  v_corso      uuid;
  v_utente     uuid;
  v_approvatore uuid;
  v_argomenti  jsonb := '{}'::jsonb;
  v_fonti      jsonb := '{}'::jsonb;
  v_domande    jsonb := '{}'::jsonb;
  v_schede     uuid[] := array[]::uuid[];
  v_s1         uuid;
  v_nuova      uuid;
  v_domanda    uuid;
  v_titoli     text[] := array[
    'Scheda di ripasso — Prova A',
    'Scheda di ripasso — Prova B',
    'Scheda di ripasso — Prova C'
  ];
  r    record;
  k    integer;
  j    integer;
  c1   integer;
  c2   integer;
  c3   integer;
  c4   integer;
begin
  select id into v_corso from public.corso where codice = 'AIWEB' limit 1;
  if v_corso is null then
    raise exception 'Catalogo mancante: applica prima 0002_seed.sql';
  end if;

  select id into v_approvatore from public.utente order by creato_il limit 1;
  if v_approvatore is null then
    raise exception 'Nessun utente: registrati nell''app e riapplica 0002_seed.sql';
  end if;

  -- Argomenti del corso: slug -> id.
  select coalesce(jsonb_object_agg(a.slug, a.id), '{}'::jsonb) into v_argomenti
  from public.argomento a
  join public.modulo m on m.id = a.modulo_id
  where m.corso_id = v_corso;

  -- Fonti dei moduli: slug dell'argomento -> id della fonte.
  select coalesce(jsonb_object_agg(a.slug, f.id), '{}'::jsonb) into v_fonti
  from public.argomento a
  join public.modulo m on m.id = a.modulo_id
  join public.fonte f on f.corso_id = m.corso_id and f.titolo like '% ' || a.nome
  where m.corso_id = v_corso;

  -- -------------------------------------------------------------------
  -- 1. Catalogo domande
  --    Le prime 10 esistono già: vengono solo mappate per testo.
  -- -------------------------------------------------------------------
  for r in
    select * from jsonb_to_recordset($json$[
      {"testo":"Quale elemento contiene il contenuto principale e unico della pagina?","livello":"L1"},
      {"testo":"Con box-sizing: border-box, width: 300px include padding e bordo?","livello":"L1"},
      {"testo":"Cosa restituisce [1, 2, 3].map(n => n * 2).filter(n => n > 2)?","livello":"L2"},
      {"testo":"Perché non usare l'indice come key di una lista riordinabile?","livello":"L2"},
      {"testo":"Qual è la differenza tra WHERE e HAVING?","livello":"L2"},
      {"testo":"Dove va conservata una chiave API?","livello":"L2"},
      {"testo":"Un utente autenticato prova a leggere il tentativo di un altro studente. Quale status è corretto?","livello":"L3"},
      {"testo":"Cosa genera il problema N+1?","livello":"L3"},
      {"testo":"Perché in un RAG si chiede al modello di citare le fonti?","livello":"L3"},
      {"testo":"Un tool get_progressi riceve l'ID utente dal testo del modello. Perché è pericoloso?","livello":"L4"},

      {"testo":"Quale attributo fornisce un testo alternativo a un'immagine?","livello":"L1","argomento":"html","fonte":"html","spiegazione":"alt descrive l'immagine agli screen reader e quando il file non si carica; title è solo un tooltip.","opzioni":["alt","title","src","role"],"corretta":0},
      {"testo":"Quale proprietà aggiunge spazio all'interno del bordo di un elemento?","livello":"L1","argomento":"css","fonte":"css","spiegazione":"padding è lo spazio interno; margin è esterno e gap vale per flex/grid.","opzioni":["padding","margin","gap","border"],"corretta":0},
      {"testo":"Quale istruzione legge dati da una tabella senza modificarli?","livello":"L1","argomento":"mysql","fonte":"mysql","spiegazione":"SELECT legge, INSERT aggiunge, UPDATE modifica e DELETE rimuove.","opzioni":["SELECT","UPDATE","INSERT","DELETE"],"corretta":0},
      {"testo":"Quale dichiarazione crea una variabile che non può essere riassegnata?","livello":"L1","argomento":"javascript","fonte":"javascript","spiegazione":"const blocca la riassegnazione del binding, non la mutazione di oggetti e array.","opzioni":["const","let","var","static"],"corretta":0},

      {"testo":"Che differenza c'è tra == e === in JavaScript?","livello":"L2","argomento":"javascript","fonte":"javascript","spiegazione":"=== confronta valore e tipo senza conversioni; == applica il coercion e produce risultati sorprendenti.","opzioni":["=== confronta anche il tipo, == converte","Sono identici","== è più sicuro","=== vale solo per i numeri"],"corretta":0},
      {"testo":"Quando React esegue la funzione di cleanup restituita da useEffect?","livello":"L2","argomento":"react","fonte":"react","spiegazione":"Il cleanup gira quando il componente viene smontato o prima dell'esecuzione dell'effetto successivo.","opzioni":["Alla rimozione del componente o prima dell'effetto successivo","A ogni render, prima del render","Solo al refresh del browser","Mai"],"corretta":0},

      {"testo":"Perché per un layout a griglia bidimensionale si preferisce CSS Grid a Flexbox?","livello":"L3","argomento":"css","fonte":"css","spiegazione":"Grid controlla righe e colonne insieme; Flexbox distribuisce lungo un solo asse.","opzioni":["Grid gestisce righe e colonne insieme, Flexbox una sola direzione","Grid è più veloce in runtime","Flexbox non supporta il responsive","Grid elimina i media query"],"corretta":0},
      {"testo":"Cosa accade a una Promise rifiutata senza catch o senza await in un try?","livello":"L3","argomento":"javascript","fonte":"javascript","spiegazione":"Diventa un unhandled rejection: in Node può terminare il processo e nei browser finisce in console.","opzioni":["Genera un unhandled rejection e può terminare il processo Node","Il rifiuto viene ignorato in silenzio","Viene convertita automaticamente in resolve","Blocca il thread principale"],"corretta":0},
      {"testo":"Perché un calcolo CPU-bound lungo blocca tutto il server Node?","livello":"L3","argomento":"nodejs","fonte":"nodejs","spiegazione":"L'event loop gira su un solo thread: durante il calcolo nessuna richiesta viene servita. Va spostato in un worker.","opzioni":["L'event loop gira su un solo thread e nessuna richiesta viene servita","Node usa un thread per ogni richiesta","Il garbage collector sospende il processo","Le Promise non supportano il calcolo"],"corretta":0},
      {"testo":"Perché un indice su una colonna con pochi valori distinti è spesso poco utile?","livello":"L3","argomento":"mysql","fonte":"mysql","spiegazione":"Con bassa cardinalità il planner legge comunque gran parte della tabella e preferisce la scansione sequenziale.","opzioni":["Il planner legge gran parte della tabella e preferisce la scansione sequenziale","MySQL rifiuta gli indici booleani","L'indice diventa corrotto","Rallenta solo le letture"],"corretta":0},
      {"testo":"Cosa indica un deadlock in InnoDB?","livello":"L3","argomento":"mysql","fonte":"mysql","spiegazione":"Due transazioni si attendono a vicenda: InnoDB rileva il ciclo e annulla una delle due.","opzioni":["Due transazioni si attendono a vicenda e una viene annullata","Una query è troppo lenta","Manca un indice primario","Il database è in sola lettura"],"corretta":0},
      {"testo":"Perché non si deve mutare direttamente lo stato di React?","livello":"L3","argomento":"react","fonte":"react","spiegazione":"React confronta i riferimenti: senza un nuovo oggetto non rileva il cambiamento e non ri-renderizza.","opzioni":["React confronta i riferimenti e non ri-renderizza senza un nuovo oggetto","React blocca le mutazioni con un errore","Lo stato è in sola lettura sul server","Le mutazioni rompono il CSS"],"corretta":0},
      {"testo":"Perché validare l'input anche se il frontend lo valida già?","livello":"L3","argomento":"express","fonte":"express","spiegazione":"Il client è sotto il controllo dell'utente: chiunque può inviare richieste dirette all'API.","opzioni":["Il client è sotto il controllo dell'utente e può essere aggirato","Il frontend non può usare JavaScript","Express non riceve il body senza validazione","La validazione client è più lenta"],"corretta":0},
      {"testo":"Cosa garantisce una transazione interattiva in Prisma?","livello":"L3","argomento":"prisma","fonte":"prisma","spiegazione":"Le operazioni vengono confermate o annullate insieme: nessuno stato intermedio resta visibile.","opzioni":["Che più operazioni vengano confermate o annullate insieme","Che le query siano più veloci","Che lo schema sia aggiornato","Che il database non vada in deadlock"],"corretta":0},
      {"testo":"Perché i documenti si spezzano in chunk prima del retrieval?","livello":"L3","argomento":"langchain","fonte":"langchain","spiegazione":"I chunk rispettano il limite di contesto e rendono il recupero più preciso, citando solo i passaggi utili.","opzioni":["Rispettare il limite di contesto e rendere il recupero più preciso","Ridurre i costi del database","Evitare CORS","Convertire il testo in JSON"],"corretta":0},

      {"testo":"Un agente genera ed esegue SQL: qual è la mitigazione corretta?","livello":"L4","argomento":"agenti-ai","fonte":"agenti-ai","spiegazione":"Query parametrizzate e un ruolo in sola lettura limitano l'impatto di un prompt manipolato.","opzioni":["Query parametrizzate ed esecuzione con un ruolo in sola lettura","Aumentare il timeout della query","Salvare la password nel prompt","Disattivare i log"],"corretta":0},
      {"testo":"Perché un agente deve avere un limite massimo di passi?","livello":"L4","argomento":"agenti-ai","fonte":"agenti-ai","spiegazione":"Senza limite il loop può non terminare, consumare token e ripetere azioni con effetti collaterali.","opzioni":["Evitare loop infiniti e costi fuori controllo","Migliorare il rendering del markdown","Ridurre la dimensione del database","Evitare la compressione gzip"],"corretta":0},
      {"testo":"Perché restituire 200 con lista vuota quando manca il permesso è peggio di 403?","livello":"L4","argomento":"express","fonte":"express","spiegazione":"Maschera un errore di autorizzazione: chi consuma l'API non distingue assenza di dati da divieto.","opzioni":["Nasconde un errore di autorizzazione e rende il debug ambiguo","Perché 200 è riservato alle GET","Perché 403 non è valido in JSON","Perché il browser blocca le liste vuote"],"corretta":0},
      {"testo":"Perché evitare una transazione lunga che attende chiamate esterne?","livello":"L4","argomento":"prisma","fonte":"prisma","spiegazione":"Locks e connessioni restano occupati fino al timeout e bloccano gli altri utenti: meglio commit brevi e idempotenza.","opzioni":["Mantiene lock e connessioni occupati fino al timeout degli altri utenti","Prisma cancella i dati non confermati","Il database chiude la connessione TCP","Le transazioni non supportano await"],"corretta":0},
      {"testo":"Perché il prompt injection è un problema di autorizzazione, non solo di prompt?","livello":"L4","argomento":"agenti-ai","fonte":"agenti-ai","spiegazione":"Il modello può invocare tool con i privilegi dell'app: i controlli di accesso vanno rifatti lato server.","opzioni":["Il modello può invocare tool con i privilegi dell'applicazione: i controlli vanno rifatti lato server","Perché il prompt è troppo lungo","Perché i modelli non leggono gli URL","Perché la temperatura è troppo alta"],"corretta":0}
    ]$json$::jsonb) as x(
      testo text,
      livello public.livello_domanda,
      argomento text,
      fonte text,
      spiegazione text,
      opzioni jsonb,
      corretta integer
    )
  loop
    select id into v_domanda from public.domanda where testo = r.testo limit 1;

    if v_domanda is null then
      if (v_argomenti ->> r.argomento) is null then
        raise exception 'Argomento non trovato per: %', r.testo;
      end if;

      insert into public.domanda (
        argomento_id, livello, testo, spiegazione, stato, origine,
        fonte_id, creata_da, approvata_da, approvata_il
      ) values (
        (v_argomenti ->> r.argomento)::uuid,
        r.livello,
        r.testo,
        r.spiegazione,
        'APPROVATA',
        'UMANO',
        (v_fonti ->> coalesce(r.fonte, r.argomento))::uuid,
        v_approvatore,
        v_approvatore,
        now()
      )
      returning id into v_domanda;

      for j in 0..3 loop
        insert into public.opzione (domanda_id, testo, corretta, ordine)
        values (v_domanda, r.opzioni ->> j, j = r.corretta, j + 1);
      end loop;
    end if;

    v_domande := v_domande || jsonb_build_object(r.testo, v_domanda);
  end loop;

  -- Verifica della composizione per livello.
  select
    count(*) filter (where d.livello = 'L1'),
    count(*) filter (where d.livello = 'L2'),
    count(*) filter (where d.livello = 'L3'),
    count(*) filter (where d.livello = 'L4')
  into c1, c2, c3, c4
  from public.domanda d
  where d.id in (select (x.value)::uuid from jsonb_each_text(v_domande) as x);

  if c1 <> 6 or c2 <> 6 or c3 <> 12 or c4 <> 6 then
    raise exception 'Composizione inattesa: L1=%, L2=%, L3=%, L4=% (attesi 6, 6, 12, 6)', c1, c2, c3, c4;
  end if;

  -- -------------------------------------------------------------------
  -- 2. Tre schede complete per utente
  -- -------------------------------------------------------------------
  for v_utente in select id from public.utente loop
    select id into v_s1
    from public.scheda
    where utente_id = v_utente and corso_id = v_corso and versione = 1;

    if v_s1 is null then
      raise notice 'Utente % senza scheda: applica 0002_seed.sql', v_utente;
      continue;
    end if;

    update public.scheda set titolo = v_titoli[1] where id = v_s1;

    v_schede := array[v_s1, null, null]::uuid[];

    for k in 2..3 loop
      select id into v_nuova
      from public.scheda
      where utente_id = v_utente and corso_id = v_corso and versione = k;
      v_schede[k] := v_nuova;

      if v_schede[k] is null then
        insert into public.scheda (
          utente_id, corso_id, classe_id, titolo, versione, stato,
          data_esame, giorni_all_esame, tempo_stimato_min, obiettivo,
          generata_da, pubblicata_il
        )
        select
          s.utente_id, s.corso_id, s.classe_id, v_titoli[k], k, 'PUBBLICATA',
          s.data_esame, s.giorni_all_esame, s.tempo_stimato_min, s.obiettivo,
          s.generata_da, now()
        from public.scheda s
        where s.id = v_s1
        returning id into v_nuova;
        v_schede[k] := v_nuova;

        insert into public.scheda_argomento (
          scheda_id, argomento_id, mastery_snapshot, ultimo_ripasso_snapshot,
          tentativi_snapshot, priorita, ruolo, evidenza, motivazione_lacuna, azione, ordine
        )
        select
          v_schede[k], argomento_id, mastery_snapshot, ultimo_ripasso_snapshot,
          tentativi_snapshot, priorita, ruolo, evidenza, motivazione_lacuna, azione, ordine
        from public.scheda_argomento
        where scheda_id = v_s1;

        insert into public.scheda_concetto (scheda_id, argomento_id, fonte_id, titolo, spiegazione, ordine)
        select v_schede[k], argomento_id, fonte_id, titolo, spiegazione, ordine
        from public.scheda_concetto
        where scheda_id = v_s1;

        insert into public.scheda_fonte (scheda_id, fonte_id, ordine)
        select v_schede[k], fonte_id, ordine
        from public.scheda_fonte
        where scheda_id = v_s1;

        insert into public.scheda_piano (scheda_id, giorno, durata_min, attivita, output_atteso)
        select v_schede[k], giorno, durata_min, attivita, output_atteso
        from public.scheda_piano
        where scheda_id = v_s1;

        insert into public.scheda_autovalutazione (scheda_id, testo, categoria, ordine)
        select v_schede[k], testo, categoria, ordine
        from public.scheda_autovalutazione
        where scheda_id = v_s1;

        insert into public.scheda_flashcard (scheda_id, flashcard_id, ordine)
        select v_schede[k], flashcard_id, ordine
        from public.scheda_flashcard
        where scheda_id = v_s1;
      end if;
    end loop;

    -- 10 domande per scheda: 4 L1-L2, 4 L3, 2 L4, senza sovrapposizioni.
    for k in 1..3 loop
      delete from public.scheda_domanda where scheda_id = v_schede[k];

      insert into public.scheda_domanda (scheda_id, domanda_id, ordine)
      select
        v_schede[k],
        q.id,
        row_number() over (order by q.livello, q.testo)::smallint
      from (
        select
          d.id,
          d.testo,
          d.livello,
          row_number() over (partition by d.livello order by d.testo) as rn,
          count(*) over (partition by d.livello) as tot
        from public.domanda d
        where d.stato = 'APPROVATA'
          and d.id in (select (x.value)::uuid from jsonb_each_text(v_domande) as x)
      ) q
      where ceil(q.rn / (q.tot / 3.0)) = k;
    end loop;
  end loop;
end;
$$;
