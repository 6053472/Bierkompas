-- Vriendschap-suggesties voor het "Vrienden"-tabblad op Ontdek (zoals
-- Snapchat's "Snel toevoegen"): willekeurige andere gebruikers die nog geen
-- vriend zijn en met wie nog geen verzoek open staat (in beide richtingen).

create or replace function public.suggest_friends(p_limit int default 12)
returns table(id uuid, name text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
    select p.id, p.name, p.avatar_url
    from public.profiles p
    where p.id <> auth.uid()
      and not exists (
          select 1 from public.friend_requests fr
          where (fr.requester_id = auth.uid() and fr.addressee_id = p.id)
             or (fr.requester_id = p.id and fr.addressee_id = auth.uid())
      )
    order by random()
    limit p_limit;
$$;

grant execute on function public.suggest_friends(int) to authenticated;

NOTIFY pgrst, 'reload schema';
