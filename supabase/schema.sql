-- Jalankan di Supabase: SQL Editor
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  nama text not null,
  role text not null check (role in ('super_admin','admin'))
);
create table settings (
  id int primary key default 1 check (id = 1),
  harga_harian int not null default 20000,
  harga_member int not null default 150000,
  durasi_member_hari int not null default 30,
  retensi_bulan int not null default 6
);
insert into settings default values;
create table members (
  id uuid primary key default gen_random_uuid(),
  no_member text unique not null,
  nama text not null,
  no_hp text, alamat text,
  admin_id uuid references profiles(id),
  created_at timestamptz default now()
);
create table memberships (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references members(id) on delete cascade,
  tanggal_mulai date not null,
  tanggal_berakhir date not null,
  harga int not null,
  tipe_pembayaran text not null,
  admin_id uuid references profiles(id),
  created_at timestamptz default now()
);
create table daily_visits (
  id uuid primary key default gen_random_uuid(),
  nama_pelanggan text,
  harga int not null,
  tipe_pembayaran text not null,
  admin_id uuid not null references profiles(id),
  created_at timestamptz default now()
);
create table monthly_summary (
  bulan date primary key,
  total_pelanggan int not null default 0,
  pendapatan_harian bigint not null default 0
);
create table audit_log (
  id bigserial primary key, aksi text, detail text,
  user_id uuid, created_at timestamptz default now()
);
create index on daily_visits (created_at);
create index on memberships (member_id);

create or replace function is_super() returns boolean
language sql security definer stable set search_path = public as
$$ select exists(select 1 from profiles where id = auth.uid() and role = 'super_admin') $$;

alter table profiles enable row level security;
alter table settings enable row level security;
alter table members enable row level security;
alter table memberships enable row level security;
alter table daily_visits enable row level security;
alter table monthly_summary enable row level security;
alter table audit_log enable row level security;

create policy p_sel on profiles for select to authenticated using (id = auth.uid() or is_super());
create policy s_sel on settings for select to authenticated using (true);
create policy s_upd on settings for update to authenticated using (is_super());
create policy m_sel on members for select to authenticated using (true);
create policy m_ins on members for insert to authenticated with check (admin_id = auth.uid());
create policy ms_sel on memberships for select to authenticated using (true);
create policy ms_ins on memberships for insert to authenticated with check (admin_id = auth.uid());
create policy v_sel on daily_visits for select to authenticated using (admin_id = auth.uid() or is_super());
create policy v_ins on daily_visits for insert to authenticated with check (admin_id = auth.uid());
create policy sum_sel on monthly_summary for select to authenticated using (is_super());
create policy a_sel on audit_log for select to authenticated using (is_super());

-- Statistik dashboard per admin (zona waktu WIB)
create or replace function dashboard_stats(p_date date)
returns table(admin_id uuid, nama text, pelanggan int, pendapatan bigint,
              member_baru int, pendapatan_member bigint)
language sql security definer stable set search_path = public as $$
  select p.id, p.nama,
    (select count(*) from daily_visits v where v.admin_id = p.id
       and (v.created_at at time zone 'Asia/Jakarta')::date = p_date)::int,
    (select coalesce(sum(v.harga),0) from daily_visits v where v.admin_id = p.id
       and (v.created_at at time zone 'Asia/Jakarta')::date = p_date)::bigint,
    (select count(*) from members m where m.admin_id = p.id
       and date_trunc('month', m.created_at at time zone 'Asia/Jakarta') = date_trunc('month', p_date::timestamp))::int,
    (select coalesce(sum(ms.harga),0) from memberships ms where ms.admin_id = p.id
       and date_trunc('month', ms.created_at at time zone 'Asia/Jakarta') = date_trunc('month', p_date::timestamp))::bigint
  from profiles p where p.role = 'admin' and is_super();
$$;

-- Bersihkan data kunjungan lama (rekap bulanan disimpan dulu)
create or replace function purge_old_data(p_bulan int)
returns int language plpgsql security definer set search_path = public as $$
declare n int; cutoff timestamptz := now() - make_interval(months => p_bulan);
begin
  if not is_super() then raise exception 'Hanya super admin'; end if;
  if p_bulan < 1 then raise exception 'Minimal 1 bulan'; end if;
  insert into monthly_summary (bulan, total_pelanggan, pendapatan_harian)
    select date_trunc('month', created_at at time zone 'Asia/Jakarta')::date, count(*), sum(harga)
    from daily_visits where created_at < cutoff group by 1
  on conflict (bulan) do update set
    total_pelanggan = monthly_summary.total_pelanggan + excluded.total_pelanggan,
    pendapatan_harian = monthly_summary.pendapatan_harian + excluded.pendapatan_harian;
  delete from daily_visits where created_at < cutoff;
  get diagnostics n = row_count;
  insert into audit_log (aksi, detail, user_id)
    values ('purge', n || ' kunjungan > ' || p_bulan || ' bulan', auth.uid());
  return n;
end $$;

-- Policy profil tambahan agar super admin dapat kelola profil
drop policy if exists p_upd on profiles;
create policy p_upd on profiles for update to authenticated using (is_super());
drop policy if exists p_ins on profiles;
create policy p_ins on profiles for insert to authenticated with check (is_super());

-- ==============================================================================
-- CARA MENETAPKAN ROLE UNTUK 2 USER (ADMIN & SUPER ADMIN)
-- ==============================================================================

-- 1. PILIHAN UTAMA (OTOMATIS):
-- Query ini langsung menetapkan user ke-1 sebagai super_admin dan user ke-2 sebagai admin:
insert into public.profiles (id, nama, role)
select 
  u.id,
  case 
    when row_number() over (order by u.created_at asc) = 1 then 'Super Admin'
    else 'Admin ' || (row_number() over (order by u.created_at asc) - 1)
  end as nama,
  case 
    when row_number() over (order by u.created_at asc) = 1 then 'super_admin'
    else 'admin'
  end as role
from auth.users u
on conflict (id) do update set role = excluded.role, nama = excluded.nama;

-- 2. PILIHAN BERDASARKAN EMAIL (Sesuaikan email):
-- insert into public.profiles (id, nama, role)
-- select id, 'Super Admin', 'super_admin' from auth.users where email = 'super@gym.com'
-- on conflict (id) do update set role = excluded.role, nama = excluded.nama;
--
-- insert into public.profiles (id, nama, role)
-- select id, 'Admin 1', 'admin' from auth.users where email = 'admin@gym.com'
-- on conflict (id) do update set role = excluded.role, nama = excluded.nama;

-- 3. CEK HASIL:
-- select p.id, u.email, p.nama, p.role from public.profiles p join auth.users u on u.id = p.id;

-- 4. TRIGGER OTOMATIS: Agar setiap kali user baru dibuat di Auth, langsung dibuatkan profil:
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  jml int;
begin
  select count(*) into jml from public.profiles;
  insert into public.profiles (id, nama, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nama', case when jml = 0 then 'Super Admin' else 'Admin ' || jml end),
    coalesce(new.raw_user_meta_data->>'role', case when jml = 0 then 'super_admin' else 'admin' end)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
