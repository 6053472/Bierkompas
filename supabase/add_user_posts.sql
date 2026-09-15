-- Zelf een post plaatsen in de Ontdek-feed (naast de vaste content uit
-- add_feed.sql). Een post is een nieuw item_type 'post' in feed_items,
-- gekoppeld aan de gebruiker die 'm plaatste zodat hij/zij 'm ook weer kan
-- verwijderen. Kan veilig opnieuw worden uitgevoerd.

alter table public.feed_items add column if not exists user_id uuid references public.profiles(id) on delete cascade;
alter table public.feed_items add column if not exists avatar_url text;

alter table public.feed_items drop constraint if exists feed_items_item_type_check;
alter table public.feed_items add constraint feed_items_item_type_check
    check (item_type in ('review', 'tip', 'weetje', 'brouwerij', 'post'));

-- Iedereen mag al lezen (zie add_feed.sql). Plaatsen mag alleen als eigen
-- 'post'; de vaste content-types (review/tip/weetje/brouwerij) blijven
-- beheerd via losse SQL, niet vanuit de app.
drop policy if exists "Feed items: insert own post" on public.feed_items;
create policy "Feed items: insert own post" on public.feed_items
    for insert with check (
        auth.uid() = user_id
        and item_type = 'post'
    );

drop policy if exists "Feed items: delete own post" on public.feed_items;
create policy "Feed items: delete own post" on public.feed_items
    for delete using (auth.uid() = user_id);

grant insert, delete on public.feed_items to authenticated;

-- View opnieuw aanmaken zodat user_id/avatar_url ook meekomen (nodig om
-- "verwijderen" alleen bij je eigen posts te tonen).
drop view if exists public.feed;
create view public.feed
with (security_invoker = on) as
select
    'item-' || id as feed_key,
    item_type,
    title,
    body,
    image_url,
    author,
    rating,
    beer_id,
    brewery_id,
    null::timestamptz as event_start,
    null::text as event_location,
    user_id,
    avatar_url,
    created_at
from public.feed_items
union all
select
    'event-' || id,
    'evenement',
    name,
    description,
    null,
    null,
    null,
    null,
    null,
    start_date,
    location_name || ', ' || city,
    null::uuid as user_id,
    null::text as avatar_url,
    created_at
from public.events;

grant select on public.feed to anon, authenticated;

-- Storage-bucket voor foto's bij een post (zelfde opzet als chat-images).
insert into storage.buckets (id, name, public)
values ('feed-images', 'feed-images', true)
on conflict (id) do nothing;

drop policy if exists "Feed images: public read" on storage.objects;
create policy "Feed images: public read" on storage.objects
    for select using (bucket_id = 'feed-images');

drop policy if exists "Feed images: insert own" on storage.objects;
create policy "Feed images: insert own" on storage.objects
    for insert with check (
        bucket_id = 'feed-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Feed images: delete own" on storage.objects;
create policy "Feed images: delete own" on storage.objects
    for delete using (
        bucket_id = 'feed-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

NOTIFY pgrst, 'reload schema';
