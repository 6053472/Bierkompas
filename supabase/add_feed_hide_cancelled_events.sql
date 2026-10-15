-- BierKompas: vervallen (en nog niet goedgekeurde) evenementen hoorden niet
-- thuis in de Ontdek-feed. De view `feed` haalde events zonder filter op
-- status op, dus stonden geannuleerde en zelfs nog niet goedgekeurde
-- evenementen daar ook tussen.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_feed.sql, add_user_posts.sql en add_event_status.sql (eerder uitgevoerd).

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
from public.events
where status = 'approved';

grant select on public.feed to anon, authenticated;

NOTIFY pgrst, 'reload schema';
