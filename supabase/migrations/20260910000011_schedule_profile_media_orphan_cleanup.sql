-- The value lives only in hosted Vault and the Edge secret store. Keeping
-- names in this migration makes the schedule reproducible without exposing
-- the shared credential in source control.
CREATE extension IF NOT EXISTS pg_net
WITH schema extensions;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'kumpul-profile-media-orphan-cleanup';
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'kumpul-profile-media-orphan-cleanup',
    '17 20 * * *',
    $command$
      with secrets as (
        select
          max(decrypted_secret) filter (
            where name = 'kumpul_project_url'
          ) as project_url,
          max(decrypted_secret) filter (
            where name = 'kumpul_profile_media_cleanup_secret'
          ) as cleanup_secret
        from vault.decrypted_secrets
      )
      select net.http_post(
        url := rtrim(secrets.project_url, '/')
          || '/functions/v1/cleanup-orphan-profile-media',
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
