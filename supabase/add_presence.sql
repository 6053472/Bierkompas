-- Online-status voor Bier-vrienden: een groene stip op de avatar als iemand
-- de app recent open had. Geen aparte presence-service nodig; de app "tikt"
-- gewoon elke X seconden een tijdstempel bij terwijl hij open is.

alter table public.profiles add column if not exists last_active_at timestamptz;

create or replace function public.touch_presence()
returns void
language sql
security definer set search_path = public
as $$
    update public.profiles set last_active_at = now() where id = auth.uid();
$$;

grant execute on function public.touch_presence() to authenticated;

-- `list_friends` (uit add_friends.sql) opnieuw gedefinieerd met een extra
-- `online`-kolom: recent (binnen 2 minuten) actief geweest. Het returntype
-- verandert, dus `create or replace` is niet genoeg: eerst droppen.
drop function if exists public.list_friends();
create or replace function public.list_friends()
returns table(friend_id uuid, name text, avatar_url text, online boolean)
language sql
security definer set search_path = public
stable
as $$
    select
        case when fr.requester_id = auth.uid() then fr.addressee_id else fr.requester_id end as friend_id,
        p.name,
        p.avatar_url,
        (p.last_active_at is not null and p.last_active_at > now() - interval '2 minutes') as online
    from public.friend_requests fr
    join public.profiles p
      on p.id = case when fr.requester_id = auth.uid() then fr.addressee_id else fr.requester_id end
    where fr.status = 'accepted'
      and (fr.requester_id = auth.uid() or fr.addressee_id = auth.uid());
$$;

grant execute on function public.list_friends() to authenticated;

NOTIFY pgrst, 'reload schema';
