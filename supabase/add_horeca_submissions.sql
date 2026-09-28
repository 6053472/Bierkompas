-- BierKompas: horeca/biergelegenheden aanmelden voor de kaart, met
-- goedkeuring door een beheerder. Exact dezelfde opzet als
-- add_brewery_submissions.sql, maar voor cafés/proeflokalen i.p.v. brouwerijen.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.

create table if not exists public.horeca_submissions (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,

    naam text not null,
    beschrijving text,

    street text not null,
    house_number text not null,
    postal_code text not null,
    city text not null,

    latitude double precision,
    longitude double precision,

    photo_url text,

    status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
    created_at timestamptz not null default now(),
    approved_at timestamptz,
    approved_by uuid references public.profiles(id),
    rejection_reason text
);

alter table public.horeca_submissions enable row level security;

drop policy if exists "Horeca submissions: view approved, own, or admin" on public.horeca_submissions;
create policy "Horeca submissions: view approved, own, or admin" on public.horeca_submissions
    for select using (
        status = 'approved'
        or user_id = auth.uid()
        or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin)
    );

drop policy if exists "Horeca submissions: insert own" on public.horeca_submissions;
create policy "Horeca submissions: insert own" on public.horeca_submissions
    for insert with check (user_id = auth.uid());

create or replace function public.approve_horeca_submission(p_submission_id bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen horeca-aanmeldingen goedkeuren';
    end if;

    update public.horeca_submissions
        set status = 'approved', approved_at = now(), approved_by = auth.uid()
        where id = p_submission_id and status = 'pending';
end;
$$;

grant execute on function public.approve_horeca_submission(bigint) to authenticated;

create or replace function public.reject_horeca_submission(p_submission_id bigint, p_reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    if not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
        raise exception 'Alleen beheerders mogen horeca-aanmeldingen afwijzen';
    end if;

    update public.horeca_submissions
        set status = 'rejected', rejection_reason = p_reason
        where id = p_submission_id and status = 'pending';
end;
$$;

grant execute on function public.reject_horeca_submission(bigint, text) to authenticated;

-- Zelfde storage-bucket-opzet als brouwerij-foto's.
insert into storage.buckets (id, name, public)
values ('horeca-photos', 'horeca-photos', true)
on conflict (id) do nothing;

drop policy if exists "Horeca photos: public read" on storage.objects;
create policy "Horeca photos: public read" on storage.objects
    for select using (bucket_id = 'horeca-photos');

drop policy if exists "Horeca photos: insert own" on storage.objects;
create policy "Horeca photos: insert own" on storage.objects
    for insert with check (
        bucket_id = 'horeca-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

NOTIFY pgrst, 'reload schema';
