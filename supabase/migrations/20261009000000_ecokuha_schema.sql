-- EcoKuha / EcoKuha: Supabase schema (migrated from Firebase Firestore)
-- Replaces the earlier README-based draft with the app's real data model.
-- Conventions:
--   * Firestore doc id (auth uid) -> uuid primary key = auth.users.id
--   * Firestore subcollections -> tables with an owner FK
--   * Deeply nested/legacy maps the app reads as-is -> jsonb columns
--   * Cloud Functions logic -> triggers/functions in the non-exposed `private` schema + pg_cron

-- ============================================================
-- 0. RESET (previous draft was empty)
-- ============================================================
do $$ declare r record; begin
  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('drop table if exists public.%I cascade', r.tablename);
  end loop;
  for r in select t.typname from pg_type t join pg_namespace n on n.oid = t.typnamespace
           where n.nspname = 'public' and t.typtype = 'e' loop
    execute format('drop type if exists public.%I cascade', r.typname);
  end loop;
end $$;
drop schema if exists private cascade;

create schema private;
grant usage on schema private to authenticated;

-- ============================================================
-- 1. HELPERS
-- ============================================================
create function private.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end $$;

create table public.admins (
  id uuid primary key references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.admin_logs (
  id bigint generated always as identity primary key,
  admin_id uuid not null references public.admins(id) on delete cascade,
  action text not null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index on public.admin_logs(admin_id, created_at desc);

create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins where id = (select auth.uid()) and is_active)
$$;

-- true while a trusted trigger is writing system-managed columns
create function private.is_system_update() returns boolean
language sql stable set search_path = '' as $$
  select coalesce(current_setting('app.system_update', true), '') = '1'
$$;

-- ============================================================
-- 2. USERS (households / collectors / junkshops) -- id = auth uid
-- ============================================================
create table public.households (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  phone text,
  date_of_birth text,
  profile_image_url text,
  role text not null default 'household' check (role = 'household'),
  city text,
  location jsonb,                 -- {lat,lng,address,note}
  location_2 jsonb,
  is_active boolean not null default true,
  is_email_verified boolean not null default false,
  is_profile_complete boolean not null default false,
  application_status text,
  last_login_at timestamptz,
  sign_in_provider text,
  -- system-managed stats (formerly Cloud Function maintained)
  total_collections integer not null default 0,
  total_earnings numeric(14,2) not null default 0,
  total_recycled_kg numeric(14,3) not null default 0,
  carbon_offset numeric(14,3) not null default 0,
  stats_updated_at timestamptz,
  extra jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.households(city);

create table public.junkshops (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  business_name text,
  phone text,
  profile_image_url text,
  role text not null default 'junkshop' check (role = 'junkshop'),
  junkshop_profile jsonb not null default '{}',  -- {business:{...}, location:{...}}
  settings jsonb not null default '{}',          -- business controls
  service_radius numeric(8,2),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  blocked_households uuid[] not null default '{}',
  is_active boolean not null default true,
  is_verified boolean not null default false,
  is_email_verified boolean not null default false,
  is_profile_complete boolean not null default false,
  application_status text,
  last_login_at timestamptz,
  sign_in_provider text,
  average_rating numeric(3,2) not null default 0,
  total_ratings integer not null default 0,
  sum_of_ratings numeric(12,2) not null default 0,
  extra jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index junkshops_active_idx on public.junkshops(latitude, longitude) where is_active;

create table public.collectors (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  phone text,
  profile_image_url text,
  role text not null default 'collector' check (role = 'collector'),
  collector_profile jsonb not null default '{}', -- {personal, contact, vehicle, documents, preferred_junkshop_id}
  application_status text not null default 'pending'
    check (application_status in ('pending','approved','rejected','reapplying','fired')),
  application_attempts integer not null default 0,
  approved_at timestamptz,
  rejected_at timestamptz,
  rejection_reason text,
  fired_at timestamptz,
  preferred_junkshop_id uuid references public.junkshops(id) on delete set null,
  partner_junkshop_id uuid references public.junkshops(id) on delete set null,
  status text not null default 'offline',        -- online/offline
  active_jobs integer not null default 0,
  vehicle_type text,
  last_active timestamptz,
  is_active boolean not null default true,
  is_email_verified boolean not null default false,
  is_profile_complete boolean not null default false,
  last_login_at timestamptz,
  sign_in_provider text,
  average_rating numeric(3,2) not null default 0 check (average_rating between 0 and 5),
  total_ratings integer not null default 0,
  sum_of_ratings numeric(12,2) not null default 0,
  extra jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.collectors(preferred_junkshop_id, application_status);
create index on public.collectors(partner_junkshop_id);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text,
  updated_at timestamptz not null default now()
);
create index on public.device_tokens(user_id);

-- ============================================================
-- 3. JUNKSHOP BUSINESS DATA
-- ============================================================
create table public.material_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category text,
  unit text,
  price_min numeric(12,2),
  price_max numeric(12,2),
  household_price_min numeric(12,2),
  household_price_max numeric(12,2),
  commission numeric(12,2),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- junkshops/{id}/materials: price list AND inventory
create table public.junkshop_materials (
  id uuid primary key default gen_random_uuid(),
  junkshop_id uuid not null references public.junkshops(id) on delete cascade,
  name text not null,
  category text,
  unit text,
  description text,
  price_min numeric(12,2),
  price_max numeric(12,2),
  household_price_min numeric(12,2),
  household_price_max numeric(12,2),
  commission numeric(12,2),
  is_active boolean not null default true,
  stock numeric(14,3) not null default 0,
  total_purchase_cost numeric(14,2) not null default 0,
  avg_purchase_cost numeric(12,2) not null default 0,
  low_stock_threshold numeric(14,3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.junkshop_materials(junkshop_id, category, name);

create table public.purchases (          -- junkshops/{id}/Purchase (manual onsite)
  id uuid primary key default gen_random_uuid(),
  junkshop_id uuid not null references public.junkshops(id) on delete cascade,
  items jsonb not null default '[]',
  total_amount numeric(14,2) not null default 0,
  notes text,
  customer_name text,
  status text not null default 'completed',
  type text not null default 'manual_onsite',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.purchases(junkshop_id, created_at desc);

create table public.sales (              -- junkshops/{id}/Sales (bulk sales)
  id uuid primary key default gen_random_uuid(),
  junkshop_id uuid not null references public.junkshops(id) on delete cascade,
  items jsonb not null default '[]',
  total_amount numeric(14,2) not null default 0,
  buyer text,
  status text not null default 'completed',
  type text not null default 'bulk_sale',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.sales(junkshop_id, created_at desc);

create table public.activity_logs (      -- junkshops/{id}/activity_logs
  id uuid primary key default gen_random_uuid(),
  junkshop_id uuid not null references public.junkshops(id) on delete cascade,
  type text not null,
  title text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index on public.activity_logs(junkshop_id, created_at desc);
create index on public.activity_logs(junkshop_id, type, created_at desc);

create table public.junkshop_logs (      -- junkshops/{id}/logs (LoggingService)
  id uuid primary key default gen_random_uuid(),
  junkshop_id uuid not null references public.junkshops(id) on delete cascade,
  type text,
  message text,
  user_id uuid references auth.users(id) on delete set null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index on public.junkshop_logs(junkshop_id, created_at desc);
create index on public.junkshop_logs(user_id);

create table public.promotions (         -- subcollection + root copy merged into one table
  id uuid primary key default gen_random_uuid(),
  junkshop_id uuid not null references public.junkshops(id) on delete cascade,
  junkshop_name text,
  title text not null,
  description text,
  type text,
  materials text[] not null default '{}',  -- junkshop_materials ids
  status text not null default 'active',
  start_date timestamptz,
  end_date timestamptz,
  image_url text,
  price_boost_details jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.promotions(junkshop_id, created_at desc);
create index promotions_active_idx on public.promotions(end_date, created_at desc) where status = 'active';

-- ============================================================
-- 4. POSTINGS (households/{uid}/postings) + live tracking + ratings
-- ============================================================
create table public.postings (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  junkshop_id uuid references public.junkshops(id) on delete set null,
  collector_id uuid references public.collectors(id) on delete set null,
  status text not null default 'pending' check (status in
    ('pending','declined','reschedule','assigned','in_transit','arrived','collecting','completed','cancelled')),
  -- app-shaped payloads
  items jsonb not null default '{}',              -- {list:[...], totalEstimatedValue, estimatedTotalWeight}
  verified_items jsonb,                           -- {items, totalValue, verifiedAt, verifiedBy}
  purchased_items jsonb,                          -- {list, total, purchasedAt}
  photos jsonb not null default '{}',             -- {arrival, collection, before_after, payment}
  household jsonb not null default '{}',          -- denormalized snapshots
  junkshop jsonb not null default '{}',
  collector jsonb not null default '{}',
  location jsonb,
  unavailable_dates timestamptz[] not null default '{}',
  special_instructions text,
  notes text,
  conversation_id text,
  -- scheduling
  scheduled_date timestamptz,
  scheduled_time text,
  date_of_collection timestamptz,
  assigned_at timestamptz,
  collection_fee numeric(12,2),
  -- decline / reschedule / cancel history
  post_attempt integer not null default 0,
  declines jsonb not null default '{}',
  previous_collector jsonb,
  collector_failure_reason text,
  collector_failed_at timestamptz,
  reschedule jsonb,
  cancellation jsonb,
  -- payment / review
  is_reviewed boolean not null default false,
  total_estimated_value numeric(14,2),
  total_verified_value numeric(14,2),
  estimated_total_weight numeric(14,3),
  household_payment_amount numeric(14,2),
  total_collector_paid numeric(14,2),
  total_junkshop_cost numeric(14,2),
  profit numeric(14,2),
  -- ratings (system-managed via ratings trigger)
  is_rated boolean not null default false,
  is_collector_rated boolean not null default false,
  is_junkshop_rated boolean not null default false,
  collector_rating numeric(3,2),
  junkshop_rating numeric(3,2),
  collector_rating_data jsonb,
  junkshop_rating_data jsonb,
  rating_data jsonb,
  rating_deadline timestamptz,
  -- timeline
  completed_at timestamptz,
  collected_at timestamptz,
  verified_at timestamptz,
  reviewed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  extra jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.postings(household_id, created_at desc);
create index on public.postings(junkshop_id, status);
create index on public.postings(collector_id, status);
create index postings_junkshop_paid_idx on public.postings(junkshop_id, reviewed_at desc)
  where status = 'completed' and is_reviewed;
create index postings_overdue_idx on public.postings(date_of_collection) where status = 'assigned';

create table public.active_collections (   -- live GPS tracking, keyed by posting
  posting_id uuid primary key references public.postings(id) on delete cascade,
  collector_id uuid not null references public.collectors(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  collector_name text,
  collector_photo text,
  status text not null default 'en_route',
  destination jsonb,                       -- {lat,lng,address}
  current_location jsonb,                  -- {lat,lng,accuracy,timestamp}
  distance_remaining double precision,
  estimated_arrival timestamptz,
  is_active boolean not null default true,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_updated timestamptz
);
create index on public.active_collections(collector_id);
create index on public.active_collections(household_id);

create table public.ratings (              -- collectors/{id}/ratings + junkshops/{id}/ratings
  id uuid primary key default gen_random_uuid(),
  posting_id uuid not null references public.postings(id) on delete cascade,
  target_type text not null check (target_type in ('collector','junkshop')),
  target_id uuid not null,
  rated_by uuid not null references auth.users(id) on delete cascade,
  rating numeric(3,2) not null check (rating between 1 and 5),
  review_text text not null default '',
  selected_reasons text[] not null default '{}',
  timeliness_score numeric(3,2),
  professionalism_score numeric(3,2),
  created_at timestamptz not null default now(),
  unique (posting_id, target_type)
);
create index on public.ratings(target_type, target_id, created_at desc);
create index on public.ratings(rated_by);

create table public.leaderboard_rankings (  -- refreshed daily by pg_cron
  user_id uuid primary key references public.households(id) on delete cascade,
  rank integer not null,
  full_name text,
  profile_image_url text,
  city text,
  total_recycled_kg numeric(14,3) not null default 0,
  total_collections integer not null default 0,
  total_earnings numeric(14,2) not null default 0,
  carbon_offset numeric(14,3) not null default 0,
  score numeric(14,3) not null default 0,
  updated_at timestamptz not null default now()
);
create index on public.leaderboard_rankings(city, rank);

-- ============================================================
-- 5. MESSAGING
-- ============================================================
create table public.conversations (
  id text primary key default gen_random_uuid()::text,   -- 'posting_<id>', 'direct_*', or uuid
  participants uuid[] not null default '{}',
  participant_details jsonb not null default '{}',       -- {uid:{name,role,profileImage,joinedAt}}
  unread_counts jsonb not null default '{}',             -- {uid:int}
  last_message text,
  last_message_sender_id text,
  last_message_sender_name text,
  last_message_type text,
  last_message_timestamp timestamptz,
  posting_id text,
  posting_status text,
  is_active boolean not null default true,
  deleted_by uuid[] not null default '{}',
  is_group_chat boolean not null default false,
  group_name text,
  junkshop_id uuid references public.junkshops(id) on delete cascade,
  scheduled_for_deletion boolean not null default false,
  deletion_scheduled_at timestamptz,
  deletion_due_at timestamptz,
  deletion_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index conversations_participants_idx on public.conversations using gin (participants);
create index on public.conversations(is_group_chat, junkshop_id) where is_group_chat;
create index conversations_deletion_idx on public.conversations(deletion_due_at) where scheduled_for_deletion;
create index on public.conversations(posting_id);
create index on public.conversations(junkshop_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id text not null references public.conversations(id) on delete cascade,
  sender_id text,                         -- uid, or 'system' / 'ecokuha_assistant'
  sender_name text,
  sender_role text,
  text text,
  type text not null default 'text',      -- text | image | system | status_update
  read_by text[] not null default '{}',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index on public.messages(conversation_id, created_at);

-- AI chat history (households/junkshops/collectors/{id}/ai_conversations)
create table public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  owner_role text not null,
  title text,
  message_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.ai_conversations(owner_id, updated_at desc);

create table public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  role text not null,
  content text,
  function_calls jsonb,
  file_metadata jsonb,
  created_at timestamptz not null default now()
);
create index on public.ai_messages(conversation_id, created_at);

-- ============================================================
-- 6. updated_at triggers
-- ============================================================
do $$ declare t text; begin
  foreach t in array array['households','junkshops','collectors','material_templates','junkshop_materials',
    'promotions','postings','conversations','ai_conversations','device_tokens'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function private.set_updated_at()', t);
  end loop;
end $$;

-- ============================================================
-- 7. GUARD TRIGGERS (system-managed / privileged columns)
-- ============================================================
create function private.guard_household() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or private.is_admin() or private.is_system_update() then return new; end if;
  if new.total_collections is distinct from old.total_collections
     or new.total_earnings is distinct from old.total_earnings
     or new.total_recycled_kg is distinct from old.total_recycled_kg
     or new.carbon_offset is distinct from old.carbon_offset
     or new.stats_updated_at is distinct from old.stats_updated_at then
    raise exception 'household statistics are system managed';
  end if;
  return new;
end $$;
create trigger guard_household before update on public.households
  for each row execute function private.guard_household();

create function private.guard_junkshop() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or private.is_admin() or private.is_system_update() then return new; end if;
  if new.is_verified is distinct from old.is_verified
     or new.average_rating is distinct from old.average_rating
     or new.total_ratings is distinct from old.total_ratings
     or new.sum_of_ratings is distinct from old.sum_of_ratings then
    raise exception 'verification and rating fields are system managed';
  end if;
  return new;
end $$;
create trigger guard_junkshop before update on public.junkshops
  for each row execute function private.guard_junkshop();

create function private.guard_collector() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  allowed text[] := array['application_status','approved_at','rejected_at','rejection_reason',
                          'updated_at','status','fired_at','partner_junkshop_id'];
begin
  if uid is null or private.is_admin() or private.is_system_update() then return new; end if;
  if new.average_rating is distinct from old.average_rating
     or new.total_ratings is distinct from old.total_ratings
     or new.sum_of_ratings is distinct from old.sum_of_ratings then
    raise exception 'rating fields are system managed';
  end if;
  if uid = old.id then
    if new.application_status is distinct from old.application_status
       and new.application_status not in ('pending','reapplying') then
      raise exception 'collectors cannot approve, reject or dismiss themselves';
    end if;
    if new.partner_junkshop_id is distinct from old.partner_junkshop_id
       or new.fired_at is distinct from old.fired_at then
      raise exception 'partner junkshop and dismissal are managed by the junkshop';
    end if;
    return new;
  elsif uid in (old.preferred_junkshop_id, old.partner_junkshop_id) then
    if (to_jsonb(new) - allowed) is distinct from (to_jsonb(old) - allowed) then
      raise exception 'junkshops may only update application/partner status fields';
    end if;
    return new;
  end if;
  raise exception 'not allowed to modify this collector';
end $$;
create trigger guard_collector before update on public.collectors
  for each row execute function private.guard_collector();

create function private.guard_posting() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.household_id is distinct from old.household_id then
    raise exception 'household_id is immutable';
  end if;
  -- timeline defaults the old app never wrote reliably
  if new.status = 'completed' and old.status is distinct from 'completed' and new.completed_at is null then
    new.completed_at := now();
  end if;
  if new.is_reviewed and not old.is_reviewed and new.reviewed_at is null then
    new.reviewed_at := now();
  end if;
  return new;
end $$;
create trigger guard_posting before update on public.postings
  for each row execute function private.guard_posting();

-- ============================================================
-- 8. BUSINESS LOGIC (replaces Cloud Functions)
-- ============================================================
-- onPostingCompleted: household stats
create function private.on_posting_stats() returns trigger
language plpgsql security definer set search_path = '' as $$
declare earned numeric := 0;
begin
  perform set_config('app.system_update', '1', true);
  if new.status = 'completed' and old.status is distinct from 'completed' then
    update public.households set total_collections = total_collections + 1, stats_updated_at = now()
     where id = new.household_id;
  end if;
  if new.is_reviewed and not old.is_reviewed then
    if jsonb_typeof(new.purchased_items) = 'object' then
      earned := coalesce(nullif(new.purchased_items->>'total', '')::numeric, 0);
    end if;
    update public.households set total_earnings = total_earnings + earned, stats_updated_at = now()
     where id = new.household_id;
  end if;
  perform set_config('app.system_update', '0', true);
  return null;
end $$;
create trigger on_posting_stats after update on public.postings
  for each row when (new.status is distinct from old.status or new.is_reviewed is distinct from old.is_reviewed)
  execute function private.on_posting_stats();

-- submitCollectorRating / submitJunkshopRating: aggregates + posting flags
create function private.on_rating_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
declare payload jsonb;
begin
  perform set_config('app.system_update', '1', true);
  payload := jsonb_build_object('rating', new.rating, 'reviewText', new.review_text,
    'selectedReasons', to_jsonb(new.selected_reasons), 'createdAt', new.created_at,
    'ratedBy', new.rated_by, 'postingId', new.posting_id, 'type', new.target_type);
  if new.target_type = 'collector' then
    update public.postings set is_collector_rated = true, collector_rating = new.rating,
           collector_rating_data = payload where id = new.posting_id;
    update public.collectors set total_ratings = total_ratings + 1,
           sum_of_ratings = sum_of_ratings + new.rating,
           average_rating = (sum_of_ratings + new.rating) / (total_ratings + 1)
     where id = new.target_id;
  else
    update public.postings set is_junkshop_rated = true, junkshop_rating = new.rating,
           junkshop_rating_data = payload where id = new.posting_id;
    update public.junkshops set total_ratings = total_ratings + 1,
           sum_of_ratings = sum_of_ratings + new.rating,
           average_rating = (sum_of_ratings + new.rating) / (total_ratings + 1)
     where id = new.target_id;
  end if;
  perform set_config('app.system_update', '0', true);
  return null;
end $$;
create trigger on_rating_insert after insert on public.ratings
  for each row execute function private.on_rating_insert();

-- onCollectorApproved: junkshop group chat
create function private.on_collector_approved() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  jid uuid; jname text; gname text; cid text; cname text;
  ids uuid[]; details jsonb;
begin
  jid := coalesce(new.preferred_junkshop_id, nullif(new.collector_profile->>'preferred_junkshop_id', '')::uuid);
  if jid is null then return null; end if;
  select coalesce(business_name, junkshop_profile->'business'->>'business_name', full_name, 'Junkshop')
    into jname from public.junkshops where id = jid;
  if not found then return null; end if;
  gname := jname || ' Group';
  cname := coalesce(new.collector_profile->'personal'->>'full_name', new.full_name, 'Collector');

  select id into cid from public.conversations where is_group_chat and junkshop_id = jid limit 1;
  if cid is null then
    select array_agg(c.id),
           jsonb_object_agg(c.id::text, jsonb_build_object(
             'name', coalesce(c.collector_profile->'personal'->>'full_name', c.full_name, 'Collector'),
             'role', 'collector', 'profileImage', c.profile_image_url, 'joinedAt', now()))
      into ids, details
      from public.collectors c
     where c.application_status = 'approved' and c.preferred_junkshop_id = jid;
    details := coalesce(details, '{}'::jsonb) || jsonb_build_object(jid::text,
      jsonb_build_object('name', jname, 'role', 'junkshop', 'profileImage', null, 'joinedAt', now()));
    insert into public.conversations (participants, participant_details, last_message, last_message_sender_id,
      last_message_sender_name, last_message_timestamp, is_group_chat, group_name, junkshop_id)
    values (array_prepend(jid, coalesce(ids, '{}')), details, 'Welcome to ' || gname || '!', 'system', 'System',
      now(), true, gname, jid)
    returning id into cid;
    insert into public.messages (conversation_id, sender_id, sender_name, text, type)
    values (cid, 'system', 'System', 'Welcome to ' || gname || '! This is the team chat for all collectors.', 'system');
  else
    update public.conversations set
      participants = (select array_agg(distinct p) from unnest(participants || new.id) p),
      participant_details = participant_details || jsonb_build_object(new.id::text, jsonb_build_object(
        'name', cname, 'role', 'collector', 'profileImage', new.profile_image_url, 'joinedAt', now())),
      last_message = cname || ' has joined the team!', last_message_sender_id = 'ecokuha_assistant',
      last_message_sender_name = 'EcoKuha Assistant', last_message_timestamp = now()
     where id = cid;
    insert into public.messages (conversation_id, sender_id, sender_name, sender_role, text, type)
    values (cid, 'ecokuha_assistant', 'EcoKuha Assistant', 'system', cname || ' has joined the team!', 'system');
  end if;
  return null;
end $$;
create trigger on_collector_approved after update on public.collectors
  for each row when (new.application_status = 'approved' and old.application_status is distinct from 'approved')
  execute function private.on_collector_approved();

-- ai_messages -> ai_conversations.message_count / updated_at (was a non-transactional increment)
create function private.sync_ai_message_count() returns trigger
language plpgsql security definer set search_path = '' as $$
declare cid uuid := coalesce(new.conversation_id, old.conversation_id);
begin
  update public.ai_conversations
     set message_count = (select count(*) from public.ai_messages where conversation_id = cid),
         updated_at = now()
   where id = cid;
  return null;
end $$;
create trigger sync_ai_message_count after insert or delete on public.ai_messages
  for each row execute function private.sync_ai_message_count();

-- checkOverdueCollections (daily)
create function private.check_overdue_collections() returns integer
language plpgsql security definer set search_path = '' as $$
declare r record; n integer := 0; reason text; cname text;
begin
  perform set_config('app.system_update', '1', true);
  for r in
    select * from public.postings
     where status = 'assigned' and date_of_collection is not null
       and (date_of_collection at time zone 'Asia/Manila')::date < (now() at time zone 'Asia/Manila')::date
  loop
    reason := format('Collection date (%s) has passed. Posting returned for reassignment.',
      to_char(r.date_of_collection at time zone 'Asia/Manila', 'FMMM/FMDD/YYYY'));
    cname := coalesce(r.collector->>'full_name', r.collector->>'name', 'Unknown');
    update public.postings set status = 'reschedule',
      previous_collector = jsonb_build_object('id', coalesce(r.collector_id::text, r.collector->>'id'),
        'name', cname, 'failedDate', r.date_of_collection, 'resetAt', now(), 'reason', reason),
      collector_failure_reason = reason, collector_failed_at = now()
     where id = r.id;
    if r.conversation_id is not null then
      insert into public.messages (conversation_id, sender_id, sender_name, sender_role, text, type, metadata)
      values (r.conversation_id, 'ecokuha_assistant', 'EcoKuha Assistant', 'system', reason, 'system',
        jsonb_build_object('postingId', r.id, 'statusUpdate', 'reassigned', 'systemData', jsonb_build_object(
          'type', 'collector_failed', 'previousCollectorId', coalesce(r.collector_id::text, r.collector->>'id'),
          'previousCollectorName', cname, 'scheduledDate', r.date_of_collection, 'reason', reason)));
      update public.conversations set last_message = reason, last_message_type = 'system',
        last_message_sender_id = 'ecokuha_assistant', last_message_sender_name = 'EcoKuha Assistant',
        last_message_timestamp = now(), posting_status = 'reschedule'
       where id = r.conversation_id;
    end if;
    n := n + 1;
  end loop;
  perform set_config('app.system_update', '0', true);
  return n;
end $$;

-- updateLeaderboardRankings (daily): score = collections*0.6 + (earnings/100)*0.4, ranked per city
create function private.refresh_leaderboard() returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  delete from public.leaderboard_rankings where true;
  insert into public.leaderboard_rankings (user_id, rank, full_name, profile_image_url, city,
    total_recycled_kg, total_collections, total_earnings, carbon_offset, score)
  select id, row_number() over (partition by city order by score desc, id), full_name, profile_image_url, city,
         total_recycled_kg, total_collections, total_earnings, carbon_offset, score
    from (select id, coalesce(full_name, 'Anonymous') as full_name, profile_image_url,
                 coalesce(city, 'Unknown') as city, total_recycled_kg, total_collections, total_earnings,
                 carbon_offset, (total_collections * 0.6 + (total_earnings / 100) * 0.4) as score
            from public.households where total_collections > 0 or total_earnings > 0) s;
  get diagnostics n = row_count;
  return n;
end $$;

-- updateHouseholdStats (manual recompute; run from SQL editor when needed)
create function private.recompute_household_stats() returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  perform set_config('app.system_update', '1', true);
  update public.households h set
    total_collections = coalesce(s.cnt, 0),
    total_earnings = coalesce(s.earned, 0),
    stats_updated_at = now()
   from (select household_id, count(*) cnt,
                sum(case when jsonb_typeof(purchased_items) = 'object'
                         then coalesce(nullif(purchased_items->>'total', '')::numeric, 0) else 0 end) earned
           from public.postings where status = 'completed' group by household_id) s
  where s.household_id = h.id;
  get diagnostics n = row_count;
  perform set_config('app.system_update', '0', true);
  return n;
end $$;

-- ============================================================
-- 9. ROW LEVEL SECURITY
-- ============================================================
do $$ declare t text; begin
  foreach t in array array['admins','admin_logs','households','junkshops','collectors','device_tokens',
    'material_templates','junkshop_materials','purchases','sales','activity_logs','junkshop_logs','promotions',
    'postings','active_collections','ratings','leaderboard_rankings','conversations','messages',
    'ai_conversations','ai_messages'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- admins
create policy admins_select on public.admins for select to authenticated using (id = (select auth.uid()));
create policy admin_logs_select on public.admin_logs for select to authenticated using (private.is_admin());
create policy admin_logs_insert on public.admin_logs for insert to authenticated
  with check (private.is_admin() and admin_id = (select auth.uid()));

-- users: readable by any signed-in user (as in Firestore rules); writable by owner/admin
create policy households_select on public.households for select to authenticated using (true);
create policy households_insert on public.households for insert to authenticated with check (id = (select auth.uid()));
create policy households_update on public.households for update to authenticated
  using (id = (select auth.uid()) or private.is_admin()) with check (id = (select auth.uid()) or private.is_admin());
create policy households_delete on public.households for delete to authenticated
  using (id = (select auth.uid()) or private.is_admin());

create policy junkshops_select on public.junkshops for select to authenticated using (true);
create policy junkshops_insert on public.junkshops for insert to authenticated with check (id = (select auth.uid()));
create policy junkshops_update on public.junkshops for update to authenticated
  using (id = (select auth.uid()) or private.is_admin()) with check (id = (select auth.uid()) or private.is_admin());
create policy junkshops_delete on public.junkshops for delete to authenticated
  using (id = (select auth.uid()) or private.is_admin());

create policy collectors_select on public.collectors for select to authenticated using (true);
create policy collectors_insert on public.collectors for insert to authenticated with check (id = (select auth.uid()));
create policy collectors_update on public.collectors for update to authenticated
  using (id = (select auth.uid()) or (select auth.uid()) in (preferred_junkshop_id, partner_junkshop_id) or private.is_admin())
  with check (id = (select auth.uid()) or (select auth.uid()) in (preferred_junkshop_id, partner_junkshop_id) or private.is_admin());
create policy collectors_delete on public.collectors for delete to authenticated using (id = (select auth.uid()));

create policy device_tokens_all on public.device_tokens for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- junkshop business data
create policy material_templates_select on public.material_templates for select to authenticated using (true);
create policy material_templates_insert on public.material_templates for insert to authenticated with check (private.is_admin());
create policy material_templates_update on public.material_templates for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy material_templates_delete on public.material_templates for delete to authenticated using (private.is_admin());

create policy junkshop_materials_select on public.junkshop_materials for select to authenticated using (true);
create policy junkshop_materials_insert on public.junkshop_materials for insert to authenticated with check (junkshop_id = (select auth.uid()));
create policy junkshop_materials_update on public.junkshop_materials for update to authenticated
  using (junkshop_id = (select auth.uid())) with check (junkshop_id = (select auth.uid()));
create policy junkshop_materials_delete on public.junkshop_materials for delete to authenticated using (junkshop_id = (select auth.uid()));

do $$ declare t text; begin
  foreach t in array array['purchases','sales'] loop
    execute format('create policy %1$s_select on public.%1$s for select to authenticated using (junkshop_id = (select auth.uid()))', t);
    execute format('create policy %1$s_insert on public.%1$s for insert to authenticated with check (junkshop_id = (select auth.uid()) and created_by = (select auth.uid()))', t);
    execute format('create policy %1$s_update on public.%1$s for update to authenticated using (junkshop_id = (select auth.uid())) with check (junkshop_id = (select auth.uid()))', t);
    execute format('create policy %1$s_delete on public.%1$s for delete to authenticated using (junkshop_id = (select auth.uid()))', t);
  end loop;
  foreach t in array array['activity_logs','junkshop_logs'] loop
    execute format('create policy %1$s_all on public.%1$s for all to authenticated using (junkshop_id = (select auth.uid())) with check (junkshop_id = (select auth.uid()))', t);
  end loop;
end $$;

create policy promotions_select on public.promotions for select to authenticated using (true);
create policy promotions_insert on public.promotions for insert to authenticated with check (junkshop_id = (select auth.uid()));
create policy promotions_update on public.promotions for update to authenticated
  using (junkshop_id = (select auth.uid())) with check (junkshop_id = (select auth.uid()));
create policy promotions_delete on public.promotions for delete to authenticated using (junkshop_id = (select auth.uid()));

-- postings: the three parties involved
create policy postings_select on public.postings for select to authenticated
  using ((select auth.uid()) in (household_id, junkshop_id, collector_id));
create policy postings_insert on public.postings for insert to authenticated
  with check (household_id = (select auth.uid()));
create policy postings_update on public.postings for update to authenticated
  using ((select auth.uid()) in (household_id, junkshop_id, collector_id))
  with check ((select auth.uid()) in (household_id, junkshop_id, collector_id));
create policy postings_delete on public.postings for delete to authenticated using (household_id = (select auth.uid()));

create policy active_collections_select on public.active_collections for select to authenticated
  using ((select auth.uid()) in (collector_id, household_id));
create policy active_collections_insert on public.active_collections for insert to authenticated
  with check (collector_id = (select auth.uid()));
create policy active_collections_update on public.active_collections for update to authenticated
  using (collector_id = (select auth.uid())) with check (collector_id = (select auth.uid()));
create policy active_collections_delete on public.active_collections for delete to authenticated
  using (collector_id = (select auth.uid())
         or exists (select 1 from public.postings p where p.id = posting_id and p.junkshop_id = (select auth.uid())));

create policy ratings_select on public.ratings for select to authenticated using (true);
create policy ratings_insert on public.ratings for insert to authenticated
  with check (rated_by = (select auth.uid()) and exists (
    select 1 from public.postings p where p.id = posting_id and p.household_id = (select auth.uid())
      and p.status = 'completed' and (p.rating_deadline is null or now() <= p.rating_deadline)
      and ((target_type = 'collector' and p.collector_id = target_id)
        or (target_type = 'junkshop' and p.junkshop_id = target_id))));

create policy leaderboard_select on public.leaderboard_rankings for select to authenticated using (true);

-- messaging
create function private.is_participant(p_conversation_id text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.conversations
                  where id = p_conversation_id and (select auth.uid()) = any(participants))
$$;

create policy conversations_select on public.conversations for select to authenticated
  using ((select auth.uid()) = any(participants));
create policy conversations_insert on public.conversations for insert to authenticated
  with check ((select auth.uid()) = any(participants));
create policy conversations_update on public.conversations for update to authenticated
  using ((select auth.uid()) = any(participants)) with check (true);
create policy conversations_delete on public.conversations for delete to authenticated
  using ((select auth.uid()) = any(participants));

create policy messages_select on public.messages for select to authenticated
  using (private.is_participant(conversation_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (private.is_participant(conversation_id));
create policy messages_update on public.messages for update to authenticated
  using (private.is_participant(conversation_id)) with check (private.is_participant(conversation_id));
create policy messages_delete on public.messages for delete to authenticated
  using (private.is_participant(conversation_id));

create policy ai_conversations_all on public.ai_conversations for all to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy ai_messages_all on public.ai_messages for all to authenticated
  using (exists (select 1 from public.ai_conversations c where c.id = conversation_id and c.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.ai_conversations c where c.id = conversation_id and c.owner_id = (select auth.uid())));

-- ============================================================
-- 10. STORAGE (replaces Firebase Storage)
--   profile-images/{uid}/...        user-uploads/{uid}/postings/...
--   posting-images/{uid}/...        promotions/{junkshopId}/...
--   documents/{uid}/... (private)
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('profile-images', 'profile-images', true, 5242880,  array['image/jpeg','image/png','image/webp']),
  ('posting-images', 'posting-images', true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('user-uploads',   'user-uploads',   true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('promotions',     'promotions',     true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('documents',      'documents',      false, 10485760, array['image/jpeg','image/png','application/pdf'])
on conflict (id) do nothing;

do $$ declare b text; begin
  foreach b in array array['profile-images','posting-images','user-uploads','promotions','documents'] loop
    execute format($f$create policy "%1$s owner select" on storage.objects for select to authenticated
      using (bucket_id = %1$L and (storage.foldername(name))[1] = (select auth.uid())::text)$f$, b);
    execute format($f$create policy "%1$s owner insert" on storage.objects for insert to authenticated
      with check (bucket_id = %1$L and (storage.foldername(name))[1] = (select auth.uid())::text)$f$, b);
    execute format($f$create policy "%1$s owner update" on storage.objects for update to authenticated
      using (bucket_id = %1$L and (storage.foldername(name))[1] = (select auth.uid())::text)
      with check (bucket_id = %1$L and (storage.foldername(name))[1] = (select auth.uid())::text)$f$, b);
    execute format($f$create policy "%1$s owner delete" on storage.objects for delete to authenticated
      using (bucket_id = %1$L and (storage.foldername(name))[1] = (select auth.uid())::text)$f$, b);
  end loop;
end $$;

-- a junkshop can read the private documents of collectors applying to it
create policy "documents junkshop reads applicant" on storage.objects for select to authenticated
  using (bucket_id = 'documents' and exists (
    select 1 from public.collectors c
     where c.id::text = (storage.foldername(name))[1]
       and (select auth.uid()) in (c.preferred_junkshop_id, c.partner_junkshop_id)));

-- ============================================================
-- 11. REALTIME (replaces Firestore snapshots())
-- ============================================================
alter publication supabase_realtime add table public.postings, public.active_collections,
  public.conversations, public.messages, public.ai_conversations, public.ai_messages,
  public.junkshop_materials, public.promotions, public.collectors;
