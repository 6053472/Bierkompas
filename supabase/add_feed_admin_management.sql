-- BierKompas: de Ontdek-feed (mini-reviews, biertips, weetjes, brouwerij-posts)
-- beheren vanuit het admin-paneel i.p.v. losse SQL-scripts.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vereist add_feed.sql en add_user_posts.sql (eerder uitgevoerd).

-- Alleen beheerders mogen de vaste content-types (review/tip/weetje/brouwerij)
-- toevoegen, bewerken of verwijderen. Gewone gebruikers blijven beperkt tot
-- hun eigen 'post' (zie add_user_posts.sql).
drop policy if exists "Feed items: admin manage curated content" on public.feed_items;
create policy "Feed items: admin manage curated content" on public.feed_items
    for all using (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    )
    with check (
        exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

-- add_user_posts.sql gaf alleen insert/delete; een admin moet ook kunnen bewerken.
grant update on public.feed_items to authenticated;

NOTIFY pgrst, 'reload schema';
