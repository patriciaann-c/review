-- =====================================================================
-- RipassoAI — schema Postgres per Supabase
-- Derivato da docs/schema-schede.sql (MySQL 8) con:
--   * UUID al posto di BIGINT AUTO_INCREMENT
--   * enum Postgres, jsonb, timestamptz
--   * RLS su tutte le tabelle
--   * RPC per quiz e ripasso flashcard
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. Enumerazioni
-- ---------------------------------------------------------------------
create type public.ruolo_utente as enum ('STUDENTE', 'DOCENTE', 'ADMIN');
create type public.stato_scheda as enum ('BOZZA', 'GENERATA', 'PUBBLICATA', 'ARCHIVIATA');
create type public.generata_da as enum ('AI', 'UMANO', 'MISTA');
create type public.priorita as enum ('CRITICA', 'ALTA', 'MEDIA', 'BASSA');
create type public.ruolo_argomento as enum ('STANDARD', 'FORZA', 'LACUNA');
create type public.tipo_fonte as enum ('MODULO', 'APPUNTI', 'DOCUMENTAZIONE', 'PROGETTO', 'ALTRO');
create type public.livello_domanda as enum ('L1', 'L2', 'L3', 'L4');
create type public.stato_domanda as enum ('BOZZA', 'APPROVATA', 'RIFIUTATA', 'ARCHIVIATA');
create type public.origine_contenuto as enum ('AI', 'UMANO', 'MISTA');
create type public.stato_tentativo as enum ('IN_CORSO', 'COMPLETATO', 'ABBANDONATO');
create type public.origine_tentativo as enum ('SCHEDA', 'DIAGNOSTICO', 'ADATTIVO', 'ASSEGNAZIONE');
create type public.stato_flashcard as enum ('ATTIVA', 'SOSPESA', 'ARCHIVIATA');
create type public.categoria_autovalutazione as enum ('SAPER_SPIEGARE', 'SAPER_FARE', 'DA_RIVEDERE');

-- ---------------------------------------------------------------------
-- 2. Tenant e identità
-- ---------------------------------------------------------------------
create table public.scuola (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null,
  slug       text not null unique,
  creato_il  timestamptz not null default now()
);

-- Profilo applicativo collegato a auth.users (la password resta in Supabase Auth).
create table public.utente (
  id               uuid primary key references auth.users (id) on delete cascade,
  scuola_id        uuid not null references public.scuola (id) on delete restrict,
  email            text not null unique,
  nome             text not null,
  ruolo            public.ruolo_utente not null default 'STUDENTE',
  email_verificata boolean not null default false,
  creato_il        timestamptz not null default now()
);
create index ix_utente_scuola_ruolo on public.utente (scuola_id, ruolo);

create table public.corso (
  id          uuid primary key default gen_random_uuid(),
  scuola_id   uuid not null references public.scuola (id) on delete restrict,
  titolo      text not null,
  codice      text not null,
  descrizione text,
  attivo      boolean not null default true,
  creato_il   timestamptz not null default now(),
  unique (scuola_id, codice)
);
create index ix_corso_scuola_attivo on public.corso (scuola_id, attivo);

create table public.iscrizione_corso (
  id            uuid primary key default gen_random_uuid(),
  corso_id      uuid not null references public.corso (id) on delete cascade,
  utente_id     uuid not null references public.utente (id) on delete cascade,
  iscritto_il   timestamptz not null default now(),
  completato_il date,
  unique (corso_id, utente_id)
);
create index ix_iscrizione_corso_utente on public.iscrizione_corso (utente_id);

create table public.classe (
  id            uuid primary key default gen_random_uuid(),
  scuola_id     uuid not null references public.scuola (id) on delete restrict,
  corso_id      uuid not null references public.corso (id) on delete restrict,
  nome          text not null,
  codice_invito text not null unique,
  -- Nullable nel MVP: la classe demo non ha ancora un docente registrato.
  docente_id    uuid references public.utente (id) on delete restrict,
  creato_il     timestamptz not null default now()
);
create index ix_classe_corso_docente on public.classe (corso_id, docente_id);
create index ix_classe_scuola on public.classe (scuola_id);

create table public.iscrizione_classe (
  id        uuid primary key default gen_random_uuid(),
  classe_id uuid not null references public.classe (id) on delete cascade,
  utente_id uuid not null references public.utente (id) on delete cascade,
  creato_il timestamptz not null default now(),
  unique (classe_id, utente_id)
);
create index ix_iscrizione_classe_utente on public.iscrizione_classe (utente_id);

