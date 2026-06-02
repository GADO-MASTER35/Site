-- ============================================================
--  SUPABASE · PAGAMENTOS + TRAVA DO TELEGRAM  (rode UMA vez,
--  DEPOIS do supabase-setup.sql)
--  Cole em: Supabase > SQL Editor > New query > Run
--
--  Objetivo: o link do Telegram NUNCA fica publico. Ele so e
--  entregue por uma Edge Function depois que o webhook do
--  DebitoPay confirmar o pagamento (payment.completed).
-- ============================================================

-- 1) Tabela de pagamentos confirmados (privada: so as Edge Functions
--    acessam, via service_role, que ignora RLS).
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  provider_ref text,            -- id da transacao no DebitoPay (payment_id/transaction_id)
  our_ref text,                 -- referencia que NOS geramos: "<creatorId>__<plan>__<rand>"
  creator_id uuid references public.creators(id) on delete set null,
  plan text,                    -- 'vip' | 'access'
  customer_email text,
  customer_phone text,
  amount numeric,
  currency text default 'MZN',
  status text default 'pending',-- 'completed' | 'failed' | 'pending'
  telegram_link text,           -- snapshot do link entregue (so no plano VIP)
  event text,
  raw jsonb,                    -- payload bruto do webhook (ajuda a depurar)
  created_at timestamptz default now()
);
create index if not exists payments_our_ref_idx     on public.payments(our_ref);
create index if not exists payments_provider_ref_idx on public.payments(provider_ref);

alter table public.payments enable row level security;
-- ninguem do navegador (anon/authenticated) le/escreve direto:
revoke all on public.payments from anon, authenticated;
-- o admin pode VER os pagamentos no painel (opcional):
drop policy if exists "admin ve pagamentos" on public.payments;
create policy "admin ve pagamentos" on public.payments
  for select using ( public.is_admin() );

-- 2) ESCONDER o telegram_link do publico.
--    Criamos uma VIEW publica que expoe tudo MENOS o telegram_link,
--    e tiramos a leitura publica direta da tabela base.
create or replace view public.creators_public
with (security_invoker = off) as
  select id, name, handle, bio, description,
         photos_count, videos_count, is_live, avatar_url,
         gallery, schedule,
         access_price, checkout_access, vip_price, checkout_vip,
         sort_order, updated_at
  from public.creators
  where approved = true;

grant select on public.creators_public to anon, authenticated;

-- remove a policy antiga que deixava o publico ler a tabela base
-- (com o telegram_link). Agora o publico so enxerga a VIEW acima.
drop policy if exists "publico ve aprovados" on public.creators;

-- ============================================================
--  PRONTO. Proximos passos no guia SETUP-PAGAMENTO.md:
--   - publicar as Edge Functions debitopay-webhook e unlock
--   - configurar no DebitoPay: webhook -> URL da function,
--     e URL de retorno -> .../obrigado.html
--   - guardar o telegram_link de cada criadora no painel admin
--     (campo "Link do grupo/canal do Telegram")
-- ============================================================
