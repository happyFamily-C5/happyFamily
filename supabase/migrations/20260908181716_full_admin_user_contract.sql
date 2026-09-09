-- PostgreSQL cannot safely use newly added enum values until this migration
-- has committed. Keep the enum expansion isolated; the next migration adds
-- the contract tables, constraints, and RPCs that use these values.
alter type public.booking_status add value if not exists 'processed';
alter type public.booking_status add value if not exists 'recycled';