-- ---------------------------------------------------------------------
-- 3. Catalogo didattico
-- ---------------------------------------------------------------------
create table public.modulo (
  id       uuid primary key default gen_random_uuid(),
  corso_id uuid not null references public.corso (id) on delete cascade,
  numero   smallint not null check (numero > 0),
  titolo   text not null,
  unique (corso_id, numero)
);

create table public.argomento (
  id          uuid primary key default gen_random_uuid(),
  modulo_id   uuid not null references public.modulo (id) on delete cascade,
  nome        text not null,
  slug        text not null,
  descrizione text,
  unique (modulo_id, slug)
);

create table public.utente_argomento (
  utente_id         uuid not null references public.utente (id) on delete cascade,
  argomento_id      uuid not null references public.argomento (id) on delete restrict,
  mastery           numeric(5, 4) not null default 0 check (mastery between 0 and 1),
  tentativi_totali  integer not null default 0,
  ultimo_ripasso_il timestamptz,
  aggiornato_il     timestamptz not null default now(),
  primary key (utente_id, argomento_id)
);
create index ix_utente_argomento_argomento on public.utente_argomento (argomento_id);

create table public.fonte (
  id          uuid primary key default gen_random_uuid(),
  corso_id    uuid references public.corso (id) on delete set null,
  tipo        public.tipo_fonte not null default 'ALTRO',
  titolo      text not null,
  riferimento text,
  creato_il   timestamptz not null default now()
);
create index ix_fonte_corso_tipo on public.fonte (corso_id, tipo);

-- ---------------------------------------------------------------------
-- 4. Scheda e sezioni
-- ---------------------------------------------------------------------
create table public.scheda (
  id                uuid primary key default gen_random_uuid(),
  utente_id         uuid not null references public.utente (id) on delete cascade,
  corso_id          uuid not null references public.corso (id) on delete restrict,
  classe_id         uuid references public.classe (id) on delete set null,
  titolo            text not null,
  versione          smallint not null default 1,
  stato             public.stato_scheda not null default 'BOZZA',
  data_esame        date,
  giorni_all_esame  smallint check (giorni_all_esame is null or giorni_all_esame >= 0),
  tempo_stimato_min smallint,
  obiettivo         text,
  generata_da       public.generata_da not null default 'MISTA',
  modello_ai        text,
  snapshot_json     jsonb,
  creata_il         timestamptz not null default now(),
  pubblicata_il     timestamptz,
  aggiornata_il     timestamptz not null default now(),
  unique (utente_id, corso_id, versione),
  check (stato <> 'PUBBLICATA' or pubblicata_il is not null)
);
create index ix_scheda_utente_data on public.scheda (utente_id, creata_il desc);
create index ix_scheda_utente_stato on public.scheda (utente_id, stato);
create index ix_scheda_corso_stato on public.scheda (corso_id, stato);

create table public.scheda_argomento (
  id                      uuid primary key default gen_random_uuid(),
  scheda_id               uuid not null references public.scheda (id) on delete cascade,
  argomento_id            uuid not null references public.argomento (id) on delete restrict,
  mastery_snapshot        numeric(5, 4) not null check (mastery_snapshot between 0 and 1),
  ultimo_ripasso_snapshot timestamptz,
  tentativi_snapshot      integer not null default 0,
  priorita                public.priorita not null,
  ruolo                   public.ruolo_argomento not null default 'STANDARD',
  evidenza                text,
  motivazione_lacuna      text,
  azione                  text,
  ordine                  smallint not null,
  unique (scheda_id, argomento_id),
  unique (scheda_id, ordine),
  check (ruolo <> 'FORZA' or evidenza is not null),
  check (ruolo <> 'LACUNA' or motivazione_lacuna is not null)
);
create index ix_scheda_argomento_argomento on public.scheda_argomento (argomento_id);

create table public.scheda_fonte (
  scheda_id uuid not null references public.scheda (id) on delete cascade,
  fonte_id  uuid not null references public.fonte (id) on delete restrict,
  ordine    smallint not null,
  primary key (scheda_id, fonte_id),
  unique (scheda_id, ordine)
);

create table public.scheda_concetto (
  id           uuid primary key default gen_random_uuid(),
  scheda_id    uuid not null references public.scheda (id) on delete cascade,
  argomento_id uuid references public.argomento (id) on delete set null,
  fonte_id     uuid not null references public.fonte (id) on delete restrict,
  titolo       text not null,
  spiegazione  text not null,
  ordine       smallint not null check (ordine between 1 and 7),
  unique (scheda_id, ordine)
);
create index ix_scheda_concetto_argomento on public.scheda_concetto (argomento_id);
create index ix_scheda_concetto_fonte on public.scheda_concetto (fonte_id);

