-- BierKompas: video-reel met externe video's (YouTube, TikTok, Instagram) en
-- eigen video's. Uitvoeren via het Supabase-dashboard: SQL Editor -> New query
-- -> plak dit bestand -> Run. Vereist add_videos.sql (eerder uitgevoerd).
--
-- Externe video's: alleen de link en het video-ID komen in de database, nooit
-- de videobestanden zelf; de app toont ze met de officiële embed-speler van
-- het platform (YouTube IFrame Player API, TikTok/Instagram embed).
-- Eigen video's: een .mp4/.webm in de opslag hieronder, of een directe link
-- (bijvoorbeeld een HLS-stream .m3u8 via Cloudflare Stream of Mux).

alter table public.videos add column if not exists source text not null default 'hosted';
alter table public.videos drop constraint if exists videos_source_check;
alter table public.videos add constraint videos_source_check
    check (source in ('hosted', 'youtube', 'tiktok', 'instagram'));

-- YouTube: video-ID. TikTok: numeriek video-ID. Instagram: 'reel/CODE' of 'p/CODE'.
alter table public.videos add column if not exists external_id text;

-- Een thumbnail is optioneel: voor YouTube leidt de app die zelf af, bij
-- eigen video's is er een zwart beeld tot de video laadt.
alter table public.videos alter column thumbnail_url drop not null;

-- Opslag voor eigen video's. Een bestand mag maximaal 50 MB zijn (de limiet
-- van het gratis Supabase-abonnement); grotere video's kun je beter via een
-- streamingdienst aanbieden en als directe link toevoegen.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('videos', 'videos', true, 52428800, array['video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do update
    set public = true, file_size_limit = 52428800, allowed_mime_types = array['video/mp4', 'video/webm', 'video/quicktime'];

drop policy if exists "Videos storage: iedereen mag lezen" on storage.objects;
create policy "Videos storage: iedereen mag lezen" on storage.objects
    for select using (bucket_id = 'videos');

drop policy if exists "Videos storage: beheerders mogen uploaden" on storage.objects;
create policy "Videos storage: beheerders mogen uploaden" on storage.objects
    for insert with check (
        bucket_id = 'videos'
        and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Videos storage: beheerders mogen verwijderen" on storage.objects;
create policy "Videos storage: beheerders mogen verwijderen" on storage.objects
    for delete using (
        bucket_id = 'videos'
        and exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

NOTIFY pgrst, 'reload schema';
