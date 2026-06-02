# Studio — Guia de instalação (do zero)

São 3 arquivos:

- **`vitrine-agencia.html`** — o site público (a vitrine +18). É o que os clientes acessam.
- **`painel-criadora.html`** — o painel do **admin** (só você). Cadastra/edita/aprova/exclui criadoras.
- **`supabase-config.js`** — onde ficam suas credenciais (preenche **uma vez** e vale para os dois).
- **`supabase-setup.sql`** — o script do banco (roda **uma vez** no Supabase).

A vitrine **cresce sozinha**: toda criadora que você publicar no painel aparece automaticamente.

---

## Passo 1 — Criar o projeto no Supabase (grátis)

1. Acesse https://supabase.com e crie uma conta (pode usar o Google).
2. Clique em **New project**. Dê um nome (ex: `studio`), crie uma **senha do banco** (guarde) e escolha a região mais próxima.
3. Espere ~2 minutos até o projeto ficar pronto.

## Passo 2 — Pegar as credenciais

1. No projeto, vá em **Project Settings** (engrenagem) → **API** (ou **Data API**).
2. Copie:
   - **Project URL** (algo como `https://xxxx.supabase.co`)
   - **anon public** (uma chave longa)
3. Abra o arquivo **`supabase-config.js`** e cole nos lugares indicados:
   ```js
   const SUPABASE_URL = "https://xxxx.supabase.co";
   const SUPABASE_ANON_KEY = "sua_chave_anon_aqui";
   const ADMIN_EMAIL = "marcoguilundo@gmail.com"; // seu e-mail de admin
   ```
   > Se quiser usar **outro** e-mail de admin, troque aqui **E TAMBÉM** dentro do `supabase-setup.sql` (na função `is_admin`).

## Passo 3 — Criar o banco

1. No Supabase, vá em **SQL Editor** → **New query**.
2. Abra o arquivo **`supabase-setup.sql`**, copie **tudo** e cole lá.
3. Clique em **Run**. Deve aparecer "Success".

> **Upload de até 100 MB:** o SQL já deixa o bucket com limite de 100 MB, mas
> o projeto tem um limite **global** que costuma vir menor. Vá em
> **Project Settings → Storage** e ajuste o **"Upload file size limit"** para
> **100 MB (ou mais)**. Sem isso, arquivos grandes são recusados pelo servidor.

## Passo 4 — Criar a conta de admin

1. Vá em **Authentication** → **Users** → **Add user** → **Create new user**.
2. Use o **mesmo e-mail** do `ADMIN_EMAIL` e defina uma senha.
3. Marque **Auto Confirm User** (para não precisar confirmar por e-mail).
4. (Recomendado) Vá em **Authentication** → **Providers** → **Email** e **desligue** "Allow new users to sign up". Assim ninguém mais cria conta.

## Passo 5 — Usar

1. Abra **`painel-criadora.html`** no navegador, entre com o e-mail/senha do admin.
2. Clique em **+ Nova criadora**, preencha, envie as fotos.
3. Marque **Publicar na vitrine** (precisa das 3 confirmações) e **Salvar**.
4. Abra **`vitrine-agencia.html`** — a criadora já aparece. Repita para quantas quiser.

---

## Onde hospedar (quando quiser pôr no ar)

Como tudo é estático (HTML/JS), dá pra publicar grátis em:
- **Netlify** ou **Vercel** (arraste a pasta) ou **GitHub Pages**.

Suba os 4 arquivos juntos (os `.html`, o `supabase-config.js` e — opcional — este guia). O `supabase-setup.sql` é só para rodar no Supabase, não precisa subir.

> Atenção: a chave **anon** é pública por natureza (vai no navegador). A segurança real está nas regras **RLS** do banco (já configuradas no SQL): o público só lê perfis aprovados e só o admin escreve.