create table public.scheda_piano (
  id            uuid primary key default gen_random_uuid(),
  scheda_id     uuid not null references public.scheda (id) on delete cascade,
  giorno        smallint not null check (giorno between 1 and 7),
  durata_min    smallint not null,
  attivita      text not null,
  output_atteso text,
  completato_il timestamptz,
  unique (scheda_id, giorno)
);

create table public.scheda_autovalutazione (
  id          uuid primary key default gen_random_uuid(),
  scheda_id   uuid not null references public.scheda (id) on delete cascade,
  testo       text not null,
  categoria   public.categoria_autovalutazione not null,
  ordine      smallint not null,
  spuntata_il timestamptz,
  unique (scheda_id, ordine)
);

-- ---------------------------------------------------------------------
-- 5. Quiz
-- ---------------------------------------------------------------------
create table public.domanda (
  id           uuid primary key default gen_random_uuid(),
  argomento_id uuid not null references public.argomento (id) on delete restrict,
  livello      public.livello_domanda not null,
  testo        text not null,
  spiegazione  text not null,
  stato        public.stato_domanda not null default 'BOZZA',
  origine      public.origine_contenuto not null default 'UMANO',
  fonte_id     uuid references public.fonte (id) on delete set null,
  creata_da    uuid references public.utente (id) on delete set null,
  approvata_da uuid references public.utente (id) on delete set null,
  approvata_il timestamptz,
  creata_il    timestamptz not null default now(),
  check (stato <> 'APPROVATA' or (approvata_da is not null and approvata_il is not null))
);
create index ix_domanda_selezione on public.domanda (argomento_id, livello, stato);
create index ix_domanda_fonte on public.domanda (fonte_id);

create table public.opzione (
  id         uuid primary key default gen_random_uuid(),
  domanda_id uuid not null references public.domanda (id) on delete cascade,
  testo      text not null,
  corretta   boolean not null default false,
  ordine     smallint not null check (ordine between 1 and 4),
  unique (domanda_id, ordine)
);

create table public.scheda_domanda (
  scheda_id  uuid not null references public.scheda (id) on delete cascade,
  domanda_id uuid not null references public.domanda (id) on delete restrict,
  ordine     smallint not null check (ordine between 1 and 10),
  primary key (scheda_id, domanda_id),
  unique (scheda_id, ordine)
);
create index ix_scheda_domanda_domanda on public.scheda_domanda (domanda_id);

create table public.tentativo (
  id                uuid primary key default gen_random_uuid(),
  utente_id         uuid references public.utente (id) on delete set null,
  scheda_id         uuid references public.scheda (id) on delete set null,
  origine           public.origine_tentativo not null default 'SCHEDA',
  stato             public.stato_tentativo not null default 'IN_CORSO',
  iniziato_il       timestamptz not null default now(),
  finito_il         timestamptz,
  risposte_totali   smallint not null default 0,
  risposte_corrette smallint not null default 0,
  punteggio         numeric(5, 2) check (punteggio is null or punteggio between 0 and 100),
  check (risposte_corrette <= risposte_totali),
  check (finito_il is null or finito_il >= iniziato_il)
);
create index ix_tentativo_utente_data on public.tentativo (utente_id, iniziato_il desc);
create index ix_tentativo_scheda on public.tentativo (scheda_id);
create index ix_tentativo_origine_stato on public.tentativo (origine, stato);

create table public.risposta (
  id           uuid primary key default gen_random_uuid(),
  tentativo_id uuid not null references public.tentativo (id) on delete cascade,
  domanda_id   uuid not null references public.domanda (id) on delete restrict,
  opzione_id   uuid references public.opzione (id) on delete set null,
  corretta     boolean not null default false,
  tempo_ms     integer,
  risposto_il  timestamptz not null default now(),
  unique (tentativo_id, domanda_id)
);
create index ix_risposta_domanda on public.risposta (domanda_id);
create index ix_risposta_opzione on public.risposta (opzione_id);

