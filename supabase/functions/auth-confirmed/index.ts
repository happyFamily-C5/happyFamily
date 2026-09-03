import { serve } from "../_shared/http.ts";

// Landing page for the e-mail confirmation redirect (Supabase Auth "Site
// URL"). The app has no deep-link auth handling yet, so after confirming,
// users return to the app and sign in with their new credentials.
const html = `<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>.kumpul — Email terkonfirmasi</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; display: grid; place-items: center; min-height: 100vh; margin: 0; background: #f4faf9; color: #1f3d38; }
  main { text-align: center; padding: 2rem; max-width: 22rem; }
  h1 { font-size: 1.25rem; }
  p { font-size: 0.95rem; line-height: 1.5; color: #4a6b64; }
</style>
</head>
<body>
<main>
  <h1>Email terkonfirmasi</h1>
  <p>Akun .kumpul kamu sudah aktif. Buka kembali aplikasi .kumpul, lalu masuk dengan email dan kata sandimu.</p>
</main>
</body>
</html>`;

serve("auth-confirmed", async () =>
  new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
    },
  }),
);
