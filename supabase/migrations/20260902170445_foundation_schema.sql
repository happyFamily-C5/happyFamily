-- Backend MVP .kumpul: foundational schemas, vocabulary, tables, and indexes.
-- PostgreSQL is the only server-side source of truth. Public client roles are
-- intentionally denied until the RLS migration grants the exact operations.

create schema if not exists private;
create schema if not exists api;

revoke all on schema private from public, anon, authenticated;
grant usage on schema api to authenticated, service_role;

alter default privileges in schema private revoke execute on functions from public;
alter default privileges in schema api revoke execute on functions from public, anon, authenticated;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

create type public.workspace_status as enum ('active', 'disabled');
create type public.event_status as enum (
  'draft', 'upcoming', 'ongoing', 'completed', 'closed', 'cancelled'
);
create type public.booking_status as enum (
  'waiting', 'accepted', 'rejected', 'expired', 'cancelled'
);
create type public.shipping_method as enum ('direct', 'ojek_online', 'expedition');
create type public.reception_decision as enum ('accepted', 'rejected');
create type public.item_condition as enum ('good', 'damaged', 'wet', 'dirty', 'moldy');
create type public.rejection_reason as enum (
  'accessories_attached', 'criteria_mismatch', 'damaged', 'wet', 'dirty',
  'moldy', 'capacity_exceeded', 'other'
);
create type public.criterion_code as enum (
  'cotton', 'linen', 'rayon', 'wool', 'tencel', 'silk', 'non_stretch',
  'denim', 'no_lace', 'polyester'
);
create type public.legal_document_type as enum ('terms', 'privacy');
create type public.deployment_environment as enum ('local', 'staging', 'production');
create type public.job_status as enum ('running', 'succeeded', 'failed');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

revoke execute on function public.set_updated_at() from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (char_length(display_name) <= 120)
);

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  status public.workspace_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workspaces_name_length check (char_length(name) between 1 and 160)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text,
  description text,
  status public.event_status not null default 'draft',
  published_at timestamptz,
  terminal_at timestamptz,
  terminal_reason text,
  start_at timestamptz,
  end_at timestamptz,
  timezone_name text,
  operational_days smallint[],
  opens_at_local time,
  closes_at_local time,
  location_name text,
  location_address text,
  location_country_code char(2),
  latitude double precision,
  longitude double precision,
  capacity_grams bigint,
  received_weight_grams bigint not null default 0,
  banner_object_path text,
  receiver_name text,
  receiver_phone text,
  receiver_address text,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint events_name_length check (name is null or char_length(name) between 1 and 160),
  constraint events_description_length check (description is null or char_length(description) <= 4000),
  constraint events_time_order check (start_at is null or end_at is null or start_at < end_at),
  constraint events_schedule_order check (
    opens_at_local is null or closes_at_local is null or opens_at_local < closes_at_local
  ),
  constraint events_operational_days check (
    operational_days is null or (
      cardinality(operational_days) between 1 and 7
      and operational_days <@ array[1,2,3,4,5,6,7]::smallint[]
    )
  ),
  constraint events_coordinates check (
    (latitude is null and longitude is null)
    or (latitude between -11.5 and 6.5 and longitude between 94.0 and 142.0)
  ),
  constraint events_capacity check (
    received_weight_grams >= 0
    and (capacity_grams is null or capacity_grams > 0)
    and (capacity_grams is null or received_weight_grams <= capacity_grams)
  ),
  constraint events_terminal_timestamp check (
    (status in ('completed', 'closed', 'cancelled') and terminal_at is not null)
    or (status not in ('completed', 'closed', 'cancelled') and terminal_at is null)
  )
);

create table public.event_criteria (
  event_id uuid not null references public.events(id) on delete cascade,
  criterion public.criterion_code not null,
  created_at timestamptz not null default now(),
  primary key (event_id, criterion)
);

create table public.event_invocations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  token_hash text not null unique,
  token_ciphertext text not null,
  token_nonce text not null,
  crypto_key_version smallint not null default 1,
  environment public.deployment_environment not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (event_id, environment)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  public_booking_id text not null unique,
  event_id uuid not null references public.events(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  donor_name_ciphertext text,
  donor_name_nonce text,
  donor_phone_ciphertext text,
  donor_phone_nonce text,
  phone_lookup_hash text,
  crypto_key_version smallint not null default 1,
  estimated_weight_grams bigint not null,
  item_count integer not null,
  shipping_method public.shipping_method not null,
  scan_model_version text not null,
  status public.booking_status not null default 'waiting',
  terminal_reason_code text,
  event_snapshot jsonb not null,
  snapshot_schema_version smallint not null default 1,
  qr_token_hash text unique,
  qr_token_ciphertext text,
  qr_token_nonce text,
  terms_version text not null,
  privacy_version text not null,
  consented_at timestamptz not null,
  expires_at timestamptz not null,
  terminal_at timestamptz,
  pii_deleted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint bookings_public_id_format check (
    public_booking_id ~ '^KPL-[0-9A-HJKMNP-TV-Z]{5}-[0-9A-HJKMNP-TV-Z]{5}$'
  ),
  constraint bookings_weights check (estimated_weight_grams > 0),
  constraint bookings_item_count check (item_count > 0 and item_count <= 100),
  constraint bookings_scan_version_length check (char_length(scan_model_version) between 1 and 80),
  constraint bookings_terminal_timestamp check (
    (status = 'waiting' and terminal_at is null)
    or (status <> 'waiting' and terminal_at is not null)
  ),
  constraint bookings_pii_complete check (
    pii_deleted_at is not null
    or (
      donor_name_ciphertext is not null and donor_name_nonce is not null
      and donor_phone_ciphertext is not null and donor_phone_nonce is not null
      and phone_lookup_hash is not null and qr_token_hash is not null
      and qr_token_ciphertext is not null and qr_token_nonce is not null
    )
  )
);

