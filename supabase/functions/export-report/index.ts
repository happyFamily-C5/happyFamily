import { decrypt } from "../_shared/crypto.ts";
import { csvLine } from "../_shared/csv.ts";
import { method, readJson, serve } from "../_shared/http.ts";
import { adminClient, organizerSession, rpc } from "../_shared/supabase.ts";

type ReportRow = Record<string, unknown> & {
  donor_name_ciphertext: string;
  donor_name_nonce: string;
  donor_phone_ciphertext: string;
  donor_phone_nonce: string;
  crypto_key_version: number;
};

const headers = [
  "booking_id",
  "event_name",
  "booking_time",
  "status",
  "estimated_weight_grams",
  "actual_weight_grams",
  "condition",
  "rejection_reason",
  "shipping_method",
  "donor_name",
  "donor_phone",
];

serve("export-report", async (req, requestId) => {
  method(req, "POST");
  const body = await readJson(req, 8_192);
  const { user } = await organizerSession(req);
  const rows = await rpc<ReportRow[]>(adminClient(), "export_report_rows_v1", {
    p_actor_id: user.id,
    p_event_id: typeof body.event_id === "string" ? body.event_id : null,
    p_created_from: typeof body.created_from === "string" ? body.created_from : null,
    p_created_to: typeof body.created_to === "string" ? body.created_to : null,
  });
  const lines = [csvLine(headers)];
  for (const row of rows) {
    const name = await decrypt(
      row.donor_name_ciphertext,
      row.donor_name_nonce,
      row.crypto_key_version,
    );
    const phone = await decrypt(
      row.donor_phone_ciphertext,
      row.donor_phone_nonce,
      row.crypto_key_version,
    );
    lines.push(csvLine([
      row.public_booking_id,
      row.event_name,
      row.created_at,
      row.status,
      row.estimated_weight_grams,
      row.actual_weight_grams,
      row.condition,
      row.rejection_reason,
      row.shipping_method,
      name,
      phone,
    ]));
  }
  return new Response(`\uFEFF${lines.join("\r\n")}\r\n`, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="kumpul-report-${
        new Date().toISOString().slice(0, 10)
      }.csv"`,
      "cache-control": "no-store",
      "x-request-id": requestId,
    },
  });
});
