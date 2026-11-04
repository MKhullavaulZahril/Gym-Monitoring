-- =====================================================================
-- PERBAIKAN SISTEM ROLE  (aman dijalankan berulang kali)
--  * Database yang sudah jalan : jalankan file ini saja.
--  * Instalasi baru            : jalankan schema.sql lebih dulu, lalu file ini.
-- Aturan baru: role HANYA ditentukan oleh tabel `profiles`, dan hanya
-- Super Admin yang bisa mengubahnya. Tidak ada lagi role otomatis.
-- =====================================================================

-- 1. Hapus mekanisme otomatis lama (trigger itu tidak aman: role bisa
--    dikirim sendiri lewat metadata saat sign up).
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

-- 2. Kolom tambahan
alter table profiles add column if not exists email text;
alter table profiles add column if not exists aktif boolean not null default true;
update profiles p set email = lower(u.email)
  from auth.users u where u.id = p.id and p.email is null;

-- 3. Fungsi pengecek role
create or replace function is_staff() returns boolean
language sql security definer stable set search_path = public as
$$ select exists(select 1 from profiles where id = auth.uid() and aktif) $$;

create or replace function is_super() returns boolean
language sql security definer stable set search_path = public as
$$ select exists(select 1 from profiles where id = auth.uid() and role = 'super_admin' and aktif) $$;

-- 4. Data hanya bisa dibaca/ditulis oleh akun yang punya role aktif.
--    (Orang asing yang sign up tidak bisa melihat data apa pun.)
drop policy if exists p_sel on profiles;
create policy p_sel on profiles for select to authenticated using (id = auth.uid() or is_super());
drop policy if exists p_ins on profiles;   -- insert langsung tidak diperlukan lagi
drop policy if exists p_upd on profiles;
create policy p_upd on profiles for update to authenticated using (is_super()) with check (is_super());

drop policy if exists s_sel on settings;
create policy s_sel on settings for select to authenticated using (is_staff());
drop policy if exists m_sel on members;
create policy m_sel on members for select to authenticated using (is_staff());
drop policy if exists m_ins on members;
create policy m_ins on members for insert to authenticated with check (admin_id = auth.uid() and is_staff());
drop policy if exists ms_sel on memberships;
create policy ms_sel on memberships for select to authenticated using (is_staff());
drop policy if exists ms_ins on memberships;
create policy ms_ins on memberships for insert to authenticated with check (admin_id = auth.uid() and is_staff());
drop policy if exists v_sel on daily_visits;
create policy v_sel on daily_visits for select to authenticated using ((admin_id = auth.uid() and is_staff()) or is_super());
drop policy if exists v_ins on daily_visits;
create policy v_ins on daily_visits for insert to authenticated with check (admin_id = auth.uid() and is_staff());

-- 5. Dipanggil dari menu Akun di aplikasi (khusus Super Admin)
create or replace function set_staff_role(p_email text, p_nama text, p_role text)
returns void language plpgsql security definer set search_path = public, auth as $$
declare uid uuid;
begin
  if not is_super() then raise exception 'Hanya Super Admin'; end if;
  if p_role not in ('admin','super_admin') then raise exception 'Role tidak valid'; end if;
  select id into uid from auth.users where lower(email) = lower(p_email);
  if uid is null then raise exception 'Akun % belum ada di Auth', p_email; end if;
  if uid = auth.uid() and p_role <> 'super_admin' then
    raise exception 'Tidak bisa menurunkan role akun sendiri';
  end if;
  insert into profiles (id, email, nama, role, aktif)
    values (uid, lower(p_email), p_nama, p_role, true)
  on conflict (id) do update
    set email = excluded.email, nama = excluded.nama, role = excluded.role, aktif = true;
  insert into audit_log (aksi, detail, user_id)
    values ('set_role', lower(p_email) || ' -> ' || p_role, auth.uid());
end $$;

-- 6. Hitung data lama dengan aturan yang SAMA seperti purge_old_data
create or replace function count_old_data(p_bulan int)
returns int language sql security definer stable set search_path = public as $$
  select case when is_super()
    then (select count(*)::int from daily_visits
          where created_at < now() - make_interval(months => p_bulan))
    else 0 end
$$;

-- =====================================================================
-- 7. LANGKAH WAJIB SEKALI: jadikan akunmu Super Admin
--    Syarat: akun sudah dibuat di Supabase > Authentication > Users
--    (Add user, centang Auto Confirm User).
--    GANTI email di bawah dengan email akunmu, lalu jalankan.
-- =====================================================================
insert into profiles (id, email, nama, role, aktif)
select id, lower(email), 'Super Admin', 'super_admin', true
from auth.users where lower(email) = lower('admin@gmail.com')
on conflict (id) do update
  set role = 'super_admin', aktif = true, email = excluded.email;

-- Cek hasilnya (harus muncul barisnya, role = super_admin):
select email, nama, role, aktif from profiles order by role desc, nama;