create table public.booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  ordinal smallint not null,
  passed boolean not null,
  scanner_model_version text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (booking_id, ordinal),
  constraint booking_items_passed check (passed),
  constraint booking_items_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create table public.receptions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  decision public.reception_decision not null,
  actual_weight_grams bigint not null,
  condition public.item_condition not null,
  rejection_reason public.rejection_reason,
  rejection_note text,
  processed_by uuid not null references auth.users(id) on delete restrict,
  processed_at timestamptz not null default now(),
  constraint receptions_weight check (actual_weight_grams > 0),
  constraint receptions_note_length check (rejection_note is null or char_length(rejection_note) <= 1000),
  constraint receptions_rejection_shape check (
    (decision = 'accepted' and rejection_reason is null and rejection_note is null)
    or decision = 'rejected'
  )
);

create table public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  scope text not null,
  actor_scope text not null,
  key text not null,
  request_hash text not null,
  resource_type text,
  resource_id uuid,
  response_payload jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  unique (scope, actor_scope, key),
  constraint idempotency_key_length check (char_length(key) between 8 and 200)
);

create table public.legal_document_versions (
  id uuid primary key default gen_random_uuid(),
  document_type public.legal_document_type not null,
  version_identifier text not null,
  public_url text not null,
  environment public.deployment_environment not null,
  published_at timestamptz not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  unique (document_type, version_identifier, environment)
);

create unique index legal_document_one_active_per_environment
  on public.legal_document_versions (document_type, environment)
  where is_active;

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_type text not null,
  actor_id text,
  workspace_id uuid references public.workspaces(id) on delete cascade,
  entity_type text not null,
  entity_id uuid,
  action_code text not null,
  request_id uuid not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint audit_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create table public.impact_aggregates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  period_start date not null,
  total_accepted_weight_grams bigint not null default 0,
  accepted_booking_count bigint not null default 0,
  rejected_booking_count bigint not null default 0,
  unique_donor_count bigint not null default 0,
  completed_event_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, event_id, period_start),
  constraint impact_counts_nonnegative check (
    total_accepted_weight_grams >= 0 and accepted_booking_count >= 0
    and rejected_booking_count >= 0 and unique_donor_count >= 0
    and completed_event_count >= 0
  )
);

create table public.job_runs (
  id uuid primary key default gen_random_uuid(),
  job_name text not null,
  status public.job_status not null default 'running',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  processed_rows bigint not null default 0,
  error_code text,
  correlation_id uuid not null default gen_random_uuid(),
  metadata jsonb not null default '{}'::jsonb
);

create table public.rate_limit_buckets (
  endpoint text not null,
  fingerprint_hash text not null,
  window_started_at timestamptz not null,
  request_count integer not null default 1,
  expires_at timestamptz not null,
  primary key (endpoint, fingerprint_hash, window_started_at),
  constraint rate_limit_count_positive check (request_count > 0)
);

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger workspaces_set_updated_at before update on public.workspaces
for each row execute function public.set_updated_at();
create trigger events_set_updated_at before update on public.events
for each row execute function public.set_updated_at();
create trigger impact_set_updated_at before update on public.impact_aggregates
for each row execute function public.set_updated_at();

create index events_workspace_status_time_idx
  on public.events (workspace_id, status, start_at, end_at);
create index events_sync_idx on public.events (workspace_id, updated_at, id);
create index bookings_event_status_expiry_idx
  on public.bookings (event_id, status, expires_at);
create index bookings_workspace_created_idx
  on public.bookings (workspace_id, created_at desc);
create index bookings_event_phone_hash_idx
  on public.bookings (event_id, phone_lookup_hash) where phone_lookup_hash is not null;
create index events_retention_idx
  on public.events (terminal_at) where terminal_at is not null;
create index audit_events_created_idx on public.audit_events (created_at);
create index idempotency_expiry_idx on public.idempotency_keys (expires_at);
create index rate_limit_expiry_idx on public.rate_limit_buckets (expires_at);

revoke all on all tables in schema public from anon, authenticated;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant usage, select on sequences to service_role;
