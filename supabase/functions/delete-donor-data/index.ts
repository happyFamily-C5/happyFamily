import { ApiError, method, readJson, serve, success } from "../_shared/http.ts";
import { adminClient, organizerSession, rpc } from "../_shared/supabase.ts";

serve("delete-donor-data", async (req, requestId) => {
  method(req, "DELETE");
  const body = await readJson(req, 4_096);
  const bookingId = typeof body.booking_id === "string" ? body.booking_id : "";
  if (!/^[0-9a-f-]{36}$/i.test(bookingId)) throw new ApiError("BOOKING_ID_INVALID", 422);
  const { user } = await organizerSession(req);
  await rpc<boolean>(adminClient(), "delete_donor_data_v1", {
    p_actor_id: user.id,
    p_booking_id: bookingId,
    p_request_id: requestId,
  });
  return success({ deleted: true }, requestId);
});
