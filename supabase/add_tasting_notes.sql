-- BierKompas: Proefnotities ("Mijn Proefnotities" op het profiel).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Kan veilig opnieuw worden uitgevoerd.
--
-- tasting_notes: eigen aantekeningen van een gebruiker bij een bier (naam komt
-- uit lib/features/favorites/beers.dart; beer_id is optioneel omdat gebruikers
-- ook een bier kunnen noteren dat niet in die vaste lijst staat).

create table if not exists public.tasting_notes (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    beer_id bigint,
    beer_name text not null,
    note text not null,
    rating smallint not null check (rating between 1 and 5),
    created_at timestamptz not null default now()
);

create index if not exists tasting_notes_user_id_created_at_idx
    on public.tasting_notes (user_id, created_at desc);

alter table public.tasting_notes enable row level security;

drop policy if exists "Tasting notes: select own" on public.tasting_notes;
create policy "Tasting notes: select own" on public.tasting_notes
    for select using (auth.uid() = user_id);

drop policy if exists "Tasting notes: insert own" on public.tasting_notes;
create policy "Tasting notes: insert own" on public.tasting_notes
    for insert with check (auth.uid() = user_id);

drop policy if exists "Tasting notes: update own" on public.tasting_notes;
create policy "Tasting notes: update own" on public.tasting_notes
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Tasting notes: delete own" on public.tasting_notes;
create policy "Tasting notes: delete own" on public.tasting_notes
    for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.tasting_notes to authenticated;
grant usage, select on sequence public.tasting_notes_id_seq to authenticated;

NOTIFY pgrst, 'reload schema';
