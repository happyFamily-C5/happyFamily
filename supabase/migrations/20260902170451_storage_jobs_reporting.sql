-- Banner storage, scheduled reconciliation, retention, and operational views.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('event-banners', 'event-banners', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy event_banners_public_read on storage.objects for select to anon, authenticated
using (bucket_id = 'event-banners');
create policy event_banners_owner_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'event-banners'
  and (storage.foldername(name))[1] = private.current_workspace_id()::text
);
create policy event_banners_owner_update on storage.objects for update to authenticated
using (
  bucket_id = 'event-banners'
  and (storage.foldername(name))[1] = private.current_workspace_id()::text
)
with check (
  bucket_id = 'event-banners'
  and (storage.foldername(name))[1] = private.current_workspace_id()::text
);
create policy event_banners_owner_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'event-banners'
  and (storage.foldername(name))[1] = private.current_workspace_id()::text
);

create or replace function private.run_lifecycle_job()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run_id uuid;
  v_processed bigint;
begin
  insert into public.job_runs (job_name) values ('lifecycle-and-expiry') returning id into v_run_id;
  begin
    v_processed := private.reconcile_events(null);
    update public.job_runs set status = 'succeeded', finished_at = clock_timestamp(),
      processed_rows = v_processed where id = v_run_id;
    return jsonb_build_object('status', 'succeeded', 'processed_rows', v_processed);
  exception when others then
    update public.job_runs set status = 'failed', finished_at = clock_timestamp(),
      error_code = sqlstate where id = v_run_id;
    return jsonb_build_object('status', 'failed', 'error_code', sqlstate);
  end;
end;
$$;

create or replace function private.run_retention_job()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run_id uuid;
  v_processed bigint := 0;
  v_affected bigint := 0;
begin
  insert into public.job_runs (job_name) values ('retention') returning id into v_run_id;
  begin
    insert into public.impact_aggregates (
      workspace_id, event_id, period_start, total_accepted_weight_grams,
      accepted_booking_count, rejected_booking_count, unique_donor_count
    )
    select b.workspace_id, b.event_id, date_trunc('month', b.created_at)::date,
      coalesce(sum(r.actual_weight_grams) filter (where r.decision = 'accepted'), 0),
      count(*) filter (where b.status = 'accepted'),
      count(*) filter (where b.status = 'rejected'),
      count(distinct b.phone_lookup_hash) filter (
        where b.status = 'accepted' and b.phone_lookup_hash is not null
      )
    from public.bookings as b
    join public.events as e on e.id = b.event_id
    left join public.receptions as r on r.booking_id = b.id
    where e.terminal_at <= now() - interval '30 days'
    group by b.workspace_id, b.event_id, date_trunc('month', b.created_at)::date
    on conflict (workspace_id, event_id, period_start) do update set
      total_accepted_weight_grams = excluded.total_accepted_weight_grams,
      accepted_booking_count = excluded.accepted_booking_count,
      rejected_booking_count = excluded.rejected_booking_count,
      unique_donor_count = excluded.unique_donor_count;

    insert into public.impact_aggregates (
      workspace_id, event_id, period_start, completed_event_count
    )
    select e.workspace_id, e.id, date_trunc('month', e.terminal_at)::date,
      case when e.status = 'completed' then 1 else 0 end
    from public.events as e
    where e.terminal_at <= now() - interval '30 days'
    on conflict (workspace_id, event_id, period_start) do update set
      completed_event_count = excluded.completed_event_count;

    delete from public.idempotency_keys as i
    using public.bookings as b, public.events as e
    where i.resource_type = 'booking' and i.resource_id = b.id
      and b.event_id = e.id and e.terminal_at <= now() - interval '30 days';
    get diagnostics v_affected = row_count;
    v_processed := v_processed + v_affected;

    delete from public.bookings as b using public.events as e
    where b.event_id = e.id and e.terminal_at <= now() - interval '30 days';
    get diagnostics v_affected = row_count;
    v_processed := v_processed + v_affected;

    delete from public.event_invocations as i using public.events as e
    where i.event_id = e.id and e.terminal_at <= now() - interval '30 days';
    get diagnostics v_affected = row_count;
    v_processed := v_processed + v_affected;

    delete from public.audit_events where created_at <= now() - interval '30 days';
    get diagnostics v_affected = row_count;
    v_processed := v_processed + v_affected;
    delete from public.idempotency_keys where expires_at <= now();
    delete from public.rate_limit_buckets where expires_at <= now();

    update public.job_runs set status = 'succeeded', finished_at = clock_timestamp(),
      processed_rows = v_processed where id = v_run_id;
    return jsonb_build_object('status', 'succeeded', 'processed_rows', v_processed);
  exception when others then
    update public.job_runs set status = 'failed', finished_at = clock_timestamp(),
      error_code = sqlstate where id = v_run_id;
    return jsonb_build_object('status', 'failed', 'error_code', sqlstate);
  end;
end;
$$;

create or replace view api.job_health_v1
with (security_invoker = true)
as
select distinct on (job_name)
  job_name, status, started_at, finished_at, processed_rows, error_code,
  correlation_id
from public.job_runs
order by job_name, started_at desc;

revoke all on api.job_health_v1 from public, anon, authenticated;
grant select on api.job_health_v1 to service_role;
revoke execute on function private.run_lifecycle_job() from public, anon, authenticated;
revoke execute on function private.run_retention_job() from public, anon, authenticated;
grant execute on function private.run_lifecycle_job() to service_role;
grant execute on function private.run_retention_job() to service_role;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname = 'kumpul-lifecycle-expiry';
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'kumpul-lifecycle-expiry', '* * * * *',
    'select private.run_lifecycle_job()'
  );

  select jobid into v_job_id from cron.job where jobname = 'kumpul-retention';
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'kumpul-retention', '17 19 * * *',
    'select private.run_retention_job()'
  );
end;
$$;
