-- ============================================================
-- Migration: melhorias de conversão/captação de leads
-- Rode este script no SQL Editor do Supabase do projeto.
-- Todas as alterações são aditivas (novas colunas/tabela) —
-- nenhuma coluna ou tabela existente é removida ou renomeada.
-- ============================================================

-- 1) Campos estruturados do imóvel
alter table properties
  add column if not exists bedrooms integer,
  add column if not exists bathrooms integer,
  add column if not exists parking_spots integer,
  add column if not exists area numeric,
  add column if not exists listing_type text default 'venda'
    check (listing_type in ('venda', 'aluguel'));

-- 2) Campos de confiança/autoridade na seção Sobre
alter table about_sections
  add column if not exists photo_url text,
  add column if not exists creci text,
  add column if not exists years_experience integer,
  add column if not exists deals_count integer,
  add column if not exists regions text[] default '{}';

-- 3) Campos dos depoimentos
alter table testimonials
  add column if not exists rating integer check (rating between 1 and 5),
  add column if not exists photo_url text,
  add column if not exists property_type text;

-- 4) Tabela de leads capturados pelo formulário da landing page
create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  name text not null,
  whatsapp text not null,
  goal text,             -- 'comprar' | 'vender' | 'alugar'
  budget_range text,
  neighborhood text,
  source text default 'lead_form',
  created_at timestamptz not null default now()
);

alter table leads enable row level security;

-- Qualquer visitante (chave anon, sem login) pode enviar um lead.
-- Ajuste/troque esta policy se o padrão de RLS do projeto for diferente.
drop policy if exists "public_insert_leads" on leads;
create policy "public_insert_leads"
  on leads for insert
  to anon, authenticated
  with check (true);

-- Somente o usuário autenticado vinculado àquele client_id (via profiles)
-- pode ver/gerenciar os leads recebidos.
drop policy if exists "owner_select_leads" on leads;
create policy "owner_select_leads"
  on leads for select
  to authenticated
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
        and (profiles.client_id = leads.client_id or profiles.is_owner = true)
    )
  );

drop policy if exists "owner_delete_leads" on leads;
create policy "owner_delete_leads"
  on leads for delete
  to authenticated
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
        and (profiles.client_id = leads.client_id or profiles.is_owner = true)
    )
  );

create index if not exists leads_client_id_created_at_idx on leads (client_id, created_at desc);
