-- ============================================================
--  PORTAL DAS MODELOS  (rode UMA vez, depois do supabase-setup.sql
--  e do pagamentos-setup.sql)
--  Cada modelo cria conta, envia documento, e o admin aprova pelo
--  telefone. Cada conta gerencia UMA vitrine (a própria).
-- ============================================================

-- 1) Colunas novas em creators
alter table public.creators add column if not exists owner uuid references auth.users(id) on delete cascade;
alter table public.creators add column if not exists phone text;
alter table public.creators add column if not exists doc_url text;             -- documento (bucket privado)
alter table public.creators add column if not exists account_status text default 'pending';  -- pending | approved | rejected

-- vitrines já existentes (criadas pelo admin) ficam aprovadas
update public.creators set account_status='approved' where owner is null and account_status is distinct from 'approved';

-- UMA vitrine por conta de modelo
create unique index if not exists creators_owner_unique on public.creators(owner) where owner is not null;
create index if not exists creators_phone_idx on public.creators(phone);

-- 2) Trigger de proteção: a modelo (não-admin) NÃO pode se auto-aprovar
--    nem publicar antes de a conta ser aprovada.
create or replace function public.protect_creator()
returns trigger language plpgsql as $$
begin
  if not public.is_admin() then
    if (tg_op = 'INSERT') then
      new.owner := auth.uid();
      new.account_status := 'pending';
      new.approved := false;
    else
      new.account_status := old.account_status;   -- só o admin muda o status da conta
      new.owner := old.owner;
      if (new.account_status is distinct from 'approved') then
        new.approved := false;                    -- só aparece na vitrine se a conta foi aprovada
      end if;
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_protect_creator on public.creators;
create trigger trg_protect_creator before insert or update on public.creators
  for each row execute function public.protect_creator();

-- 3) RLS em creators: modelo mexe só na PRÓPRIA (o admin já tem "for all")
drop policy if exists "modelo le propria"   on public.creators;
drop policy if exists "modelo cria propria" on public.creators;
drop policy if exists "modelo edita propria" on public.creators;
create policy "modelo le propria"   on public.creators for select using ( owner = auth.uid() );
create policy "modelo cria propria" on public.creators for insert with check ( owner = auth.uid() );
create policy "modelo edita propria" on public.creators for update using ( owner = auth.uid() ) with check ( owner = auth.uid() );

-- 4) Payments: a modelo vê os pagamentos da PRÓPRIA vitrine
drop policy if exists "modelo ve pagamentos" on public.payments;
create policy "modelo ve pagamentos" on public.payments for select
  using ( exists (select 1 from public.creators c where c.id = payments.creator_id and c.owner = auth.uid()) );

-- 5) Storage: bucket PRIVADO para os documentos (só a modelo e o admin)
insert into storage.buckets (id, name, public, file_size_limit)
values ('model-docs','model-docs', false, 20971520)        -- 20 MB, privado
on conflict (id) do update set public=false, file_size_limit=20971520;

drop policy if exists "doc modelo envia"  on storage.objects;
drop policy if exists "doc modelo le"     on storage.objects;
drop policy if exists "doc admin tudo"    on storage.objects;
create policy "doc modelo envia" on storage.objects for insert
  with check ( bucket_id='model-docs' and (storage.foldername(name))[1] = auth.uid()::text );
create policy "doc modelo le" on storage.objects for select
  using ( bucket_id='model-docs' and ( (storage.foldername(name))[1] = auth.uid()::text or public.is_admin() ) );
create policy "doc admin tudo" on storage.objects for all
  using ( bucket_id='model-docs' and public.is_admin() ) with check ( bucket_id='model-docs' and public.is_admin() );

-- 6) Storage: a modelo também sobe o CONTEÚDO dela no bucket público
--    creator-media, na pasta dela (auth.uid()).
drop policy if exists "modelo envia content"    on storage.objects;
drop policy if exists "modelo atualiza content" on storage.objects;
drop policy if exists "modelo exclui content"   on storage.objects;
create policy "modelo envia content" on storage.objects for insert
  with check ( bucket_id='creator-media' and (storage.foldername(name))[1] = auth.uid()::text );
create policy "modelo atualiza content" on storage.objects for update
  using ( bucket_id='creator-media' and (storage.foldername(name))[1] = auth.uid()::text );
create policy "modelo exclui content" on storage.objects for delete
  using ( bucket_id='creator-media' and (storage.foldername(name))[1] = auth.uid()::text );

-- ============================================================
--  DEPOIS DISTO:
--   - Authentication > Providers > Email: LIGAR "Allow new users to
--     sign up" (pra modelos criarem conta). O admin continua sendo só
--     o e-mail definido em is_admin().
--   - A página modelo.html cuida do cadastro/login/gerência.
--   - No painel admin, "Aprovar modelo" (por telefone) ativa a conta.
-- ============================================================
