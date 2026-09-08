-- BierKompas: profielfoto ondersteuning.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

alter table public.profiles add column if not exists avatar_url text;

-- Storage-bucket voor profielfoto's (publiek leesbaar, alleen eigenaar mag schrijven).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Avatars: public read" on storage.objects;
create policy "Avatars: public read" on storage.objects
    for select using (bucket_id = 'avatars');

drop policy if exists "Avatars: insert own" on storage.objects;
create policy "Avatars: insert own" on storage.objects
    for insert with check (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Avatars: update own" on storage.objects;
create policy "Avatars: update own" on storage.objects
    for update using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Avatars: delete own" on storage.objects;
create policy "Avatars: delete own" on storage.objects
    for delete using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
