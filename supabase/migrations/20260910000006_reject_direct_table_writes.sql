-- Plan invariant: booking status, reception rows, and event capacity may only
-- change through transactional RPCs. Every mutation path (guest legacy edge
-- functions, account/operations adapters, lifecycle jobs) already runs with
-- the service role or through SECURITY DEFINER functions, which bypass these
-- authenticated policies, so dropping them closes the direct PostgREST write
-- path without touching any caller. Select policies stay so operational reads
-- remain available to the workspace owner.

drop policy if exists bookings_insert_owner on public.bookings;
drop policy if exists bookings_update_owner on public.bookings;
drop policy if exists bookings_delete_owner on public.bookings;

drop policy if exists receptions_insert_owner on public.receptions;
drop policy if exists receptions_update_owner on public.receptions;
drop policy if exists receptions_delete_owner on public.receptions;

drop policy if exists events_insert_owner on public.events;
drop policy if exists events_update_owner on public.events;
-- Draft deletion also goes through cancel_or_delete_event_v2, which audits and
-- refuses drafts that somehow carry bookings; remove the unaudited path too.
drop policy if exists events_delete_owner on public.events;
