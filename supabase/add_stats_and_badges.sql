-- BierKompas: per-profiel stats, badges en Bier Streaks.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

-- 1. Stats + streak-velden op het profiel.
alter table public.profiles add column if not exists beers_tasted integer not null default 0;
alter table public.profiles add column if not exists breweries_explored integer not null default 0;
alter table public.profiles add column if not exists current_streak integer not null default 0;
alter table public.profiles add column if not exists longest_streak integer not null default 0;
alter table public.profiles add column if not exists last_activity_date date;

-- 2. Badge-definities (algemeen, niet per gebruiker).
create table if not exists public.badges (
    id text primary key,
    title text not null,
    description text not null,
    icon_name text not null,
    requirement_type text not null,
    requirement_value integer not null
);

alter table public.badges enable row level security;

drop policy if exists "Badges: public read" on public.badges;
create policy "Badges: public read" on public.badges
    for select using (true);

insert into public.badges (id, title, description, icon_name, requirement_type, requirement_value) values
    ('streak_7', 'Week Streak', '7 dagen op rij actief in Bierkompas.', 'local_fire_department', 'streak', 7),
    ('streak_30', 'Maand Streak', '30 dagen op rij actief in Bierkompas.', 'whatshot', 'streak', 30),
    ('streak_100', 'Streak Legende', '100 dagen op rij actief in Bierkompas.', 'military_tech', 'streak', 100)
on conflict (id) do nothing;

-- 3. Welke badges een gebruiker heeft verdiend.
create table if not exists public.user_badges (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    badge_id text not null references public.badges(id) on delete cascade,
    earned_at timestamptz not null default now(),
    constraint unique_user_badge unique (user_id, badge_id)
);

alter table public.user_badges enable row level security;

drop policy if exists "User badges: select own" on public.user_badges;
create policy "User badges: select own" on public.user_badges
    for select using (auth.uid() = user_id);

-- Geen insert/update/delete-policy voor gebruikers: badges worden alleen
-- toegekend via de onderstaande functie (security definer), niet rechtstreeks
-- vanuit de app, zodat gebruikers zichzelf geen badges kunnen geven.

-- 4. Streak-logica: 1x per dag aanroepen bij een relevante actie in de app.
-- Vandaag al actief geweest -> streak blijft gelijk.
-- Gisteren actief geweest -> streak +1.
-- Langer geleden (of nog nooit) -> streak reset naar 1.
-- Kent automatisch nieuwe streak-badges toe zodra de drempel gehaald is.
create or replace function public.record_daily_activity(p_user_id uuid)
returns table(current_streak integer, longest_streak integer, newly_earned_badges text[])
language plpgsql
security definer set search_path = public
as $$
declare
    v_last_date date;
    v_current_streak integer;
    v_longest_streak integer;
    v_new_streak integer;
    v_today date := current_date;
    v_newly_earned text[];
begin
    select last_activity_date, current_streak, longest_streak
        into v_last_date, v_current_streak, v_longest_streak
        from public.profiles
        where id = p_user_id
        for update;

    if v_last_date = v_today then
        v_new_streak := v_current_streak;
    elsif v_last_date = v_today - 1 then
        v_new_streak := v_current_streak + 1;
    else
        v_new_streak := 1;
    end if;

    update public.profiles
        set current_streak = v_new_streak,
            longest_streak = greatest(v_longest_streak, v_new_streak),
            last_activity_date = v_today
        where id = p_user_id;

    with inserted as (
        insert into public.user_badges (user_id, badge_id)
        select p_user_id, b.id
        from public.badges b
        where b.requirement_type = 'streak'
            and b.requirement_value <= v_new_streak
            and not exists (
                select 1 from public.user_badges ub
                where ub.user_id = p_user_id and ub.badge_id = b.id
            )
        on conflict (user_id, badge_id) do nothing
        returning badge_id
    )
    select coalesce(array_agg(badge_id), array[]::text[]) into v_newly_earned from inserted;

    return query select v_new_streak, greatest(v_longest_streak, v_new_streak), v_newly_earned;
end;
$$;

grant execute on function public.record_daily_activity(uuid) to authenticated;
