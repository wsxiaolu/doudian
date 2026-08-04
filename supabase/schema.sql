-- ============================================================================
-- 抖店订单管家 · Supabase 建表脚本
-- ============================================================================
-- 用途：在 Supabase 项目的 SQL Editor 里「全选 → Run」执行一次即可。
-- 服务代码在云端不可用时（表不存在 / RLS 未开）会给出中文提示，见
-- lib/data/remote/supabase_service.dart 的 describeError。
--
-- 设计对齐 lib/data/models/*.dart 各实体的 toRemote() 字段：
--   · 时间统一用 timestamptz（UTC）；金额用 numeric(12,2)；布尔用 boolean
--   · 枚举（状态 / 来源 / 类型 / 进度）用 text + CHECK 约束，值与 *.code 一致
--   · id 用 text（客户端生成的 UUID v4）；user_id 用 uuid 关联 auth.users
--   · 软删除 is_deleted，同步时连删除一起推，保证多端一致
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. 公共触发器：自动维护 updated_at
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- 1. 订单
-- ----------------------------------------------------------------------------
create table if not exists public.orders (
  id                  text    primary key,
  user_id             uuid    not null references auth.users (id) on delete cascade,
  order_no            text    not null,
  status              text    not null
                        check (status in ('pending_payment','pending_ship','shipped','completed','after_sale','cancelled')),
  source              text    not null default 'manual'
                        check (source in ('douyin','manual')),
  customer_id         text,
  buyer_nick          text,
  receiver_name       text,
  receiver_phone      text,
  receiver_address    text,
  province            text,
  city                text,
  district            text,
  product_summary     text,
  item_count          integer not null default 0,
  total_amount        numeric(12,2) not null default 0,
  pay_amount          numeric(12,2) not null default 0,
  post_amount         numeric(12,2) not null default 0,
  discount_amount     numeric(12,2) not null default 0,
  logistics_code      text,
  logistics_name      text,
  tracking_no         text,
  buyer_words         text,
  seller_words        text,
  remark              text,
  order_time          timestamptz,
  pay_time            timestamptz,
  ship_time           timestamptz,
  finish_time         timestamptz,
  douyin_update_time  timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  is_deleted          boolean not null default false
);

-- ----------------------------------------------------------------------------
-- 2. 订单明细（子订单 / 商品行）
-- ----------------------------------------------------------------------------
create table if not exists public.order_items (
  id            text    primary key,
  user_id       uuid    not null references auth.users (id) on delete cascade,
  order_id      text    not null references public.orders (id) on delete cascade,
  sku_order_no  text,
  product_id    text,
  product_name  text    not null,
  spec          text,
  sku_id        text,
  outer_sku_id  text,
  image_url     text,
  quantity      integer not null default 1,
  sale_price    numeric(12,2) not null default 0,
  pay_amount    numeric(12,2) not null default 0,
  cost_price    numeric(12,2) not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  is_deleted    boolean not null default false
);

-- ----------------------------------------------------------------------------
-- 3. 商品档案
-- ----------------------------------------------------------------------------
create table if not exists public.products (
  id          text    primary key,
  user_id     uuid    not null references auth.users (id) on delete cascade,
  name        text    not null,
  spec        text,
  sku_code    text,
  category    text,
  image_url   text,
  cost_price  numeric(12,2) not null default 0,
  sale_price  numeric(12,2) not null default 0,
  stock       integer not null default 0,
  remark      text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);

-- ----------------------------------------------------------------------------
-- 4. 客户（买家）
-- ----------------------------------------------------------------------------
create table if not exists public.customers (
  id          text    primary key,
  user_id     uuid    not null references auth.users (id) on delete cascade,
  name        text    not null,
  buyer_nick  text,
  open_id     text,
  phone       text,
  address     text,
  remark      text,
  source      text    not null default 'manual'
                check (source in ('douyin','manual')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  is_deleted  boolean not null default false
);

-- ----------------------------------------------------------------------------
-- 5. 售后单
-- ----------------------------------------------------------------------------
create table if not exists public.after_sales (
  id                text    primary key,
  user_id           uuid    not null references auth.users (id) on delete cascade,
  order_id          text,
  order_no          text    not null,
  after_sale_no     text,
  type              text    not null
                      check (type in ('refund_only','return_refund','exchange','reship')),
  stage             text    not null
                      check (stage in ('pending','processing','finished','rejected')),
  buyer_nick        text,
  product_summary   text,
  reason            text,
  refund_amount     numeric(12,2) not null default 0,
  progress_note     text,
  return_tracking_no text,
  apply_time        timestamptz,
  finish_time       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  is_deleted        boolean not null default false
);

-- ----------------------------------------------------------------------------
-- 6. 用户资料（对应 user_profiles，email 由 auth.users 管理，不冗余存储）
-- ----------------------------------------------------------------------------
create table if not exists public.user_profiles (
  id           uuid    primary key references auth.users (id) on delete cascade,
  display_name text,
  shop_name    text,
  phone        text,
  avatar_url   text,
  updated_at   timestamptz not null default now()
);

-- 注册时自动建一条资料行，避免首次登录后拉不到 profile
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.user_profiles (id, display_name, updated_at)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''), now())
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 7. 抖店应用配置（跟着账号走，换设备登录同一账号即可继续同步）
--    注：App Key / Secret 属敏感凭据，仅存于云端该用户名下，本地不落库。
-- ----------------------------------------------------------------------------
create table if not exists public.shop_configs (
  user_id     uuid    primary key references auth.users (id) on delete cascade,
  app_key     text,
  app_secret  text,
  shop_id     text,
  updated_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 8. 自动维护 updated_at 的触发器（每张业务表）
-- ----------------------------------------------------------------------------
create trigger trg_orders_updated   before update on public.orders
  for each row execute function public.set_updated_at();
create trigger trg_order_items_updated before update on public.order_items
  for each row execute function public.set_updated_at();
create trigger trg_products_updated before update on public.products
  for each row execute function public.set_updated_at();
create trigger trg_customers_updated before update on public.customers
  for each row execute function public.set_updated_at();
create trigger trg_after_sales_updated before update on public.after_sales
  for each row execute function public.set_updated_at();
create trigger trg_user_profiles_updated before update on public.user_profiles
  for each row execute function public.set_updated_at();
create trigger trg_shop_configs_updated before update on public.shop_configs
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 9. 索引（账号维度查询 / 增量同步水位线高频访问）
-- ----------------------------------------------------------------------------
create index if not exists idx_orders_user          on public.orders (user_id);
create index if not exists idx_orders_user_updated  on public.orders (user_id, updated_at);
create index if not exists idx_orders_no            on public.orders (order_no);
create index if not exists idx_order_items_user     on public.order_items (user_id);
create index if not exists idx_order_items_order    on public.order_items (order_id);
create index if not exists idx_products_user        on public.products (user_id);
create index if not exists idx_customers_user       on public.customers (user_id);
create index if not exists idx_customers_openid     on public.customers (open_id);
create index if not exists idx_after_sales_user     on public.after_sales (user_id);
create index if not exists idx_after_sales_order    on public.after_sales (order_id);

-- ----------------------------------------------------------------------------
-- 10. 行级安全（RLS）：所有表按 user_id 隔离，用户只能读写自己的数据
-- ----------------------------------------------------------------------------
alter table public.orders          enable row level security;
alter table public.order_items     enable row level security;
alter table public.products        enable row level security;
alter table public.customers       enable row level security;
alter table public.after_sales     enable row level security;
alter table public.user_profiles   enable row level security;
alter table public.shop_configs    enable row level security;

-- 业务表通用策略：owner 可读写
create policy orders_owner       on public.orders          for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy order_items_owner   on public.order_items     for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy products_owner      on public.products        for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy customers_owner     on public.customers       for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy after_sales_owner   on public.after_sales     for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy shop_configs_owner  on public.shop_configs    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 资料表策略：用户只能看/改自己的资料
create policy user_profiles_select on public.user_profiles for select using (auth.uid() = id);
create policy user_profiles_upsert on public.user_profiles for insert with check (auth.uid() = id);
create policy user_profiles_update on public.user_profiles for update using (auth.uid() = id) with check (auth.uid() = id);
