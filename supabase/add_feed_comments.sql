-- BierKompas: reacties op de Ontdek-feed, inclusief een optionele
-- beoordeling (proefnotitie) bij een mini-review ("proeverij"). Uitvoeren
-- via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand
-- -> Run. Vereist add_feed.sql, add_stats_and_badges.sql, add_new_badges.sql
-- en add_remaining_badges.sql (eerder uitgevoerd; die maakt o.a. de functie
-- check_meta_badges aan die hieronder wordt aangeroepen).
--
-- Dit verandert ook wanneer 'Super Model' wordt toegekend: niet meer bij een
-- hoog gemiddelde van je EIGEN proefnotities, maar bij een hoge gemiddelde
-- BEOORDELING DIE JE VAN ANDEREN KRIJGT op je proeverij-posts -- dat past
-- beter bij "behaal een hoge beoordeling", en vereist dat andere mensen ook
-- echt kunnen reageren/beoordelen (wat deze migratie toevoegt).

create table if not exists public.feed_comments (
    id bigint generated always as identity primary key,
    feed_item_id bigint not null references public.feed_items(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    author text not null,
    avatar_url text,
    body text not null,
    rating numeric(2,1) check (rating between 1 and 5),
    created_at timestamptz not null default now()
);

create index if not exists feed_comments_feed_item_idx on public.feed_comments (feed_item_id, created_at);

alter table public.feed_comments enable row level security;

drop policy if exists "Feed comments: iedereen mag lezen" on public.feed_comments;
create policy "Feed comments: iedereen mag lezen" on public.feed_comments
    for select using (true);

drop policy if exists "Feed comments: eigen reactie verwijderen" on public.feed_comments;
create policy "Feed comments: eigen reactie verwijderen" on public.feed_comments
    for delete using (auth.uid() = user_id);

-- Geen directe insert-policy: reacties gaan via post_feed_comment hieronder,
-- zodat author/avatar betrouwbaar uit het eigen profiel komen (niet door de
-- client zelf in te vullen) en de badge-logica er altijd bij hoort.
grant select, delete on public.feed_comments to authenticated;

-- Plaatst een reactie. Bij een meegegeven [p_rating] (alleen zinvol op een
-- mini-review) wordt voor de MAKER van die post herberekend of die een hoog
-- genoeg gemiddelde (>=4.5 bij minstens 3 ontvangen beoordelingen) heeft
-- gekregen van anderen voor de 'Super Model'-badge.
create or replace function public.post_feed_comment(p_feed_item_id bigint, p_body text, p_rating numeric default null)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
    v_author text;
    v_avatar_url text;
    v_post_owner uuid;
    v_post_type text;
    v_count integer;
    v_avg numeric;
begin
    select name, avatar_url into v_author, v_avatar_url from public.profiles where id = auth.uid();

    insert into public.feed_comments (feed_item_id, user_id, author, avatar_url, body, rating)
    values (p_feed_item_id, auth.uid(), coalesce(v_author, 'Bierliefhebber'), v_avatar_url, p_body, p_rating);

    if p_rating is not null then
        select user_id, item_type into v_post_owner, v_post_type
            from public.feed_items where id = p_feed_item_id;

        if v_post_owner is not null and v_post_type = 'review' then
            select count(*), avg(fc.rating) into v_count, v_avg
                from public.feed_comments fc
                join public.feed_items fi on fi.id = fc.feed_item_id
                where fi.user_id = v_post_owner
                    and fi.item_type = 'review'
                    and fc.rating is not null;

            if v_count >= 3 and v_avg >= 4.5 then
                insert into public.user_badges (user_id, badge_id)
                values (v_post_owner, 'super_model')
                on conflict (user_id, badge_id) do nothing;
                perform public.check_meta_badges(v_post_owner);
            end if;
        end if;
    end if;
end;
$$;

grant execute on function public.post_feed_comment(bigint, text, numeric) to authenticated;

-- 'Super Model' komt nu van ontvangen beoordelingen (hierboven), niet meer
-- van je eigen proefnotitie-cijfer -- deze functie kent 'm dus niet meer toe,
-- maar blijft bestaan (en bijgewerkt via de app aangeroepen) voor de overige
-- meta-badge-check.
create or replace function public.record_tasting_note_created(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if p_user_id <> auth.uid() then
        raise exception 'Niet toegestaan.';
    end if;
    perform public.check_meta_badges(p_user_id);
end;
$$;

grant execute on function public.record_tasting_note_created(uuid) to authenticated;

NOTIFY pgrst, 'reload schema';
