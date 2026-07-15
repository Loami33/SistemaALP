-- ============================================================
-- Migration: faturas (invoices) e chave PIX do dono
-- Rode este script no SQL Editor do Supabase do projeto.
-- Todas as alterações são aditivas — nenhuma tabela ou coluna
-- existente é removida ou renomeada.
-- ============================================================

-- 1) Configuração do dono: chave PIX usada nas faturas
create table if not exists owner_settings (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  pix_key text,
  updated_at timestamptz not null default now()
);

alter table owner_settings enable row level security;

drop policy if exists "owner_manage_own_settings" on owner_settings;
create policy "owner_manage_own_settings"
  on owner_settings for all
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- 2) Faturas enviadas para os clientes
create table if not exists invoices (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  amount numeric not null check (amount > 0),
  description text,
  pix_key_snapshot text,
  status text not null default 'pending' check (status in ('pending', 'paid')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

alter table invoices enable row level security;

-- Somente o dono (profiles.is_owner = true) gerencia faturas.
drop policy if exists "owner_manage_invoices" on invoices;
create policy "owner_manage_invoices"
  on invoices for all
  to authenticated
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_owner = true
    )
  )
  with check (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.is_owner = true
    )
  );

create index if not exists invoices_client_id_idx on invoices (client_id, created_at desc);
