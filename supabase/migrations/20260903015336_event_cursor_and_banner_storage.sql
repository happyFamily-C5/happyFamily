-- Opaque event sync cursors and banner Storage least-privilege hardening.

create or replace function private.encode_event_cursor(
  p_updated_at timestamptz,
  p_version bigint,
  p_id uuid
)
returns text
language sql
immutable
set search_path = ''
as $$
  select rtrim(translate(
    replace(replace(encode(convert_to(jsonb_build_object(
      'updated_at', p_updated_at,
      'version', p_version,
      'id', p_id
    )::text, 'UTF8'), 'base64'), E'\n', ''), E'\r', ''),
    '+/', '-_'
  ), '=')
$$;

create or replace function private.decode_event_cursor(p_cursor text)
returns table(updated_at timestamptz, version bigint, id uuid)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_base64 text;
  v_payload jsonb;
begin
  if p_cursor is null or length(p_cursor) < 16 or length(p_cursor) > 512
    or p_cursor !~ '^[A-Za-z0-9_-]+$'
  then
    raise exception using errcode = '22023', message = 'CURSOR_INVALID';
  end if;
  v_base64 := replace(replace(p_cursor, '-', '+'), '_', '/');
  v_base64 := v_base64 || repeat('=', (4 - length(v_base64) % 4) % 4);
  v_payload := convert_from(decode(v_base64, 'base64'), 'UTF8')::jsonb;
  if jsonb_typeof(v_payload) <> 'object'
    or not v_payload ?& array['updated_at', 'version', 'id']
  then
    raise exception using errcode = '22023', message = 'CURSOR_INVALID';
  end if;
  updated_at := (v_payload ->> 'updated_at')::timestamptz;
  version := (v_payload ->> 'version')::bigint;
  id := (v_payload ->> 'id')::uuid;
  if version < 1 then
    raise exception using errcode = '22023', message = 'CURSOR_INVALID';
  end if;
  return next;
exception
  when others then
    raise exception using errcode = '22023', message = 'CURSOR_INVALID';
end;
$$;

create or replace function private.list_events_cursor_impl(
  p_cursor text default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid := private.require_workspace();
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_after_updated_at timestamptz;
  v_after_version bigint;
  v_after_id uuid;
  v_items jsonb;
  v_cursor text;
  v_has_more boolean;
begin
  if p_cursor is not null then
    select decoded.updated_at, decoded.version, decoded.id
    into v_after_updated_at, v_after_version, v_after_id
    from private.decode_event_cursor(p_cursor) as decoded;
  end if;

  perform private.reconcile_events(v_workspace_id);

  with page as materialized (
    select e as event_row, e.updated_at, e.version, e.id
    from public.events as e
    where e.workspace_id = v_workspace_id
      and (
        v_after_updated_at is null
        or (e.updated_at, e.version, e.id)
          > (v_after_updated_at, v_after_version, v_after_id)
      )
    order by e.updated_at, e.version, e.id
    limit v_limit + 1
  ), visible as materialized (
    select * from page
    order by updated_at, version, id
    limit v_limit
  )
  select
    coalesce((
      select jsonb_agg(private.event_to_json(v.event_row)
        order by v.updated_at, v.version, v.id)
      from visible as v
    ), '[]'::jsonb),
    coalesce((
      select private.encode_event_cursor(v.updated_at, v.version, v.id)
      from visible as v
      order by v.updated_at desc, v.version desc, v.id desc
      limit 1
    ), p_cursor),
    exists(select 1 from page offset v_limit)
  into v_items, v_cursor, v_has_more;

  return jsonb_build_object(
    'items', v_items,
    'cursor', v_cursor,
    'has_more', v_has_more,
    'server_time', now()
  );
end;
$$;

create or replace function api.list_events_v2(
  p_cursor text default null,
  p_limit integer default 50
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.list_events_cursor_impl(p_cursor, p_limit)
$$;

revoke execute on function private.encode_event_cursor(timestamptz, bigint, uuid)
from public, anon, authenticated;
revoke execute on function private.decode_event_cursor(text)
from public, anon, authenticated;
revoke execute on function private.list_events_cursor_impl(text, integer)
from public, anon;
grant execute on function private.list_events_cursor_impl(text, integer)
to authenticated;
revoke execute on function api.list_events_v2(text, integer)
from public, anon;
grant execute on function api.list_events_v2(text, integer)
to authenticated, service_role;

drop index if exists public.events_sync_idx;
create index events_sync_idx
on public.events (workspace_id, updated_at, version, id);

-- Banner bytes must pass the upload-event-banner Edge Function. Removing all
-- authenticated write policies prevents clients from bypassing MIME sniffing
-- and image-dimension validation through the Storage API.
drop policy if exists event_banners_owner_insert on storage.objects;
drop policy if exists event_banners_owner_update on storage.objects;
drop policy if exists event_banners_owner_delete on storage.objects;

-- Hosted projects provide these two values through Vault. Local migrations
-- still register the schedule deterministically, but the query is a no-op
-- until both secrets exist:
--   kumpul_project_url              e.g. https://project-ref.supabase.co
--   kumpul_banner_cleanup_secret    random secret shared with the function
create extension if not exists pg_net with schema extensions;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'kumpul-banner-orphan-cleanup';
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
  perform cron.schedule(
    'kumpul-banner-orphan-cleanup',
    '47 19 * * *',
    $command$
      with secrets as (
        select
          max(decrypted_secret) filter (where name = 'kumpul_project_url') as project_url,
          max(decrypted_secret) filter (
            where name = 'kumpul_banner_cleanup_secret'
          ) as cleanup_secret
        from vault.decrypted_secrets
      )
      select net.http_post(
        url := rtrim(secrets.project_url, '/')
          || '/functions/v1/cleanup-orphan-banners',
        headers := jsonb_build_object(
          'content-type', 'application/json',
          'x-cron-secret', secrets.cleanup_secret
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 10000
      )
      from secrets
      where secrets.project_url is not null
        and secrets.cleanup_secret is not null
    $command$
  );
end;
$$;
