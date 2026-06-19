-- Create memact profiles table
create table if not exists public.memact_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  full_name text not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint username_length check (char_length(username) >= 3),
  constraint username_format check (username ~ '^[a-z0-9._-]+$')
);

-- Create memact contributions table
create table if not exists public.memact_contributions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  contributor_type text not null check (contributor_type in ('user', 'friend', 'app', 'agent', 'organization')),
  contributor_name text not null,
  status text not null check (status in ('pending', 'approved', 'rejected')),
  visibility text not null check (visibility in ('private', 'friends', 'apps', 'agents', 'public')),
  is_starred boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

-- Create memact connections table
create table if not exists public.memact_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  type text not null check (type in ('app', 'agent', 'friend')),
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

-- Enable Row Level Security (RLS)
alter table public.memact_profiles enable row level security;
alter table public.memact_contributions enable row level security;
alter table public.memact_connections enable row level security;

-- Policies for profiles
drop policy if exists "allow public read on profiles" on public.memact_profiles;
create policy "allow public read on profiles"
  on public.memact_profiles
  for select
  to anon, authenticated
  using (true);

drop policy if exists "allow users to manage own profile" on public.memact_profiles;
create policy "allow users to manage own profile"
  on public.memact_profiles
  for all
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Policies for contributions
drop policy if exists "allow users to manage own contributions" on public.memact_contributions;
create policy "allow users to manage own contributions"
  on public.memact_contributions
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "allow public read on approved public contributions" on public.memact_contributions;
create policy "allow public read on approved public contributions"
  on public.memact_contributions
  for select
  to anon, authenticated
  using (visibility = 'public' and status = 'approved');

-- Policies for connections
drop policy if exists "allow users to manage own connections" on public.memact_connections;
create policy "allow users to manage own connections"
  on public.memact_connections
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
