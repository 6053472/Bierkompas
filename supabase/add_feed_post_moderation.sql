-- BierKompas: eigen posts in de Ontdek-feed krijgen nu (1) een soort-keuze
-- (Post / Mini-review / Biertip / Weetje, i.p.v. altijd alleen 'Post') en
-- (2) moeten eerst door een beheerder goedgekeurd worden voordat ze
-- zichtbaar worden, net als evenementen/brouwerijen/horeca.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_feed.sql, add_user_posts.sql en add_feed_admin_management.sql (eerder uitgevoerd).

alter table public.feed_items add column if not exists status text not null default 'approved';
alter table public.feed_items drop constraint if exists feed_items_status_check;
alter table public.feed_items add constraint feed_items_status_check
    check (status in ('pending', 'approved'));

-- Gebruikers mogen nu ook zelf 'review'/'tip'/'weetje' kiezen (naast 'post'),
-- maar niet 'brouwerij' (dat blijft redactioneel/beheerder-only). Elke eigen
-- post komt er als 'pending' in, ongeacht wat er verder wordt meegestuurd.
drop policy if exists "Feed items: insert own post" on public.feed_items;
create policy "Feed items: insert own post" on public.feed_items
    for insert with check (
        auth.uid() = user_id
        and item_type in ('post', 'review', 'tip', 'weetje')
        and status = 'pending'
    );

-- De Ontdek-feed toont voortaan alleen goedgekeurde content (en goedgekeurde
-- evenementen, zie add_feed_hide_cancelled_events.sql).
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
where status = 'approved'
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
from public.events
where status = 'approved';

grant select on public.feed to anon, authenticated;

NOTIFY pgrst, 'reload schema';
