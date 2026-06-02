-- ============================================================
--  SUPABASE · CONFIGURACAO DO BANCO  (rode uma vez)
--  Cole tudo isto em: Supabase > SQL Editor > New query > Run
--
--  MODELO: existe UM administrador (o e-mail definido abaixo).
--  So ele cria/edita/aprova/exclui criadoras. O publico (site)
--  enxerga apenas perfis com approved = true.
--
--  >>> TROQUE o e-mail abaixo pelo seu e-mail de admin se for outro.
-- ============================================================

-- 1) Tabela de criadoras
--    id proprio (nao depende mais de uma conta de login por criadora):
--    assim o admin pode cadastrar QUANTAS criadoras quiser.
create table if not exists public.creators (
  id uuid primary key default gen_random_uuid(),
  name text,
  handle text,
  bio text,
  description text,
  photos_count text,
  videos_count text,
  is_live boolean default false,
  avatar_url text,
  gallery jsonb default '[]'::jsonb,        -- previas (urls)
  schedule jsonb default '[]'::jsonb,       -- [{date,time,note}]
  access_price text,
  checkout_access text,
  vip_price text,
  checkout_vip text,
  telegram_link text,
  -- confirmacoes legais (o admin atesta ao publicar)
  confirmed_age boolean default false,
  confirmed_ownership boolean default false,
  confirmed_removal boolean default false,
  -- so fica visivel na vitrine quando o admin aprova
  approved boolean default false,
  sort_order int default 0,                 -- ordem na vitrine (menor = primeiro)
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ordena a vitrine de forma estavel
create index if not exists creators_order_idx
  on public.creators (approved, sort_order, updated_at desc);

-- 2) Funcao auxiliar: o usuario logado e o admin?
--    Compara o e-mail do token JWT com o e-mail de admin.
create or replace function public.is_admin()
returns boolean
language sql stable
as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'marcoguilundo@gmail.com'
$$;

-- 3) Seguranca por linha (RLS)
alter table public.creators enable row level security;

-- limpa policies antigas (se voce rodou a versao anterior deste arquivo)
drop policy if exists "modelo le o proprio perfil"   on public.creators;
drop policy if exists "modelo cria o proprio perfil" on public.creators;
drop policy if exists "modelo edita o proprio perfil" on public.creators;
drop policy if exists "publico ve perfis aprovados"  on public.creators;
drop policy if exists "admin gerencia tudo"          on public.creators;
drop policy if exists "publico ve aprovados"         on public.creators;

-- 3a) O ADMIN faz tudo (ler/criar/editar/excluir) em qualquer perfil
create policy "admin gerencia tudo"
  on public.creators for all
  using ( public.is_admin() )
  with check ( public.is_admin() );

-- 3b) O PUBLICO (chave anon, sem login) so le perfis aprovados
create policy "publico ve aprovados"
  on public.creators for select
  using ( approved = true );

-- 4) Storage: bucket publico para as imagens/videos (limite de 100 MB por arquivo)
insert into storage.buckets (id, name, public, file_size_limit)
values ('creator-media','creator-media', true, 104857600)   -- 104857600 bytes = 100 MB
on conflict (id) do update set file_size_limit = excluded.file_size_limit, public = true;

-- limpa policies antigas de storage (se existirem)
drop policy if exists "modelo envia na propria pasta"   on storage.objects;
drop policy if exists "modelo atualiza propria pasta"    on storage.objects;
drop policy if exists "leitura publica das imagens"      on storage.objects;
drop policy if exists "admin envia imagens"              on storage.objects;
drop policy if exists "admin atualiza imagens"           on storage.objects;
drop policy if exists "admin exclui imagens"             on storage.objects;
drop policy if exists "leitura publica imagens"          on storage.objects;

-- 4a) So o admin envia/edita/exclui imagens no bucket
create policy "admin envia imagens"
  on storage.objects for insert
  with check ( bucket_id = 'creator-media' and public.is_admin() );

create policy "admin atualiza imagens"
  on storage.objects for update
  using ( bucket_id = 'creator-media' and public.is_admin() );

create policy "admin exclui imagens"
  on storage.objects for delete
  using ( bucket_id = 'creator-media' and public.is_admin() );

-- 4b) Qualquer um pode VER as imagens (necessario pra vitrine publica)
create policy "leitura publica imagens"
  on storage.objects for select
  using ( bucket_id = 'creator-media' );

-- ============================================================
--  PRONTO. Depois disto:
--  1) Authentication > Users > Add user: crie o usuario admin
--     com o e-mail acima e uma senha. (Marque "Auto Confirm User".)
--  2) Authentication > Providers > Email: DESLIGUE "Allow new users
--     to sign up" para que ninguem mais consiga criar conta.
--  3) Abra painel-criadora.html, faca login como admin e cadastre
--     as criadoras. Marque "Publicar na vitrine" quando estiver pronta.
-- ============================================================
