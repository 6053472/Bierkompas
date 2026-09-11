-- BierKompas: categorie per badge, zodat "Bekijk alles" badges kan groeperen
-- zoals in het Mijn Prestaties-ontwerp (Evenement Badges / Culturele Verkenning
-- / Algemene Prestaties).
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

alter table public.badges add column if not exists category text not null default 'algemeen';

update public.badges set category = 'evenement' where id in (
    'bottle_share', 'better_together', 'draft_city', 'home_brewed_goodness',
    'taster_please', 'trip_to_the_farm', 'visit_the_beer_garden'
);

update public.badges set category = 'cultureel' where id in (
    'flanders_red_ale', 'haze_for_days', 'ill_be_bock', 'keep_your_wits',
    'land_of_the_free', 'pucker_up', 'respect_the_kolsch',
    'silence_of_the_lambics', 'to_the_alt'
);

update public.badges set category = 'algemeen' where id in (
    'epic_milestone', 'la_creme_de_la_creme', 'super_model', 'century_club',
    'wheel_of_styles', 'streak_7', 'streak_30', 'streak_100'
);

-- Streak-badges tonen allemaal het vuurtje-icoon.
update public.badges set icon_name = 'local_fire_department'
    where id in ('streak_7', 'streak_30', 'streak_100');

NOTIFY pgrst, 'reload schema';
