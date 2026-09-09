-- Local-only, non-PII development seed. Hosted environments must publish their
-- real legal document versions explicitly during provisioning.
insert into public.legal_document_versions (
  document_type, version_identifier, public_url, environment, published_at, is_active
) values
  ('terms', 'local-v1', 'https://example.invalid/legal/terms/local-v1', 'local', now(), true),
  ('privacy', 'local-v1', 'https://example.invalid/legal/privacy/local-v1', 'local', now(), true)
on conflict (document_type, version_identifier, environment) do update set
  public_url = excluded.public_url,
  published_at = excluded.published_at,
  is_active = excluded.is_active;
