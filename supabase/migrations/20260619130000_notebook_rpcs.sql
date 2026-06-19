-- Create RPC function to propose contribution
create or replace function public.memact_propose_contribution(
  api_key_input text,
  content_input text,
  contributor_type_input text,
  contributor_name_input text,
  visibility_input text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  verification jsonb;
  new_contribution_id uuid;
begin
  verification := public.memact_verify_api_key(api_key_input, array['context:write']::text[], array[]::text[]);
  if not (verification->>'allowed')::boolean then
    raise exception 'Access denied: %', verification->'error'->>'message';
  end if;

  insert into public.memact_contributions (
    user_id,
    content,
    contributor_type,
    contributor_name,
    status,
    visibility,
    is_starred
  ) values (
    (verification->>'user_id')::uuid,
    content_input,
    contributor_type_input,
    contributor_name_input,
    'pending',
    visibility_input,
    false
  ) returning id into new_contribution_id;

  return jsonb_build_object(
    'accepted', true,
    'contribution', jsonb_build_object(
      'id', new_contribution_id,
      'user_id', verification->>'user_id',
      'content', content_input,
      'contributor_type', contributor_type_input,
      'contributor_name', contributor_name_input,
      'status', 'pending',
      'visibility', visibility_input,
      'is_starred', false
    )
  );
end;
$$;

grant execute on function public.memact_propose_contribution(text, text, text, text, text) to anon, authenticated;

-- Create RPC function to get contributions for app (CAP)
create or replace function public.memact_get_contributions_for_app(
  api_key_input text,
  required_scopes_input text[],
  activity_categories_input text[]
)
returns table (
  id uuid,
  user_id uuid,
  content text,
  contributor_type text,
  contributor_name text,
  status text,
  visibility text,
  is_starred boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  verification jsonb;
begin
  verification := public.memact_verify_api_key(api_key_input, required_scopes_input, activity_categories_input);
  if not (verification->>'allowed')::boolean then
    raise exception 'Access denied: %', verification->'error'->>'message';
  end if;

  return query
  select c.id, c.user_id, c.content, c.contributor_type, c.contributor_name, c.status, c.visibility, c.is_starred, c.created_at
  from public.memact_contributions c
  where c.user_id = (verification->>'user_id')::uuid
    and c.status = 'approved'
    and c.visibility in ('public', 'apps', 'agents');
end;
$$;

grant execute on function public.memact_get_contributions_for_app(text, text[], text[]) to anon, authenticated;

notify pgrst, 'reload schema';
