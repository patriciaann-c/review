-- =====================================================================
-- RipassoAI — dati demo
-- Catalogo del corso + scheda di esempio (Giulia R., 5A).
-- Eseguire DOPO la registrazione del primo utente: la scheda viene
-- creata per ogni profilo presente in public.utente.
-- =====================================================================

do $$
declare
  v_scuola   uuid;
  v_corso    uuid;
  v_classe   uuid;
  v_utente   uuid;
  v_scheda   uuid;
  v_modulo   uuid;
  v_argomento uuid;
  v_fonte    uuid;
  v_domanda  uuid;
  v_flash    uuid;
  v_argomenti jsonb := '{}'::jsonb;
  v_fonti     jsonb := '{}'::jsonb;
  v_titoli    text[] := array[
    'HTML', 'CSS', 'JavaScript', 'React', 'Node.js',
    'MySQL', 'Express', 'Prisma', 'LangChain', 'Skill e agenti AI'
  ];
  v_slugs     text[] := array[
    'html', 'css', 'javascript', 'react', 'nodejs',
    'mysql', 'express', 'prisma', 'langchain', 'agenti-ai'
  ];
  i integer;
  j integer;
  r record;
begin
  -- -------------------------------------------------------------------
  -- Catalogo (idempotente)
  -- -------------------------------------------------------------------
  select id into v_scuola from public.scuola where slug = 'demo';
  if v_scuola is null then
    insert into public.scuola (nome, slug)
    values ('RipassoAI Demo', 'demo')
    returning id into v_scuola;
  end if;

  select id into v_corso
  from public.corso
  where scuola_id = v_scuola and codice = 'AIWEB';

  if v_corso is null then
    insert into public.corso (scuola_id, titolo, codice, descrizione, attivo)
    values (
      v_scuola,
      'AI Web Development',
      'AIWEB',
      'Corso completo di sviluppo web con AI: dal frontend al database, fino agli agenti.',
      true
    )
    returning id into v_corso;
  end if;

  for i in 1..10 loop
    insert into public.modulo (corso_id, numero, titolo)
    values (v_corso, i, v_titoli[i])
    on conflict (corso_id, numero) do update set titolo = excluded.titolo
    returning id into v_modulo;

    insert into public.argomento (modulo_id, nome, slug, descrizione)
    values (v_modulo, v_titoli[i], v_slugs[i], 'Argomento del modulo ' || i)
    on conflict (modulo_id, slug) do update set nome = excluded.nome
    returning id into v_argomento;

    v_argomenti := v_argomenti || jsonb_build_object(v_titoli[i], v_argomento);

    -- Una fonte per modulo.
    select id into v_fonte
    from public.fonte
    where corso_id = v_corso and titolo = 'Modulo ' || lpad(i::text, 2, '0') || ' — ' || v_titoli[i];

    if v_fonte is null then
      insert into public.fonte (corso_id, tipo, titolo, riferimento)
      values (
        v_corso,
        'MODULO',
        'Modulo ' || lpad(i::text, 2, '0') || ' — ' || v_titoli[i],
        'moduli/' || lpad(i::text, 2, '0') || '-' || v_slugs[i] || '.md'
      )
      returning id into v_fonte;
    end if;

    v_fonti := v_fonti || jsonb_build_object(v_titoli[i], v_fonte);
  end loop;

  -- Fonti trasversali.
  insert into public.fonte (corso_id, tipo, titolo, riferimento)
  select v_corso, 'APPUNTI', 'Appunti della professoressa', 'Appunti su Express e Prisma'
  where not exists (
    select 1 from public.fonte where corso_id = v_corso and titolo = 'Appunti della professoressa'
  );
  select id into v_fonte from public.fonte where corso_id = v_corso and titolo = 'Appunti della professoressa';
  v_fonti := v_fonti || jsonb_build_object('APPUNTI', v_fonte);

  insert into public.fonte (corso_id, tipo, titolo, riferimento)
  select v_corso, 'DOCUMENTAZIONE', 'Documentazione ufficiale', 'React, Prisma, LangChain, MySQL 8'
  where not exists (
    select 1 from public.fonte where corso_id = v_corso and titolo = 'Documentazione ufficiale'
  );
  select id into v_fonte from public.fonte where corso_id = v_corso and titolo = 'Documentazione ufficiale';
  v_fonti := v_fonti || jsonb_build_object('DOCUMENTAZIONE', v_fonte);

  insert into public.fonte (corso_id, tipo, titolo, riferimento)
  select v_corso, 'PROGETTO', 'Progetto finale', 'progetto-finale.md, sezione sicurezza'
  where not exists (
    select 1 from public.fonte where corso_id = v_corso and titolo = 'Progetto finale'
  );
  select id into v_fonte from public.fonte where corso_id = v_corso and titolo = 'Progetto finale';
  v_fonti := v_fonti || jsonb_build_object('PROGETTO', v_fonte);

  -- Classe 5A (senza docente nel MVP).
  select id into v_classe from public.classe where codice_invito = 'RIPASSO5A';
  if v_classe is null then
    insert into public.classe (scuola_id, corso_id, nome, codice_invito, docente_id)
    values (v_scuola, v_corso, '5A', 'RIPASSO5A', null)
    returning id into v_classe;
  end if;

  -- -------------------------------------------------------------------
  -- Scheda demo per ogni profilo registrato
  -- -------------------------------------------------------------------
  for v_utente in select id from public.utente loop
    select id into v_scheda
    from public.scheda
    where utente_id = v_utente and corso_id = v_corso and versione = 1;

    if v_scheda is not null then
      continue;
    end if;

    -- Iscrizioni.
    insert into public.iscrizione_corso (corso_id, utente_id)
    values (v_corso, v_utente)
    on conflict (corso_id, utente_id) do nothing;

    insert into public.iscrizione_classe (classe_id, utente_id)
    values (v_classe, v_utente)
    on conflict (classe_id, utente_id) do nothing;

    insert into public.scheda (
      utente_id, corso_id, classe_id, titolo, versione, stato,
      data_esame, giorni_all_esame, tempo_stimato_min, obiettivo,
      generata_da, pubblicata_il
    ) values (
      v_utente, v_corso, v_classe,
      'Scheda di ripasso — Esame finale', 1, 'PUBBLICATA',
      current_date + 14, 14, 25,
      'Non devo solo ricordare le definizioni: devo costruire una piccola web app completa (frontend, API, database, AI) e spiegare le scelte. Le parti da consolidare sono Express, Prisma e la sicurezza degli agenti.',
      'MISTA', now()
    )
    returning id into v_scheda;

    -- Mappa argomenti, punti di forza e lacune.
    for r in
      select * from jsonb_to_recordset($json_arg$[
        {"nome":"HTML","mastery":0.85,"giorni":3,"priorita":"BASSA","ruolo":"FORZA","evidenza":"Costruisco form e pagine navigabili da tastiera senza guardare esempi.","ordine":1},
        {"nome":"CSS","mastery":0.60,"giorni":12,"priorita":"MEDIA","ruolo":"STANDARD","ordine":2},
        {"nome":"JavaScript","mastery":0.70,"giorni":6,"priorita":"MEDIA","ruolo":"FORZA","evidenza":"Padroneggio array, DOM, fetch e gestione degli errori.","ordine":3},
        {"nome":"React","mastery":0.55,"giorni":9,"priorita":"ALTA","ruolo":"STANDARD","ordine":4},
        {"nome":"Node.js","mastery":0.50,"giorni":8,"priorita":"ALTA","ruolo":"STANDARD","ordine":5},
        {"nome":"MySQL","mastery":0.65,"giorni":5,"priorita":"MEDIA","ruolo":"FORZA","evidenza":"Scrivo join e aggregazioni e so leggere un piano EXPLAIN semplice.","ordine":6},
        {"nome":"Express","mastery":0.45,"giorni":14,"priorita":"ALTA","ruolo":"LACUNA","motivazione":"Senza permessi corretti la piattaforma è insicura.","azione":"Rileggere modulo 07, rifare esercizi 3.1–3.3, scrivere 5 test di accesso negato.","ordine":7},
        {"nome":"Prisma","mastery":0.40,"giorni":14,"priorita":"ALTA","ruolo":"LACUNA","motivazione":"È il ponte tra API e database: un errore qui rompe i dati.","azione":"Rifare schema e transazione di submit del modulo 08.","ordine":8},
        {"nome":"LangChain","mastery":0.35,"giorni":20,"priorita":"ALTA","ruolo":"STANDARD","ordine":9},
        {"nome":"Skill e agenti AI","mastery":0.30,"giorni":null,"priorita":"CRITICA","ruolo":"LACUNA","motivazione":"È la parte nuova dell'esame e la più rischiosa.","azione":"Skill quiz-generator + 5 test di prompt injection.","ordine":10}
      ]$json_arg$::jsonb) as x(
        nome text, mastery numeric, giorni integer,
        priorita public.priorita, ruolo public.ruolo_argomento,
        evidenza text, motivazione text, azione text, ordine integer
      )
    loop
      insert into public.scheda_argomento (
        scheda_id, argomento_id, mastery_snapshot, ultimo_ripasso_snapshot,
        tentativi_snapshot, priorita, ruolo, evidenza, motivazione_lacuna, azione, ordine
      ) values (
        v_scheda,
        (v_argomenti ->> r.nome)::uuid,
        r.mastery,
        case when r.giorni is null then null else now() - make_interval(days => r.giorni) end,
        4,
        r.priorita,
        r.ruolo,
        r.evidenza,
        r.motivazione,
        r.azione,
        r.ordine
      );
    end loop;

    -- Concetti chiave.
    for r in
      select * from jsonb_to_recordset($json_concetti$[
        {"titolo":"Semantica HTML","spiegazione":"L'elemento si sceglie per il significato: main è unico, article è autonomo, section raggruppa.","argomento":"HTML","fonte":"HTML","ordine":1},
        {"titolo":"Box model","spiegazione":"Con border-box la larghezza include contenuto, padding e bordo: evita overflow imprevisti.","argomento":"CSS","fonte":"CSS","ordine":2},
        {"titolo":"Stato derivato","spiegazione":"In React non si duplica ciò che si può calcolare da props e stato: si evitano desincronizzazioni.","argomento":"React","fonte":"React","ordine":3},
        {"titolo":"Event loop","spiegazione":"Node esegue JavaScript su un thread: un calcolo CPU-bound blocca le richieste e va spostato in un worker.","argomento":"Node.js","fonte":"Node.js","ordine":4},
        {"titolo":"Indice composito","spiegazione":"L'ordine delle colonne conta: l'indice va costruito sulle query reali e verificato con EXPLAIN.","argomento":"MySQL","fonte":"MySQL","ordine":5},
        {"titolo":"401 vs 403","spiegazione":"401 significa non autenticato, 403 significa autenticato senza permesso: la distinzione guida debug e sicurezza.","argomento":"Express","fonte":"Express","ordine":6},
        {"titolo":"RAG con citazioni","spiegazione":"Il modello risponde solo sul contesto recuperato e cita le fonti: se manca l'informazione, rifiuta.","argomento":"LangChain","fonte":"LangChain","ordine":7}
      ]$json_concetti$::jsonb) as x(
        titolo text, spiegazione text, argomento text, fonte text, ordine integer
      )
    loop
      insert into public.scheda_concetto (scheda_id, argomento_id, fonte_id, titolo, spiegazione, ordine)
      values (
        v_scheda,
        (v_argomenti ->> r.argomento)::uuid,
        (v_fonti ->> r.fonte)::uuid,
        r.titolo,
        r.spiegazione,
        r.ordine
      );
    end loop;

    -- Domande e opzioni.
    for r in
      select * from jsonb_to_recordset($json_quiz$[
        {"ordine":1,"livello":"L1","argomento":"HTML","fonte":"HTML","testo":"Quale elemento contiene il contenuto principale e unico della pagina?","spiegazione":"<main> racchiude il contenuto principale e va usato una sola volta per pagina.","opzioni":["<main>","<header>","<aside>","<footer>"],"corretta":0},
        {"ordine":2,"livello":"L1","argomento":"CSS","fonte":"CSS","testo":"Con box-sizing: border-box, width: 300px include padding e bordo?","spiegazione":"Sì: la larghezza dichiarata comprende contenuto, padding e bordo.","opzioni":["Sì, sempre","No, solo il contenuto","Solo il padding","Solo il bordo"],"corretta":0},
        {"ordine":3,"livello":"L2","argomento":"JavaScript","fonte":"JavaScript","testo":"Cosa restituisce [1, 2, 3].map(n => n * 2).filter(n => n > 2)?","spiegazione":"map produce [2, 4, 6], poi filter tiene solo i valori maggiori di 2: [4, 6].","opzioni":["[4, 6]","[2, 4, 6]","[1, 2, 3]","[]"],"corretta":0},
        {"ordine":4,"livello":"L2","argomento":"React","fonte":"React","testo":"Perché non usare l'indice come key di una lista riordinabile?","spiegazione":"Se la lista cambia ordine l'indice non identifica più lo stesso elemento: React riusa nodi sbagliati e si perdono stato e focus.","opzioni":["Perché se cambia l'ordine l'indice non identifica più l'elemento","Perché React accetta solo stringhe","Perché l'indice rallenta il CSS","Perché impedisce il rendering"],"corretta":0},
        {"ordine":5,"livello":"L2","argomento":"MySQL","fonte":"MySQL","testo":"Qual è la differenza tra WHERE e HAVING?","spiegazione":"WHERE filtra le righe prima dell'aggregazione; HAVING filtra i gruppi dopo.","opzioni":["WHERE filtra prima dell'aggregazione, HAVING dopo","WHERE filtra dopo, HAVING prima","Sono sinonimi","HAVING vale solo per MySQL 5"],"corretta":0},
        {"ordine":6,"livello":"L2","argomento":"Node.js","fonte":"Node.js","testo":"Dove va conservata una chiave API?","spiegazione":"In .env, escluso da Git; .env.example documenta le variabili senza segreti.","opzioni":["In .env, escluso da Git","Nel codice del componente","In localStorage","Nel README"],"corretta":0},
        {"ordine":7,"livello":"L3","argomento":"Express","fonte":"Express","testo":"Un utente autenticato prova a leggere il tentativo di un altro studente. Quale status è corretto?","spiegazione":"403: l'identità è valida ma il permesso manca. 401 sarebbe sbagliato perché l'utente è autenticato.","opzioni":["403","401","500","200"],"corretta":0},
        {"ordine":8,"livello":"L3","argomento":"Prisma","fonte":"Prisma","testo":"Cosa genera il problema N+1?","spiegazione":"Una query per il padre e una per ogni figlio. Si riduce con include/select mirati, join o batch.","opzioni":["Una query per il padre e una per ogni figlio","Una query unica con join","Un errore di migrazione","Un indice duplicato"],"corretta":0},
        {"ordine":9,"livello":"L3","argomento":"LangChain","fonte":"LangChain","testo":"Perché in un RAG si chiede al modello di citare le fonti?","spiegazione":"Rende la risposta verificabile e riduce le allucinazioni: l'utente può controllare il documento.","opzioni":["Per rendere la risposta verificabile e ridurre le allucinazioni","Per aumentare i token","Per nascondere il prompt","Per evitare il database"],"corretta":0},
        {"ordine":10,"livello":"L4","argomento":"Skill e agenti AI","fonte":"Skill e agenti AI","testo":"Un tool get_progressi riceve l'ID utente dal testo del modello. Perché è pericoloso?","spiegazione":"Il modello può essere manipolato e passare l'ID di un altro utente. L'ID va preso dalla sessione autenticata e filtrato per ownership.","opzioni":["Il modello può essere manipolato e passare l'ID di un altro utente","Perché il tool è troppo lento","Perché l'ID è un UUID","Perché Supabase non accetta ID"],"corretta":0}
      ]$json_quiz$::jsonb) as x(
        ordine integer, livello public.livello_domanda, argomento text, fonte text,
        testo text, spiegazione text, opzioni jsonb, corretta integer
      )
    loop
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
        (v_fonti ->> r.fonte)::uuid,
        v_utente,
        v_utente,
        now()
      )
      returning id into v_domanda;

      for j in 0..3 loop
        insert into public.opzione (domanda_id, testo, corretta, ordine)
        values (v_domanda, r.opzioni ->> j, j = r.corretta, j + 1);
      end loop;

      insert into public.scheda_domanda (scheda_id, domanda_id, ordine)
      values (v_scheda, v_domanda, r.ordine);
    end loop;

    -- Flashcard.
    for r in
      select * from jsonb_to_recordset($json_flash$[
        {"fronte":"main","retro":"Contenuto principale, unico per pagina","argomento":"HTML","fonte":"HTML","ordine":1},
        {"fronte":"border-box","retro":"Larghezza include contenuto, padding e bordo","argomento":"CSS","fonte":"CSS","ordine":2},
        {"fronte":"map vs filter","retro":"map trasforma, filter seleziona","argomento":"JavaScript","fonte":"JavaScript","ordine":3},
        {"fronte":"Perché key stabile","retro":"Identifica l'elemento tra i re-render","argomento":"React","fonte":"React","ordine":4},
        {"fronte":"WHERE vs HAVING","retro":"Prima vs dopo l'aggregazione","argomento":"MySQL","fonte":"MySQL","ordine":5},
        {"fronte":"Event loop bloccato","retro":"Calcolo CPU-bound sul thread JS","argomento":"Node.js","fonte":"Node.js","ordine":6},
        {"fronte":"401 vs 403","retro":"Non autenticato vs non autorizzato","argomento":"Express","fonte":"Express","ordine":7},
        {"fronte":"N+1","retro":"Una query per padre + una per figlio","argomento":"Prisma","fonte":"Prisma","ordine":8},
        {"fronte":"RAG","retro":"Recupero documenti + generazione con citazioni","argomento":"LangChain","fonte":"LangChain","ordine":9},
        {"fronte":"Tool e identità","retro":"L'ID utente arriva dalla sessione, non dal modello","argomento":"Skill e agenti AI","fonte":"Skill e agenti AI","ordine":10}
      ]$json_flash$::jsonb) as x(
        fronte text, retro text, argomento text, fonte text, ordine integer
      )
    loop
      insert into public.flashcard (
        utente_id, argomento_id, fonte_id, fronte, retro,
        facilita, intervallo_giorni, ripasso_il, stato
      ) values (
        v_utente,
        (v_argomenti ->> r.argomento)::uuid,
        (v_fonti ->> r.fonte)::uuid,
        r.fronte,
        r.retro,
        2.50,
        1,
        current_date,
        'ATTIVA'
      )
      returning id into v_flash;

      insert into public.scheda_flashcard (scheda_id, flashcard_id, ordine)
      values (v_scheda, v_flash, r.ordine);
    end loop;

    -- Piano 7 giorni.
    for r in
      select * from jsonb_to_recordset($json_piano$[
        {"giorno":1,"durata":30,"attivita":"Rileggi modulo 07 (auth, RBAC) e fai 3 test di accesso negato","output":"Test verdi"},
        {"giorno":2,"durata":30,"attivita":"Rifai lo schema Prisma e la transazione di submit","output":"Codice funzionante"},
        {"giorno":3,"durata":30,"attivita":"Esercizi React 3.1–3.3 (custom hook, context, form)","output":"1 componente testato"},
        {"giorno":4,"durata":30,"attivita":"Ingestion + RAG del modulo 09 su 2 documenti","output":"5 risposte con citazioni"},
        {"giorno":5,"durata":30,"attivita":"Skill quiz-generator + 5 attacchi di prompt injection","output":"Report red team"},
        {"giorno":6,"durata":30,"attivita":"Prova B completa senza appunti","output":"Punteggio e 3 lacune"},
        {"giorno":7,"durata":30,"attivita":"Spiega a voce 5 argomenti e registra 10 minuti","output":"Registrazione + autovalutazione"}
      ]$json_piano$::jsonb) as x(
        giorno integer, durata integer, attivita text, output text
      )
    loop
      insert into public.scheda_piano (scheda_id, giorno, durata_min, attivita, output_atteso)
      values (v_scheda, r.giorno, r.durata, r.attivita, r.output);
    end loop;

    -- Autovalutazione.
    for r in
      select * from jsonb_to_recordset($json_auto$[
        {"testo":"So spiegare la semantica HTML senza appunti.","categoria":"SAPER_SPIEGARE","ordine":1,"spuntata":true},
        {"testo":"So scrivere una query con join e gruppo.","categoria":"SAPER_FARE","ordine":2,"spuntata":true},
        {"testo":"So implementare auth e RBAC senza guardare il codice.","categoria":"SAPER_FARE","ordine":3,"spuntata":false},
        {"testo":"So progettare una pipeline RAG con citazioni.","categoria":"SAPER_SPIEGARE","ordine":4,"spuntata":false},
        {"testo":"So difendere un agente da prompt injection.","categoria":"SAPER_FARE","ordine":5,"spuntata":false},
        {"testo":"So motivare le mie scelte tecniche in 2 minuti.","categoria":"SAPER_SPIEGARE","ordine":6,"spuntata":false}
      ]$json_auto$::jsonb) as x(
        testo text, categoria public.categoria_autovalutazione, ordine integer, spuntata boolean
      )
    loop
      insert into public.scheda_autovalutazione (scheda_id, testo, categoria, ordine, spuntata_il)
      values (
        v_scheda, r.testo, r.categoria, r.ordine,
        case when r.spuntata then now() else null end
      );
    end loop;

    -- Fonti della scheda.
    for i in 1..10 loop
      insert into public.scheda_fonte (scheda_id, fonte_id, ordine)
      values (v_scheda, (v_fonti ->> v_titoli[i])::uuid, i);
    end loop;
    insert into public.scheda_fonte (scheda_id, fonte_id, ordine)
    values (v_scheda, (v_fonti ->> 'APPUNTI')::uuid, 11);
    insert into public.scheda_fonte (scheda_id, fonte_id, ordine)
    values (v_scheda, (v_fonti ->> 'DOCUMENTAZIONE')::uuid, 12);
    insert into public.scheda_fonte (scheda_id, fonte_id, ordine)
    values (v_scheda, (v_fonti ->> 'PROGETTO')::uuid, 13);
  end loop;

  if not exists (select 1 from public.utente) then
    raise notice 'Catalogo creato. Registra un utente dall''app e riesegui questo seed per creare la scheda demo.';
  end if;
end;
$$;