-- ---------------------------------------------------------------------
-- 6. Flashcard e ripetizione spaziata
-- ---------------------------------------------------------------------
create table public.flashcard (
  id                uuid primary key default gen_random_uuid(),
  utente_id         uuid not null references public.utente (id) on delete cascade,
  argomento_id      uuid not null references public.argomento (id) on delete restrict,
  fonte_id          uuid references public.fonte (id) on delete set null,
  fronte            text not null,
  retro             text not null,
  facilita          numeric(3, 2) not null default 2.50 check (facilita between 1.30 and 2.80),
  intervallo_giorni integer not null default 1 check (intervallo_giorni >= 1),
  ripasso_il        date not null,
  stato             public.stato_flashcard not null default 'ATTIVA',
  creata_il         timestamptz not null default now()
);
create index ix_flashcard_utente_ripasso on public.flashcard (utente_id, ripasso_il);
create index ix_flashcard_argomento on public.flashcard (argomento_id);
create index ix_flashcard_fonte on public.flashcard (fonte_id);

create table public.scheda_flashcard (
  scheda_id    uuid not null references public.scheda (id) on delete cascade,
  flashcard_id uuid not null references public.flashcard (id) on delete cascade,
  ordine       smallint not null check (ordine between 1 and 10),
  primary key (scheda_id, flashcard_id),
  unique (scheda_id, ordine)
);
create index ix_scheda_flashcard_flashcard on public.scheda_flashcard (flashcard_id);

create table public.flashcard_ripasso (
  id                    uuid primary key default gen_random_uuid(),
  flashcard_id          uuid not null references public.flashcard (id) on delete cascade,
  qualita               smallint not null check (qualita between 0 and 5),
  intervallo_precedente integer not null,
  intervallo_nuovo      integer not null,
  facilita_precedente   numeric(3, 2) not null check (facilita_precedente between 1.30 and 2.80),
  facilita_nuova        numeric(3, 2) not null check (facilita_nuova between 1.30 and 2.80),
  ripassata_il          timestamptz not null default now()
);
create index ix_flashcard_ripasso_carta_data on public.flashcard_ripasso (flashcard_id, ripassata_il desc);

-- ---------------------------------------------------------------------
-- 7. Funzioni di supporto per le policy (SECURITY DEFINER: no ricorsione)
-- ---------------------------------------------------------------------
create or replace function public.ha_ruolo(p_ruolo public.ruolo_utente)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.utente u
    where u.id = auth.uid() and u.ruolo = p_ruolo
  );
$$;

create or replace function public.docente_della_classe(p_classe_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.classe c
    where c.id = p_classe_id and c.docente_id = auth.uid()
  );
$$;

create or replace function public.e_proprietario_scheda(p_scheda_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.scheda s
    where s.id = p_scheda_id and s.utente_id = auth.uid()
  );
$$;

create or replace function public.puo_leggere_scheda(p_scheda_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.scheda s
    where s.id = p_scheda_id
      and (
        s.utente_id = auth.uid()
        or public.docente_della_classe(s.classe_id)
        or public.ha_ruolo('ADMIN')
      )
  );
$$;

-- ---------------------------------------------------------------------
-- 8. RLS
-- ---------------------------------------------------------------------
alter table public.scuola enable row level security;
alter table public.utente enable row level security;
alter table public.corso enable row level security;
alter table public.iscrizione_corso enable row level security;
alter table public.classe enable row level security;
alter table public.iscrizione_classe enable row level security;
alter table public.modulo enable row level security;
alter table public.argomento enable row level security;
alter table public.utente_argomento enable row level security;
alter table public.fonte enable row level security;
alter table public.scheda enable row level security;
alter table public.scheda_argomento enable row level security;
alter table public.scheda_fonte enable row level security;
alter table public.scheda_concetto enable row level security;
alter table public.scheda_piano enable row level security;
alter table public.scheda_autovalutazione enable row level security;
alter table public.domanda enable row level security;
alter table public.opzione enable row level security;
alter table public.scheda_domanda enable row level security;
alter table public.tentativo enable row level security;
alter table public.risposta enable row level security;
alter table public.flashcard enable row level security;
alter table public.scheda_flashcard enable row level security;
alter table public.flashcard_ripasso enable row level security;

-- Scuola: solo la propria.
create policy "scuola_lettura" on public.scuola for select to authenticated
using (id = (select u.scuola_id from public.utente u where u.id = auth.uid()));

-- Profilo: se stesso (o admin della scuola).
create policy "utente_lettura" on public.utente for select to authenticated
using (id = auth.uid() or public.ha_ruolo('ADMIN'));
create policy "utente_modifica" on public.utente for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

