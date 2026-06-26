-- Migration: contributions user-action RPCs
-- The memact_contributions table already exists (20260617000000_memact_notebook.sql).
-- This migration adds the RPCs needed by the address page (username.memact.com)
-- for the signed-in user to list, approve, reject, edit, and delete their own claims.
--
-- Table shape (already in DB):
--   id              uuid
--   user_id         uuid
--   content         text        -- the readable claim text
--   contributor_type text       -- 'user' | 'friend' | 'app' | 'agent' | 'organization'
--   contributor_name text       -- display name of who proposed it
--   status          text        -- 'pending' | 'approved' | 'rejected'
--   visibility      text        -- 'private' | 'friends' | 'apps' | 'agents' | 'public'
--   is_starred      boolean
--   created_at      timestamptz

-- ──────────────────────────────────────────────────────────
-- RPC: memact_list_contributions
-- Returns all contributions for the signed-in user, newest first.
-- Called by the address page on mount.
-- ──────────────────────────────────────────────────────────
create or replace function public.memact_list_contributions()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  current_user_id uuid := public.memact_require_authenticated_user();
begin
  return jsonb_build_object(
    'contributions', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'entry_id',          c.id,
          'title',             c.content,
          'source_app',        c.contributor_name,
          'source_type',       case when c.contributor_type = 'user' then 'self' else 'app' end,
          'status',            c.status,
          'visibility',        c.visibility,
          'is_starred',        c.is_starred,
          'proposed_at',       c.created_at,
          'updated_at',        c.created_at
        )
        order by c.created_at desc
      ), '[]'::jsonb)
      from public.memact_contributions c
      where c.user_id = current_user_id
    )
  );
end;
$$;

grant execute on function public.memact_list_contributions() to authenticated;

-- ──────────────────────────────────────────────────────────
-- RPC: memact_approve_contribution
-- Moves a contribution to 'approved'. Optionally lets the
-- user edit the content text at the same time.
-- ──────────────────────────────────────────────────────────
create or replace function public.memact_approve_contribution(
  contribution_id_input uuid,
  text_override_input   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  current_user_id uuid := public.memact_require_authenticated_user();
  target          public.memact_contributions%rowtype;
begin
  select * into target
  from public.memact_contributions c
  where c.id = contribution_id_input
    and c.user_id = current_user_id;

  if not found then
    raise exception 'Contribution not found.';
  end if;

  update public.memact_contributions
  set
    status  = 'approved',
    content = coalesce(nullif(trim(text_override_input), ''), content)
  where id = target.id
  returning * into target;

  perform public.memact_audit(
    current_user_id,
    'contribution.approve',
    jsonb_build_object('contribution_id', target.id, 'content', target.content)
  );

  return jsonb_build_object(
    'contribution', jsonb_build_object(
      'entry_id', target.id,
      'title',    target.content,
      'status',   target.status
    )
  );
end;
$$;

grant execute on function public.memact_approve_contribution(uuid, text) to authenticated;

-- ──────────────────────────────────────────────────────────
-- RPC: memact_reject_contribution
-- Marks a contribution as rejected. Stays visible under the
-- Rejected filter tab so the user has a record.
-- ──────────────────────────────────────────────────────────
create or replace function public.memact_reject_contribution(
  contribution_id_input uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  current_user_id uuid := public.memact_require_authenticated_user();
  target          public.memact_contributions%rowtype;
begin
  select * into target
  from public.memact_contributions c
  where c.id = contribution_id_input
    and c.user_id = current_user_id;

  if not found then
    raise exception 'Contribution not found.';
  end if;

  update public.memact_contributions
  set status = 'rejected'
  where id = target.id
  returning * into target;

  perform public.memact_audit(
    current_user_id,
    'contribution.reject',
    jsonb_build_object('contribution_id', target.id)
  );

  return jsonb_build_object('ok', true, 'entry_id', target.id);
end;
$$;

grant execute on function public.memact_reject_contribution(uuid) to authenticated;

-- ──────────────────────────────────────────────────────────
-- RPC: memact_edit_contribution
-- Updates the content text of a contribution.
-- Also used for archiving (status = 'rejected' + a UI label).
-- ──────────────────────────────────────────────────────────
create or replace function public.memact_edit_contribution(
  contribution_id_input uuid,
  text_input            text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  current_user_id uuid := public.memact_require_authenticated_user();
  target          public.memact_contributions%rowtype;
begin
  select * into target
  from public.memact_contributions c
  where c.id = contribution_id_input
    and c.user_id = current_user_id;

  if not found then
    raise exception 'Contribution not found.';
  end if;

  update public.memact_contributions
  set content = coalesce(nullif(trim(text_input), ''), content)
  where id = target.id
  returning * into target;

  perform public.memact_audit(
    current_user_id,
    'contribution.edit',
    jsonb_build_object('contribution_id', target.id, 'content', target.content)
  );

  return jsonb_build_object(
    'contribution', jsonb_build_object(
      'entry_id', target.id,
      'title',    target.content,
      'status',   target.status
    )
  );
end;
$$;

grant execute on function public.memact_edit_contribution(uuid, text) to authenticated;

-- ──────────────────────────────────────────────────────────
-- RPC: memact_delete_contribution
-- Permanently deletes a contribution row.
-- ──────────────────────────────────────────────────────────
create or replace function public.memact_delete_contribution(
  contribution_id_input uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  current_user_id uuid := public.memact_require_authenticated_user();
  target          public.memact_contributions%rowtype;
begin
  select * into target
  from public.memact_contributions c
  where c.id = contribution_id_input
    and c.user_id = current_user_id;

  if not found then
    raise exception 'Contribution not found.';
  end if;

  delete from public.memact_contributions where id = target.id;

  perform public.memact_audit(
    current_user_id,
    'contribution.delete',
    jsonb_build_object('contribution_id', target.id)
  );

  return jsonb_build_object('ok', true, 'entry_id', target.id);
end;
$$;

grant execute on function public.memact_delete_contribution(uuid) to authenticated;

notify pgrst, 'reload schema';
