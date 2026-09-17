-- Descriptions are optional in the Admin event form, so publish must accept
-- an event whose draft normalization stored a blank description as NULL.
CREATE OR REPLACE FUNCTION private.publish_event_v2_impl(
  p_event_id uuid,
  p_request_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := private.require_role('admin');
  v_workspace public.workspaces;
  v_event public.events;
  v_active_count integer;
  v_field_errors jsonb := '{}'::jsonb;
BEGIN
  SELECT * INTO v_workspace FROM public.workspaces
  WHERE owner_user_id = v_actor_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'WORKSPACE_UNAVAILABLE';
  END IF;
  PERFORM private.assert_workspace_publishable(v_workspace);

  SELECT * INTO v_event FROM public.events
  WHERE id = p_event_id AND workspace_id = v_workspace.id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'EVENT_NOT_FOUND';
  END IF;
  IF v_event.status <> 'draft' THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'EVENT_NOT_PUBLISHABLE';
  END IF;

  IF nullif(btrim(v_event.name), '') IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('name', 'Nama acara belum diisi.');
  END IF;
  IF v_event.banner_object_path IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('banner', 'Banner acara belum diunggah.');
  END IF;
  IF v_event.start_at IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('start_at', 'Tanggal dan waktu mulai belum diisi.');
  END IF;
  IF v_event.end_at IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('end_at', 'Tanggal dan waktu selesai belum diisi.');
  ELSIF v_event.end_at <= now() THEN
    v_field_errors := v_field_errors || jsonb_build_object('end_at', 'Tanggal dan waktu selesai harus masih di masa depan.');
  END IF;
  IF v_event.timezone_name IS DISTINCT FROM 'Asia/Jakarta' THEN
    v_field_errors := v_field_errors || jsonb_build_object('timezone_name', 'Zona waktu acara harus Asia/Jakarta.');
  END IF;
  IF coalesce(cardinality(v_event.operational_days), 0) = 0 THEN
    v_field_errors := v_field_errors || jsonb_build_object('operational_days', 'Pilih minimal satu hari operasional.');
  END IF;
  IF v_event.opens_at_local IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('opens_at_local', 'Jam buka operasional belum diisi.');
  END IF;
  IF v_event.closes_at_local IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('closes_at_local', 'Jam tutup operasional belum diisi.');
  END IF;
  IF nullif(btrim(v_event.location_name), '') IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('location_name', 'Nama lokasi belum diisi.');
  END IF;
  IF nullif(btrim(v_event.location_address), '') IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('location_address', 'Alamat lokasi belum diisi.');
  END IF;
  IF v_event.capacity_grams IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('capacity_grams', 'Kapasitas donasi belum diisi.');
  END IF;
  IF v_event.max_donation_per_user_grams IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('max_donation_per_user_grams', 'Batas donasi per donatur belum diisi.');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.event_criteria WHERE event_id = v_event.id) THEN
    v_field_errors := v_field_errors || jsonb_build_object('criteria', 'Pilih minimal satu kriteria donasi.');
  END IF;
  IF nullif(btrim(v_event.receiver_name), '') IS NULL
    OR nullif(btrim(v_event.receiver_phone), '') IS NULL
    OR nullif(btrim(v_event.receiver_address), '') IS NULL THEN
    v_field_errors := v_field_errors || jsonb_build_object('receiver', 'Data penerima dari profil workspace belum lengkap.');
  END IF;

  IF v_field_errors <> '{}'::jsonb THEN
    RAISE EXCEPTION USING
      errcode = '23514',
      message = 'EVENT_PUBLISH_FIELDS_REQUIRED',
      detail = v_field_errors::text;
  END IF;

  SELECT count(*) INTO v_active_count FROM public.events
  WHERE workspace_id = v_workspace.id AND status IN ('upcoming', 'ongoing');
  IF v_active_count >= 5 THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'ACTIVE_EVENT_LIMIT';
  END IF;

  UPDATE public.events SET
    status = CASE WHEN start_at <= now() THEN 'ongoing'::public.event_status ELSE 'upcoming'::public.event_status END,
    published_at = now(), version = version + 1
  WHERE id = v_event.id RETURNING * INTO v_event;
  INSERT INTO public.audit_events(actor_type, actor_id, workspace_id, entity_type, entity_id, action_code, request_id)
  VALUES ('admin', v_actor_id::text, v_workspace.id, 'event', v_event.id, 'event.published', p_request_id);
  RETURN private.event_user_json(v_event);
END;
$$;
