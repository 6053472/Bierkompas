-- BierKompas: fix voor "infinite recursion detected in policy for relation profiles".
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Veilig om opnieuw te draaien.
--
-- Oorzaak: de beveiligingsregels (RLS) verwezen in een cirkel naar elkaar:
--   profiles  -> "organisator mag deelnemers zien" leest event_registrations + events
--   events    -> "beheerder mag alles zien" leest profiles (is_admin)
--   profiles  -> ... enzovoort.
-- Oplossing: die controles lopen nu via security-definer-functies. Die lezen de
-- tabellen zonder opnieuw de RLS-regels te activeren, dus geen cirkel meer.

-- 1. Is de ingelogde gebruiker beheerder? (bestond al, voor de zekerheid opnieuw)
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;

grant execute on function public.is_admin() to anon, authenticated;

-- 2. Mag de ingelogde gebruiker dit profiel zien omdat diegene zich heeft
-- aangemeld voor een evenement van de ingelogde gebruiker?
create or replace function public.is_participant_of_my_event(p_profile_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.event_registrations er
        join public.events e on e.id = er.event_id
        where er.user_id = p_profile_id
          and e.user_id = auth.uid()
    );
$$;

grant execute on function public.is_participant_of_my_event(uuid) to authenticated;

-- 3. Profielen: zelfde regel als eerst, maar zonder cirkel.
drop policy if exists "Profiles: event owners can view participants" on public.profiles;
drop policy if exists "Profiles: event owners and admins can view participants" on public.profiles;
create policy "Profiles: event owners and admins can view participants"
on public.profiles
for select
to authenticated
using (
    public.is_participant_of_my_event(id)
    or public.is_admin()
);

-- 4. Evenementen: beheerder-controle via is_admin() in plaats van een
-- rechtstreekse select op profiles.
drop policy if exists "Events: view approved, own, or admin" on public.events;
create policy "Events: view approved, own, or admin" on public.events
    for select using (
        status in ('approved', 'cancelled')
        or user_id = auth.uid()
        or public.is_admin()
    );

drop policy if exists "Events: owner or admin can update" on public.events;
create policy "Events: owner or admin can update" on public.events
    for update using (
        user_id = auth.uid()
        or public.is_admin()
    );

drop policy if exists "Events: admin delete" on public.events;
create policy "Events: admin delete" on public.events
    for delete using (public.is_admin());

NOTIFY pgrst, 'reload schema';
