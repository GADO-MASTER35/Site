# Verificação de pagamento + liberação do Telegram

O link do Telegram **não fica no site**. Ele só é entregue pela função `unlock`
**depois** que o webhook do DebitoPay confirmar o pagamento. Resumo do fluxo:

```
Cliente clica "Pagar e entrar no VIP"
   → site gera uma referência e manda pro link do DebitoPay (?reference=...)
   → cliente paga
   → DebitoPay chama o WEBHOOK (Edge Function) → grava "pago" em payments
   → DebitoPay redireciona o cliente pra /obrigado.html
   → obrigado.html chama a função UNLOCK → confirma e mostra o Telegram
```

## Pré-requisitos
1. Já rodou o `supabase-setup.sql` e preencheu o `supabase-config.js` (URL + anon key).
2. A criadora precisa existir **no banco** (cadastrada pelo **painel admin**), com:
   - o **link de pagamento VIP** no campo de checkout VIP, e
   - o **link do grupo Telegram** no campo "Link do grupo/canal do Telegram".
   > A Biby de exemplo que está fixa no código (modo demo) **não** vale para a
   > verificação real — cadastre-a pelo painel para entrar no banco.

## Passo 1 — Banco
No Supabase → SQL Editor, cole e rode o **`pagamentos-setup.sql`**.
Isso cria a tabela `payments`, esconde o `telegram_link` do público (view
`creators_public`) e libera a leitura pública só da view.

## Passo 2 — Publicar as Edge Functions
Precisa do Supabase CLI (uma vez):
```bash
npm i -g supabase
supabase login
supabase link --project-ref SEU_PROJECT_REF
```
Guarde o segredo do webhook (o mesmo que você define no DebitoPay):
```bash
supabase secrets set DEBITOPAY_WEBHOOK_SECRET="cole_o_segredo_aqui"
```
Publique as duas funções (a pasta `supabase/functions/...` já está pronta):
```bash
supabase functions deploy debitopay-webhook --no-verify-jwt
supabase functions deploy unlock --no-verify-jwt
```
As URLs ficam assim:
- Webhook: `https://SEU_PROJECT_REF.functions.supabase.co/debitopay-webhook`
- Unlock:  `https://SEU_PROJECT_REF.functions.supabase.co/unlock`

## Passo 3 — Configurar no DebitoPay (no link de pagamento VIP)
1. **Webhook / URL de notificação** → a URL do `debitopay-webhook` acima.
2. **Segredo do webhook** → o MESMO valor do `DEBITOPAY_WEBHOOK_SECRET`.
3. **URL de retorno / sucesso** → `https://SEU-SITE/obrigado.html`
4. Se o DebitoPay permitir **repassar uma referência** (campo "reference"/
   "external_id"/"metadata"), ótimo — o site já manda `?reference=...`.

## Passo 4 — Teste real (1 pagamento pequeno)
1. No site, abra a criadora → "Pagar e entrar no VIP" → pague.
2. No Supabase → Table editor → `payments`: deve aparecer a linha com
   `status = completed`. Abra a coluna `raw` e confira os nomes dos campos
   que o DebitoPay enviou (reference, payment_id, link, etc.).
3. Você deve voltar para `obrigado.html` e ver o botão do Telegram.

### Se o Telegram não aparecer
Quase sempre é o **casamento da referência**. Olhe a coluna `raw` da tabela
`payments` e me diga quais campos vieram — eu ajusto 2 linhas na função
`debitopay-webhook` (variáveis `ourRef`, `providerRef`, `linkSlug`) e na
`unlock`. O resto do fluxo não muda.

## Segurança
- A chave **anon** e a **service_role**: a service_role fica **só** nas Edge
  Functions (nunca no navegador). O site usa só a anon.
- O `telegram_link` não é mais lido pela vitrine — só sai pela função `unlock`,
  e somente quando há pagamento `completed`.
- O webhook valida a assinatura **HMAC-SHA256**; sem assinatura válida, recusa.
