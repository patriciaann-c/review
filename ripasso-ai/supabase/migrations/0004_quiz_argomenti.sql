-- =====================================================================
-- RipassoAI — 0004: quiz per argomento
--   * importa_quiz(): helper di seed, non esposto al client
--   * invia_quiz_argomento(): corregge un tentativo su un singolo argomento
--     (tentativo con scheda_id null e origine DIAGNOSTICO)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Helper di import: inserisce domande+opzioni se il testo è nuovo.
--    SECURITY DEFINER e revocato: serve solo alle migrazioni.
-- ---------------------------------------------------------------------
create or replace function public.importa_quiz(p_slug text, p_domande jsonb)
returns integer
language plpgsql security definer set search_path = public
as $$
declare
  v_argomento uuid;
  v_nome      text;
  v_fonte     uuid;
  v_utente    uuid;
  v_domanda   uuid;
  v_inserite  integer := 0;
  r record;
  j integer;
begin
  select a.id, a.nome into v_argomento, v_nome
  from public.argomento a
  join public.modulo m on m.id = a.modulo_id
  where a.slug = p_slug
  limit 1;

  if v_argomento is null then
    raise exception 'Argomento inesistente: %', p_slug;
  end if;

  select f.id into v_fonte from public.fonte f where f.titolo like '% ' || v_nome limit 1;
  select id into v_utente from public.utente order by creato_il limit 1;

  if v_utente is null then
    raise exception 'Nessun utente: registrati nell''app e riapplica 0002_seed.sql';
  end if;

  for r in
    select * from jsonb_to_recordset(p_domande) as x(
      livello public.livello_domanda,
      testo text,
      spiegazione text,
      opzioni jsonb,
      corretta integer
    )
  loop
    select id into v_domanda from public.domanda where testo = r.testo limit 1;

    if v_domanda is null then
      insert into public.domanda (
        argomento_id, livello, testo, spiegazione, stato, origine,
        fonte_id, creata_da, approvata_da, approvata_il
      ) values (
        v_argomento, r.livello, r.testo, r.spiegazione, 'APPROVATA', 'UMANO',
        v_fonte, v_utente, v_utente, now()
      )
      returning id into v_domanda;

      for j in 0..3 loop
        insert into public.opzione (domanda_id, testo, corretta, ordine)
        values (v_domanda, r.opzioni ->> j, j = r.corretta, j + 1);
      end loop;

      v_inserite := v_inserite + 1;
    end if;
  end loop;

  return v_inserite;
end;
$$;

revoke all on function public.importa_quiz(text, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. Correzione di un quiz per argomento
-- ---------------------------------------------------------------------
create or replace function public.invia_quiz_argomento(p_argomento_id uuid, p_risposte jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_utente    uuid := auth.uid();
  v_tentativo uuid;
  v_totale    integer;
  v_corrette  integer := 0;
  v_punteggio numeric(5, 2);
  v_dettagli  jsonb := '[]'::jsonb;
  r record;
  v_corretta  boolean;
begin
  if v_utente is null then
    raise exception 'Utente non autenticato';
  end if;

  if not exists (select 1 from public.argomento a where a.id = p_argomento_id) then
    raise exception 'Argomento non trovato';
  end if;

  select count(*) into v_totale
  from public.domanda
  where argomento_id = p_argomento_id and stato = 'APPROVATA';

  insert into public.tentativo (utente_id, scheda_id, origine, stato, risposte_totali)
  values (v_utente, null, 'DIAGNOSTICO', 'IN_CORSO', v_totale)
  returning id into v_tentativo;

  for r in
    select
      (x ->> 'domanda_id')::uuid as domanda_id,
      nullif(x ->> 'opzione_id', '')::uuid as opzione_id,
      nullif(x ->> 'tempo_ms', '')::integer as tempo_ms
    from jsonb_array_elements(p_risposte) x
  loop
    -- Ignora domande di altri argomenti o non approvate.
    if not exists (
      select 1 from public.domanda d
      where d.id = r.domanda_id
        and d.argomento_id = p_argomento_id
        and d.stato = 'APPROVATA'
    ) then
      continue;
    end if;

    select o.corretta into v_corretta
    from public.opzione o
    where o.id = r.opzione_id and o.domanda_id = r.domanda_id;
    v_corretta := coalesce(v_corretta, false);

    insert into public.risposta (tentativo_id, domanda_id, opzione_id, corretta, tempo_ms)
    values (v_tentativo, r.domanda_id, r.opzione_id, v_corretta, r.tempo_ms)
    on conflict (tentativo_id, domanda_id) do nothing;

    if v_corretta then
      v_corrette := v_corrette + 1;
    end if;

    v_dettagli := v_dettagli || jsonb_build_object(
      'domanda_id', r.domanda_id,
      'corretta', v_corretta,
      'opzione_corretta_id', (
        select o.id from public.opzione o
        where o.domanda_id = r.domanda_id and o.corretta
        limit 1
      ),
      'spiegazione', (
        select d.spiegazione from public.domanda d where d.id = r.domanda_id
      )
    );

    insert into public.utente_argomento (
      utente_id, argomento_id, mastery, tentativi_totali, ultimo_ripasso_il, aggiornato_il
    )
    select
      v_utente,
      d.argomento_id,
      case when v_corretta then 0.3 else 0 end,
      1,
      now(),
      now()
    from public.domanda d
    where d.id = r.domanda_id
    on conflict (utente_id, argomento_id) do update
      set mastery = round(
            (public.utente_argomento.mastery * 0.7)
            + (case when v_corretta then 0.3 else 0 end),
            4
          ),
          tentativi_totali = public.utente_argomento.tentativi_totali + 1,
          ultimo_ripasso_il = now(),
          aggiornato_il = now();
  end loop;

  v_punteggio := round((v_corrette::numeric / greatest(v_totale, 1)) * 100, 2);

  update public.tentativo
     set stato = 'COMPLETATO',
         finito_il = now(),
         risposte_corrette = v_corrette,
         punteggio = v_punteggio
   where id = v_tentativo;

  return jsonb_build_object(
    'tentativo_id', v_tentativo,
    'punteggio', v_punteggio,
    'corrette', v_corrette,
    'totali', v_totale,
    'dettagli', v_dettagli
  );
end;
$$;

revoke all on function public.invia_quiz_argomento(uuid, jsonb) from public, anon;
grant execute on function public.invia_quiz_argomento(uuid, jsonb) to authenticated;
