// ============================================================
//  Edge Function: debitopay-webhook
//  Recebe o webhook do DebitoPay, valida a assinatura HMAC-SHA256
//  e grava o pagamento confirmado em public.payments.
//
//  Deploy:
//    supabase functions deploy debitopay-webhook --no-verify-jwt
//  Secrets (Supabase > Edge Functions > Secrets):
//    DEBITOPAY_WEBHOOK_SECRET = <segredo do webhook no DebitoPay>
//  (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY ja existem por padrao)
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SECRET       = Deno.env.get("DEBITOPAY_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function toHex(buf: ArrayBuffer) {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function hmacHex(secret: string, msg: Uint8Array) {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  return toHex(await crypto.subtle.sign("HMAC", key, msg));
}
function safeEq(a: string, b: string) {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!SECRET) return new Response(JSON.stringify({ error: "DEBITOPAY_WEBHOOK_SECRET ausente" }), { status: 503 });

  // valida assinatura sobre o corpo BRUTO
  const raw = new Uint8Array(await req.arrayBuffer());
  const sigHeader = req.headers.get("x-webhook-signature") || req.headers.get("x-debitopay-signature") || "";
  const sig = sigHeader.replace(/^sha256=/i, "").trim();
  const expected = await hmacHex(SECRET, raw);
  if (!sig || !safeEq(sig, expected)) {
    return new Response(JSON.stringify({ error: "assinatura invalida" }), { status: 401 });
  }

  let body: any = {};
  try { body = JSON.parse(new TextDecoder().decode(raw)); } catch { /* corpo nao-JSON */ }

  const type = body.event || body.type || "";
  const d = body.data || body;
  const sb = createClient(SUPABASE_URL, SERVICE_KEY);

  // identificadores possiveis (tentamos varios nomes)
  const ourRef      = d.reference || d.source_id || d.external_reference || d.metadata?.reference || "";
  const providerRef = d.payment_id || d.transaction_id || d.id || d.txid || "";
  const linkSlug    = d.link || d.payment_link || d.product || d.link_slug || d.slug || "";
  const email       = d.customer_email || d.email || "";
  const phone       = d.customer_phone || d.phone || "";
  const amount      = Number(d.amount || 0) || null;

  // descobre a criadora + plano:
  //  1) pela nossa referencia "<creatorId>__<plan>__<rand>"
  //  2) ou casando o slug do link com checkout_vip / checkout_access
  let creatorId: string | null = null;
  let plan: string | null = null;

  if (ourRef && String(ourRef).includes("__")) {
    const parts = String(ourRef).split("__");
    creatorId = parts[0] || null;
    plan = parts[1] || null;
  }
  if (!creatorId && linkSlug) {
    const { data } = await sb.from("creators")
      .select("id, checkout_vip, checkout_access")
      .or(`checkout_vip.ilike.%${linkSlug}%,checkout_access.ilike.%${linkSlug}%`)
      .limit(1);
    if (data && data[0]) {
      creatorId = data[0].id;
      plan = (data[0].checkout_vip || "").includes(linkSlug) ? "vip" : "access";
    }
  }

  // pega o telegram da criadora (so usado no plano VIP)
  let telegram: string | null = null;
  if (creatorId) {
    const { data } = await sb.from("creators").select("telegram_link").eq("id", creatorId).maybeSingle();
    telegram = data?.telegram_link || null;
  }

  const status = type === "payment.completed" ? "completed"
               : type === "payment.failed"    ? "failed"
               : "pending";

  await sb.from("payments").insert({
    provider_ref: providerRef || null,
    our_ref: ourRef || null,
    creator_id: creatorId,
    plan,
    customer_email: email || null,
    customer_phone: phone || null,
    amount,
    status,
    telegram_link: plan === "vip" ? telegram : null,
    event: type,
    raw: body,
  });

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
