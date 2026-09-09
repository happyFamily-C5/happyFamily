-- Operational backlog and invariant checks consumed by monitoring with service-role access.

create index events_lifecycle_end_idx
on public.events (end_at)
where status in ('upcoming', 'ongoing');

create index events_lifecycle_start_idx
on public.events (start_at)
where status = 'upcoming';

create index bookings_expiry_backlog_idx
on public.bookings (expires_at)
where status = 'waiting';

create index job_runs_name_started_idx
on public.job_runs (job_name, started_at desc);

create or replace view api.operational_health_v1
with (security_invoker = true)
as
select
  clock_timestamp() as observed_at,
  (
    select count(*)
    from public.events
    where status in ('upcoming', 'ongoing') and end_at <= now()
  ) as event_completion_backlog,
  (
    select count(*)
    from public.events
    where status = 'upcoming' and start_at <= now() and end_at > now()
  ) as event_start_backlog,
  (
    select count(*)
    from public.bookings
    where status = 'waiting' and expires_at <= now()
  ) as booking_expiry_backlog,
  (
    select count(*)
    from public.bookings as b
    join public.events as e on e.id = b.event_id
    where e.terminal_at <= now() - interval '30 days'
  ) as retention_booking_backlog,
  (
    select count(*)
    from public.event_invocations as i
    join public.events as e on e.id = i.event_id
    where e.terminal_at <= now() - interval '30 days'
  ) as retention_invocation_backlog,
  (
    select count(*)
    from public.audit_events
    where created_at <= now() - interval '30 days'
  ) as retention_audit_backlog,
  (
    select count(*)
    from public.events
    where received_weight_grams > capacity_grams
  ) as capacity_invariant_violations,
  (
    select count(*)
    from public.job_runs
    where status = 'failed' and started_at >= now() - interval '24 hours'
  ) as failed_job_runs_24h,
  (
    select count(*)
    from public.job_runs
    where status = 'running' and started_at <= now() - interval '5 minutes'
  ) as stuck_job_runs,
  (
    select max(finished_at)
    from public.job_runs
    where job_name = 'lifecycle-and-expiry' and status = 'succeeded'
  ) as last_lifecycle_success_at,
  (
    select max(finished_at)
    from public.job_runs
    where job_name = 'retention' and status = 'succeeded'
  ) as last_retention_success_at,
  (
    select max(finished_at)
    from public.job_runs
    where job_name = 'banner-orphan-cleanup' and status = 'succeeded'
  ) as last_banner_cleanup_success_at;

revoke all on api.operational_health_v1 from public, anon, authenticated;
grant select on api.operational_health_v1 to service_role;
