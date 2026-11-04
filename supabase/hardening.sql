-- =====================================================================
-- PENGUATAN SISTEM  (jalankan SETELAH fix_roles.sql; aman diulang)
--  1. Harga ditentukan SERVER (admin tidak bisa memalsukan harga)
--  2. Pendaftaran member atomik (member + membership sekaligus)
--  3. Admin bisa membatalkan salah input & mengubah data member
--  4. Tanggal memakai zona waktu WIB (bukan jam HP)
--  5. Pencarian member (nama / no HP), rekap bulanan, member aktif
-- =====================================================================

alter table daily_visits add column if not exists batal boolean not null default false;
alter table members add column if not exists updated_at timestamptz;
create index if not exists daily_visits_admin_created on daily_visits (admin_id, created_at);
create index if not exists memberships_created on memberships (created_at);

create or replace function wib_today() returns date
language sql stable as $$ select (now() at time zone 'Asia/Jakarta')::date $$;

-- Insert langsung dari aplikasi ditutup; semua lewat fungsi di bawah.
drop policy if exists m_ins on members;
drop policy if exists ms_ins on memberships;
drop policy if exists v_ins on daily_visits;

-- ---------- Pelanggan harian ----------
create or replace function catat_kunjungan(p_nama text, p_tipe text)
returns int language plpgsql security definer set search_path = public as $$
declare h int;
begin
  if not is_staff() then raise exception 'Akun tidak punya akses'; end if;
  if p_tipe not in ('Tunai','Transfer','QRIS') then raise exception 'Tipe pembayaran tidak valid'; end if;
  select harga_harian into h from settings where id = 1;
  insert into daily_visits (nama_pelanggan, harga, tipe_pembayaran, admin_id)
    values (nullif(trim(coalesce(p_nama,'')), ''), h, p_tipe, auth.uid());
  return h;
end $$;

create or replace function kunjungan_saya_hari_ini()
returns table(id uuid, nama_pelanggan text, harga int, tipe_pembayaran text, waktu timestamptz, batal boolean)
language sql security definer stable set search_path = public as $$
  select v.id, v.nama_pelanggan, v.harga, v.tipe_pembayaran, v.created_at, v.batal
  from daily_visits v
  where v.admin_id = auth.uid() and is_staff()
    and (v.created_at at time zone 'Asia/Jakarta')::date = wib_today()
  order by v.created_at desc limit 100
$$;

