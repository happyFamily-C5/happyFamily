-- `\\+` was persisted as a literal backslash plus a quantifier in the prior
-- POSIX pattern. A character class expresses literal plus unambiguously.
alter table public.profiles drop constraint if exists profiles_phone_format;
alter table public.profiles add constraint profiles_phone_format
  check (phone_e164 is null or phone_e164 ~ '^[+]62[0-9]{8,13}$');

alter table public.workspaces drop constraint if exists workspaces_phone_format;
alter table public.workspaces add constraint workspaces_phone_format
  check (office_phone_e164 is null or office_phone_e164 ~ '^[+]62[0-9]{8,13}$');
