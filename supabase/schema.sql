-- BierKompas Supabase schema (Compleet)

-- 1. Profiles: publieke gebruikersgegevens gekoppeld aan auth.users
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    name text not null,
    email text not null,
    created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles: select own" on public.profiles
    for select using (auth.uid() = id);

create policy "Profiles: update own" on public.profiles
    for update using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, name, email)
    values (new.id, coalesce(new.raw_user_meta_data->>'name', ''), new.email);
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

-- 2. User consents: hoofdgoedkeuring, leeftijd/alcohol, account/veiligheid
create table if not exists public.user_consents (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    terms_version text not null,
    privacy_version text not null,
    accepted_at timestamptz not null default now(),
    age_confirmed boolean not null default false,
    lawful_alcohol_use boolean not null default false,
    accurate_account_data boolean not null default false,
    personal_account boolean not null default false,
    credentials_secure boolean not null default false,
    no_impersonation boolean not null default false,
    constraint unique_user_consent_version unique (user_id, terms_version, privacy_version)
);

alter table public.user_consents enable row level security;

create policy "Consents: select own" on public.user_consents
    for select using (auth.uid() = user_id);

create policy "Consents: insert own" on public.user_consents
    for insert with check (auth.uid() = user_id);

create policy "Consents: update own" on public.user_consents
    for update using (auth.uid() = user_id);

-- 3. Favorites
create table if not exists public.favorites (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    item_type text not null,
    item_id bigint not null,
    created_at timestamptz not null default now(),
    constraint unique_favorite unique (user_id, item_type, item_id)
);

alter table public.favorites enable row level security;

create policy "Favorites: select own" on public.favorites
    for select using (auth.uid() = user_id);

create policy "Favorites: insert own" on public.favorites
    for insert with check (auth.uid() = user_id);

create policy "Favorites: delete own" on public.favorites
    for delete using (auth.uid() = user_id);

create table if not exists public.events (
    id bigint generated always as identity primary key,
    user_id uuid references auth.users(id) on delete cascade,

    name text not null,
    event_type text not null,

    start_date timestamptz not null,
    end_date timestamptz not null,
    opening_hours text,

    street text not null,
    house_number text not null,
    postal_code text not null,
    city text not null,
    location_name text not null,

    description text not null,

    ticket_regular boolean not null default false,
    ticket_beer boolean not null default false,
    ticket_vip boolean not null default false,

    price numeric(10,2),
    price_incl_btw boolean not null default false,
    price_excl_btw boolean not null default false,

    created_at timestamptz not null default now()
);

alter table public.events enable row level security;

create policy "Events: everyone can view"
on public.events for select using (true);

create policy "Events: authenticated users can insert"
on public.events for insert with check (auth.uid() = user_id);

create policy "Events: owner can update"
on public.events for update using (auth.uid() = user_id);

create policy "Events: owner can delete"
on public.events for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.events to authenticated;
grant select on public.events to anon;

NOTIFY pgrst, 'reload schema';