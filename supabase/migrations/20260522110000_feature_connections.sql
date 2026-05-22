create table if not exists public.memact_feature_connections (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  app_id uuid not null references public.memact_apps(id) on delete cascade,
  api_key_id uuid not null references public.memact_api_keys(id) on delete cascade,
  feature_id text not null,
  created_at timestamptz not null default timezone('utc', now()),
  disconnected_at timestamptz
);

create index if not exists memact_feature_connections_owner_idx
  on public.memact_feature_connections(owner_user_id);

create index if not exists memact_feature_connections_app_idx
  on public.memact_feature_connections(app_id);

create unique index if not exists memact_feature_connections_active_idx
  on public.memact_feature_connections(owner_user_id, app_id, api_key_id, feature_id)
  where disconnected_at is null;

alter table public.memact_feature_connections enable row level security;

drop policy if exists "memact feature connections own rows" on public.memact_feature_connections;
create policy "memact feature connections own rows"
  on public.memact_feature_connections
  for all
  to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

notify pgrst, 'reload schema';