-- Catalogo: leggibile da ogni utente autenticato.
create policy "corso_lettura" on public.corso for select to authenticated using (true);
create policy "modulo_lettura" on public.modulo for select to authenticated using (true);
create policy "argomento_lettura" on public.argomento for select to authenticated using (true);
create policy "fonte_lettura" on public.fonte for select to authenticated using (true);
create policy "domanda_lettura" on public.domanda for select to authenticated using (true);
create policy "opzione_lettura" on public.opzione for select to authenticated using (true);

-- Iscrizioni.
create policy "iscrizione_corso_lettura" on public.iscrizione_corso for select to authenticated
using (utente_id = auth.uid() or public.ha_ruolo('ADMIN'));
create policy "iscrizione_classe_lettura" on public.iscrizione_classe for select to authenticated
using (utente_id = auth.uid() or public.ha_ruolo('ADMIN'));
create policy "classe_lettura" on public.classe for select to authenticated
using (
  docente_id = auth.uid()
  or public.ha_ruolo('ADMIN')
  or exists (
    select 1 from public.iscrizione_classe ic
    where ic.classe_id = id and ic.utente_id = auth.uid()
  )
);

-- Padronanza: solo la propria.
create policy "utente_argomento_lettura" on public.utente_argomento for select to authenticated
using (utente_id = auth.uid());

-- Scheda e figli.
create policy "scheda_lettura" on public.scheda for select to authenticated
using (public.puo_leggere_scheda(id));
create policy "scheda_inserimento" on public.scheda for insert to authenticated
with check (utente_id = auth.uid());
create policy "scheda_modifica" on public.scheda for update to authenticated
using (utente_id = auth.uid()) with check (utente_id = auth.uid());
create policy "scheda_cancellazione" on public.scheda for delete to authenticated
using (utente_id = auth.uid());

create policy "scheda_argomento_lettura" on public.scheda_argomento for select to authenticated
using (public.puo_leggere_scheda(scheda_id));
create policy "scheda_fonte_lettura" on public.scheda_fonte for select to authenticated
using (public.puo_leggere_scheda(scheda_id));
create policy "scheda_concetto_lettura" on public.scheda_concetto for select to authenticated
using (public.puo_leggere_scheda(scheda_id));
create policy "scheda_piano_lettura" on public.scheda_piano for select to authenticated
using (public.puo_leggere_scheda(scheda_id));
create policy "scheda_domanda_lettura" on public.scheda_domanda for select to authenticated
using (public.puo_leggere_scheda(scheda_id));
create policy "scheda_flashcard_lettura" on public.scheda_flashcard for select to authenticated
using (public.puo_leggere_scheda(scheda_id));

-- Autovalutazione: leggibile da chi vede la scheda, spuntabile solo dal proprietario.
create policy "autovalutazione_lettura" on public.scheda_autovalutazione for select to authenticated
using (public.puo_leggere_scheda(scheda_id));
create policy "autovalutazione_modifica" on public.scheda_autovalutazione for update to authenticated
using (public.e_proprietario_scheda(scheda_id))
with check (public.e_proprietario_scheda(scheda_id));

-- Tentativi e risposte: solo i propri.
create policy "tentativo_lettura" on public.tentativo for select to authenticated
using (utente_id = auth.uid() or public.ha_ruolo('ADMIN'));
create policy "tentativo_inserimento" on public.tentativo for insert to authenticated
with check (utente_id = auth.uid());
create policy "tentativo_modifica" on public.tentativo for update to authenticated
using (utente_id = auth.uid()) with check (utente_id = auth.uid());
create policy "risposta_lettura" on public.risposta for select to authenticated
using (
  exists (
    select 1 from public.tentativo t
    where t.id = tentativo_id and (t.utente_id = auth.uid() or public.ha_ruolo('ADMIN'))
  )
);
create policy "risposta_inserimento" on public.risposta for insert to authenticated
with check (
  exists (
    select 1 from public.tentativo t
    where t.id = tentativo_id and t.utente_id = auth.uid()
  )
);

