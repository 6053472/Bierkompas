-- BierKompas Supabase schema
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Vervangt de oude PHP/MySQL-tabellen. Authenticatie (users) wordt afgehandeld
-- door Supabase's ingebouwde auth.users-tabel.

-- 1. Profiles: publieke gebruikersgegevens (naam/e-mail) gekoppeld aan auth.users.
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

-- Trigger: maakt automatisch een profielrij aan zodra iemand zich registreert
-- via auth.signUp(data: {'name': ...}).
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

-- 2. User consents: hoofdgoedkeuring, leeftijd/alcohol, account/veiligheid.
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

-- 3. Favorites: nog niet gekoppeld aan een scherm, klaar voor later.
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
