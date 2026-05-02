create extension if not exists "uuid-ossp";

create table public.brands (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now(),
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  shopify_domain text not null unique,
  shopify_access_token text,
  plan text default 'free' check (plan in ('free','growth','professional','enterprise')),
  status text default 'pending' check (status in ('active','inactive','pending')),
  last_audit_at timestamptz
);
alter table public.brands enable row level security;
create policy "Users can only see own brands" on public.brands for all using (auth.uid() = user_id);

create table public.products (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now(),
  brand_id uuid references public.brands(id) on delete cascade not null,
  shopify_product_id text not null,
  title text not null,
  handle text not null,
  product_type text,
  vendor text,
  raw_data jsonb default '{}',
  last_synced_at timestamptz default now(),
  unique(brand_id, shopify_product_id)
);
alter table public.products enable row level security;
create policy "Users can only see own products" on public.products for all using (exists (select 1 from public.brands where brands.id = products.brand_id and brands.user_id = auth.uid()));

create table public.audits (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now(),
  brand_id uuid references public.brands(id) on delete cascade not null,
  product_id uuid references public.products(id) on delete cascade not null,
  core_score numeric(5,2) default 0,
  full_score numeric(5,2) default 0,
  category_scores jsonb default '{}',
  gaps jsonb default '[]',
  recommendations jsonb default '[]',
  status text default 'pending' check (status in ('pending','running','complete','failed'))
);
alter table public.audits enable row level security;
create policy "Users can only see own audits" on public.audits for all using (exists (select 1 from public.brands where brands.id = audits.brand_id and brands.user_id = auth.uid()));

create table public.sov_results (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now(),
  brand_id uuid references public.brands(id) on delete cascade not null,
  prompt text not null,
  ai_engine text not null check (ai_engine in ('chatgpt','gemini','perplexity')),
  brand_mentioned boolean default false,
  position integer,
  competitors_mentioned jsonb default '[]',
  raw_response text
);
alter table public.sov_results enable row level security;
create policy "Users can only see own SOV results" on public.sov_results for all using (exists (select 1 from public.brands where brands.id = sov_results.brand_id and brands.user_id = auth.uid()));

create index idx_products_brand_id on public.products(brand_id);
create index idx_audits_brand_id on public.audits(brand_id);
create index idx_audits_product_id on public.audits(product_id);
create index idx_sov_brand_id on public.sov_results(brand_id);
