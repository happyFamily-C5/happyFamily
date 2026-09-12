-- `operations:publish_event` publishes through the idempotent v2 RPC, then
-- calls this service-role-only helper to recover or create the event's stable
-- invocation. Keeping this step idempotent lets a retry repair the response
-- when publishing committed but the Edge Function did not return its URL.
CREATE OR REPLACE FUNCTION private.ensure_event_invocation_impl(
  p_actor_id uuid,
  p_event_id uuid,
  p_token_hash text,
  p_token_ciphertext text,
  p_token_nonce text,
  p_crypto_key_version smallint,
  p_environment public.deployment_environment
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_invocation public.event_invocations;
BEGIN
  PERFORM 1
  FROM public.events AS e
  JOIN public.workspaces AS w ON w.id = e.workspace_id
  WHERE e.id = p_event_id
    AND w.owner_user_id = p_actor_id
    AND w.status = 'active'
    AND e.status IN ('upcoming', 'ongoing')
  FOR UPDATE OF e;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'EVENT_NOT_FOUND';
  END IF;

  INSERT INTO public.event_invocations (
    event_id,
    token_hash,
    token_ciphertext,
    token_nonce,
    crypto_key_version,
    environment
  ) VALUES (
    p_event_id,
    p_token_hash,
    p_token_ciphertext,
    p_token_nonce,
    p_crypto_key_version,
    p_environment
  )
  ON CONFLICT (event_id, environment) DO UPDATE SET
    token_hash = CASE
      WHEN public.event_invocations.revoked_at IS NULL
        THEN public.event_invocations.token_hash
      ELSE excluded.token_hash
    END,
    token_ciphertext = CASE
      WHEN public.event_invocations.revoked_at IS NULL
        THEN public.event_invocations.token_ciphertext
      ELSE excluded.token_ciphertext
    END,
    token_nonce = CASE
      WHEN public.event_invocations.revoked_at IS NULL
        THEN public.event_invocations.token_nonce
      ELSE excluded.token_nonce
    END,
    crypto_key_version = CASE
      WHEN public.event_invocations.revoked_at IS NULL
        THEN public.event_invocations.crypto_key_version
      ELSE excluded.crypto_key_version
    END,
    revoked_at = NULL,
    created_at = CASE
      WHEN public.event_invocations.revoked_at IS NULL
        THEN public.event_invocations.created_at
      ELSE now()
    END
  RETURNING * INTO v_invocation;

  RETURN jsonb_build_object(
    'invocation_ciphertext', v_invocation.token_ciphertext,
    'invocation_nonce', v_invocation.token_nonce,
    'crypto_key_version', v_invocation.crypto_key_version
  );
END;
$$;

CREATE OR REPLACE FUNCTION api.ensure_event_invocation_v1(
  p_actor_id uuid,
  p_event_id uuid,
  p_token_hash text,
  p_token_ciphertext text,
  p_token_nonce text,
  p_crypto_key_version smallint,
  p_environment public.deployment_environment
) RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT private.ensure_event_invocation_impl(
    p_actor_id,
    p_event_id,
    p_token_hash,
    p_token_ciphertext,
    p_token_nonce,
    p_crypto_key_version,
    p_environment
  )
$$;

REVOKE EXECUTE ON FUNCTION private.ensure_event_invocation_impl(
  uuid, uuid, text, text, text, smallint, public.deployment_environment
) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION api.ensure_event_invocation_v1(
  uuid, uuid, text, text, text, smallint, public.deployment_environment
) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.ensure_event_invocation_impl(
  uuid, uuid, text, text, text, smallint, public.deployment_environment
) TO service_role;
GRANT EXECUTE ON FUNCTION api.ensure_event_invocation_v1(
  uuid, uuid, text, text, text, smallint, public.deployment_environment
) TO service_role;
