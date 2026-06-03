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
// link unico do Telegram (mesmo para todas) — guardado como secret, nunca no site
const TELEGRAM_VIP = Deno.env.get("TELEGRAM_VIP_LINK") ?? "";

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
  // "ja sou cliente": recuperar acesso pelo telefone usado no pagamento
  const phone = (url.searchParams.get("phone") || "").replace(/\D/g, "").slice(-9);

  if (!ref && !phone) return json({ paid: false, reason: "sem-dados" });

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);

  let rows: any[] = [];
  if (ref) {
    const { data, error } = await sb
      .from("payments").select("plan")
      .eq("status", "completed")
      .or(`our_ref.eq.${ref},provider_ref.eq.${ref}`)
      .limit(20);
    if (error) return json({ paid: false, error: error.message });
    rows = data || [];
  } else {
    // compara o telefone normalizado (so digitos, ultimos 9)
    const { data, error } = await sb
      .from("payments").select("plan, customer_phone")
      .eq("status", "completed")
      .not("customer_phone", "is", null)
      .limit(1000);
    if (error) return json({ paid: false, error: error.message });
    rows = (data || []).filter((r: any) =>
      String(r.customer_phone || "").replace(/\D/g, "").slice(-9) === phone);
  }

  if (!rows.length) return json({ paid: false });

  const vip = rows.some((r: any) => r.plan === "vip");
  // qualquer pagamento confirmado da acesso a galeria; VIP tambem da o Telegram
  return json({ paid: true, access: true, vip, telegram: vip ? (TELEGRAM_VIP || null) : null });
});
