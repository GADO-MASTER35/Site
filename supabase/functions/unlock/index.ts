// ============================================================
//  Edge Function: unlock
//  A pagina obrigado.html chama esta function com a referencia
//  do pagamento. Se existir um pagamento CONFIRMADO para aquela
//  referencia, devolve o link do Telegram. Senao, paid:false.
//
//  Deploy:
//    supabase functions deploy unlock --no-verify-jwt
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const url = new URL(req.url);
  const ref =
    url.searchParams.get("reference") ||
    url.searchParams.get("ref") ||
    url.searchParams.get("transaction_id") ||
    url.searchParams.get("payment_id") ||
    url.searchParams.get("id") ||
    "";

  if (!ref) return json({ paid: false, reason: "sem-referencia" });

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);
  const { data, error } = await sb
    .from("payments")
    .select("status, plan, telegram_link")
    .eq("status", "completed")
    .or(`our_ref.eq.${ref},provider_ref.eq.${ref}`)
    .limit(1);

  if (error) return json({ paid: false, error: error.message }, 200);

  const row = data && data[0];
  if (row && row.plan === "vip" && row.telegram_link) {
    return json({ paid: true, telegram: row.telegram_link });
  }
  if (row) return json({ paid: true, telegram: null }); // pago, mas plano sem Telegram
  return json({ paid: false });
});
