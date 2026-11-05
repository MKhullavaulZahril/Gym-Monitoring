-- =====================================================================
-- KATEGORI HARGA: UMUM & PELAJAR  (jalankan setelah hardening.sql)
--   Harian : umum 15.000  | pelajar 10.000
--   Member : umum 150.000 | pelajar 75.000   (per 30 hari)
-- Harga tetap bisa diubah Super Admin di menu Data. Aman dijalankan ulang
-- (harga awal hanya diisi satu kali, sehingga perubahanmu tidak tertimpa).
-- =====================================================================

-- Kolom harga pelajar + isi harga awal (sekali saja)
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'settings'
                   and column_name = 'harga_harian_pelajar') then
    alter table settings add column harga_harian_pelajar int not null default 10000;
    alter table settings add column harga_member_pelajar int not null default 75000;
    update settings set harga_harian = 15000, harga_member = 150000, durasi_member_hari = 30 where id = 1;
  end if;
end $$;

-- Kolom kategori (data lama otomatis 'umum')
alter table members     add column if not exists kategori text not null default 'umum' check (kategori in ('umum','pelajar'));
alter table memberships add column if not exists kategori text not null default 'umum' check (kategori in ('umum','pelajar'));
alter table daily_visits add column if not exists kategori text not null default 'umum' check (kategori in ('umum','pelajar'));

-- Fungsi lama (tanpa kategori) dihapus agar tidak bisa dipakai melewati harga baru
drop function if exists catat_kunjungan(text, text);
drop function if exists daftar_member(text, text, text, text, text);
drop function if exists perpanjang_member(uuid, text);
drop function if exists cek_member(text);
drop function if exists kunjungan_saya_hari_ini();

create or replace function catat_kunjungan(p_nama text, p_tipe text, p_kategori text)
returns int language plpgsql security definer set search_path = public as $$
declare s settings%rowtype; h int;
begin
  if not is_staff() then raise exception 'Akun tidak punya akses'; end if;
  if p_tipe not in ('Tunai','Transfer','QRIS') then raise exception 'Tipe pembayaran tidak valid'; end if;
  if p_kategori not in ('umum','pelajar') then raise exception 'Kategori tidak valid'; end if;
  select * into s from settings where id = 1;
  h := case when p_kategori = 'pelajar' then s.harga_harian_pelajar else s.harga_harian end;
  insert into daily_visits (nama_pelanggan, kategori, harga, tipe_pembayaran, admin_id)
    values (nullif(trim(coalesce(p_nama,'')), ''), p_kategori, h, p_tipe, auth.uid());
  return h;
end $$;

create or replace function kunjungan_saya_hari_ini()
returns table(id uuid, nama_pelanggan text, kategori text, harga int, tipe_pembayaran text, waktu timestamptz, batal boolean)
language sql security definer stable set search_path = public as $$
  select v.id, v.nama_pelanggan, v.kategori, v.harga, v.tipe_pembayaran, v.created_at, v.batal
  from daily_visits v
  where v.admin_id = auth.uid() and is_staff()
    and (v.created_at at time zone 'Asia/Jakarta')::date = wib_today()
  order by v.created_at desc limit 100
$$;

create or replace function daftar_member(p_no text, p_nama text, p_hp text, p_alamat text, p_tipe text, p_kategori text)
returns int language plpgsql security definer set search_path = public as $$
declare s settings%rowtype; mid uuid; h int; v_no text := trim(coalesce(p_no,''));
begin
  if not is_staff() then raise exception 'Akun tidak punya akses'; end if;
  if v_no = '' or trim(coalesce(p_nama,'')) = '' then raise exception 'No. member dan nama wajib diisi'; end if;
  if p_tipe not in ('Tunai','Transfer','QRIS') then raise exception 'Tipe pembayaran tidak valid'; end if;
  if p_kategori not in ('umum','pelajar') then raise exception 'Kategori tidak valid'; end if;
  if exists (select 1 from members where lower(no_member) = lower(v_no)) then
    raise exception 'No. member % sudah terpakai', v_no;
  end if;
  select * into s from settings where id = 1;
  h := case when p_kategori = 'pelajar' then s.harga_member_pelajar else s.harga_member end;
  insert into members (no_member, nama, no_hp, alamat, kategori, admin_id)
    values (v_no, trim(p_nama), nullif(trim(coalesce(p_hp,'')), ''), nullif(trim(coalesce(p_alamat,'')), ''), p_kategori, auth.uid())
    returning id into mid;
  insert into memberships (member_id, tanggal_mulai, tanggal_berakhir, harga, tipe_pembayaran, kategori, admin_id)
    values (mid, wib_today(), wib_today() + s.durasi_member_hari, h, p_tipe, p_kategori, auth.uid());
  return h;
end $$;

create or replace function perpanjang_member(p_member_id uuid, p_tipe text, p_kategori text)
returns int language plpgsql security definer set search_path = public as $$
declare s settings%rowtype; h int; akhir date; mulai date;
begin
  if not is_staff() then raise exception 'Akun tidak punya akses'; end if;
  if p_tipe not in ('Tunai','Transfer','QRIS') then raise exception 'Tipe pembayaran tidak valid'; end if;
  if p_kategori not in ('umum','pelajar') then raise exception 'Kategori tidak valid'; end if;
  if not exists (select 1 from members where id = p_member_id) then raise exception 'Member tidak ditemukan'; end if;
  select * into s from settings where id = 1;
  h := case when p_kategori = 'pelajar' then s.harga_member_pelajar else s.harga_member end;
  select max(tanggal_berakhir) into akhir from memberships where member_id = p_member_id;
  mulai := greatest(wib_today(), coalesce(akhir, wib_today()));
  insert into memberships (member_id, tanggal_mulai, tanggal_berakhir, harga, tipe_pembayaran, kategori, admin_id)
    values (p_member_id, mulai, mulai + s.durasi_member_hari, h, p_tipe, p_kategori, auth.uid());
  update members set kategori = p_kategori, updated_at = now() where id = p_member_id;
  return h;
end $$;

create or replace function cek_member(p_q text)
returns table(id uuid, no_member text, nama text, no_hp text, alamat text, kategori text, berakhir date, sisa_hari int)
language sql security definer stable set search_path = public as $$
  with q as (select trim(coalesce(p_q,'')) as t),
  hasil as (
    select m.id as mid, m.no_member as mno, m.nama as mnama, m.no_hp as mhp, m.alamat as malamat,
      m.kategori as mkat,
      (select max(ms.tanggal_berakhir) from memberships ms where ms.member_id = m.id) as akhir,
      (lower(m.no_member) = lower(q.t)) as exact
    from members m cross join q
    where is_staff() and q.t <> ''
      and (lower(m.no_member) = lower(q.t)
           or m.nama ilike '%' || q.t || '%'
           or coalesce(m.no_hp,'') ilike '%' || q.t || '%')
  )
  select h.mid, h.mno, h.mnama, h.mhp, h.malamat, h.mkat, h.akhir, (h.akhir - wib_today())::int
  from hasil h order by h.exact desc, h.mnama limit 10
$$;

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in
      ('catat_kunjungan','daftar_member','perpanjang_member','cek_member','kunjungan_saya_hari_ini')
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;

notify pgrst, 'reload schema';
