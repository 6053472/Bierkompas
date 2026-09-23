-- BierKompas: debug-hulpje voor de Bier Streak.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vervangt record_daily_activity door een versie die duidelijk faalt (in plaats
-- van stil niets te doen) als er geen profielrij bestaat voor de gebruiker.
-- Verder identiek aan de versie in add_stats_and_badges.sql.

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
    select p.last_activity_date, p.current_streak, p.longest_streak
        into v_last_date, v_current_streak, v_longest_streak
        from public.profiles p
        where p.id = p_user_id
        for update;

    if not found then
        raise exception 'record_daily_activity: geen profiel gevonden voor gebruiker %', p_user_id;
    end if;

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

NOTIFY pgrst, 'reload schema';
