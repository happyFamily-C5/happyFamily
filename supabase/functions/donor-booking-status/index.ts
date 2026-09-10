import { verifyDonorToken } from "../_shared/crypto.ts";
import { ApiError, method, serve, success } from "../_shared/http.ts";
import { adminClient, rpc } from "../_shared/supabase.ts";

serve("donor-booking-status", async (req, requestId) => {
  method(req, "GET");
  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) throw new ApiError("DONOR_TOKEN_INVALID", 401);
  const claims = await verifyDonorToken(authorization.slice(7).trim());
  const data = await rpc<Record<string, unknown>>(adminClient(), "donor_booking_status_v1", {
    p_booking_id: claims.sub,
  });
  return success(data, requestId);
});