create or replace function batalkan_kunjungan(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v daily_visits%rowtype;
begin
  select * into v from daily_visits where id = p_id;
  if not found then raise exception 'Data tidak ditemukan'; end if;
  if not (is_super() or (is_staff() and v.admin_id = auth.uid()
          and (v.created_at at time zone 'Asia/Jakarta')::date = wib_today())) then
    raise exception 'Hanya bisa membatalkan input sendiri pada hari yang sama';
  end if;
  update daily_visits set batal = true where id = p_id;
  insert into audit_log (aksi, detail, user_id)
    values ('batal_kunjungan', 'Rp' || v.harga || ' ' || v.tipe_pembayaran, auth.uid());
end $$;

-- ---------- Member ----------
create or replace function daftar_member(p_no text, p_nama text, p_hp text, p_alamat text, p_tipe text)
returns int language plpgsql security definer set search_path = public as $$
declare s settings%rowtype; mid uuid; v_no text := trim(coalesce(p_no,''));
begin
  if not is_staff() then raise exception 'Akun tidak punya akses'; end if;
  if v_no = '' or trim(coalesce(p_nama,'')) = '' then raise exception 'No. member dan nama wajib diisi'; end if;
  if p_tipe not in ('Tunai','Transfer','QRIS') then raise exception 'Tipe pembayaran tidak valid'; end if;
  if exists (select 1 from members where lower(no_member) = lower(v_no)) then
    raise exception 'No. member % sudah terpakai', v_no;
  end if;
  select * into s from settings where id = 1;
  insert into members (no_member, nama, no_hp, alamat, admin_id)
    values (v_no, trim(p_nama), nullif(trim(coalesce(p_hp,'')), ''), nullif(trim(coalesce(p_alamat,'')), ''), auth.uid())
    returning id into mid;
  insert into memberships (member_id, tanggal_mulai, tanggal_berakhir, harga, tipe_pembayaran, admin_id)
    values (mid, wib_today(), wib_today() + s.durasi_member_hari, s.harga_member, p_tipe, auth.uid());
  return s.harga_member;
end $$;

create or replace function perpanjang_member(p_member_id uuid, p_tipe text)
returns int language plpgsql security definer set search_path = public as $$
declare s settings%rowtype; akhir date; mulai date;
begin
  if not is_staff() then raise exception 'Akun tidak punya akses'; end if;
  if p_tipe not in ('Tunai','Transfer','QRIS') then raise exception 'Tipe pembayaran tidak valid'; end if;
  if not exists (select 1 from members where id = p_member_id) then raise exception 'Member tidak ditemukan'; end if;
  select * into s from settings where id = 1;
  select max(tanggal_berakhir) into akhir from memberships where member_id = p_member_id;
  mulai := greatest(wib_today(), coalesce(akhir, wib_today()));
  insert into memberships (member_id, tanggal_mulai, tanggal_berakhir, harga, tipe_pembayaran, admin_id)
    values (p_member_id, mulai, mulai + s.durasi_member_hari, s.harga_member, p_tipe, auth.uid());
  return s.harga_member;
end $$;

create or replace function ubah_member(p_id uuid, p_no text, p_nama text, p_hp text, p_alamat text)
returns void language plpgsql security definer set search_path = public as $$
declare v_no text := trim(coalesce(p_no,''));
begin
  if not is_staff() then raise exception 'Akun tidak punya akses'; end if;
  if v_no = '' or trim(coalesce(p_nama,'')) = '' then raise exception 'No. member dan nama wajib diisi'; end if;
  if exists (select 1 from members where lower(no_member) = lower(v_no) and id <> p_id) then
    raise exception 'No. member % sudah terpakai', v_no;
  end if;
  update members set no_member = v_no, nama = trim(p_nama),
    no_hp = nullif(trim(coalesce(p_hp,'')), ''), alamat = nullif(trim(coalesce(p_alamat,'')), ''),
    updated_at = now()
  where id = p_id;
  insert into audit_log (aksi, detail, user_id) values ('ubah_member', v_no || ' / ' || trim(p_nama), auth.uid());
end $$;

-- Cari lewat no. member (scan) atau nama / no. HP. sisa_hari dihitung server (WIB).
create or replace function cek_member(p_q text)
returns table(id uuid, no_member text, nama text, no_hp text, alamat text, berakhir date, sisa_hari int)
language sql security definer stable set search_path = public as $$
  with q as (select trim(coalesce(p_q,'')) as t),
  hasil as (
    select m.id as mid, m.no_member as mno, m.nama as mnama, m.no_hp as mhp, m.alamat as malamat,
      (select max(ms.tanggal_berakhir) from memberships ms where ms.member_id = m.id) as akhir,
      (lower(m.no_member) = lower(q.t)) as exact
    from members m cross join q
    where is_staff() and q.t <> ''
      and (lower(m.no_member) = lower(q.t)
           or m.nama ilike '%' || q.t || '%'
           or coalesce(m.no_hp,'') ilike '%' || q.t || '%')
  )
  select h.mid, h.mno, h.mnama, h.mhp, h.malamat, h.akhir, (h.akhir - wib_today())::int
  from hasil h order by h.exact desc, h.mnama limit 10
$$;

create or replace function member_aktif() returns int
language sql security definer stable set search_path = public as $$
  select case when is_staff()
    then (select count(distinct member_id)::int from memberships where tanggal_berakhir > wib_today())
    else 0 end
$$;

-- ---------- Laporan (Super Admin) ----------
drop function if exists dashboard_stats(date);
create function dashboard_stats(p_date date)
returns table(admin_id uuid, nama text, role text, pelanggan int, pendapatan bigint,
              member_baru int, pendapatan_member bigint)
language sql security definer stable set search_path = public as $$
  select p.id, p.nama, p.role,
    (select count(*) from daily_visits v where v.admin_id = p.id and not v.batal
       and (v.created_at at time zone 'Asia/Jakarta')::date = p_date)::int,
    (select coalesce(sum(v.harga),0) from daily_visits v where v.admin_id = p.id and not v.batal
       and (v.created_at at time zone 'Asia/Jakarta')::date = p_date)::bigint,
    (select count(*) from members m where m.admin_id = p.id
       and date_trunc('month', m.created_at at time zone 'Asia/Jakarta') = date_trunc('month', p_date::timestamp))::int,
    (select coalesce(sum(ms.harga),0) from memberships ms where ms.admin_id = p.id
       and date_trunc('month', ms.created_at at time zone 'Asia/Jakarta') = date_trunc('month', p_date::timestamp))::bigint
  from profiles p where is_super()
  order by p.role, p.nama
$$;

-- Gabungan data hidup + arsip bulanan (monthly_summary) sehingga tetap utuh setelah pembersihan
create or replace function rekap_bulanan(p_bulan int default 12)
returns table(bulan date, pelanggan int, pendapatan_harian bigint, member_baru int, pendapatan_member bigint)
language sql security definer stable set search_path = public as $$
  with b as (
    select (date_trunc('month', now() at time zone 'Asia/Jakarta')::date - make_interval(months => g))::date as bln
    from generate_series(0, greatest(p_bulan, 1) - 1) g
  )
  select b.bln,
    (coalesce((select s.total_pelanggan from monthly_summary s where s.bulan = b.bln), 0)
      + (select count(*) from daily_visits v where not v.batal
           and date_trunc('month', v.created_at at time zone 'Asia/Jakarta')::date = b.bln))::int,
    (coalesce((select s.pendapatan_harian from monthly_summary s where s.bulan = b.bln), 0)
      + (select coalesce(sum(v.harga),0) from daily_visits v where not v.batal
           and date_trunc('month', v.created_at at time zone 'Asia/Jakarta')::date = b.bln))::bigint,
    (select count(*) from members m
       where date_trunc('month', m.created_at at time zone 'Asia/Jakarta')::date = b.bln)::int,
    (select coalesce(sum(ms.harga),0) from memberships ms
       where date_trunc('month', ms.created_at at time zone 'Asia/Jakarta')::date = b.bln)::bigint
  from b where is_super()
  order by b.bln desc
$$;

-- ---------- Pembersihan data ----------
-- Batas waktu dibulatkan ke awal hari WIB agar hitung, ekspor, dan hapus memakai batas yang sama.
create or replace function purge_cutoff(p_bulan int) returns timestamptz
language sql security definer stable set search_path = public as $$
  select case when is_super() then
    (date_trunc('day', now() at time zone 'Asia/Jakarta') - make_interval(months => p_bulan)) at time zone 'Asia/Jakarta'
  end
$$;

create or replace function count_old_data(p_bulan int) returns int
language sql security definer stable set search_path = public as $$
  select coalesce((select count(*)::int from daily_visits where created_at < purge_cutoff(p_bulan)), 0)
$$;

create or replace function purge_old_data(p_bulan int)
returns int language plpgsql security definer set search_path = public as $$
declare n int; cutoff timestamptz;
begin
  if not is_super() then raise exception 'Hanya Super Admin'; end if;
  if p_bulan < 1 then raise exception 'Minimal 1 bulan'; end if;
  cutoff := purge_cutoff(p_bulan);
  insert into monthly_summary (bulan, total_pelanggan, pendapatan_harian)
    select date_trunc('month', created_at at time zone 'Asia/Jakarta')::date, count(*), sum(harga)
    from daily_visits where created_at < cutoff and not batal group by 1
  on conflict (bulan) do update set
    total_pelanggan = monthly_summary.total_pelanggan + excluded.total_pelanggan,
    pendapatan_harian = monthly_summary.pendapatan_harian + excluded.pendapatan_harian;
  delete from daily_visits where created_at < cutoff;
  get diagnostics n = row_count;
  insert into audit_log (aksi, detail, user_id)
    values ('purge', n || ' kunjungan sebelum ' || cutoff::date, auth.uid());
  return n;
end $$;

-- ---------- Hanya akun login yang boleh memanggil fungsi ----------
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'wib_today','is_staff','is_super','catat_kunjungan','kunjungan_saya_hari_ini',
      'batalkan_kunjungan','daftar_member','perpanjang_member','ubah_member','cek_member',
      'member_aktif','dashboard_stats','rekap_bulanan','purge_cutoff','count_old_data',
      'purge_old_data','set_staff_role')
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;
