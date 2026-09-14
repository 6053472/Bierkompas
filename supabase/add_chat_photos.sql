-- Foto's versturen in de chat: nieuw message_type 'image' + een
-- Storage-bucket voor chatfoto's (zelfde opzet als de profielfoto's in
-- add_avatar.sql, maar dan per conversatie-map).

alter table public.messages drop constraint if exists messages_message_type_check;
alter table public.messages add constraint messages_message_type_check
    check (message_type in ('text', 'beer_share', 'event_invite', 'image'));

insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do nothing;

-- Bestandspad is "<mijn user id>/<bestandsnaam>", zodat de map-naam altijd
-- overeenkomt met de uploader. Lezen mag iedereen (publieke bucket), net als
-- bij avatars; alleen de eigenaar mag in zijn eigen map schrijven/verwijderen.
drop policy if exists "Chat images: public read" on storage.objects;
create policy "Chat images: public read" on storage.objects
    for select using (bucket_id = 'chat-images');

drop policy if exists "Chat images: insert own" on storage.objects;
create policy "Chat images: insert own" on storage.objects
    for insert with check (
        bucket_id = 'chat-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Chat images: delete own" on storage.objects;
create policy "Chat images: delete own" on storage.objects
    for delete using (
        bucket_id = 'chat-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

NOTIFY pgrst, 'reload schema';