-- Flashcard: solo le proprie.
create policy "flashcard_lettura" on public.flashcard for select to authenticated
using (utente_id = auth.uid());
create policy "flashcard_inserimento" on public.flashcard for insert to authenticated
with check (utente_id = auth.uid());
create policy "flashcard_modifica" on public.flashcard for update to authenticated
using (utente_id = auth.uid()) with check (utente_id = auth.uid());
create policy "flashcard_cancellazione" on public.flashcard for delete to authenticated
using (utente_id = auth.uid());
create policy "flashcard_ripasso_lettura" on public.flashcard_ripasso for select to authenticated
using (
  exists (
    select 1 from public.flashcard f
    where f.id = flashcard_id and f.utente_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------
-- 9. Trigger: crea il profilo quando nasce un utente Supabase Auth
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_scuola uuid;
begin
  select id into v_scuola from public.scuola order by creato_il limit 1;

  if v_scuola is null then
    insert into public.scuola (nome, slug)
    values ('RipassoAI Demo', 'demo')
    returning id into v_scuola;
  end if;

  insert into public.utente (id, scuola_id, email, nome, ruolo)
  values (
    new.id,
    v_scuola,
    new.email,
    coalesce(nullif(new.raw_user_meta_data ->> 'nome', ''), split_part(new.email, '@', 1)),
    'STUDENTE'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- 10. RPC: correzione del quiz
--     Il client non riceve mai "corretta" prima dell'invio.
-- ---------------------------------------------------------------------
create or replace function public.invia_tentativo(p_scheda_id uuid, p_risposte jsonb)
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

  if not exists (
    select 1 from public.scheda s
    where s.id = p_scheda_id and s.utente_id = v_utente
  ) then
    raise exception 'Scheda non trovata';
  end if;

  select count(*) into v_totale
  from public.scheda_domanda
  where scheda_id = p_scheda_id;

  insert into public.tentativo (utente_id, scheda_id, origine, stato, risposte_totali)
  values (v_utente, p_scheda_id, 'SCHEDA', 'IN_CORSO', v_totale)
  returning id into v_tentativo;

  for r in
    select
      (x ->> 'domanda_id')::uuid as domanda_id,
      nullif(x ->> 'opzione_id', '')::uuid as opzione_id,
      nullif(x ->> 'tempo_ms', '')::integer as tempo_ms
    from jsonb_array_elements(p_risposte) x
  loop
    -- Ignora domande che non appartengono alla scheda.
    if not exists (
      select 1 from public.scheda_domanda sd
      where sd.scheda_id = p_scheda_id and sd.domanda_id = r.domanda_id
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

    -- Aggiorna la padronanza con una media mobile (70% storico, 30% esito).
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

-- ---------------------------------------------------------------------
-- 11. RPC: ripasso flashcard (SM-2 semplificato)
-- ---------------------------------------------------------------------
create or replace function public.ripassa_flashcard(p_flashcard_id uuid, p_qualita integer)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_utente   uuid := auth.uid();
  f          record;
  v_intervallo integer;
  v_facilita numeric(3, 2);
begin
  if v_utente is null then
    raise exception 'Utente non autenticato';
  end if;
  if p_qualita < 0 or p_qualita > 5 then
    raise exception 'Qualità non valida';
  end if;

  select * into f
  from public.flashcard
  where id = p_flashcard_id and utente_id = v_utente;

  if not found then
    raise exception 'Flashcard non trovata';
  end if;

  if p_qualita < 3 then
    v_intervallo := 1;
    v_facilita := f.facilita;
  else
    v_intervallo := case
      when f.intervallo_giorni <= 1 then 6
      else round(f.intervallo_giorni * f.facilita)::integer
    end;

    v_facilita := f.facilita
      + (0.1 - (5 - p_qualita) * (0.08 + (5 - p_qualita) * 0.02));
    v_facilita := greatest(1.30, least(2.80, round(v_facilita, 2)));
  end if;

  insert into public.flashcard_ripasso (
    flashcard_id, qualita, intervallo_precedente, intervallo_nuovo,
    facilita_precedente, facilita_nuova
  ) values (
    p_flashcard_id, p_qualita, f.intervallo_giorni, v_intervallo,
    f.facilita, v_facilita
  );

  update public.flashcard
     set intervallo_giorni = v_intervallo,
         facilita = v_facilita,
         ripasso_il = current_date + v_intervallo
   where id = p_flashcard_id;

  return jsonb_build_object(
    'intervallo_giorni', v_intervallo,
    'facilita', v_facilita,
    'ripasso_il', current_date + v_intervallo
  );
end;
$$;

-- Solo gli utenti autenticati possono eseguire le RPC.
revoke all on function public.invia_tentativo(uuid, jsonb) from public, anon;
revoke all on function public.ripassa_flashcard(uuid, integer) from public, anon;
grant execute on function public.invia_tentativo(uuid, jsonb) to authenticated;
grant execute on function public.ripassa_flashcard(uuid, integer) to authenticated;
