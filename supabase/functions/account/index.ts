import {
  activeEncryptionKeyVersion,
  canonicalJson,
  decrypt,
  encrypt,
  hmacHex,
  sha256Hex,
} from "../_shared/crypto.ts";
import { opaqueToken, publicBookingId } from "../_shared/ids.ts";
import { normalizeIndonesianPhone } from "../_shared/phone.ts";
import { ApiError, method, readJson, serve, success } from "../_shared/http.ts";
import { adminClient, organizerSession, rpc } from "../_shared/supabase.ts";
import { validateAccountBooking } from "../_shared/validation.ts";

function text(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  return typeof value === "string" ? value.trim() : "";
}

function uuid(body: Record<string, unknown>, key: string): string {
  const value = text(body, key);
  if (!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(value)) throw new ApiError("INVALID_REQUEST", 400);
  return value;
}

function email(body: Record<string, unknown>, key: string): string {
  const value = text(body, key).toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value) || value.length > 254) {
    throw new ApiError("INVALID_REQUEST", 400);
  }
  return value;
}

type AccountProfile = { display_name: string; phone_e164: string | null };
type BookingResult = {
  booking_id: string;
  public_booking_id: string;
  status: string;
  expires_at: string;
  event_snapshot: Record<string, unknown>;
  qr_token_ciphertext: string;
  qr_token_nonce: string;
  crypto_key_version: number;
  idempotent_replay: boolean;
};

// Authenticated account API. The platform verifies the bearer JWT before this
// handler runs; organizerSession additionally resolves the user and forwards
// only its immutable auth user id to service-role-only booking RPCs.
serve("account", async (req, requestId) => {
  method(req, "POST");
  const body = await readJson(req);
  const action = text(body, "action");
  const { user, client } = await organizerSession(req);
  const service = adminClient();

  switch (action) {
    case "complete_onboarding": {
      const role = text(body, "role");
      if (role !== "admin" && role !== "donor") throw new ApiError("INVALID_REQUEST", 400);
      return success(await rpc(client, "complete_onboarding_v1", { p_role: role }), requestId);
    }
    case "update_profile":
      return success(
        await rpc(client, "update_user_profile_v1", {
          p_display_name: text(body, "display_name"),
          p_phone_e164: text(body, "phone_e164"),
          p_address: text(body, "address"),
          p_location_label: text(body, "location_label"),
          p_latitude: typeof body.latitude === "number" ? body.latitude : null,
          p_longitude: typeof body.longitude === "number" ? body.longitude : null,
          p_avatar_object_path: text(body, "avatar_object_path"),
        }),
        requestId,
      );
    case "request_email_change": {
      const { data, error } = await client.auth.updateUser({ email: email(body, "email") });
      if (error) throw error;
      return success(
        {
          email: data.user?.email ?? null,
          email_change_sent_at: data.user?.email_change_sent_at ?? null,
          pending_email: data.user?.new_email ?? null,
        },
        requestId,
      );
    }
    case "update_workspace":
      return success(
        await rpc(client, "update_workspace_profile_v1", {
          p_name: text(body, "name"),
          p_address: text(body, "address"),
          p_phone_e164: text(body, "phone_e164"),
          p_email: text(body, "email"),
          p_logo_object_path: text(body, "logo_object_path"),
        }),
        requestId,
      );
    case "dashboard":
      return success(await rpc(client, "user_dashboard_v1", {}), requestId);
    case "booking_detail":
      return success(
        await rpc(client, "booking_detail_v2", { p_booking_id: uuid(body, "booking_id") }),
        requestId,
      );
    case "donation_history":
      return success(await rpc(client, "user_donation_history_v1", {}), requestId);
    case "event_history":
      return success(await rpc(client, "user_event_history_v1", {}), requestId);
    case "create_booking": {
      const key = req.headers.get("idempotency-key")?.trim() ?? "";
      if (!/^[A-Za-z0-9._:-]{8,200}$/.test(key)) {
        throw new ApiError("IDEMPOTENCY_KEY_REQUIRED", 400);
      }
      const untrustedBooking = body.booking;
      if (
        !untrustedBooking || Array.isArray(untrustedBooking) || typeof untrustedBooking !== "object"
      ) {
        throw new ApiError("INVALID_REQUEST", 400);
      }
      const eventId = uuid(body, "event_id");
      const booking = validateAccountBooking(untrustedBooking as Record<string, unknown>);
      const { data: profile, error: profileError } = await service
        .from("profiles")
        .select("display_name, phone_e164")
        .eq("id", user.id)
        .maybeSingle<AccountProfile>();
      if (profileError) throw profileError;
      if (!profile || !profile.display_name.trim() || !profile.phone_e164) {
        throw new ApiError("PROFILE_INCOMPLETE", 422);
      }
      const phone = normalizeIndonesianPhone(profile.phone_e164);
      const keyVersion = activeEncryptionKeyVersion();
      const donorName = await encrypt(profile.display_name.trim(), keyVersion);
      const donorPhone = await encrypt(phone, keyVersion);
      const qrToken = opaqueToken();
      const protectedQr = await encrypt(qrToken, keyVersion);
      const result = await rpc<BookingResult>(service, "create_account_booking_v2", {
        p_actor_id: user.id,
        p_event_id: eventId,
        p_idempotency_key: key,
        p_request_hash: await sha256Hex(canonicalJson({ event_id: eventId, booking })),
        p_booking: {
          public_booking_id: publicBookingId(),
          donor_name_ciphertext: donorName.ciphertext,
          donor_name_nonce: donorName.nonce,
          donor_phone_ciphertext: donorPhone.ciphertext,
          donor_phone_nonce: donorPhone.nonce,
          phone_lookup_hash: await hmacHex(phone),
          crypto_key_version: keyVersion,
          ...booking,
          qr_token_hash: await sha256Hex(qrToken),
          qr_token_ciphertext: protectedQr.ciphertext,
          qr_token_nonce: protectedQr.nonce,
          request_id: requestId,
        },
      });
      // On an idempotent replay the newly generated token above is discarded;
      // decrypt the durable token returned by the RPC so the client always
      // receives the same QR payload for the same booking request.
      const returnedQr = await decrypt(
        result.qr_token_ciphertext,
        result.qr_token_nonce,
        result.crypto_key_version,
      );
      return success(
        {
          booking_id: result.booking_id,
          public_booking_id: result.public_booking_id,
          status: result.status,
          expires_at: result.expires_at,
          event_snapshot: result.event_snapshot,
          qr_token: returnedQr,
          idempotent_replay: result.idempotent_replay,
        },
        requestId,
        result.idempotent_replay ? 200 : 201,
      );
    }
    case "cancel_booking": {
      const key = req.headers.get("idempotency-key")?.trim() ?? "";
      if (!/^[A-Za-z0-9._:-]{8,200}$/.test(key)) {
        throw new ApiError("IDEMPOTENCY_KEY_REQUIRED", 400);
      }
      return success(
        await rpc(service, "cancel_account_booking_v1", {
          p_actor_id: user.id,
          p_booking_id: uuid(body, "booking_id"),
          p_idempotency_key: key,
          p_request_id: requestId,
        }),
        requestId,
      );
    }
    default:
      throw new ApiError("INVALID_REQUEST", 400);
  }
});
